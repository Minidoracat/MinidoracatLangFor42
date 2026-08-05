# /// script
# dependencies = []
# requires-python = ">=3.10"
# ///
"""sanitize_format_tokens 回歸測試（42.20.1 Translator.formatted() 相容性）

執行：uv run scripts/test_format_tokens.py
不依賴測試框架，assert 失敗即測試失敗（exit code != 0）。

背景：42.20.1 起 getText 對所有翻譯值強制跑 String.formatted()，
裸 % 拋 UnknownFormatConversionException（未捕捉）→ 主選單黑畫面。
案例取自 2026-08-05 實際崩潰（console.txt：MainOptions.lua:889 UI_BloodDecals、
ServerSettingsScreen.lua:5156 sandbox tooltip）。
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from scripts.sync_translations import (  # noqa: E402
    _format_token_issues,
    sanitize_format_tokens,
)

# (輸入, 期望輸出, 說明)
CASES: list[tuple[str, str, str]] = [
    # ── 實際崩潰案例 ──
    ("10%", "10%%", "行尾裸 %（UI_BloodDecals1，主選單黑畫面元凶）"),
    ("侵蝕程度發展到 100% 所需的天數", "侵蝕程度發展到 100%% 所需的天數", "% 後接空格（sandbox tooltip 崩潰）"),
    ("大約75%的警員", "大約75%%的警員", "% 後接 CJK"),
    # ── 編號佔位保留 ──
    ("%1 (取 %2%)", "%1 (取 %2%%)", "編號佔位保留、裸 % 逸出"),
    ("音量: %1%<br>主音量: %2 %3%", "音量: %1%%<br>主音量: %2 %3%%", "多個編號佔位混裸 %"),
    # ── 已逸出者不動（冪等） ──
    ("100%%", "100%%", "既有 %% 不得變成 %%%%"),
    ("%1%% %2 - %3 經驗", "%1%% %2 - %3 經驗", "官方式混合值不動"),
    # ── 連續 % 邊角 ──
    ("a%%%b", "a%%%%b", "%%% = %% + 裸 %，只逸出第三個"),
    ("50%%%", "50%%%%", "%% 後接行尾裸 %"),
    # ── printf → 編號 ──
    ("溫度: %.1f ºC", "溫度: %1 ºC", "%.1f → %1（官方 42.20.1 對其翻譯檔做了同樣改寫；呼叫端先把數值格式化成字串再餵 %1）"),
    ("風速: %s, %d 節, %d 公里", "風速: %1, %2 節, %3 公里", "printf 依出現順序編號"),
    ("扇區 %i, %i 和 %i", "扇區 %1, %2 和 %3", "%i（Java 無此轉換符，原樣必炸）"),
    ("溼度: %s%%", "溼度: %1%%", "printf 後接既有 %%"),
    # ── %% 相鄰 [sdif] 不得被誤判成 printf（單趟消耗回歸案例） ──
    ("100%%stamina", "100%%stamina", "%% 後接 s 不是 printf"),
    ("50%%d 機率", "50%%d 機率", "%% 後接 d 不是 printf"),
    # ── 不含 % 者原樣 ──
    ("無", "無", "無 % 快速路徑"),
]

failures = 0
for src, expected, note in CASES:
    got = sanitize_format_tokens(src)
    if got != expected:
        print(f"❌ {note}\n   輸入 {src!r}\n   期望 {expected!r}\n   實得 {got!r}")
        failures += 1
    # 冪等：再跑一次必須不變
    again = sanitize_format_tokens(got)
    if again != got:
        print(f"❌ 冪等失敗：{note}\n   一次 {got!r}\n   二次 {again!r}")
        failures += 1

# 無法等價轉換者必須 fail-closed（raise），不得靜默字面化後寫回
for bad_value, note in [
    ("%1 個，共 %s 個", "printf 與編號混用"),
    (" ".join(["%s"] * 10), "printf 超過 9 個（%10 無效）"),
    ("進度 %02d 完成", "printf 變體 %02d"),
    ("寬度 %-5s 對齊", "printf 變體 %-5s"),
]:
    try:
        got = sanitize_format_tokens(bad_value, "T|k")
    except ValueError:
        pass
    else:
        raise AssertionError(f"{note} 應 raise ValueError，實得 {got!r}")

# checker 純函式：漏檢回歸（codex review 2026-08-05 抓到的兩個盲點）
for value, expect_hit, note in [
    ("%10 分鐘", True, "%1 後緊接數字（formatFixer 只認 %1-%9）"),
    ("%1.2f 秒", True, "%N 後接 .數字（殘位變字面）"),
    ("%1$s 已完成", True, "Java 編號式 %N$（formatFixer 會疊成 %N$s$s）"),
    ("進度 %s", True, "raw printf 應被標記"),
    ("10%", True, "行尾裸 %"),
    ("100%%", False, "已逸出者安全"),
    ("%1 好了", False, "編號佔位安全"),
    ("%1。", False, "%N 接全形句號安全（非 precision 形狀）"),
]:
    hits = _format_token_issues(value)
    assert bool(hits) == expect_hit, f"checker {note}: {value!r} → {hits}"

assert failures == 0, f"{failures} 個案例失敗"
print(f"✅ 全部 {len(CASES)} 個案例通過（含冪等驗證）")
