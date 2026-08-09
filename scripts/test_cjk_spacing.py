"""check_cjk_spacing 判準回歸測試。

2026-08-09：判準由「對側語言」改為「官方同語系」。本測試鎖住新判準的四個分支，
特別是舊判準會漏掉的那一支（官方同語系乾淨、對側帶空格 → 應報）。

用法：uv run python scripts/test_cjk_spacing.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from sync_translations import _SPACED_CJK  # noqa: E402


def judge(value: str, official_same_lang: str | None, peer_other_lang: str | None) -> bool:
    """複刻 check_cjk_spacing 的判定核心：True = 應回報為我方倒退。"""
    if not _SPACED_CJK.search(value):
        return False
    if isinstance(official_same_lang, str):
        return not _SPACED_CJK.search(official_same_lang)
    return not (isinstance(peer_other_lang, str) and _SPACED_CJK.search(peer_other_lang))


SPACED = "存 檔 世 界 版 本 : %1"
CLEAN = "存檔世界版本: %1"
SPACED_CN = "世 界 存 档 文 件 版 本 : %1"

CASES = [
    # (說明, 我方值, 官方同語系, 對側語言, 期望回報)
    ("值本身沒空格 → 不報", CLEAN, None, None, False),
    ("官方同語系也帶空格 → 繼承，不報", SPACED, SPACED, None, False),
    # ↓ 舊判準（看對側）會放行，新判準（看官方同語系）要抓到：83 筆真倒退屬此支
    ("官方同語系乾淨、對側帶空格 → 我方倒退，應報", SPACED, CLEAN, SPACED_CN, True),
    ("官方同語系乾淨、對側也乾淨 → 應報", SPACED, CLEAN, CLEAN, True),
    ("無官方可比、對側帶空格 → 退回對側判準，不報", SPACED, None, SPACED_CN, False),
    ("無官方可比、對側乾淨 → 退回對側判準，應報", SPACED, None, CLEAN, True),
    ("無官方可比、對側無此鍵 → 應報", SPACED, None, None, True),
]


def main() -> int:
    failed = 0
    for desc, val, off, peer, want in CASES:
        got = judge(val, off, peer)
        if got != want:
            failed += 1
            print(f"FAIL: {desc}\n      期望 {want}，實得 {got}")
    # 傳單／城鎮 description 這類官方自帶排版必須維持放行
    flyer = "馬 爾 德 勞 - 煥 然 一 新"
    if judge(flyer, flyer, flyer):
        failed += 1
        print("FAIL: 官方自帶排版（傳單/城鎮 description）被誤報")

    if failed:
        print(f"\n{failed} 個案例失敗")
        return 1
    print(f"PASS: check_cjk_spacing 判準 {len(CASES) + 1}/{len(CASES) + 1} 案例通過")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
