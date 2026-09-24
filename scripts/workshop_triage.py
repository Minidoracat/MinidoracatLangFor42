# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
# -*- coding: utf-8 -*-
"""Steam Workshop 留言批次分類（Jev 雷達）。

用法：
    uv run scripts/workshop_triage.py                      # 預設兩個 ID 的快照
    uv run scripts/workshop_triage.py --id 3386633401
    uv run scripts/workshop_triage.py --from-json reports/workshop_comments.3386633401.json
    uv run scripts/workshop_triage.py --limit 5            # 冒煙用，只跑前 5 則

只讀不寫：本腳本不回覆留言、不登入 Steam、不改任何翻譯檔，只產出報告。

為什麼分兩段（抓取／分類）：
Steam 的留言分頁是 AJAX，第一頁 HTML 只有 10 則，靠 reader 或 Web API 拿不到全部。
所以抓取必須真的開瀏覽器翻頁（見 BROWSER_SCRAPE_JS），結果落地成
reports/workshop_comments.<id>.json；本腳本本身維持 stdlib，不依賴 playwright。

輸出：
    reports/workshop_triage.<ts>.jsonl  每列一則留言＋完整機率分佈
    reports/workshop_triage.<ts>.tsv    同樣資料的扁平版（丟進試算表排序用）
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
REPORTS = REPO / "reports"

# workshop_id -> state 裡的 mod 欄位值（Jev 要靠這個分辨兩包的責任範圍）
MODS = {
    "3386633401": "本體翻譯 MOD",
    "3765907717": "模組翻譯包",
}

# MOD 作者本人的留言多半是回覆玩家，不該被排進「待處理」。把這件事當成 state 的
# 一個欄位交給 Jev，而不是直接過濾掉——作者的公告有時也帶著待辦資訊。
MOD_AUTHOR = "minidoracat"

ENDPOINT = "/v1/systemone"
PRICE_PER_MTOK_IN = 0.042  # 輸出免費，只算輸入

# 抓取留言用的瀏覽器腳本。放在這裡是為了讓「怎麼抓」跟「怎麼分類」同一個檔案可查；
# 實際執行是在有 browser 的環境（omp eval 的 tab.evaluate）裡貼上這段，
# 反覆點 pagebtn_next 直到 disabled，每頁以 comment id 去重。
BROWSER_SCRAPE_JS = r"""
// 單頁擷取：回傳本頁留言 + 是否還有下一頁
(() => {
  const out = [];
  for (const el of document.querySelectorAll('.commentthread_comment')) {
    const a = el.querySelector('.commentthread_author_link');
    const ts = el.querySelector('.commentthread_comment_timestamp[data-timestamp]');
    const tx = el.querySelector('.commentthread_comment_text');
    out.push({
      id: (el.id || '').replace('comment_', ''),
      author: a ? a.innerText.trim() : null,
      author_url: a ? a.href : null,
      posted_at: ts ? (ts.getAttribute('title') || ts.innerText.trim()) : null,
      posted_ts: ts ? Number(ts.getAttribute('data-timestamp') || 0) : 0,
      text: tx ? tx.innerText.trim() : ''
    });
  }
  const next = document.querySelector('[id$="_pagebtn_next"]');
  return { rows: out, hasNext: !!next && !next.className.includes('disabled') };
})()
// 翻頁：document.querySelector('[id$="_pagebtn_next"]').click()
// 然後輪詢第一則留言的 id 換掉才算載入完成（AJAX 沒有 load 事件）
"""

QUESTIONS = {
    "kind": {
        "type": "choice",
        "instructions": "依 `text` 判斷這則 Workshop 留言的主要類型；`mod` 是這則留言所屬的翻譯包。",
        "criteria": {
            "bug": "回報遊戲內顯示錯誤、崩潰、排版壞掉或功能失效",
            "translation_error": "指出用字錯誤、簡繁誤轉、或某句翻錯了",
            "missing_translation": "指出某處仍是英文、沒被翻到",
            "request": "希望支援某個 MOD、或要求新增功能",
            "praise": "感謝、稱讚、單純表達喜歡",
            "question": "詢問用法、安裝方式或與其他 MOD 的相容性",
            "other": "以上都不是（閒聊、無意義字串、系統提示、作者自己的公告）",
        },
    },
    "needs_reply": {
        "type": "noul",
        "instructions": "`text` 是否明確在等 MOD 作者回應（提問、請求、或回報後等待處理）？"
                        "`by_mod_author` 為 true 代表這是 MOD 作者自己寫的（通常是在回覆別人），這種不需要回覆。",
    },
    "urgency": {
        "type": "score",
        "instructions": "依 `text` 判斷 MOD 作者需要多快處理這則留言；"
                        "`by_mod_author` 為 true 的留言是作者自己的回覆或公告，不是待辦。",
        "criteria": [
            "閒聊或稱讚，不需處理",
            "有具體問題但可等下次更新",
            "多人受影響或阻斷遊玩，應盡快處理",
        ],
    },
    "mentions_specific_text": {
        "type": "noul",
        "instructions": "`text` 是否引用了具體的遊戲內文字、物品名或 MOD 名稱，讓作者能直接定位到出處？",
    },
}


def fetch_comments(workshop_id: str, from_json: str | None = None) -> dict:
    """讀入某個 Workshop 項目的留言快照。

    快照由瀏覽器分頁抓取產生（見 BROWSER_SCRAPE_JS），格式：
        {"workshop_id", "mod", "title", "pages", "comments": [{id, author, posted_at, text, ...}]}
    找不到就直接失敗——寧可停下來也不要拿半套資料去跑分類。
    """
    path = Path(from_json) if from_json else REPORTS / f"workshop_comments.{workshop_id}.json"
    if not path.is_absolute():
        path = REPO / path
    if not path.exists():
        raise SystemExit(
            f"找不到留言快照：{path}\n"
            f"請先用瀏覽器開 https://steamcommunity.com/sharedfiles/filedetails/?id={workshop_id} ，\n"
            f"以 BROWSER_SCRAPE_JS 逐頁抓取後存成該檔（Steam 留言是 AJAX 分頁，只讀第一頁會少九成）。"
        )
    data = json.loads(path.read_text(encoding="utf-8"))
    data.setdefault("workshop_id", workshop_id)
    data.setdefault("mod", MODS.get(workshop_id, workshop_id))
    return data


def _post(payload: dict) -> dict:
    base = os.environ["TYPESAFE_BASE_URL"].rstrip("/")
    req = urllib.request.Request(
        base + ENDPOINT,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={
            "Authorization": "Bearer " + os.environ["TYPESAFE_API_KEY"],
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        return json.loads(resp.read().decode("utf-8"))


def by_mod_author(comment: dict) -> bool:
    """判斷是否為 MOD 作者本人的留言（Steam 顯示名稱可能改，連結 id 較穩，兩者都看）。"""
    haystack = f"{comment.get('author') or ''} {comment.get('author_url') or ''}".lower()
    return MOD_AUTHOR in haystack


def classify(comment: dict, mod: str, model: str, attempts: int = 3) -> dict:
    """單則留言送 Jev；失敗重試到 attempts 次，全敗則回傳帶 error 的結果（不吞錯）。"""
    payload = {
        "model": model,
        "state": {
            "author": comment.get("author") or "",
            "posted_at": comment.get("posted_at") or "",
            "text": comment.get("text") or "",
            "mod": mod,
            "by_mod_author": by_mod_author(comment),
        },
        "questions": QUESTIONS,
    }
    last = ""
    for i in range(attempts):
        try:
            return _post(payload)
        except urllib.error.HTTPError as e:
            last = f"HTTP {e.code}: {e.read().decode('utf-8', 'replace')[:300]}"
        except Exception as e:  # 連線／逾時／JSON 壞掉都算這類
            last = f"{type(e).__name__}: {e}"
        if i < attempts - 1:
            time.sleep(1.5 * (i + 1))
    return {"error": last}


def to_row(comment: dict, src: dict, resp: dict) -> dict:
    """把一則留言 + Jev 回應攤平成輸出列；失敗的留言也保留一列並標 error。"""
    ans = resp.get("answers") or {}
    kind = ans.get("kind") or {}
    urgency = ans.get("urgency") or {}
    usage = resp.get("usage") or {}
    kind_choice = kind.get("choice")
    needs_reply = float((ans.get("needs_reply") or {}).get("noul") or 0.0)
    urgency_score = float(urgency.get("score") or 0.0)
    return {
        "workshop_id": src["workshop_id"],
        "mod": src["mod"],
        "comment_id": comment.get("id"),
        "author": comment.get("author"),
        "author_url": comment.get("author_url"),
        "posted_at": comment.get("posted_at"),
        "posted_ts": comment.get("posted_ts"),
        "text": comment.get("text") or "",
        "by_mod_author": by_mod_author(comment),
        "kind": kind_choice,
        "kind_prob": float((kind.get("probabilities") or {}).get(kind_choice, 0.0)) if kind_choice else 0.0,
        "kind_confidence": kind.get("confidence"),
        "kind_probabilities": kind.get("probabilities"),
        "needs_reply": needs_reply,
        "urgency": urgency_score,
        "urgency_confidence": urgency.get("confidence"),
        "urgency_probabilities": urgency.get("probabilities"),
        "mentions_specific_text": float((ans.get("mentions_specific_text") or {}).get("noul") or 0.0),
        # 排序鍵：急迫度 × 是否在等回覆——只急不等人（例如作者自己的公告）會被壓下去
        "priority": round(urgency_score * needs_reply, 4),
        "model": resp.get("model"),
        "input_tokens": usage.get("input_tokens", 0),
        "output_tokens": usage.get("output_tokens", 0),
        "cost": usage.get("cost", 0.0),
        "error": resp.get("error"),
    }


TSV_COLS = [
    "priority", "urgency", "needs_reply", "kind", "kind_prob", "mentions_specific_text",
    "mod", "workshop_id", "comment_id", "author", "by_mod_author", "posted_at", "text", "model",
    "input_tokens", "output_tokens", "cost", "error",
]


def tsv_cell(value) -> str:
    if value is None:
        return ""
    return str(value).replace("\t", " ").replace("\r", " ").replace("\n", "\\n")


def write_reports(rows: list[dict], out_dir: Path, stamp: str) -> tuple[Path, Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    jsonl = out_dir / f"workshop_triage.{stamp}.jsonl"
    tsv = out_dir / f"workshop_triage.{stamp}.tsv"
    with jsonl.open("w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
    with tsv.open("w", encoding="utf-8") as f:
        f.write("\t".join(TSV_COLS) + "\n")
        for row in rows:
            f.write("\t".join(tsv_cell(row.get(c)) for c in TSV_COLS) + "\n")
    return jsonl, tsv


def summarize(rows: list[dict], failures: list[dict]) -> None:
    total = len(rows)
    kinds: dict[str, int] = {}
    for row in rows:
        kinds[row["kind"] or "(失敗)"] = kinds.get(row["kind"] or "(失敗)", 0) + 1
    in_tok = sum(r["input_tokens"] for r in rows)
    out_tok = sum(r["output_tokens"] for r in rows)
    cost = sum(r["cost"] or 0.0 for r in rows)
    print(f"\n留言總數：{total}（分類失敗 {len(failures)}）")
    print("各類別計數：")
    for k, v in sorted(kinds.items(), key=lambda kv: -kv[1]):
        print(f"  {k:<22} {v}")
    print(f"needs_reply > 0.7：{sum(1 for r in rows if r['needs_reply'] > 0.7)} 則")
    print(f"urgency >= 1.5：{sum(1 for r in rows if r['urgency'] >= 1.5)} 則")

    print("\n前 10 筆待處理（依 urgency×needs_reply）：")
    for i, row in enumerate(rows[:10], 1):
        text = (row["text"] or "").replace("\n", " ")
        print(f"{i:>2}. [{row['priority']:.2f}] {row['author']} / {row['posted_at']} / {row['mod']}")
        print(f"    {row['kind']}({row['kind_prob']:.2f}) reply={row['needs_reply']:.2f} "
              f"urg={row['urgency']:.2f} specific={row['mentions_specific_text']:.2f}")
        print(f"    {text[:110]}")

    print(f"\ntoken：輸入 {in_tok} / 輸出 {out_tok}；API 回報成本 ${cost:.6f}"
          f"（依 ${PRICE_PER_MTOK_IN}/MTok 估算輸入 ${in_tok * PRICE_PER_MTOK_IN / 1e6:.6f}）")
    if failures:
        print(f"\n[警告] {len(failures)} 則重試後仍失敗，已跳過：", file=sys.stderr)
        for row in failures:
            print(f"  {row['workshop_id']}/{row['comment_id']} {row['error']}", file=sys.stderr)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Steam Workshop 留言批次分類（Jev）")
    ap.add_argument("--id", action="append", default=None,
                    help=f"Workshop 項目 ID，可重複；預設 {', '.join(MODS)}")
    ap.add_argument("--from-json", default=None, help="直接指定留言快照檔（只能搭配單一 --id）")
    ap.add_argument("--out-dir", default=str(REPORTS), help="報告輸出目錄（預設 reports/）")
    ap.add_argument("--workers", type=int, default=8, help="並行請求數（預設 8）")
    ap.add_argument("--limit", type=int, default=0, help="每個 ID 只跑前 N 則（冒煙測試用）")
    args = ap.parse_args(argv)

    ids = args.id or list(MODS)
    if args.from_json and len(ids) != 1:
        ap.error("--from-json 只能搭配單一 --id")
    model = os.environ.get("TYPESAFE_DEFAULT_MODEL")
    if not model or not os.environ.get("TYPESAFE_API_KEY") or not os.environ.get("TYPESAFE_BASE_URL"):
        raise SystemExit("缺少 TYPESAFE_BASE_URL / TYPESAFE_API_KEY / TYPESAFE_DEFAULT_MODEL 環境變數")

    jobs: list[tuple[dict, dict]] = []
    for wid in ids:
        src = fetch_comments(wid, args.from_json)
        comments = src.get("comments") or []
        if args.limit:
            comments = comments[: args.limit]
        print(f"{wid} {src['mod']}：快照 {src.get('pages', '?')} 頁 / {len(src.get('comments') or [])} 則"
              f"（本次分類 {len(comments)} 則）")
        jobs.extend((c, src) for c in comments)

    rows: list[dict] = []
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = [pool.submit(classify, c, src["mod"], model) for c, src in jobs]
        for (comment, src), fut in zip(jobs, futures):
            rows.append(to_row(comment, src, fut.result()))

    rows.sort(key=lambda r: (r["priority"], r["urgency"], r["needs_reply"]), reverse=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    jsonl, tsv = write_reports(rows, Path(args.out_dir), stamp)
    failures = [r for r in rows if r["error"]]
    summarize(rows, failures)
    print(f"\n報告：{jsonl}\n      {tsv}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
