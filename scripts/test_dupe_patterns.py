# /// script
# dependencies = ["opencc-python-reimplemented"]
# requires-python = ">=3.10"
# ///
"""_DUPE_PATTERNS 回歸測試（譯文片段重複偵測）

執行：uv run scripts/test_dupe_patterns.py
不依賴測試框架，assert 失敗即測試失敗（exit code != 0）。

背景：這組 pattern 歷史上漏檢過三類，各自都留了案例在下面
  1. 單字疊字（白白糖／負負八）→ 刻意不由本組負責，改走 check_dup_single()
  2. 帶分隔符的片段重複（`256x256 像素 像素`）→ 2026-07-30 補入
  3. 拉丁詞組用多空格分隔（`LSU␠␠LSU`）→ 2026-07-30 補入（原 pattern 只認單一空格）
"""
from __future__ import annotations

import sys
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
]

failed = 0
for text, want, why in CASES:
    got = hits(text)
    if got != want:
        failed += 1
        print(f"FAIL 期望{'命中' if want else '不命中'} 實際{'命中' if got else '不命中'}: "
              f"{text!r} — {why}", file=sys.stderr)

assert not failed, f"{failed} 個案例失敗"
print(f"PASS: _DUPE_PATTERNS {len(CASES)}/{len(CASES)} 案例通過")
