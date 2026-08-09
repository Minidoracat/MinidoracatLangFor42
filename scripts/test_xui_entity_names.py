"""A28 守門：實體工作站名稱是否真的翻得到（xuiSkin DisplayName → Recipes.json）。

## 機制（2026-08-09 由 codex review 更正，原本的理解是錯的）

xuiSkin 腳本寫的是英文字面：

    entity ES_Advanced_Forge { DisplayName = Advanced Forge, ... }

**關鍵在生產端而不是消費端**。`XuiSkinScript.java:163-169` 在**腳本解析期**就做了：

    String newVal = val.replace(" ", "");              // "AdvancedForge"
    String translatedText = Translator.getRecipeName(newVal);
    if (!translatedText.equalsIgnoreCase(newVal)) val = translatedText;
    entityUiScript.displayName = val;                  // 存的已經是譯文

`Core.java` 的 `Translator.loadFiles()` 早於 `ScriptManager.instance.Load()`，
所以解析時翻譯表已就緒。也就是說 **`Recipes.json` 就是這批名稱的真相來源**。

消費端 `XuiSkin.java:350/393` 的 `Translator.getText(this.displayName)` 拿到的
已是中文，`getTextInternal` 純前綴路由查不到便原樣回傳——結果正確。

⚠️ **不要因為看到 `getText(字面)` 就以為需要 Lua 反查修補。** 本專案曾據此寫了
一支 `XuiEntityName_Flx.lua` 與 86 個 `IGUI_XuiEntity_*` 鍵，實際 43/44 全是
no-op，而且補的值與 `Recipes.json` 實際生效值分岔了 12～13 筆（例如 `BlastFurnace`
實際「高階熔爐」卻補成「鼓風熔爐」），等於製造第二套詞彙真相。整批已撤銷。

## 真正的失效模式

`getRecipeName` 查不到鍵時回傳鍵名本身（`Translator.java:675-686`），於是畫面
顯示去空格後的英文字面。所以守門條件是：**每個 DisplayName 去空格後都要在
CH/CN `Recipes.json` 有鍵**。

本檔只對「可見」子集強制要求——`ISEntityUI.CanOpenWindowFor`（`ISEntityUI.lua:332`）
檢查 `config:isUiEnabled()`，只有 `uiEnabled = true` 的實體會開視窗／進世界右鍵
選單／出現在手把互動提示（`ISButtonPrompt.lua:624-633`）。其餘僅列為資訊。

⚠️ **潛在風險**：`ISEntityBuildMenu.lua:77-78` 也吃 `style:getDisplayName()`，
目前因 `hasSomethingToBuild()` 開頭是 `return; --TODO REMOVE` 而不可達。官方
若把它接回來，那 39 個不可見名稱就會一起變成可見缺口。升版時請重查該死碼。

解析 xuiSkin 用**大括號配對**，不靠縮排猜測（各檔縮排不一致，會漏）也不靠
扁平掃描（會把巢狀 component 的值算到 entity 頭上）。

用法：uv run python scripts/test_xui_entity_names.py
      找不到 vanilla 時預設失敗；CI 等沒裝遊戲的環境用 --allow-no-vanilla。
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MOD = ROOT / "MOD/MinidoracatLangFor42/Contents/mods/MinidoracatLangFor42/42/media"
TRANSLATE = MOD / "lua/shared/Translate"
VANILLA = Path("D:/SteamLibrary/steamapps/common/ProjectZomboid/media")

failed: list[str] = []


def fail(msg: str) -> None:
    failed.append(msg)
    print(f"FAIL: {msg}")


def recipe_key(display_name: str) -> str:
    """複刻 XuiSkinScript.java:164 的 `val.replace(" ", "")`。"""
    return display_name.replace(" ", "")


def _blocks(text: str):
    """以大括號配對逐行解析，yield (path_tuple, key, value)。

    `{` 出現時把最近一個非空、非括號的行當成該區塊標頭，因此 path 會長成
    ('xuiSkin default', 'entity ES_Forge', 'components', 'component X')。
    """
    stack: list[str] = []
    pending = ""
    for raw in text.splitlines():
        line = raw.strip()
        while line:
            if line.startswith("{"):
                stack.append(pending)
                pending = ""
                line = line[1:].strip()
                continue
            if line.startswith("}"):
                if stack:
                    stack.pop()
                pending = ""
                line = line[1:].strip()
                continue
            m = re.search(r"[{}]", line)
            seg, line = (line[: m.start()], line[m.start():]) if m else (line, "")
            for piece in seg.split(","):
                piece = piece.strip()
                if not piece:
                    continue
                if "=" in piece:
                    k, _, v = piece.partition("=")
                    yield tuple(stack), k.strip(), v.strip()
                else:
                    pending = piece


def ui_enabled_styles() -> set[str]:
    """entity 定義中 uiEnabled = true 者所引用的 entityStyle 名。

    註：`UiConfigScript` 的 Java 預設值是 true 且解析大小寫不敏感，此處只認
    腳本裡明寫的小寫 true——42.20.2 全庫實測 200 個引用皆明寫，故等價；
    若日後官方開始省略該欄，本函式會低估，需同步放寬。
    """
    out: set[str] = set()
    for p in (VANILLA / "scripts").rglob("entity_*.txt"):
        try:
            t = p.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for m in re.finditer(r"entity\s+(\w+)\s*\n\s*\{(.*?)\n    \}", t, re.S):
            st = re.search(r"entityStyle\s*=\s*(\w+)", m.group(2))
            ui = re.search(r"uiEnabled\s*=\s*(\w+)", m.group(2))
            if st and ui and ui.group(1) == "true":
                out.add(st.group(1))
    return out


def display_names() -> tuple[dict[str, set[str]], dict[str, set[str]]]:
    """回傳 (可見, 不可見)，各為 {DisplayName: {來源說明}}。"""
    entity_dn: dict[str, str] = {}
    comp_dn: dict[str, set[str]] = {}
    for p in (VANILLA / "scripts").rglob("*.txt"):
        try:
            t = p.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        if "xuiSkin" not in t:
            continue
        for path, k, v in _blocks(t):
            if k != "DisplayName" or not v:
                continue
            ent = next((s for s in path if s.startswith("entity ")), None)
            if not ent:
                continue
            style = ent.split(None, 1)[1]
            if any(s.startswith("component ") or s == "components" for s in path):
                comp_dn.setdefault(v, set()).add(style)
            else:
                entity_dn[style] = v

    vis = ui_enabled_styles()
    visible: dict[str, set[str]] = {}
    hidden: dict[str, set[str]] = {}
    for style, dn in entity_dn.items():
        (visible if style in vis else hidden).setdefault(dn, set()).add(f"entity {style}")
    for dn, styles in comp_dn.items():
        for style in styles:
            (visible if style in vis else hidden).setdefault(dn, set()).add(f"component of {style}")
    return visible, {k: v for k, v in hidden.items() if k not in visible}


def load_recipes(lang: str) -> dict[str, str]:
    return json.loads((TRANSLATE / lang / "Recipes.json").read_text(encoding="utf-8-sig"))


def main() -> int:
    if not VANILLA.is_dir():
        # 不可以回 0——整份檢查都沒跑，回綠燈等於守門失效。
        lenient = "--allow-no-vanilla" in sys.argv
        print(f"{'INCOMPLETE' if lenient else 'FAIL'}: 找不到 vanilla（{VANILLA}），"
              f"xuiSkin 涵蓋率檢查未執行")
        return 0 if lenient else 1

    ch, cn = load_recipes("CH"), load_recipes("CN")
    visible, hidden = display_names()
    if not visible:
        fail("掃不到任何 uiEnabled=true 的 DisplayName——解析規則可能已失效")
        return 1

    for lang, d in (("CH", ch), ("CN", cn)):
        missing = sorted(n for n in visible if recipe_key(n) not in d)
        if missing:
            fail(f"{lang} 有 {len(missing)} 個可見工作站名稱在 Recipes.json 查無鍵"
                 f"（遊戲會顯示去空格的英文字面）："
                 f"{[(n, recipe_key(n), sorted(visible[n])) for n in missing[:6]]}")
        # 值不得等於鍵名本身——那會讓 XuiSkinScript 的 equalsIgnoreCase 判定
        # 「沒翻到」而保留英文原字面
        for n in visible:
            k = recipe_key(n)
            v = d.get(k)
            if v is not None and (not v.strip() or v.lower() == k.lower() or v == n):
                fail(f"[{lang}] Recipes.json 的 {k!r} 值無效（等同未翻）：{v!r}")

    gap_hidden = sorted(n for n in hidden if recipe_key(n) not in ch)
    if gap_hidden:
        print(f"ℹ️ 另有 {len(gap_hidden)} 個 DisplayName 查無 Recipes 鍵，但其實體 "
              f"uiEnabled=false 故目前不可見。若官方把 ISEntityBuildMenu "
              f"（hasSomethingToBuild 目前是 `return; --TODO REMOVE` 死碼）接回來，"
              f"這些會一起變成缺口：{gap_hidden[:5]}…")

    if failed:
        print(f"\n{len(failed)} 項失敗")
        return 1
    print(f"PASS: {len(visible)} 個可見工作站名稱（entity＋component 層）"
          f"去空格後在 CH/CN Recipes.json 皆有有效譯文")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
