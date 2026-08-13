"""gen-aebs-map 來源契約 fail-closed 回歸測試。

執行：uv run scripts/test_aebs_generator.py

背景：runtime 反解由 scripts/test_aebs_restore.lua 守門，但那支測試 dofile 的是
已生成的 Lua 表，完全不執行 generator——來源契約若失效（PZ 改鍵、譯文被清空、
EN 佔位符順序調換），generator 會靜默產出殘缺或錯位的表而 runtime 測試照樣全綠。
本檔以 mutation 直接打 _aebs_check_contract，逐項證明這些漂移都會 fail-closed。
所列案例皆為 codex 端 review-plus 以 mutation probe 實證可被放行的缺口。
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from sync_translations import (
    AEBS_EXPECTED_KEYS,
    AEBS_PARAMETRISED_KEYS,
    _aebs_check_contract,
    _aebs_lua_pattern,
)

# 最小合法基準：每個契約 key 給一個唯一英文值，帶參數者用正序 %N
BASE_EN = {}
for _index, _key in enumerate(sorted(AEBS_EXPECTED_KEYS)):
    if _key in AEBS_PARAMETRISED_KEYS:
        BASE_EN[_key] = " ".join(f"%{n}" for n in range(1, 3)) + f" filler {_index}"
    else:
        BASE_EN[_key] = f"phrase {_index}"


def _mods(en):
    """由 EN 造出合法的 CH/CN：值不同於鍵名、佔位符集合一致。"""
    return {
        label: {key: f"[{label}] {value}" for key, value in en.items()}
        for label in ("CH", "CN")
    }


def expect_ok(en, why):
    errors = _aebs_check_contract(en, _mods(en))
    assert not errors, f"應通過卻報錯（{why}）：{errors}"


def expect_error(en, mods, why):
    errors = _aebs_check_contract(en, mods)
    assert errors, f"應 fail-closed 卻通過：{why}"


def main():
    # 0. 基準必須通過，否則後面的 mutation 沒有鑑別力
    expect_ok(BASE_EN, "未變動的合法基準")

    # 1. producer 仍在使用的 key 被刪除 → 模板會靜默消失
    en = dict(BASE_EN)
    del en["AEBS_temperature"]
    expect_error(en, _mods(en), "刪除 AEBS_temperature")

    # 2. EN 出現契約外的新 key → 必須人工對版 producer 後才更新 manifest
    en = dict(BASE_EN)
    en["AEBS_brand_new_key"] = "something new"
    expect_error(en, _mods(en), "EN 新增契約外 key")

    # 3. CH/CN 值為空字串或未譯佔位
    for bad in ("", "   ", "~"):
        mods = _mods(BASE_EN)
        mods["CH"]["AEBS_fog_0"] = bad
        expect_error(BASE_EN, mods, f"CH 值為 {bad!r}")

    # 4. CH/CN 值等於鍵名（等同未譯）
    mods = _mods(BASE_EN)
    mods["CN"]["AEBS_fog_0"] = "AEBS_fog_0"
    expect_error(BASE_EN, mods, "CN 值等於鍵名")

    # 5. CH/CN 缺鍵
    mods = _mods(BASE_EN)
    del mods["CH"]["AEBS_wind_0"]
    expect_error(BASE_EN, mods, "CH 缺 AEBS_wind_0")

    # 6. EN 佔位符對調 → placeholder set 相同，但捕獲依出現順序 unpack 會錯位
    en = dict(BASE_EN)
    en["AEBS_wind_0"] = "%2 then %1 filler"
    expect_error(en, _mods(en), "EN 的 %1/%2 對調")

    # 7. 佔位符不連續（跳號）
    en = dict(BASE_EN)
    en["AEBS_wind_0"] = "%1 then %3 filler"
    expect_error(en, _mods(en), "EN 佔位符跳號")

    # 8. 譯文佔位符與 EN 不符（少一個 → 靜默吞內容；多一個 → Missing arguments）
    mods = _mods(BASE_EN)
    mods["CH"]["AEBS_wind_0"] = "只有 %1"
    expect_error(BASE_EN, mods, "CH 少一個佔位符")

    # 9. 英文原文碰撞 → 整行全等表與 greedy 都以英文為索引，無法消歧
    en = dict(BASE_EN)
    en["AEBS_fog_1"] = en["AEBS_fog_0"]
    expect_error(en, _mods(en), "AEBS_fog_0/1 英文值碰撞")

    # 10. 帶參數的 key 集合漂移（原本無參數的 key 突然有參數）
    en = dict(BASE_EN)
    en["AEBS_fog_0"] = "fog %1"
    expect_error(en, _mods(en), "無參數 key 變成帶參數")

    # 11. 裸 key 清單漂移：少掉任一 producer activity key
    en = dict(BASE_EN)
    del en["AEBS_rand_pre_7"]
    expect_error(en, _mods(en), "刪除 AEBS_rand_pre_7")

    # ---- pattern 生成正確性（runtime 反解的前提）----
    # %% 是字面百分號，Lua pattern 中須逸出成 %%；magic 字元逐一逸出
    pattern, count = _aebs_lua_pattern("average temperature %1. Humidity: %2%%...")
    assert count == 2, count
    assert pattern == "^average temperature (.-)%. Humidity: (.-)%%%.%.%.$", pattern

    # 參數落在字串結尾時用貪婪 (.*)，否則靠後方固定文字錨定
    pattern, _ = _aebs_lua_pattern("%1 wind from the %2. %3")
    assert pattern == "^(.-) wind from the (.-)%. (.*)$", pattern

    # anchored=False 供 string.find 取結束位置後續接剩餘內容
    pattern, _ = _aebs_lua_pattern("start in the %1...", anchored=False)
    assert pattern == "^start in the (.-)%.%.%.", pattern
    assert _aebs_lua_pattern("start in the %1...")[0].endswith("$")

    print("gen-aebs-map 契約測試全數通過")


if __name__ == "__main__":
    main()
