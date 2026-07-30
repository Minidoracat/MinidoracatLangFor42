# /// script
# requires-python = ">=3.10"
# dependencies = ["opencc>=1.1"]
# ///
"""凍結 gate 2：術語引擎與舊管線的 outcome-equivalence 比對。

舊管線：OpenCC s2twp + opencc_fixes post_fixes（sync_translations.convert_s2twp）
新管線：OpenCC s2t（純字級，僅本比對用）→ terminology 引擎 charfix + replace

對 REF 全語料逐值比對，差異依「詞對」自動分桶：
  - select/lint 桶：預期差異（引擎依設計不自動轉，語境由人工選）→ 列計數即可
  - 其他桶：未被術語表涵蓋的 s2twp 行為 → 逐桶裁定（採納入表／確認淘汰）
裁定記錄於 terminology.json 的 _equivalence_adjudication，本測試比對裁定清單，
未裁定的新差異桶＝FAIL。
"""
from __future__ import annotations

import difflib
import json
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import opencc  # noqa: E402

import sync_translations as st  # noqa: E402  (舊管線)
import terminology as T  # noqa: E402  (新管線)

S2T = opencc.OpenCC("s2t")
S2TWP = opencc.OpenCC("s2twp")


def old_pipeline(text: str) -> str:
    """凍結前的舊管線：s2twp + opencc_fixes post_fixes（自建，主腳本已拔除）。"""
    result = S2TWP.convert(text)
    for pattern, replacement, _desc in st.POST_FIXES:
        result = pattern.sub(replacement, result)
    return result


def diff_pairs(a: str, b: str) -> list[tuple[str, str]]:
    """抽出兩字串的差異詞對。

    codex review 修正：insert/delete 也必須成桶（打開/開啟 只產生 delete＋insert，
    舊版只收 replace 導致 432 個差異值無桶假 PASS）。做法：把「中間只隔 ≤1 個
    相同字」的相鄰非 equal opcode 合併成一個 replace 型 span，再加單一鄰字語境。
    """
    sm = difflib.SequenceMatcher(None, a, b)
    ops = sm.get_opcodes()
    groups: list[tuple[int, int, int, int]] = []   # (i1, i2, j1, j2) 合併後
    cur = None
    for op, i1, i2, j1, j2 in ops:
        if op == "equal":
            if cur is not None and (i2 - i1) <= 1:
                continue  # 短 equal 視為黏合劑，先不收斂
            if cur is not None:
                groups.append(cur)
                cur = None
            continue
        if cur is None:
            cur = (i1, i2, j1, j2)
        else:
            cur = (cur[0], i2, cur[2], j2)
    if cur is not None:
        groups.append(cur)

    out = []
    for i1, i2, j1, j2 in groups:
        L = 1 if i1 > 0 and j1 > 0 and a[i1 - 1] == b[j1 - 1] else 0
        R = 1 if i2 < len(a) and j2 < len(b) and a[i2] == b[j2] else 0
        pa, pb = a[i1 - L:i2 + R], b[j1 - L:j2 + R]
        if pa != pb:
            out.append((pa, pb))
    return out


