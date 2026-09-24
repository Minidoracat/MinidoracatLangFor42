# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
jev_scan.py — 譯文三方比對雷達（Jev 批次判讀，report-only）

拿我方 CH 譯文、官方 EN 原文、官方 CH 譯文三方對齊，逐鍵丟給 Jev（TypeSafe systemone）
問四個獨立的是非題，產出「可疑鍵」清單供人工審查。

**本工具只產報告，絕不修改任何翻譯真相檔。**

四題（皆為 noul，回傳 0..1 機率）：
  s2t_error          我方譯文是否有簡轉繁一簡對多繁誤轉或殘留簡體字
  prc_wording        我方譯文是否用了大陸慣用詞而台灣慣用另一個詞
  meaning_mismatch   我方譯文語意是否與官方 EN 不一致（漏譯／誤譯／多譯）
  worse_than_official 我方譯文是否明顯不如官方 CH（無官方 CH 時不問）

資料來源（以「檔名|鍵」對齊）：
  我方 CH  MOD/MinidoracatLangFor42/Contents/mods/.../Translate/CH/*.json
  官方 EN  <PZ>/media/lua/shared/Translate/EN/<同檔名>.json
  官方 CH  <PZ>/media/lua/shared/Translate/CH/<同檔名>.json（缺檔則該欄留空、不問第四題）

濾網：EN 值為空白或 `Placeholder` 的鍵直接跳過；RadioData／Recorded_Media 分句文本
與官方 CH 去標點空白後相同者只問前兩題（語意題與優劣題對其無鑑別力）。

環境變數：TYPESAFE_BASE_URL / TYPESAFE_API_KEY / TYPESAFE_DEFAULT_MODEL

使用方式：
  uv run scripts/jev_scan.py --dry-run
  uv run scripts/jev_scan.py --sample 300
  uv run scripts/jev_scan.py --files "ItemName.json" --threshold 0.6
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import os
import random
import sys
import time
import unicodedata
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
CH_DIR = (
    PROJECT_ROOT
    / "MOD/MinidoracatLangFor42/Contents/mods/MinidoracatLangFor42/42"
    / "media/lua/shared/Translate/CH"
)
DEFAULT_PZ_DIR = Path("D:/SteamLibrary/steamapps/common/ProjectZomboid")

SEED = 42
MAX_QUESTIONS = 32
INPUT_USD_PER_MTOK = 0.042  # 輸出免費

# ---------------------------------------------------------------- 題目定義

Q_S2T = (
    "把 `ours_ch` 逐字讀過，判斷是否存在**寫錯的漢字**。錯字有兩種："
    "(1) 簡轉繁一簡對多繁選錯：乾燥誤寫成幹燥、頭髮誤寫成頭發、麵條誤寫成面條、"
    "裡面誤寫成里面、以後誤寫成以后、複製誤寫成復製、系統誤寫成係統、戰鬥誤寫成戰斗；"
    "(2) 殘留簡體字形：这个东西、开门、发现、义、过、广。"
    "注意：「這」「個」「東西」「裡面」「開門」「以後」「乾淨」本身都是**正確**的台灣正體寫法，"
    "看到它們不算錯。指不出具體某一個字寫錯，就判 false。不評斷翻譯是否貼切。"
)
Q_S2T_TRUE = "能明確指出某個字寫錯了，並說得出它在台灣正體中應該寫成哪個字（例：「幹燥」的「幹」應為「乾」）。"
Q_S2T_FALSE = "逐字看完，每個字都是台灣正體的正確寫法，指不出任何錯字。"

Q_PRC = (
    "只看 `ours_ch` 的**詞彙選用**：是否使用中國大陸慣用詞，而台灣對同一概念慣用另一個詞"
    "（默認→預設、信息→訊息、軟件→軟體、視頻→影片、菜單→選單、界面→介面、兼容→相容、"
    "加載→載入、優化→最佳化、質量→品質、網絡→網路、屏幕→螢幕、內存→記憶體、激活→啟用、"
    "打印→列印、鼠標→滑鼠、缺省→預設、數據→資料）。兩岸通用的詞不算。"
)
Q_PRC_TRUE = "至少有一個詞是大陸慣用而台灣對同一概念慣用另一個詞。"
Q_PRC_FALSE = "所有詞彙在台灣中文都是自然慣用的說法。"

Q_MEANING = (
    "比較 `ours_ch` 與 `en` 的**語意內容**：是否漏掉英文有的資訊、譯錯意思、"
    "或加入英文沒有的內容。純粹的在地化意譯（語序調整、遊戲術語慣用譯法、"
    "省略冠詞、標點差異、把專有名詞保留英文）不算不一致。"
)
Q_MEANING_TRUE = "中文與英文指涉的事物或動作不同，或明顯漏譯／多譯了實質資訊。"
Q_MEANING_FALSE = "中文忠實傳達了英文的意思，差異僅在文體或在地化表達。"

Q_WORSE = (
    "拿 `ours_ch` 與官方譯文 `official_ch` 相比（兩者都對應同一個 `en`）："
    "我方是否**明顯較差**——語意錯得更多、漏譯、用字錯誤、或明顯不如官方通順。"
    "只是用詞選擇不同、或我方更在地化而兩者都正確，不算較差。"
)
Q_WORSE_TRUE = "能說出我方在語意正確性或用字上具體差在哪裡，官方版本明顯較佳。"
Q_WORSE_FALSE = "我方與官方品質相當或更好，挑不出我方明顯較差之處。"


def _noul(instructions: str, yes: str, no: str) -> dict:
    return {
        "type": "noul",
        "instructions": instructions,
        "criteria": {"true": yes, "false": no},
    }


SENTENCE_FILES = {"RadioData.json", "Recorded_Media.json"}


def normalize_text(text: str) -> str:
    """去除標點與空白，供分句文本與官方 CH 比對是否實質相同。"""
    return "".join(
        c for c in text if not (c.isspace() or unicodedata.category(c).startswith("P"))
    )


def same_as_official(item: dict) -> bool:
    """分句文本（RadioData／Recorded_Media）與官方 CH 去標點空白後相同：
    語意題與優劣題對它們沒有鑑別力，只問用字兩題。"""
    return (
        item["file"] in SENTENCE_FILES
        and bool(item["official_ch"])
        and normalize_text(item["ours_ch"]) == normalize_text(item["official_ch"])
    )


def is_placeholder_en(en: str) -> bool:
    return en.strip().rstrip(".").lower() == "placeholder"


def questions_for(has_official: bool, prefix: str = "", wording_only: bool = False) -> dict:
    """單一鍵的題組；`prefix` 非空時用於 batch 模式（題名 `k3.s2t_error`）。
    `wording_only` 時只問 s2t_error／prc_wording。"""
    where = f"（只針對 `items.{prefix}`）" if prefix else ""
    p = f"{prefix}." if prefix else ""
    qs = {
        f"{p}s2t_error": _noul(where + Q_S2T, Q_S2T_TRUE, Q_S2T_FALSE),
        f"{p}prc_wording": _noul(where + Q_PRC, Q_PRC_TRUE, Q_PRC_FALSE),
    }
    if wording_only:
        return qs
    qs[f"{p}meaning_mismatch"] = _noul(where + Q_MEANING, Q_MEANING_TRUE, Q_MEANING_FALSE)
    if has_official:
        qs[f"{p}worse_than_official"] = _noul(where + Q_WORSE, Q_WORSE_TRUE, Q_WORSE_FALSE)
    return qs


METRICS = ("s2t_error", "prc_wording", "meaning_mismatch", "worse_than_official")

# ---------------------------------------------------------------- 資料載入


def load_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as fh:
        data = json.load(fh)
    if not isinstance(data, dict):
        raise ValueError(f"{path} 不是平面 dict")
    return data


def load_pairs(pz_dir: Path, files_glob: str | None) -> tuple[list[dict], dict[str, int]]:
    """回傳 (待掃項目, 統計)。項目形狀 {file,key,en,official_ch,ours_ch}。"""
    if not CH_DIR.is_dir():
        sys.exit(f"找不到我方 CH 目錄：{CH_DIR}")
    en_dir = pz_dir / "media/lua/shared/Translate/EN"
    official_ch_dir = pz_dir / "media/lua/shared/Translate/CH"
    if not en_dir.is_dir():
        sys.exit(f"找不到官方 EN 目錄：{en_dir}（用 --pz-dir 指定 PZ 安裝路徑）")

    items: list[dict] = []
    stats = {"total": 0, "no_en": 0, "placeholder_en": 0, "no_official_ch": 0, "skipped_nonstr": 0}
    for path in sorted(CH_DIR.glob("*.json")):
        if files_glob and not fnmatch.fnmatch(path.name, files_glob):
            continue
        ours = load_json(path)
        en_path = en_dir / path.name
        och_path = official_ch_dir / path.name
        en_map = load_json(en_path) if en_path.is_file() else {}
        och_map = load_json(och_path) if och_path.is_file() else {}
        for key, value in ours.items():
            stats["total"] += 1
            if not isinstance(value, str) or not value.strip():
                stats["skipped_nonstr"] += 1
                continue
            en = en_map.get(key)
            if not isinstance(en, str) or not en.strip():
                stats["no_en"] += 1
                continue
            if is_placeholder_en(en):
                stats["placeholder_en"] += 1
                continue
            official = och_map.get(key)
            official = official if isinstance(official, str) and official.strip() else ""
            if not official:
                stats["no_official_ch"] += 1
            items.append(
                {
                    "file": path.name,
                    "key": key,
                    "en": en,
                    "official_ch": official,
                    "ours_ch": value,
                }
            )
    return items, stats


# ---------------------------------------------------------------- Jev 呼叫


def state_of(item: dict) -> dict:
    st = {"key": item["key"], "en": item["en"], "ours_ch": item["ours_ch"]}
    if item["official_ch"]:
        st["official_ch"] = item["official_ch"]
    return st


def _questions(item: dict, prefix: str = "") -> dict:
    return questions_for(bool(item["official_ch"]), prefix, wording_only=same_as_official(item))


def build_request(batch: list[dict], model: str) -> tuple[dict, list[str]]:
    """回傳 (payload, 每個項目的題名前綴)。batch 長度 1 時不加前綴。"""
    if len(batch) == 1:
        return {"model": model, "state": state_of(batch[0]),
                "questions": _questions(batch[0])}, [""]
    prefixes = [f"k{i + 1}" for i in range(len(batch))]
    state = {"items": {p: state_of(it) for p, it in zip(prefixes, batch)}}
    questions: dict = {}
    for prefix, item in zip(prefixes, batch):
        questions.update(_questions(item, prefix))
    return {"model": model, "state": state, "questions": questions}, prefixes


def estimate_tokens(payload: dict) -> int:
    """粗估 input token。係數由實測擬合：CJK 約 1.5 tok/字、其餘約 0.4 tok/字元
    （6 次實測 payload 誤差 <1%）。"""
    text = json.dumps(payload, ensure_ascii=False)
    cjk = sum(1 for ch in text if "\u3400" <= ch <= "\u9fff")
    return round(1.5 * cjk + 0.4 * (len(text) - cjk))


def call_jev(payload: dict, url: str, api_key: str, retries: int = 2) -> dict:
    data = json.dumps(payload).encode("utf-8")
    last: Exception | None = None
    for attempt in range(retries + 1):
        req = urllib.request.Request(
            url,
            data=data,
            headers={"Content-Type": "application/json",
                     "Authorization": f"Bearer {api_key}"},
        )
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except Exception as exc:  # noqa: BLE001 — 任何失敗都重試，最後照實往上拋
            last = exc
            if isinstance(exc, urllib.error.HTTPError):
                try:
                    last = RuntimeError(f"HTTP {exc.code}: {exc.read().decode('utf-8', 'replace')[:300]}")
                except Exception:  # noqa: BLE001
                    last = RuntimeError(f"HTTP {exc.code}")
            if attempt < retries:
                time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(str(last))


def scan_batch(batch: list[dict], url: str, api_key: str, model: str) -> list[dict]:
    payload, prefixes = build_request(batch, model)
    resp = call_jev(payload, url, api_key)
    answers = resp.get("answers") or {}
    usage = resp.get("usage") or {}
    n = len(batch)
    rows = []
    for prefix, item in zip(prefixes, batch):
        p = f"{prefix}." if prefix else ""
        row = dict(item)
        probs = {}
        for metric in METRICS:
            ans = answers.get(f"{p}{metric}")
            probs[metric] = round(float(ans["noul"]), 4) if ans and "noul" in ans else None
        row.update(probs)
        row["max_prob"] = max((v for v in probs.values() if v is not None), default=0.0)
        row["model"] = resp.get("model", model)
        # batch 模式的 usage 是整批共用，平均攤到每一列以維持總量正確
        row["input_tokens"] = round(usage.get("input_tokens", 0) / n, 2)
        row["output_tokens"] = round(usage.get("output_tokens", 0) / n, 2)
        row["cost_usd"] = round(usage.get("cost", 0.0) / n, 8)
        rows.append(row)
    return rows


# ---------------------------------------------------------------- 輸出

TSV_COLUMNS = (
    "file", "key", "max_prob", "s2t_error", "prc_wording", "meaning_mismatch",
    "worse_than_official", "en", "official_ch", "ours_ch", "model",
    "input_tokens", "output_tokens", "cost_usd",
)


def tsv_cell(value) -> str:
    if value is None:
        return ""
    return str(value).replace("\t", "\\t").replace("\n", "\\n").replace("\r", "")


def sidecar(prefix: Path, ext: str) -> Path:
    return prefix.with_name(prefix.name + ext)


def write_reports(out_prefix: Path, rows: list[dict], errors: list[dict]) -> None:
    out_prefix.parent.mkdir(parents=True, exist_ok=True)
    # 前綴含時間戳（jev_scan.20260919-215649），with_suffix 會把它當副檔名吃掉
    with sidecar(out_prefix, ".jsonl").open("w", encoding="utf-8", newline="\n") as fh:
        for row in rows:
            fh.write(json.dumps(row, ensure_ascii=False) + "\n")
    with sidecar(out_prefix, ".tsv").open("w", encoding="utf-8", newline="\n") as fh:
        fh.write("\t".join(TSV_COLUMNS) + "\n")
        for row in rows:
            fh.write("\t".join(tsv_cell(row.get(c)) for c in TSV_COLUMNS) + "\n")
    if errors:
        with sidecar(out_prefix, ".errors.jsonl").open("w", encoding="utf-8", newline="\n") as fh:
            for err in errors:
                fh.write(json.dumps(err, ensure_ascii=False) + "\n")


# ---------------------------------------------------------------- 主流程


def main() -> int:
    ap = argparse.ArgumentParser(description="譯文三方比對雷達（Jev，report-only）")
    ap.add_argument("--pz-dir", type=Path, default=DEFAULT_PZ_DIR, help="PZ 安裝根目錄")
    ap.add_argument("--files", help="只掃符合此 glob 的檔名，例：'ItemName.json'")
    ap.add_argument("--sample", type=int, help="隨機抽樣 N 鍵（seed 42）")
    ap.add_argument("--threshold", type=float, default=0.5, help="可疑判定機率門檻")
    ap.add_argument("--batch", type=int, default=1, help="每個請求塞幾個鍵（省 token）")
    ap.add_argument("--workers", type=int, default=8, help="並行請求數")
    ap.add_argument("--out", type=Path, help="輸出前綴，預設 reports/jev_scan.<ts>")
    ap.add_argument("--dry-run", action="store_true", help="只算鍵數與估算成本，不打 API")
    args = ap.parse_args()

    if args.batch < 1:
        sys.exit("--batch 至少為 1")
    max_batch = MAX_QUESTIONS // len(METRICS)
    if args.batch > max_batch:
        sys.exit(f"--batch 上限 {max_batch}（每請求最多 {MAX_QUESTIONS} 題）")

    items, stats = load_pairs(args.pz_dir, args.files)
    if args.sample and args.sample < len(items):
        random.Random(SEED).shuffle(items)
        items = items[: args.sample]

    batches = [items[i : i + args.batch] for i in range(0, len(items), args.batch)]
    est_tokens = sum(estimate_tokens(build_request(b, "m")[0]) for b in batches)
    est_cost = est_tokens / 1_000_000 * INPUT_USD_PER_MTOK

    print(f"我方 CH 鍵總數      {stats['total']}")
    print(f"  無 EN 錨點（跳過） {stats['no_en']}")
    print(f"  EN 為 Placeholder（跳過）{stats['placeholder_en']}")
    print(f"  空值／非字串（跳過）{stats['skipped_nonstr']}")
    print(f"待掃鍵數            {len(items)}（其中無官方 CH {sum(1 for i in items if not i['official_ch'])}）")
    print(f"請求數              {len(batches)}（batch={args.batch}）")
    print(f"估算 input token    {est_tokens:,}")
    print(f"估算成本            ${est_cost:.4f}")
    if args.dry_run:
        return 0

    base_url = os.environ.get("TYPESAFE_BASE_URL")
    api_key = os.environ.get("TYPESAFE_API_KEY")
    model = os.environ.get("TYPESAFE_DEFAULT_MODEL")
    if not (base_url and api_key and model):
        sys.exit("缺少 TYPESAFE_BASE_URL / TYPESAFE_API_KEY / TYPESAFE_DEFAULT_MODEL 環境變數")
    url = base_url.rstrip("/") + "/v1/systemone"

    rows: list[dict] = []
    errors: list[dict] = []
    started = time.time()
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {pool.submit(scan_batch, b, url, api_key, model): b for b in batches}
        done = 0
        for future, batch in futures.items():
            done += 1
            try:
                rows.extend(future.result())
            except Exception as exc:  # noqa: BLE001 — 重試耗盡，記錄後續跑
                errors.append({"keys": [f"{i['file']}|{i['key']}" for i in batch],
                               "error": str(exc)})
                print(f"[跳過] {batch[0]['file']}|{batch[0]['key']} … {exc}", file=sys.stderr)
            if done % 50 == 0:
                print(f"  …{done}/{len(batches)}", file=sys.stderr)
    elapsed = time.time() - started

    rows.sort(key=lambda r: r["max_prob"], reverse=True)
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    out_prefix = args.out or (PROJECT_ROOT / "reports" / f"jev_scan.{ts}")
    write_reports(out_prefix, rows, errors)

    actual_tokens = sum(r["input_tokens"] for r in rows)
    actual_cost = sum(r["cost_usd"] for r in rows)
    print("\n—— 掃描結果 ——")
    print(f"已判讀              {len(rows)} 鍵 / 失敗跳過 {len(errors)} 批")
    for metric in METRICS:
        hits = sum(1 for r in rows if (r.get(metric) or 0) >= args.threshold)
        asked = sum(1 for r in rows if r.get(metric) is not None)
        print(f"  {metric:<20} ≥{args.threshold}: {hits}（有問 {asked} 題）")
    flagged = sum(1 for r in rows if r["max_prob"] >= args.threshold)
    print(f"任一題超過門檻      {flagged}")
    print(f"實際 input token    {actual_tokens:,.0f}")
    print(f"實際成本            ${actual_cost:.4f}")
    print(f"耗時                {elapsed:.1f}s")
    print(f"報告                {out_prefix}.jsonl / .tsv")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
