"""排版守門回歸測試：check_cjk_spacing 判準 + richtext_eaten 吞字偵測。

**直接呼叫產品函式**，不複刻判定邏輯——2026-08-09 review 指出舊版把判定核心重打一遍，
產品程式碼改回舊判準測試照樣 PASS，等於零鑑別力。本版改以 tmp 目錄 monkeypatch
`MOD_CH`／`MOD_CN`／`VANILLA_PZ_DEFAULT` 後呼叫真函式。

用法：uv run python scripts/test_cjk_spacing.py
"""
import json
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import sync_translations as st  # noqa: E402

SPACED = "存 檔 世 界 版 本 : %1"
CLEAN = "存檔世界版本: %1"
SPACED_CN = "世 界 存 档 文 件 版 本 : %1"
FLYER = "馬 爾 德 勞 - 煥 然 一 新"

failed: list[str] = []


def fail(msg: str) -> None:
    failed.append(msg)
    print(f"FAIL: {msg}")


def write(root: Path, lang: str, fn: str, data: dict) -> None:
    d = root / lang
    d.mkdir(parents=True, exist_ok=True)
    (d / fn).write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")


def run_cjk_case(desc, ours_ch, ours_cn, off_ch, want_reported):
    """建 tmp 樹 → monkeypatch → 呼叫真正的 check_cjk_spacing()。"""
    tmp = Path(tempfile.mkdtemp())
    try:
        mod, van = tmp / "mod", tmp / "van" / "media" / "lua" / "shared" / "Translate"
        write(mod, "CH", "UI.json", {"K": ours_ch})
        write(mod, "CN", "UI.json", {"K": ours_cn} if ours_cn is not None else {})
        if off_ch is not None:
            write(van, "CH", "UI.json", {"K": off_ch})
        else:
            (van / "CH").mkdir(parents=True, exist_ok=True)
        (van / "CN").mkdir(parents=True, exist_ok=True)

        old = (st.MOD_CH, st.MOD_CN, st.VANILLA_PZ_DEFAULT)
        st.MOD_CH, st.MOD_CN, st.VANILLA_PZ_DEFAULT = mod / "CH", mod / "CN", tmp / "van"
        try:
            got = any("[CH]" in i for i in st.check_cjk_spacing())
        finally:
            st.MOD_CH, st.MOD_CN, st.VANILLA_PZ_DEFAULT = old
        if got != want_reported:
            fail(f"{desc}\n      期望回報={want_reported}，實得={got}")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main() -> int:
    # ── check_cjk_spacing：四個分支 ──
    run_cjk_case("值本身無空格 → 不報", CLEAN, CLEAN, CLEAN, False)
    run_cjk_case("官方同語系也帶空格 → 繼承，不報", SPACED, SPACED_CN, SPACED, False)
    # 舊判準（看對側）會放行，新判準要抓到——41fc357 的 83 筆真倒退全屬此支
    run_cjk_case("官方同語系乾淨、對側帶空格 → 應報", SPACED, SPACED_CN, CLEAN, True)
    run_cjk_case("官方同語系乾淨、對側也乾淨 → 應報", SPACED, CLEAN, CLEAN, True)
    # 官方無此鍵（我方自有鍵）→ 退回對側判準
    run_cjk_case("無官方可比、對側帶空格 → 不報", SPACED, SPACED_CN, None, False)
    run_cjk_case("無官方可比、對側乾淨 → 應報", SPACED, CLEAN, None, True)
    run_cjk_case("傳單／城鎮排版（官方同語系亦有）→ 不報", FLYER, FLYER, FLYER, False)

    # ── richtext_eaten：吞字偵測 ──
    for desc, value, want in [
        ("標籤前有空白 → 不吞", "健康面板. <LINE> 下一段", 0),
        ("正文緊貼標籤 → 吞掉整段", "健康面板.<LINE> 下一段", len("健康面板.")),
        ("連續標籤無正文 → 不吞", "<LINE><LINE> 內容", 0),
        ("逐字空格時只吞一字", "健 康 面 板 .<LINE> 下一段", 1),
        ("無標籤 → 不吞", "純文字沒有標籤", 0),
        ("尾段無空白仍會渲染 → 不計損失", "<LINE> 結尾沒有空白", 0),
    ]:
        got = st.richtext_eaten(value)
        if got != want:
            fail(f"richtext_eaten：{desc}\n      期望 {want}，實得 {got}（值={value!r}）")

    if failed:
        print(f"\n{len(failed)} 個案例失敗")
        return 1
    print("PASS: check_cjk_spacing 7 案 + richtext_eaten 6 案，全部通過（直接呼叫產品函式）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