def main() -> int:
    eng = T.load()
    adjudicated: dict[str, str] = {
        k: v for k, v in json.loads(T.TERMINOLOGY_JSON.read_text(encoding="utf-8"))
        .get("_equivalence_adjudication", {}).items() if not k.startswith("_")
    }
    # select/lint 的來源詞 → 差異屬預期
    expected_src = set()
    for r in eng.selects + eng.lints:
        expected_src.add(r["pair"].split("→")[0].split("(")[0])

    values: list[tuple[str, str]] = []
    files_ok = 0
    for f in sorted(st.REF_CN.glob("*.json")) + sorted(st.REF_CN.glob("*.txt")):
        if f.name in st.EXCLUDE_GENERATE or f.name in st.MANUAL_MAINTAINED:
            continue
        try:
            data = st.read_translation(f)
        except Exception as exc:  # codex review：解析失敗必須 fail，不得靜默縮小語料
            print(f"❌ REF {f.name} 解析失敗：{exc!r}")
            return 1
        files_ok += 1
        values += [(f"{f.name}|{k}", v) for k, v in data.items() if isinstance(v, str) and v.strip()]
    # codex review：語料下限 gate——REF 缺失/殘缺時不得假 PASS
    if files_ok < 40 or len(values) < 40_000:
        print(f"❌ REF 語料不足（檔 {files_ok} / 值 {len(values)}），"
              f"translation-reference 可能缺失或殘缺，中止")
        return 1

    import re as _re
    SPACED = _re.compile(r"(?:[一-鿿] ){1,}[一-鿿]")
    buckets: Counter[tuple[str, str]] = Counter()
    samples: dict[tuple[str, str], str] = {}
    diff_values = spaced_values = 0
    for key, v in values:
        old = old_pipeline(v)
        new = eng.convert(S2T.convert(v))[0]
        if old == new:
            continue
        diff_values += 1
        # 逐字空格教學文本：舊 post_fixes 帶 \s pattern 才轉得動；生產輸入（官方 CH）
        # 不帶空格，整值歸類不逐桶。
        if SPACED.search(v):
            spaced_values += 1
            continue
        for pair in diff_pairs(new, old):  # 方向：新→舊（舊管線多做了什麼）
            buckets[pair] += 1
            samples.setdefault(pair, f"{key}: {v[:60]}")

    # 正規化：剝空格→剝共同前後綴，供 select/裁定/規則/ClassC 比對
    replace_pairs = {r["pair"] for r in eng.replaces}
    drop_pairs = set(json.loads(T.TERMINOLOGY_JSON.read_text(encoding="utf-8")).get("_dropped", {}))
    T2S = opencc.OpenCC("t2s")

    def norm(a: str, b: str) -> tuple[str, str]:
        a, b = a.replace(" ", ""), b.replace(" ", "")
        while len(a) > 1 and len(b) > 1 and a[0] == b[0]:
            a, b = a[1:], b[1:]
        while len(a) > 1 and len(b) > 1 and a[-1] == b[-1]:
            a, b = a[:-1], b[:-1]
        return a, b

    # replace 對照表：規則的 src/repl 供「剝空格後包含」匹配
    rp = [(r["pair"].split("→")[0], r["pair"].split("→")[1]) for r in eng.replaces]
    sel_srcs = [r["pair"].split("→")[0] for r in eng.selects] + \
               [r["pair"].split("→")[1] for r in eng.selects if "→" in r["pair"]]

    expected, unadjudicated = [], []
    for (a, b), n in buckets.most_common():
        tag = f"{a}→{b}"
        sa, sb = a.replace(" ", ""), b.replace(" ", "")
        na, nb = norm(a, b)
        ntag = f"{na}→{nb}"
        if any(src in sa or src in sb for src in sel_srcs):
            expected.append((tag, n))                       # select 來源/目標詞（含空格變體）
        elif tag in adjudicated or ntag in adjudicated or f"{sa}→{sb}" in adjudicated:
            expected.append((f"{tag}（裁定）", n))
        elif ntag in drop_pairs or f"{nb}→{na}" in drop_pairs:
            expected.append((f"{tag}（淘汰規則）", n))
        elif any(s in sa and t in sb for s, t in rp) or any(s in sb and t in sa for s, t in rp):
            expected.append((f"{tag}（規則的空格/語境變體）", n))
        elif (len(na) <= 2 and len(nb) <= 2
              and T2S.convert(na) == T2S.convert(nb)):
            # codex review：ClassC 收窄到 ≤2 字核心的一簡對多繁字（制/製、只/隻…），
            # 避免長片語的語義差異被 t2s 相等誤放行
            expected.append((f"{tag}（ClassC 一簡對多繁）", n))
        else:
            unadjudicated.append((tag, n, samples[(a, b)]))

    print(f"語料 {len(values)} 值 / 新舊管線有差異 {diff_values} 值 / 差異桶 {len(buckets)}")
    print(f"  其中逐字空格教學文本 {spaced_values} 值（舊管線 \s pattern 專屬行為；生產輸入為官方 CH 無空格，裁定為預期類）")
    print(f"預期差異桶（select/lint/已裁定）: {len(expected)}")
    for tag, n in expected[:40]:
        print(f"   {tag} ×{n}")
    if unadjudicated:
        print(f"\n❌ 未裁定差異桶 {len(unadjudicated)}：")
        for tag, n, s in unadjudicated[:60]:
            print(f"   {tag} ×{n}   例 {s[:70]}")
        dump = Path(__file__).resolve().parent / "equivalence_unadjudicated.json"
        dump.write_text(json.dumps([{"tag": t, "n": n, "sample": smp} for t, n, smp in unadjudicated],
                                   ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"完整清單 → {dump.name}")
        return 1
    print("\nPASS：outcome-equivalence 全部差異已裁定")
    return 0


if __name__ == "__main__":
    sys.exit(main())
