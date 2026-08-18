# /// script
# requires-python = ">=3.11"
# ///
"""streets.xml 同步資料閘門回歸測試。

驗證 MOD 中文街道檔與官方 vanilla streets.xml 的結構一致性：
  1. XML well-formed
  2. 條目數與幾何＋width **依官方順序逐位一致**（zip 對位；檔案以官方順序逐條
     重建，順序即對應關係——多重集合比對會放過整片錯位）—— 官方新增/移除/
     改線街道未同步時在此失敗（42.20.3 路名中英混雜事件的資料面根因）
  3. 官方 streets.xml 承載目錄集合仍 == {Muldraugh, KY}（MapStreets_Flx.lua
     只跳過該目錄；集合變動＝需擴充跳過清單）
  4. 無純 ASCII 街名（未翻譯偵測；含中文的混合名如「JC卡羅爾路」合法）
  5. 全檔 CRLF 行尾（拒混合行尾與裸 CR）、無 BOM（與官方檔一致）

官方檔缺失（無 PZ 安裝）時 exit 2 跳過；可用環境變數 PZ_PATH 覆蓋安裝路徑。
PZ 版本更新後必跑：失敗即代表官方動了 streets.xml，需重跑同步流程
（幾何橋映射沿用 + 新街名人工翻譯，見 HARDCODE_REGISTRY.md 42.20.3 對版結論）。
"""

import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OURS = (
    REPO
    / "MOD/MinidoracatLangFor42/Contents/mods/MinidoracatLangFor42/42/media/maps/Riverside, KY/streets.xml"
)
PZ_PATH = Path(os.environ.get("PZ_PATH", r"D:\SteamLibrary\steamapps\common\ProjectZomboid"))
OFFICIAL = PZ_PATH / "media" / "maps" / "Muldraugh, KY" / "streets.xml"


def load(path: Path):
    root = ET.parse(path).getroot()
    out = []
    for s in root.findall("street"):
        pts = tuple(
            (float(p.get("x")), float(p.get("y"))) for p in s.find("points").findall("point")
        )
        out.append({"name": s.get("name"), "width": s.get("width"), "pts": pts})
    return out


def main() -> int:
    if not OFFICIAL.exists():
        print(f"SKIP: 官方檔不存在（{OFFICIAL}），設 PZ_PATH 後重跑")
        return 2

    failures = []

    raw = OURS.read_bytes()
    if raw[:3] == b"\xef\xbb\xbf":
        failures.append("我方檔含 BOM（應為 UTF-8 無 BOM）")
    if b"\r\n" not in raw:
        failures.append("我方檔非 CRLF 行尾（應與官方一致）")
    else:
        stripped = raw.replace(b"\r\n", b"")
        if b"\n" in stripped or b"\r" in stripped:
            failures.append("我方檔含混合行尾（存在非 CRLF 的裸 LF 或裸 CR）")

    ours = load(OURS)  # 解析失敗直接拋例外 = XML 不合法
    off = load(OFFICIAL)

    if len(ours) != len(off):
        failures.append(f"條目數不一致：我方 {len(ours)} vs 官方 {len(off)}")
    # 幾何＋width 逐位比對：檔案以官方順序逐條重建，順序即對應關係；
    # 多重集合比對會放過「整片錯位但集合相等」的對位錯亂（review lanes 共識）
    mism = [
        i
        for i, (a, b) in enumerate(zip(off, ours))
        if a["pts"] != b["pts"] or a["width"] != b["width"]
    ]
    if mism:
        i = mism[0]
        failures.append(
            f"幾何/width 逐位不一致 {len(mism)} 條（首例 #{i}：官方 {off[i]['name']!r} w={off[i]['width']} vs 我方 {ours[i]['name']!r} w={ours[i]['width']}）——官方 streets.xml 已改版，需重同步"
        )

    # 核心不變量：官方英文街道檔的唯一承載目錄必須仍是 Muldraugh, KY——
    # MapStreets_Flx.lua 只跳過該目錄；若官方新增第二個帶 streets.xml 的地圖目錄，
    # 其英文街道會被目錄迴圈載入、與中文並存（幽靈街道事件重演），必須擴充跳過清單
    carriers = sorted(p.parent.name for p in (PZ_PATH / "media" / "maps").glob("*/streets.xml"))
    if carriers != ["Muldraugh, KY"]:
        failures.append(
            f"官方 streets.xml 承載目錄集合變動：{carriers}（預期僅 ['Muldraugh, KY']）——需同步擴充 MapStreets_Flx.lua 的跳過清單與本閘門"
        )

    ascii_names = sorted({s["name"] for s in ours if all(ord(ch) < 128 for ch in s["name"])})
    if ascii_names:
        failures.append(f"疑似未翻譯街名 {len(ascii_names)} 個：{ascii_names[:10]}")

    if failures:
        print("FAIL: streets.xml 資料閘門")
        for f in failures:
            print("  -", f)
        return 1

    print(f"PASS: streets.xml 資料閘門（{len(ours)} 條，與官方 {OFFICIAL.parent.name} 幾何一致、全譯）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
