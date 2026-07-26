# /// script
# dependencies = ["opencc-python-reimplemented"]
# requires-python = ">=3.10"
# ///
"""check_dict_sync() 回歸測試（跨專案字典一致性檢查）

執行：uv run scripts/test_dict_sync.py
不依賴測試框架，assert 失敗即測試失敗（exit code != 0）。
"""
from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import scripts.sync_translations as st  # noqa: E402


def make_dict(rules: list[dict], suspicious: list[dict] | None = None) -> dict:
    return {
        "post_fixes": [{"category": "測試類", "rules": rules}],
        "suspicious_patterns": suspicious or [],
    }


def run_case(mine: dict, theirs, expect_substrings: list[str]) -> None:
    """寫兩份暫存字典（theirs 傳 str 表示原樣寫入壞損內容），跑 check_dict_sync 驗證結果"""
    with tempfile.TemporaryDirectory() as td:
        mine_p = Path(td) / "mine.json"
        theirs_p = Path(td) / "theirs.json"
        mine_p.write_text(json.dumps(mine, ensure_ascii=False), encoding="utf-8")
        if isinstance(theirs, str):
            theirs_p.write_text(theirs, encoding="utf-8")
        else:
            theirs_p.write_text(json.dumps(theirs, ensure_ascii=False), encoding="utf-8")
        orig = st.FIXES_JSON, st.SIBLING_FIXES_JSON
        st.FIXES_JSON, st.SIBLING_FIXES_JSON = mine_p, theirs_p
        try:
            issues = st.check_dict_sync()
        finally:
            st.FIXES_JSON, st.SIBLING_FIXES_JSON = orig
    assert len(issues) == len(expect_substrings), (
        f"預期 {len(expect_substrings)} 條、實得 {len(issues)}: {issues}"
    )
    for sub, issue in zip(expect_substrings, issues):
        assert sub in issue, f"預期含「{sub}」，實得: {issue}"


R_A = {"pattern": "幹燥", "replacement": "乾燥"}
SUS = [{"char": "幹", "description": "d", "before_exclude": ["才"], "after_exclude": []}]

# 1. 完全一致 → 零 issue
run_case(make_dict([R_A], SUS), make_dict([R_A], SUS), [])

# 2. replacement 分歧、note 含「分岔」→ 放行
run_case(
    make_dict([{"pattern": "外掛", "replacement": "物品", "note": "合理分岔"}]),
    make_dict([{"pattern": "外掛", "replacement": "模組"}]),
    [],
)

# 3. replacement 分歧、無註記 → 報告
run_case(
    make_dict([{"pattern": "外掛", "replacement": "物品"}]),
    make_dict([{"pattern": "外掛", "replacement": "模組"}]),
    ["replacement 分歧且無註記"],
)

# 4. 單邊獨有：無註記報告、「勿移植」放行
run_case(make_dict([R_A, {"pattern": "^幹$", "replacement": "乾"}]), make_dict([R_A]), ["本體獨有且無分岔註記"])
run_case(
    make_dict([R_A, {"pattern": "^幹$", "replacement": "乾", "note": "模組包已否決勿移植"}]),
    make_dict([R_A]),
    [],
)

# 5. 方向性漏檢（codex finding）：本體 identity、模組包同 pattern active → 必須報告
run_case(
    make_dict([{"pattern": "關係", "replacement": "關係", "note": "保留不變"}]),
    make_dict([{"pattern": "關係", "replacement": "關系"}]),
    ["模組包獨有且無分岔註記"],
)

# 6. 檔內重複 pattern → 報重複本身；且 last-wins 存活規則與對面分歧也照常報
run_case(
    make_dict([{"pattern": "幹燥", "replacement": "乾燥"}, {"pattern": "幹燥", "replacement": "干燥"}]),
    make_dict([R_A]),
    ["本體字典檔內重複 pattern", "replacement 分歧且無註記"],
)

# 7. suspicious：exclude 清單不同步報告；description 差異不報告
run_case(
    make_dict([R_A], SUS),
    make_dict([R_A], [{"char": "幹", "description": "不同的描述", "before_exclude": [], "after_exclude": []}]),
    ["suspicious「幹」before_exclude 不同步"],
)

# 8. 模組包字典壞損 → 一條「無法讀取」，不裸拋
run_case(make_dict([R_A]), "{broken json", ["無法讀取模組包字典"])

# 9. 本體字典缺失 → 一條「無法讀取」，不裸拋
with tempfile.TemporaryDirectory() as td:
    theirs_p = Path(td) / "theirs.json"
    theirs_p.write_text(json.dumps(make_dict([R_A]), ensure_ascii=False), encoding="utf-8")
    orig = st.FIXES_JSON, st.SIBLING_FIXES_JSON
    st.FIXES_JSON, st.SIBLING_FIXES_JSON = Path(td) / "missing.json", theirs_p
    try:
        issues = st.check_dict_sync()
    finally:
        st.FIXES_JSON, st.SIBLING_FIXES_JSON = orig
    assert len(issues) == 1 and "無法讀取本體字典" in issues[0], issues

print("PASS: check_dict_sync 9/9 案例通過")
