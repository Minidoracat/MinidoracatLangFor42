# /// script
# requires-python = ">=3.10"
# ///
"""除錯/管理員選單硬編碼英文的涵蓋率檢查（HARDCODE_REGISTRY.md A16 對版基準）。

從 vanilla Lua 抽出情境選單的英文字面選項，用與 DebugContextMenu_Flx.lua 的
deriveKey 完全相同的規則推導鍵，再比對我方 ContextMenu.json 是否有譯文。

PZ 版本升級後重跑本腳本：
  - 「未涵蓋」清單變長 → 官方新增了硬編碼選單項，需補鍵或接線
  - 「孤兒鍵」變長     → 官方移除/改掛鍵，我方鍵可考慮淘汰

用法：
  uv run scripts/check_debug_menu_coverage.py            # 摘要
  uv run scripts/check_debug_menu_coverage.py --list     # 列出未涵蓋字串
  uv run scripts/check_debug_menu_coverage.py --pz PATH  # 指定 PZ 安裝路徑
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MOD_TR = (REPO / "MOD/MinidoracatLangFor42/Contents/mods/MinidoracatLangFor42/42"
          "/media/lua/shared/Translate")
DEFAULT_PZ = Path(r"D:/SteamLibrary/steamapps/common/ProjectZomboid")

PREFIX = "ContextMenu_CatDebug_"

# 只掃情境選單的 addOption/addDebugOption；第一個參數必須是英文字面。
# ISComboBox / ISTickBox / ISRadioButtons 也有 addOption，用接收者名稱排除。
CALL_RE = re.compile(
    r'(?P<recv>[A-Za-z_][\w.:\[\]]*)\s*:\s*'
    r'add(?:Debug)?Option(?:OnTop)?\s*\(\s*'
    r'(?P<q>["\'])(?P<text>(?:(?!(?P=q))[^\\]|\\.)*)(?P=q)'
)

NON_MENU_RECEIVERS = {
    "tickBox", "combo", "comboBox", "self.comboBox", "self.brushType",
    "self.town", "self.traitsSelector", "self.booleanOption", "radio",
    "self.radio", "box", "self.tickBox", "self.combo", "self.difficulty",
    "self.gameMode", "self.speed", "self.zombies",
    # ISTickBox / ISComboBox 欄位（非情境選單）
    "self.tickBoxLeft", "self.tickBoxCenter", "self.tickBoxRight",
    "self.categoryCB",
}

# 刻意保留原文（技術標籤 / 資源 ID），不列為缺口
DELIBERATE = {
    "DBG: ISVehicleMechanics.cheat=false",
    "DBG: ISVehicleMechanics.cheat=true",
    "ISVehicleMechanics.cheat=false",
    "ISVehicleMechanics.cheat=true",
    "[MAIN] ", "[OVERLAY] ", "[ATTACHED] ",
}

# 開發者專用編輯器（HARDCODE_REGISTRY.md B15-f）：明確不修，單獨計數不混入缺口
DEV_EDITOR_DIRS = (
    "DebugUIs/AttachmentEditorUI", "DebugUIs/ObjectViewer", "DebugUIs/WatchWindow",
    "DebugUIs/SpriteModelEditor", "DebugUIs/SeamEditor", "DebugUIs/TileGeometryEditor",
    "DebugUIs/DebugMenu",
)

# 零呼叫點死碼（B6 doCheatMenu、doBedOption 觀察項）：官方接線後才需處理
DEAD_CODE = {
    "Get On Bed", "Bed: Awake To Asleep", "Bed: Asleep To Awake",
}

# 字面值只是「拼接前綴」，實際顯示字串是前綴＋動態值：
# 由 DebugContextMenu_Flx.lua 的 PATTERNS 或拼接後的完整鍵處理，非缺口。
CONCAT_PREFIX = {
    "Add ", "Invincible ", "Set Alarm ", "Create All From ",
    "Farming Seasons Enabled: ", "Set Invisible ",
}


def derive_key(name: str) -> str:
    """必須與 DebugContextMenu_Flx.lua 的 deriveKey 逐字一致。"""
    s = name.replace("+", "Plus").replace("-", "Minus").replace(":", "Colon")
    return PREFIX + re.sub(r"[^0-9A-Za-z]", "", s)


def strip_comments(src: str) -> str:
    src = re.sub(r"--\[\[.*?\]\]", "", src, flags=re.S)
    return "\n".join(ln for ln in src.splitlines() if not ln.lstrip().startswith("--"))


def load_keys() -> set[str]:
    p = MOD_TR / "CH" / "ContextMenu.json"
    data = json.loads(p.read_text(encoding="utf-8"))
    return {k for k in data if k.startswith(PREFIX)}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pz", type=Path, default=DEFAULT_PZ)
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args()

    lua_root = args.pz / "media/lua"
    if not lua_root.is_dir():
        print(f"找不到 vanilla Lua：{lua_root}", file=sys.stderr)
        return 2

    keys = load_keys()
    found: dict[str, list[str]] = {}      # 英文 -> 出現檔案
    skipped_recv = 0

    for path in sorted(lua_root.rglob("*.lua")):
        try:
            src = strip_comments(path.read_text(encoding="utf-8", errors="ignore"))
        except OSError:
            continue
        for m in CALL_RE.finditer(src):
            recv = m.group("recv")
            text = m.group("text")
            if recv in NON_MENU_RECEIVERS:
                skipped_recv += 1
                continue
            # 必須含 ASCII 字母才算英文字面（排除純數字/符號）
            if not re.search(r"[A-Za-z]{2}", text):
                continue
            found.setdefault(text, []).append(str(path.relative_to(lua_root)))

    def is_dev_editor(text: str) -> bool:
        # found[text] 是 lua 根目錄的相對路徑（Windows 為反斜線），
        # DEV_EDITOR_DIRS 是路徑片段，用 substring 比對而非 startswith
        return all(
            any(d in f.replace("\\", "/") for d in DEV_EDITOR_DIRS)
            for f in found[text]
        )

    covered, uncovered, dev_editor, dead, concat = [], [], [], [], []
    for text in found:
        if text in DELIBERATE:
            continue
        if derive_key(text) in keys:
            covered.append(text)
        elif text in CONCAT_PREFIX:
            concat.append(text)
        elif text in DEAD_CODE:
            dead.append(text)
        elif is_dev_editor(text):
            dev_editor.append(text)
        else:
            uncovered.append(text)

    orphans = keys - {derive_key(t) for t in found} - {k for k in keys if "_Pat_" in k}

    total = len(covered) + len(uncovered)
    pct = (len(covered) / total * 100) if total else 0.0
    print(f"情境選單英文字面（扣除已知豁免後）：{total} 條"
          f"　｜　非選單接收者 {skipped_recv} 處、刻意保留 {len(DELIBERATE)} 條")
    print(f"已涵蓋 {len(covered)}（{pct:.1f}%）  未涵蓋 {len(uncovered)}")
    print(f"另計：開發者編輯器 {len(dev_editor)} 條（B15-f，明確不修）、"
          f"零呼叫點死碼 {len(dead)} 條（官方接線後才需處理）、"
          f"拼接前綴 {len(concat)} 條（由 PATTERNS 於執行期處理）")
    print(f"我方 {PREFIX}* 鍵 {len(keys)} 個，其中未對應到任何 vanilla Lua 字面"
          f" {len(orphans)} 個")
    print("  ⚠️ 這些多半**不是**真孤兒：Randomized Building / Vehicle / Zombie 故事名"
          "來自 Java getName()、選項 tooltip 走 setName() 而非 addOption，"
          "本掃描只讀 Lua 的 addOption 字面，看不到它們。刪鍵前務必個別查證。")

    if args.list:
        print("\n--- 未涵蓋 ---")
        for t in sorted(uncovered):
            print(f"  {t!r}\n      -> {derive_key(t)}\n      出現於 {found[t][0]}"
                  f"{'（等 %d 檔）' % len(found[t]) if len(found[t]) > 1 else ''}")
        print("\n--- 孤兒鍵（抽樣 30）---")
        for k in sorted(orphans)[:30]:
            print(f"  {k}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
