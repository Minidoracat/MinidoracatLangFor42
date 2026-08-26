# /// script
# dependencies = []
# requires-python = ">=3.10"
# ///
"""42.20.4 PrintMedia 標記驗證回歸測試。

執行：uv run scripts/test_print_media_info.py
"""
from __future__ import annotations

import contextlib
import io
import json
import re
import sys
import tempfile
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import scripts.sync_translations as sync  # noqa: E402

VALID = [
    ("非版面標題", "Print_Media_Test_title", "一般標題"),
    (
        "新版圖片路徑",
        "Print_Media_Test_info",
        "<type:parent, width:800, height:1131>"
        "<type:texture, x:0, y:0, texture:media/textures/example.png, width:800, height:1131>",
    ),
    (
        "新版字型與布林數值",
        "Print_Media_Test_info",
        "<type:text, x:1, shadow:1, font:SdfOldBold>中文",
    ),
    ("官方容許的尾逗號", "Print_Media_Test_info", "<type:texture, width:1,>"),
    (
        "既有 map 特殊值",
        "maptext",
        '<type:map, x:60, y:100, width:100, height:150, mapID:"RustyRifle">',
    ),
]

INVALID = [
    ("版面純文字", "一般標題", "標籤開始"),
    ("舊式圖片呼叫", '<type:texture, texture:getTexture("media/textures/example.png")>', "資源路徑"),
    ("帶空格舊式圖片呼叫", '<type:texture, texture:getTexture ("media/textures/example.png")>', "資源路徑"),
    ("任意圖片字串", "<type:texture, texture:example.png>", "資源路徑"),
    ("舊式字型列舉", "<type:text, x:1, font:UIFont.SdfOldBold>中文", "UIFont 名稱"),
    ("未知字型", "<type:text, x:1, font:DoesNotExist>中文", "UIFont 名稱"),
    ("算式數值", "<type:parent, width:960/2, height:670>", "tonumber"),
    ("布林字面", "<type:text, x:1, shadow:true, font:SdfOldBold>中文", "tonumber"),
    ("底線數值", "<type:text, x:1_0, font:SdfOldBold>中文", "tonumber"),
    ("全形數字", "<type:text, x:\uff11, font:SdfOldBold>中文", "tonumber"),
    ("NBSP 字型", "<type:text, x:1, font:\u00a0SdfOldBold>中文", "UIFont 名稱"),
    ("NBSP 圖片路徑", "<type:texture, texture:\u00a0media/textures/example.png>", "資源路徑"),
    ("NBSP type", "<type:\u00a0text, x:1, font:SdfOldBold>中文", "未知或缺少 type"),
    ("加引號圖片路徑", '<type:texture, texture:"media/textures/example.png">', "資源路徑"),
    ("非有限數值", "<type:text, x:1e309, font:SdfOldBold>中文", "有限數值"),
    ("未閉合標籤", "<type:text, x:1", "未閉合"),
    (
        "早期標籤未閉合",
        "<type:text, x:1中文<type:text, x:2, font:SdfOldBold>OK",
        "前一個標籤未閉合",
    ),
    ("空 text payload", "<type:text, x:1, font:SdfOldBold>", "文字內容"),
]

for note, key, value in VALID:
    assert sync._validate_print_media_info(key, value) is None, note

for note, value, expected in INVALID:
    error = sync._validate_print_media_info("Print_Media_Test_info", value)
    assert error and expected in error, f"{note}: {error!r}"

# 整合契約：validator 命中必須讓 fix-check 非零退出，不能只列印警告。
with tempfile.TemporaryDirectory() as temp_dir:
    root = Path(temp_dir)
    ch_dir, cn_dir, lua_dir = root / "CH", root / "CN", root / "lua"
    for directory in (ch_dir, cn_dir, lua_dir):
        directory.mkdir()
    invalid_data = {
        "Print_Media_Test_info":
            '<type:texture, texture:getTexture ("media/textures/example.png")>'
    }
    for directory in (ch_dir, cn_dir):
        (directory / "Print_Media.json").write_text(
            json.dumps(invalid_data), encoding="utf-8"
        )

    patched = {
        "MOD_CH": ch_dir,
        "MOD_CN": cn_dir,
        "MOD_LUA": lua_dir,
        "FLX_FILES": [],
        "SIBLING_FIXES_JSON": root / "missing-opencc-fixes.json",
    }
    with contextlib.ExitStack() as stack:
        for name, value in patched.items():
            stack.enter_context(mock.patch.object(sync, name, value))
        stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
        try:
            sync.cmd_fix_check()
        except SystemExit as exc:
            assert exc.code == 1
        else:
            raise AssertionError("Print Media 標記錯誤未讓 fix-check 非零退出")

# 每一期報紙標題的報社名前綴，必須等於同語系 IGUI_NewspaperTitle_*。
newspaper_issue_key = re.compile(
    r"^Print_Media_(.+?)_"
    r"(?:January|February|March|April|May|June|July|August|September|October|November|December)"
    r"\d+_title$"
)
newspaper_titles_checked = 0
for language, translate_dir in (("CH", sync.MOD_CH), ("CN", sync.MOD_CN)):
    print_media = json.loads((translate_dir / "Print_Media.json").read_text(encoding="utf-8"))
    ig_ui = json.loads((translate_dir / "IG_UI.json").read_text(encoding="utf-8"))
    language_count = 0
    for key, value in print_media.items():
        match = newspaper_issue_key.match(key)
        if not match:
            continue
        expected = ig_ui.get("IGUI_NewspaperTitle_" + match.group(1))
        assert expected, f"{language} {key}: 缺少報社名稱翻譯鍵"
        actual, separator, _date = value.partition(" - ")
        assert separator and actual == expected, (
            f"{language} {key}: 報社名 {actual!r}，期望 {expected!r}"
        )
        language_count += 1
    assert language_count == 22, f"{language}: 期別標題數量漂移 {language_count} != 22"
    newspaper_titles_checked += language_count
print(
    f"✅ PrintMedia 標記驗證 {len(VALID) + len(INVALID)} 案＋CLI gate，"
    f"報紙標題 {newspaper_titles_checked} 筆通過"
)
