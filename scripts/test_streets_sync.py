# /// script
# requires-python = ">=3.11"
# ///
"""街名翻譯資料閘門回歸測試（純文字覆蓋，無 XML 幾何副本）。

42.20.4 起街名中文化改走 Translate/CH|CN/UI.json 的 `UI_WorldMapStreet_<原版街名>`
鍵（鍵＝字面前綴＋官方街名原字串），MapStreets_Flx.lua 只在原版 loader 的顯示
副本窗口套字，不再夾帶 streets.xml。本閘門驗：

  1. 沒有 XML 幾何副本殘留：MOD 樹內不得再出現 maps/**/streets.xml
  2. CH / CN 兩語系的街名鍵集與譯值完全一致
  3. 譯值有效：非空白、不等於鍵名、不等於英文原名（未翻譯偵測）
  4. 覆蓋當前官方街名：官方 Muldraugh, KY/streets.xml 每個街名都有譯鍵
  5. 無殘留譯鍵：官方已不存在的街名不該還留著（官方改版後的清理提示）

刻意不再比對幾何／width／點數／條目數——我方不再持有街道幾何，官方改線、
增減條目都不影響本包；唯一需要跟版的是「官方出現新街名」，由第 4 項抓。

官方檔缺失（無 PZ 安裝）時 exit 2 跳過官方相關項（1-3 仍會跑）；
可用環境變數 PZ_PATH 覆蓋安裝路徑。
"""

import json
import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MOD_MEDIA = REPO / "MOD/MinidoracatLangFor42/Contents/mods/MinidoracatLangFor42/42/media"
TRANSLATE = MOD_MEDIA / "lua/shared/Translate"
LANGS = ("CH", "CN")
KEY_PREFIX = "UI_WorldMapStreet_"

PZ_PATH = Path(os.environ.get("PZ_PATH", r"D:\SteamLibrary\steamapps\common\ProjectZomboid"))
OFFICIAL = PZ_PATH / "media" / "maps" / "Muldraugh, KY" / "streets.xml"


def main() -> int:
    failures = []

    # 1. 幾何副本已退場
    leftovers = sorted(str(p.relative_to(REPO)) for p in MOD_MEDIA.glob("maps/*/streets.xml"))
    if leftovers:
        failures.append(f"MOD 樹仍有 streets.xml 幾何副本：{leftovers}——街名已改走翻譯鍵，副本會與官方資料打架")

    # 2+3. 各語系鍵集與譯值
    per_lang = {}
    for lang in LANGS:
        path = TRANSLATE / lang / "UI.json"
        data = json.loads(path.read_text(encoding="utf-8"))  # 解析失敗直接拋例外＝檔案不合法
        entries = {k: v for k, v in data.items() if k.startswith(KEY_PREFIX)}
        per_lang[lang] = entries
        if not entries:
            failures.append(f"{lang}/UI.json 沒有任何 {KEY_PREFIX}* 街名鍵")
        for key in sorted(entries):
            value, original = entries[key], key[len(KEY_PREFIX):]
            if not original:
                failures.append(f"{lang}：{key} 缺原版街名（前綴後為空）")
            if not isinstance(value, str) or not value.strip():
                failures.append(f"{lang}：{key} 譯值為空")
            elif value == key:
                failures.append(f"{lang}：{key} 譯值等於鍵名（遊戲內會顯示裸 key）")
            elif value == original:
                failures.append(f"{lang}：{key} 尚未翻譯（譯值等於英文原名）")

    if per_lang["CH"].keys() != per_lang["CN"].keys():
        only_ch = sorted(per_lang["CH"].keys() - per_lang["CN"].keys())
        only_cn = sorted(per_lang["CN"].keys() - per_lang["CH"].keys())
        failures.append(f"CH/CN 街名鍵集不一致：僅 CH {only_ch[:5]}（{len(only_ch)}）／僅 CN {only_cn[:5]}（{len(only_cn)}）")
    elif per_lang["CH"] != per_lang["CN"]:
        failures.append("CH/CN 街名譯值不一致")

    maps = PZ_PATH / "media" / "maps"
    if maps.is_dir():
        sources = {path.parent.name.lower() for path in maps.glob("*/streets.xml")}
        if sources != {"muldraugh, ky"}:
            failures.append(f"官方街道承載目錄已變動，需審核純文字 loader 範圍：{sorted(sources)}")

    # 4+5. 對當前官方街名的覆蓋
    if OFFICIAL.exists():
        root = ET.parse(OFFICIAL).getroot()
        official_names = {s.get("name") for s in root.findall("street")}
        have = {k[len(KEY_PREFIX):] for k in per_lang["CH"]}
        missing = sorted(official_names - have)
        if missing:
            failures.append(f"官方街名缺譯鍵 {len(missing)} 個（官方已改版，需補譯）：{missing[:10]}")
        stale = sorted(have - official_names)
        if stale:
            failures.append(f"殘留譯鍵 {len(stale)} 個（官方已無此街名，請刪除）：{stale[:10]}")
    elif not failures:
        print(f"SKIP: 官方檔不存在（{OFFICIAL}），已驗鍵集/譯值，官方覆蓋項跳過；設 PZ_PATH 後重跑")
        return 2

    if failures:
        print("FAIL: 街名翻譯資料閘門")
        for f in failures:
            print("  -", f)
        return 1

    print(f"PASS: 街名翻譯資料閘門（{len(official_names)} 個官方街名全覆蓋，CH/CN 各 {len(per_lang['CH'])} 鍵，無 XML 副本）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
