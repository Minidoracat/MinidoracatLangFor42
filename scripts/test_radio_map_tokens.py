"""gen-radio-map 反查表 raw/runtime 契約回歸測試（42.20.2 %% 遷移）。

執行：uv run scripts/test_radio_map_tokens.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from sync_translations import _build_radio_en_to_key


def expect_error(en, ch, cn, why):
    try:
        _build_radio_en_to_key(en, ch, cn)
    except ValueError:
        return
    raise AssertionError(f"應 fail-closed 卻通過：{why}")


def main():
    # 1. %% 條目：表鍵必須是執行期單 % 形（server 烘進 RadioLine 的樣子）
    m, _, _, _ = _build_radio_en_to_key(
        {"RD_a": "... for 10%% off!"}, {"RD_a": "九折優惠!"}, {"RD_a": "九折优惠!"}
    )
    assert m == {"... for 10% off!": "RD_a"}, m

    # 2. EN==CH==CN 的未譯 %% 條目：不得因 raw/runtime 混比而誤判為已譯
    m, _, _, _ = _build_radio_en_to_key(
        {"RD_b": "Sale 10%%"}, {"RD_b": "Sale 10%%"}, {"RD_b": "Sale 10%%"}
    )
    assert m == {}, m

    # 3. 一般已譯條目照常輸出；同 raw EN 重複維持 first-wins 並記錄
    m, first, dups, ambig = _build_radio_en_to_key(
        {"RD_c": "Hello.", "RD_d": "Hello."},
        {"RD_c": "你好。", "RD_d": "妳好。"},
        {"RD_c": "你好。", "RD_d": "你好。"},
    )
    assert m == {"Hello.": "RD_c"} and dups == {"Hello.": ["RD_c", "RD_d"]} and "Hello." in ambig

    # 4. 不同 raw EN 正規化成同一 runtime 鍵且譯文不同 → 拒絕生成
    expect_error(
        {"RD_e": "80%% off", "RD_f": "80% off"},
        {"RD_e": "兩折", "RD_f": "八折"},
        {"RD_e": "两折", "RD_f": "八折"},
        "正規化碰撞且譯文不同",
    )

    # 5. %N 佔位符（EN 或 CH/CN 任一側）→ 拒絕生成（靜態反查不支援）
    expect_error({"RD_g": "sector %1"}, {"RD_g": "扇區 %1"}, {"RD_g": "扇区 %1"}, "EN 含 %N")
    expect_error({"RD_h": "sector one"}, {"RD_h": "扇區 %1"}, {"RD_h": "扇区一"}, "CH 含 %N")

    print("✅ test_radio_map_tokens：6 個案例全部通過")


if __name__ == "__main__":
    main()
