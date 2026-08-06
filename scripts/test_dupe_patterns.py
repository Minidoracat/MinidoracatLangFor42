# /// script
# dependencies = ["opencc-python-reimplemented"]
# requires-python = ">=3.10"
# ///
"""_DUPE_PATTERNS 回歸測試（譯文片段重複偵測）

執行：uv run scripts/test_dupe_patterns.py
不依賴測試框架，assert 失敗即測試失敗（exit code != 0）。

背景：這組 pattern 歷史上漏檢過四類，各自都留了案例在下面
  1. 單字疊字（白白糖／負負八）→ 刻意不由本組負責，改走 check_dup_single()
  2. 帶分隔符的片段重複（`256x256 像素 像素`）→ 2026-07-30 補入
  3. 拉丁詞組用多空格分隔（`LSU␠␠LSU`）→ 2026-07-30 補入（原 pattern 只認單一空格）
  4. 跨 <br> 的整句重複（wallLogDesc `製作簡單但耗費資源`×2：單元 9 字超出
     regex 上限、分隔又是多字元 `. <br>`）→ 2026-08-06 補入 _has_br_segment_dup()
"""
from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import scripts.sync_translations as st  # noqa: E402


def hits(text: str) -> bool:
    return any(p.search(text) for p in st._DUPE_PATTERNS)


# (值, 是否應命中, 說明)
CASES: list[tuple[str, bool, str]] = [
    # ── 應命中：真實出現過的誤植 ──
    ("顯示與效能與效能", True, "尾端片段重複（698c262 潤色誤植原型）"),
    ("為瓦斯噴槍為瓦斯噴槍補充燃料", True, "句首長片段重複"),
    ("錯誤: preview.png 檔案的大小必須正好是 256x256 像素 像素.", True,
     "帶空白分隔的片段重複"),
    # ── 刻意不命中：放寬分隔符的代價大於收益 ──
    ("商店, 滿滿當當, 滿滿當當", False,
     "「逗號+空格」分隔刻意不抓：放寬會掃進中文頂真句，實測 13 誤報 0 真錯"),
    ("需要一些黏土? 可以透過搜尋找到它們, 它們也會在河邊出現.", False, "頂真句（它們, 它們）"),
    ("低耐力, 低耐力恢復.", False, "頂真句（trait 描述的正常寫法）"),
    ("《橄欖球, 橄欖球, 還是橄欖球》Ernest Winter 著", False,
     "官方書名本身就是三連（key: IGUI_BookTitle_FootballFootballFootball）"),
    ("LSU  LSU  橄欖球球衣 (藍)", True, "拉丁詞組＋雙空格（曾漏檢：Base.Football_Jersey_Blue）"),
    ("LSU LSU 橄欖球球衣", True, "拉丁詞組＋單空格"),
    ("Dog Goblin Dog Goblin 海報", True, "多詞拉丁詞組重複"),
    # ── 不應命中：正常表達／官方原樣 ──
    ("XX XX XX XX / YY YY YY YY", False, "2 字佔位樣板，官方 EN 亦如此（Print_Media 傳單）"),
    ("Vertex Break", False, "公司名"),
    ("The Tea Division", False, "公司名"),
    ("LSU 橄欖球球衣 (藍)", False, "修好後的值"),
    ("可可粉", False, "單字疊字不由本組負責（走 check_dup_single）"),
    ("使用使用者清單視窗中的按鈕.", False, "使用＋使用者，跨詞邊界的正常複合"),
    ("扳動步槍槍機", False, "步槍＋槍機，正常複合"),
    ("捆起來的原木做成的堅固牆壁. <br>製作簡單但耗費資源. <br>製作簡單但耗費資源.", False,
     "跨 <br> 整句重複不由本組負責（走 _has_br_segment_dup，見 BR_CASES）"),
]

# _has_br_segment_dup 專屬案例（<br> 切段後相鄰段全等）
BR_CASES: list[tuple[str, bool, str]] = [
    ("捆起來的原木做成的堅固牆壁. <br>製作簡單但耗費資源. <br>製作簡單但耗費資源.", True,
     "修復前實例（CH Tooltip_craft_wallLogDesc，在庫裡活到 2026-08-06）"),
    ("捆起來的原木做成的堅固牆壁. <br>製作簡單但耗費資源.", False, "修好後的值"),
    ("簡單的牆.<br>可以加固, 上灰泥和刷漆.", False, "不同段落，正常"),
    ("<br><br>", False, "空段不算重複"),
]

failed = 0
for cases, fn in ((CASES, hits), (BR_CASES, st._has_br_segment_dup)):
    for text, want, why in cases:
        got = fn(text)
        if got != want:
            failed += 1
            print(f"FAIL 期望{'命中' if want else '不命中'} 實際{'命中' if got else '不命中'}: "
                  f"{text!r} — {why}", file=sys.stderr)

assert not failed, f"{failed} 個案例失敗"
total = len(CASES) + len(BR_CASES)
print(f"PASS: _DUPE_PATTERNS + _has_br_segment_dup {total}/{total} 案例通過")

# ── 整合案例：走 check_duplicated_fragments() 真入口 ──
# helper 直測鎖不住接線（2026-08-06 codex review 指出）：若日後拆掉接線、或把
# br-dup 檢查移到 _DUPE_MAX_LEN 閘門之後，上面案例照樣全綠。這裡鎖三個契約：
#   1. _has_br_segment_dup 確實接進 check_duplicated_fragments
#   2. 檢查在長度閘門之前（>60 字仍命中）
#   3. skip-file 與 allowlist 對它同樣生效
seg = "用來確認長度閘門不會擋住跨換行整句重複偵測的一段刻意加長敘述"
dup_value = f"{seg}. <br>{seg}."
assert len(dup_value) > st._DUPE_MAX_LEN, "fixture 必須超過長度閘門才有鑑別力"

with tempfile.TemporaryDirectory() as td:
    ch_dir = Path(td) / "CH"
    cn_dir = Path(td) / "CN"
    ch_dir.mkdir()
    cn_dir.mkdir()
    fixtures: dict[str, dict[str, str]] = {
        "Tooltip.json": {"IT_long_dup": dup_value},                     # 應命中
        "RadioData.json": {"RD_x": dup_value},                          # skip-file，不掃
        "Sandbox.json": {"Sandbox_MetaKnowledge_tooltip": dup_value},   # allowlist，壓掉
    }
    for name, data in fixtures.items():
        (ch_dir / name).write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    _orig = st.MOD_CH, st.MOD_CN
    st.MOD_CH, st.MOD_CN = ch_dir, cn_dir
    try:
        got = st.check_duplicated_fragments()
    finally:
        st.MOD_CH, st.MOD_CN = _orig

assert len(got) == 1 and "IT_long_dup" in got[0], f"整合結果不符: {got!r}"
print("PASS: check_duplicated_fragments 整合案例（>60 字 br-dup／skip-file／allowlist）通過")
