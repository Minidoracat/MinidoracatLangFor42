# /// script
# dependencies = []
# requires-python = ">=3.10"
# ///
# pyright: reportMissingImports=false, reportMissingTypeArgument=false
"""
PZ 翻譯同步工具
用途：將 translation-reference (簡體中文) 同步到 MOD 目錄（CN + CH）
使用方式：uv run scripts/sync_translations.py [命令]

命令：
  compare         - 比對差異（預設）
  sync-cn         - （已凍結）顯示 CN 維護流程說明
  sync-ch         - （已凍結）顯示 CH 維護流程說明，不做任何寫入
  sync-lua        - 同步 Lua 腳本
  sync-all        - 執行全部同步（Lua + fix-check；CH/CN 已凍結）
  fix-check       - 檢查轉換常見錯誤（凍結語料照常適用）
  en-snapshot     - 保存官方 EN 全鍵快照（凍結後維護的基準）
  en-diff         - 官方 EN 新舊 diff → 新增/改值/刪除 維護佇列
  ch-lint         - 術語引擎巡檢 CH 語料（select/lint 詞提示）
  import-new      - 官方 CH 底稿＋術語引擎產出新鍵提案（人工簽核用）
  gen-vehicle-map - 從 vanilla EN IG_UI.json 生成 VehicleKey_Flx 反查表
  gen-item-name-map - 從 vanilla EN ItemName.json 生成 ItemNameFix_Flx 反查表
  gen-radio-map   - 從 vanilla/MOD RadioData.json 生成 RadioData_Flx 英文→RD key 反查表
  gen-media-map   - 從 vanilla recorded_media.lua + EN Recorded_Media.json 生成 RecordedMediaName_Flx 反查表
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
import xml.etree.ElementTree as ET
from collections import OrderedDict
from pathlib import Path


# ============================================================
# 路徑配置
# ============================================================
PROJECT_ROOT = Path(__file__).resolve().parent.parent

if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.pz_translate import (
    PREFIX_STRIP_CATEGORIES,
    SKIP_FILES as PZ_SKIP_FILES,
    detect_category,
    parse_city_directory,
    parse_lua_translation,
    parse_recorded_media,
    read_translation,
    txt_to_json_filename,
)

REF_BASE = PROJECT_ROOT / "translation-reference" / "B42Trans_CN_As1" / "42.0" / "media"
MOD_BASE = (
    PROJECT_ROOT
    / "MOD"
    / "MinidoracatLangFor42"
    / "Contents"
    / "mods"
    / "MinidoracatLangFor42"
    / "42"
    / "media"
)

REF_CN = REF_BASE / "lua" / "shared" / "Translate" / "CN"
MOD_CN = MOD_BASE / "lua" / "shared" / "Translate" / "CN"
MOD_CH = MOD_BASE / "lua" / "shared" / "Translate" / "CH"

REF_LUA = REF_BASE / "lua" / "client"
MOD_LUA = MOD_BASE / "lua" / "client"

# ============================================================
# 特殊檔案處理規則
# ============================================================
# （原 SKIP_CH_CONVERT = {"language.txt"} 已移除：42.20 起 language.txt 是死檔，
#  改由下方 EXCLUDE_GENERATE 統一擋住 CN/CH 兩側生成。）

# ============================================================
# Lua 腳本清單
# ============================================================
# Flx 腳本（雙語通用，直接從 REF 複製）
# MOD 統一使用 _Flx.lua 處理雙語，不再建立分離的 _CN/_CH 版本
FLX_FILES: list[str] = [
    "MapLabel_Flx.lua",
    "ModInfoPanel_FIx.lua",
]

# ============================================================
# OpenCC 後處理修正規則（從 JSON 字典載入）
# ============================================================
FIXES_JSON = Path(__file__).resolve().parent / "opencc_fixes.json"
# 模組包字典（跨專案一致性檢查用）
SIBLING_FIXES_JSON = (
    PROJECT_ROOT.parent / "MinidoracatModLangFor42" / "sources" / "opencc_fixes.json"
)


def _load_fixes() -> tuple[list[tuple[re.Pattern, str, str]], list[dict]]:
    """從 opencc_fixes.json 載入修正規則和可疑模式"""
    try:
        raw = FIXES_JSON.read_text(encoding="utf-8")
    except FileNotFoundError:
        print(f"⚠️ 修正字典不存在：{FIXES_JSON}", file=sys.stderr)
        print("  將不套用任何後處理修正規則。", file=sys.stderr)
        return [], []
    except OSError as exc:
        print(f"⚠️ 無法讀取修正字典：{exc}", file=sys.stderr)
        return [], []

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        print(f"❌ 修正字典 JSON 格式錯誤：{exc}", file=sys.stderr)
        print(f"  請檢查 {FIXES_JSON}", file=sys.stderr)
        sys.exit(1)

    # 載入 post_fixes
    post_fixes: list[tuple[re.Pattern, str, str]] = []
    for group in data.get("post_fixes", []):
        cat = group["category"]
        for rule in group["rules"]:
            desc = f"{cat}: {rule.get('note', rule['replacement'])}"
            post_fixes.append((re.compile(rule["pattern"]), rule["replacement"], desc))

    # 載入 suspicious_patterns
    suspicious: list[dict] = []
    for sp in data.get("suspicious_patterns", []):
        suspicious.append({
            "char": sp["char"],
            "description": sp["description"],
            "after_exclude": sp.get("after_exclude", []),
            "before_exclude": sp.get("before_exclude", []),
            # 整檔豁免：某些檔案的語料性質使該字元恆為正解，逐字排除清單會被撐爆
            # 且反過來削弱其他檔案的檢查力（實例：SurvivorNames 全為人名音譯，
            # 「里」在 布里格斯／克里夫蘭／海因里希 中永遠正確，「裡」永遠是錯的）。
            # 刻意不納入跨專案字典一致性比對——檔名本就因專案而異。
            "skip_files": sp.get("skip_files", []),
        })

    return post_fixes, suspicious


POST_FIXES, SUSPICIOUS_PATTERNS = _load_fixes()

# ============================================================
# 人工覆寫層（皆已封存：ch_overrides.json 2026-07-31、cn_overrides.json 2026-08-06）
# ------------------------------------------------------------
# CN 凍結（sync-cn 墓碑化）後，兩檔皆為歷史紀錄，管線不再讀取；
# 值均已實體化進 CH/CN 成品檔，直接編輯成品即 durable。
# 封存 schema（供讀檔考古）：
#   {"<檔名>|<鍵>": "<人工值>"}                        （簡式）
#   {"<檔名>|<鍵>": {"value": "<人工值>", "ref": "<登記時 REF 原文 hash>"}}
#   {"<檔名>|<鍵>": {"drop": true, "note": "<理由>"}}   （deny-list：死鍵不得輸出）
# drop 的歷史用途：REF（As1 42.0）仍有、但官方 42.20 已移除／改鍵名的死鍵
# （42.20.2 稽核 306 筆）。不用「官方 EN 有無」當自動閘門——實測 REF 有 1320 鍵
# 官方 EN 沒有，其中 1286 鍵仍在出貨（Recipes.json 一檔 512），自動閘會誤刪。
# ============================================================

# 不得生成的 REF 檔：
# - streets.txt：CN/CH 皆未版控也無消費端（街道翻譯走 maps/Riverside, KY/streets.xml）。
# - language.txt：PZ 42.20 起 Languages.java 只認 language.json，tryFillMapFromFile 的
#   路徑模板亦寫死 .json，全快照 grep language.txt 零命中 → 死檔，2026-07-29 已刪除。
#   （MOD 也**不應**改放 language.json：loadTranslateDirectory 對已存在語言是
#   languages.set(index, lang)，會直接覆蓋本體的 CH/CN 語言定義。）
EXCLUDE_GENERATE = {"streets.txt", "language.txt"}

# 人工維護檔：CH/CN 的 credits.txt 為結構化名單（老版/新版/電臺組三區塊，
# Initial commit 以來人工維護），REF 現版為較舊扁平名單，同步會回退名單。
# 42.20 官方移除了 credits.txt 的讀取（改為只認本體目錄的 Credits_Translator.json），
# 名單已於 2026-07-29 遷入 Credits.json 的 credits_CatLangFor42_group / _names
# 兩個自有鍵，由 CreditsScreen_Flx.lua 包裝 doCreditsText 接回；.txt 本體已刪除。
MANUAL_MAINTAINED = {"credits.txt"}


def sha256(path: Path) -> str:
    """計算檔案 SHA256"""
    h = hashlib.sha256()
    h.update(path.read_bytes())
    return h.hexdigest()


# ============================================================
# CH 凍結（2026-07-31）：OpenCC 轉換已退場
# ------------------------------------------------------------
# CH 成品即真相；不再由 REF 全量再生。新鍵匯入走 import-new
# （官方 CH 底稿 → scripts/terminology.py 術語引擎 → 人工簽核）。
# 等價證明見 scripts/test_terminology_equivalence.py（凍結 gate 2）。
# ============================================================


def _validate_print_media_info(key: str, value: str) -> str | None:
    """檢查 Print_Media _info 值是否被截斷。

    Returns:
        錯誤描述字串，None 表示無問題。
    """
    if not key.endswith("_info"):
        return None

    # 檢查 getTexture( 是否有配對的 )
    pos = 0
    while True:
        idx = value.find("getTexture(", pos)
        if idx == -1:
            break
        paren_start = idx + len("getTexture(")
        close_pos = value.find(")", paren_start)
        if close_pos == -1:
            return "getTexture( 缺少閉合括號 — 值被截斷"
        pos = close_pos + 1

    # 檢查最後一個 < 是否有對應的 >
    last_open = value.rfind("<")
    if last_open != -1:
        last_close = value.rfind(">")
        if last_close < last_open:
            return "未閉合的 <type:...> 標籤 — 值被截斷"

    return None


def check_suspicious(text: str, filename: str) -> list[str]:
    """檢查可能需要人工修正的模式（基於 JSON 字典的前後文排除）
    
    支援 PZ 富文本格式（CJK 字元間可能有空格），排除檢查時會跳過空格。
    """
    issues: list[str] = []
    for i, line in enumerate(text.splitlines(), 1):
        for sp in SUSPICIOUS_PATTERNS:
            if filename in sp["skip_files"]:
                continue
            char = sp["char"]
            desc = sp["description"]
            after_ex = sp["after_exclude"]
            before_ex = sp["before_exclude"]
            idx = 0
            while True:
                pos = line.find(char, idx)
                if pos < 0:
                    break
                idx = pos + 1
                # 取後文（跳過空格以處理 PZ 富文本的 CJK 間距）
                after_raw = line[pos + len(char):pos + len(char) + 6]
                after_text = after_raw.replace(" ", "")
                if any(after_text.startswith(ex) for ex in after_ex):
                    continue
                # 取前文（跳過空格）
                before_raw = line[max(0, pos - 6):pos]
                before_text = before_raw.replace(" ", "")
                if any(before_text.endswith(ex) for ex in before_ex):
                    continue
                # 匹配到可疑模式
                ctx_start = max(0, pos - 15)
                ctx_end = min(len(line), pos + len(char) + 15)
                context = line[ctx_start:ctx_end].strip()
                issues.append(f"  {filename}:{i} [{desc}] ...{context}...")
    return issues


# ============================================================
# 比對功能
# ============================================================
def find_changed_files(ref_dir: Path, mod_dir: Path) -> dict[str, dict]:
    """Find changed translation files (REF .txt/.json vs MOD .json)"""
    changes: dict[str, dict] = {}

    # Process .txt files in REF (legacy format)
    for ref_file in sorted(ref_dir.glob("*.txt")):
        if not ref_file.is_file():
            continue
        if ref_file.name in PZ_SKIP_FILES:
            continue

        rel = str(ref_file.relative_to(ref_dir))
        json_name = txt_to_json_filename(ref_file.name)
        mod_file = mod_dir / json_name

        if not mod_file.exists():
            changes[rel] = {
                "status": "new",
                "ref_path": ref_file,
                "mod_path": mod_file,
                "json_name": json_name,
                "ref_size": ref_file.stat().st_size,
            }
            continue

        # Compare parsed content
        ref_data = read_translation(ref_file)
        mod_data = read_translation(mod_file)
        if ref_data != mod_data:
            changes[rel] = {
                "status": "modified",
                "ref_path": ref_file,
                "mod_path": mod_file,
                "json_name": json_name,
                "ref_keys": len(ref_data),
                "mod_keys": len(mod_data),
                "key_delta": len(ref_data) - len(mod_data),
            }

    # Process .json files in REF (new format)
    for ref_file in sorted(ref_dir.glob("*.json")):
        if not ref_file.is_file():
            continue

        rel = str(ref_file.relative_to(ref_dir))
        json_name = ref_file.name
        mod_file = mod_dir / json_name

        if not mod_file.exists():
            changes[rel] = {
                "status": "new",
                "ref_path": ref_file,
                "mod_path": mod_file,
                "json_name": json_name,
                "ref_size": ref_file.stat().st_size,
            }
            continue

        ref_data = read_translation(ref_file)
        mod_data = read_translation(mod_file)
        if ref_data != mod_data:
            changes[rel] = {
                "status": "modified",
                "ref_path": ref_file,
                "mod_path": mod_file,
                "json_name": json_name,
                "ref_keys": len(ref_data),
                "mod_keys": len(mod_data),
                "key_delta": len(ref_data) - len(mod_data),
            }

    # Process city directories in REF (legacy format)
    for city_dir in sorted(d for d in ref_dir.iterdir() if d.is_dir()):
        title_path = city_dir / "title.txt"
        desc_path = city_dir / "description.txt"
        if not title_path.exists() or not desc_path.exists():
            continue

        rel = city_dir.name + "/"
        json_name = f"{city_dir.name}.json"
        mod_file = mod_dir / json_name

        # Skip if already handled by .json glob above
        if json_name in {info["json_name"] for info in changes.values()}:
            continue

        if not mod_file.exists():
            changes[rel] = {
                "status": "new",
                "ref_path": city_dir,
                "mod_path": mod_file,
                "json_name": json_name,
            }
            continue

        ref_data = parse_city_directory(city_dir)
        mod_data = read_translation(mod_file)
        if ref_data != mod_data:
            changes[rel] = {
                "status": "modified",
                "ref_path": city_dir,
                "mod_path": mod_file,
                "json_name": json_name,
            }

    return changes


def cmd_compare():
    """比對命令"""
    print("=" * 60)
    print("翻譯同步比對報告")
    print("=" * 60)
    
    # CN vs CN
    print("\n📁 REF CN vs MOD CN（直接比對）")
    print("-" * 40)
    cn_changes = find_changed_files(REF_CN, MOD_CN)
    if not cn_changes:
        print("  ✅ 完全相同")
    else:
        for name, info in sorted(cn_changes.items()):
            if info["status"] == "new":
                print(f"  ➕ {name} → {info['json_name']} (新增, {info['ref_size']}B)")
            elif info["status"] == "modified":
                delta = info["key_delta"]
                sign = "+" if delta > 0 else ""
                print(
                    f"  📝 {name} → {info['json_name']} "
                    f"(CN={info['ref_keys']} keys MOD={info['mod_keys']} keys {sign}{delta})"
                )

    # CN vs CH
    print(f"\n📁 REF CN vs MOD CH（簡繁比對）")
    print("-" * 40)
    # Check .txt REF files (legacy)
    for ref_file in sorted(REF_CN.glob("*.txt")):
        if ref_file.name in PZ_SKIP_FILES:
            continue
        json_name = txt_to_json_filename(ref_file.name)
        ch_file = MOD_CH / json_name
        if not ch_file.exists():
            print(f"  ❌ {ref_file.name} → {json_name} (CH 不存在)")
            continue
        ref_data = read_translation(ref_file)
        ch_data = read_translation(ch_file)
        if len(ref_data) != len(ch_data):
            delta = len(ref_data) - len(ch_data)
            sign = "+" if delta > 0 else ""
            print(
                f"  📝 {ref_file.name} → {json_name} "
                f"(CN={len(ref_data)} keys CH={len(ch_data)} keys {sign}{delta})"
            )

    # Check .json REF files (new format)
    for ref_file in sorted(REF_CN.glob("*.json")):
        json_name = ref_file.name
        ch_file = MOD_CH / json_name
        if not ch_file.exists():
            print(f"  ❌ {json_name} (CH 不存在)")
            continue
        ref_data = read_translation(ref_file)
        ch_data = read_translation(ch_file)
        if len(ref_data) != len(ch_data):
            delta = len(ref_data) - len(ch_data)
            sign = "+" if delta > 0 else ""
            print(
                f"  📝 {json_name} "
                f"(CN={len(ref_data)} keys CH={len(ch_data)} keys {sign}{delta})"
            )

    # Also check city directories (legacy)
    for city_dir in sorted(d for d in REF_CN.iterdir() if d.is_dir()):
        title_path = city_dir / "title.txt"
        if not title_path.exists():
            continue
        json_name = f"{city_dir.name}.json"
        ch_file = MOD_CH / json_name
        if not ch_file.exists():
            print(f"  ❌ {city_dir.name}/ → {json_name} (CH 不存在)")

    # Lua 腳本（Flx 雙語腳本）
    print(f"\n📁 Lua 腳本比對")
    print("-" * 40)
    for flx in FLX_FILES:
        ref_f = REF_LUA / flx
        mod_f = MOD_LUA / flx
        if not ref_f.exists():
            continue
        if not mod_f.exists():
            print(f"  ➕ {flx} (Flx 腳本 MOD 不存在)")
            continue
        if sha256(ref_f) != sha256(mod_f):
            print(f"  📝 {flx} (Flx 腳本有差異)")
        else:
            print(f"  ✅ {flx}")


# ============================================================
# 同步功能
# ============================================================
def cmd_sync_cn():
    """（已凍結）CN 不再從 REF 再生。"""
    print("=" * 60)
    print("CN 已凍結（2026-08-06）——sync-cn 不再執行任何寫入")
    print("=" * 60)
    print("CN 成品（MOD/.../Translate/CN）即人工真相，直接編輯即 durable。")
    print("As1 上游改為僅供參考：REF 更新後逐筆審查異動，要採用的改動手動入庫")
    print("（compare 可對照 REF/MOD 鍵覆蓋；新鍵照舊走 en-snapshot / en-diff 追官方 EN）。")
    print("歷史 cn_overrides.json 已封存（值皆已實體化進 CN 檔；")
    print("含 42.20.2 死鍵稽核 deny-list 306 筆——sync-cn 既凍結，死鍵不會再復活）。")
    print("fix-check 守門照常，任何 CN 手改後都要跑。")


def cmd_sync_ch():
    """（已凍結）CH 不再從 REF 再生。"""
    print("=" * 60)
    print("CH 已凍結（2026-07-31）——sync-ch 不再執行任何寫入")
    print("=" * 60)
    print("CH 成品（MOD/.../Translate/CH）即人工真相，維護流程：")
    print("  1. en-snapshot / en-diff  追蹤官方 EN 變動，產生維護佇列")
    print("  2. import-new             官方 CH 底稿＋術語引擎產出新鍵提案（人工簽核後手動入庫）")
    print("  3. ch-lint                術語巡檢（select/lint 詞提示）")
    print("  4. fix-check              既有結構/疊字/空格檢查照常")
    print("歷史 ch_overrides.json 已封存（值皆已實體化進 CH 檔）。")


def check_dict_sync() -> list[str]:
    """比對本體與模組包的 opencc_fixes.json，回傳無註記分岔的清單"""

    issues: list[str] = []

    def load(path: Path, side: str) -> tuple[dict[str, dict], dict[str, dict]] | None:
        # identity 規則（pattern == replacement）為保護性文件規則，不參與比對；
        # 檔內重複 pattern 會互相遮蔽，直接列為問題
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            rules: dict[str, dict] = {}
            for group in data.get("post_fixes", []):
                for rule in group["rules"]:
                    pattern = rule["pattern"]
                    if pattern == rule["replacement"]:
                        continue
                    if pattern in rules:
                        issues.append(f"  {side}字典檔內重複 pattern（後者遮蔽前者）: {pattern}")
                    rules[pattern] = {
                        "replacement": rule["replacement"],
                        "category": group["category"],
                        "note": rule.get("note", ""),
                    }
            sus = {
                sp["char"]: {
                    "before": set(sp.get("before_exclude", [])),
                    "after": set(sp.get("after_exclude", [])),
                }
                for sp in data.get("suspicious_patterns", [])
            }
            return rules, sus
        except (OSError, json.JSONDecodeError, KeyError, TypeError) as exc:
            issues.append(f"  無法讀取{side}字典（{path}）: {exc!r}，本次未比對")
            return None

    def allowed(rule: dict) -> bool:
        return "分岔" in rule["note"] or "勿移植" in rule["note"]

    loaded_mine = load(FIXES_JSON, "本體")
    loaded_theirs = load(SIBLING_FIXES_JSON, "模組包")
    if loaded_mine is None or loaded_theirs is None:
        return issues
    mine, mine_sus = loaded_mine
    theirs, theirs_sus = loaded_theirs

    for pattern, rule in mine.items():
        other = theirs.get(pattern)
        if other is None:
            if not allowed(rule):
                issues.append(
                    f"  本體獨有且無分岔註記: [{rule['category']}] {pattern} → {rule['replacement']}"
                )
        elif other["replacement"] != rule["replacement"]:
            if not (allowed(rule) or allowed(other)):
                issues.append(
                    f"  replacement 分歧且無註記: {pattern} → 本體「{rule['replacement']}」/ 模組包「{other['replacement']}」"
                )
    for pattern, rule in theirs.items():
        if pattern not in mine and not allowed(rule):
            issues.append(
                f"  模組包獨有且無分岔註記: [{rule['category']}] {pattern} → {rule['replacement']}"
            )
    # suspicious_patterns：char 存在性＋前後文排除清單都要同步（description 為純文件，不比對）
    for char in sorted(set(mine_sus) | set(theirs_sus)):
        if char not in mine_sus or char not in theirs_sus:
            side = "本體" if char in mine_sus else "模組包"
            issues.append(f"  suspicious_patterns 僅{side}有: {char}")
            continue
        for field, label in (("before", "before_exclude"), ("after", "after_exclude")):
            a, b = mine_sus[char][field], theirs_sus[char][field]
            if a != b:
                issues.append(
                    f"  suspicious「{char}」{label} 不同步: 本體獨有={sorted(a - b)} 模組包獨有={sorted(b - a)}"
                )
    return issues


# 片段重複偵測：潤色時「擴寫既有短譯」很容易把新增片段貼兩次
# （2026-07-29 於 42.20 盤查抓到 14 筆，最早可追到 commit 698c262 的全量潤色，
#  例如「顯示」擴寫成「顯示與效能」時寫成「顯示與效能與效能」）。
#
# 2026-07-30：這組 pattern 最小片段是 2 字，且跳過 RadioData 等檔、只掃 60 字內，
# 因此完全漏掉**單字**疊字（白白糖／負負八／木木吉他／大大風）與**帶分隔符**的
# 變體（「256x256 像素 像素」）——共 88 鍵在庫裡活過兩個 release。
# 已補：帶分隔符樣式進本組；單字疊字改走 check_dup_single()（需人工複核，見該函式）。
_DUPE_PATTERNS = [
    re.compile(r"([一-鿿]{2,6})\1$"),      # 尾端整段重複
    re.compile(r"([一-鿿]{3,8})\1"),       # 句中長片段重複
    # 中間夾單一標點/空白的片段重複（實例：`256x256 像素 像素`）。
    # ⚠️ 分隔符刻意限定「單一字元」，不可放寬成 [,、\s]+：放寬後會跨過「逗號+空格」
    # 而掃進中文常見的頂真句（`找到它們, 它們也會…`／`低耐力, 低耐力恢復`／
    # `完全顯示, 顯示為…`），2026-07-30 實測產生 13 筆誤報、零真錯。
    re.compile(r"([一-鿿]{2,8})[,、\s]\1"),
    # 英文／拉丁詞組重複。分隔用 \s+ 而非單一空格：`LSU␠␠LSU`（雙空格）曾因此漏檢
    # （2026-07-30 於 Base.Football_Jersey_Blue 手動抓到）。{3,} 是為了排除 `XX XX`
    # 這類佔位樣板（官方 EN 亦如此，屬正常）。
    re.compile(r"\b([A-Za-z]{3,}(?:\s+[A-Za-z]+){0,2})\s+\1\b"),
]

# 逐字重複屬正常表達的檔案（歌詞、廣播、報刊、人名等）不掃
_DUPE_SKIP_FILES = {
    "RadioData.json", "Print_Media.json", "Recorded_Media.json",
    "Print_Text.json", "SurvivorNames.json",
}
_DUPE_MAX_LEN = 60  # 只掃短字串；長敘述重複詞多為正常修辭

# 已對照官方 EN 查證為正常表達的命中（登記制；勿用來塞真錯）。
# 留著永久 ⚠️ 會讓人開始忽略這道檢查，故逐案登記並註明理由。
_DUPE_ALLOWLIST = {
    "Sandbox.json|Sandbox_MetaKnowledge_tooltip":
        '並列選項「完整顯示、顯示為 "???"」；EN: fully shown, shown as "???" or fully hidden',
}

# 單字／雙字疊段：中文大量正常疊用（可可粉／謝謝／娛樂娛樂／使用使用者清單），
# 無法硬性失敗。以「對側語言同鍵是否也疊」當過濾器後仍有噪音（對側是英文原文、
# 或譯文已改寫），故本檢查只輸出待人工複核清單，不計入 fix-check 的成敗。
#
# 為何 2 字疊段放這裡而不是 _DUPE_PATTERNS：把句中 pattern 從 {3,8} 放寬到 {2,8}
# 實測新增 10 筆命中、真錯 0 筆（使用使用者清單 ×5、娛樂娛樂 ×2、啊啊啊啊 ×2、
# 自定义定义颜色 — EN 為 "Custom Defined Colors"，皆合法），2026-07-30。
_DUPE_SINGLE = re.compile(r"([一-鿿])\1")
_DUPE_PAIR = re.compile(r"([一-鿿]{2})\1")
_DUPE_SINGLE_MAX_LEN = 40

# 逐字空格排版：`白 糖` 這種字間有縫的值。As1 原有的（Print_Media 傳單、城鎮
# description 等有排版理由者）對側也帶空格，屬正常；只有「對側無空格」才是
# 我們重譯時帶進來的產物（698c262 造成 1220 筆，2026-07-30 已剝除）。
# 它還會遮蔽疊字偵測（`彈 匣 退 出 退 出` 掃不到），所以必須守住不再回來。
_SPACED_CJK = re.compile(r"(?:[一-鿿] ){3,}[一-鿿]")

# <br> 切段後「相鄰段全等」＝整句被貼兩次。獨立於 _DUPE_PATTERNS：重複單元可以
# 超過片段 regex 的 8 字上限，分隔又是整段 `. <br>`（多字元），兩條 pattern 同時
# 失效——2026-08-06 Tooltip_craft_wallLogDesc「製作簡單但耗費資源」×2 因此漏檢。
# 段落全等比對不會誤報頂真句／修辭，故不受 _DUPE_MAX_LEN 限制。
_BR_SPLIT = re.compile(r"<br\s*/?>", re.IGNORECASE)


def _has_br_segment_dup(value: str) -> bool:
    """<br> 切段後相鄰兩段（去除首尾空白與句點）全等即視為誤植。"""
    segs = [s.strip(" .") for s in _BR_SPLIT.split(value)]
    return any(a and a == b for a, b in zip(segs, segs[1:]))


def check_duplicated_fragments() -> list[str]:
    """找出譯文中疑似「片段被貼兩次」的值（CH + CN）。"""
    issues: list[str] = []
    for lang, mod_dir in (("CH", MOD_CH), ("CN", MOD_CN)):
        for path in sorted(mod_dir.rglob("*.json")):
            if path.name in _DUPE_SKIP_FILES or ".omc" in path.parts:
                continue
            try:
                data = read_translation(path)
            except Exception:  # noqa: BLE001
                continue
            for key, value in data.items():
                if not isinstance(value, str):
                    continue
                if f"{path.name}|{key}" in _DUPE_ALLOWLIST:
                    continue
                if _has_br_segment_dup(value):
                    issues.append(f"  [{lang}] {path.name} | {key}: {value!r}")
                    continue
                if len(value) > _DUPE_MAX_LEN:
                    continue
                if any(p.search(value) for p in _DUPE_PATTERNS):
                    issues.append(f"  [{lang}] {path.name} | {key}: {value!r}")
    return issues


def check_dup_single() -> list[str]:
    """單字／雙字疊段待複核清單（CH/CN 互為對側過濾）。僅提示，不代表錯誤。"""
    notes: list[str] = []
    for lang, mod_dir, other_dir in (("CH", MOD_CH, MOD_CN), ("CN", MOD_CN, MOD_CH)):
        for path in sorted(mod_dir.glob("*.json")):
            try:
                data = read_translation(path)
                other = read_translation(other_dir / path.name)
            except Exception:  # noqa: BLE001
                continue
            for key, value in data.items():
                if not isinstance(value, str) or len(value) > _DUPE_SINGLE_MAX_LEN:
                    continue
                peer = other.get(key)
                for pat, label in ((_DUPE_PAIR, "雙字"), (_DUPE_SINGLE, "單字")):
                    m = pat.search(value)
                    if not m:
                        continue
                    # 對側同鍵也疊 → 原文如此，屬正常表達
                    if isinstance(peer, str) and pat.search(peer):
                        break
                    notes.append(
                        f"  [{lang}] {path.name} | {key}: {value!r} ← {label}疊「{m.group(1)}」"
                    )
                    break
    return notes


def richtext_eaten(value: str) -> int:
    """回傳這個值會被 RichText 吞掉的正文字元數。

    錨點：`ISUI/RichTextLayout.lua` 的 tokenizer（我方 `ISRichTextPanel_Flx.lua` 同邏輯）——
    以空白切 token，token 內同時含 `<` 與 `>` 時整段走 `processCommand`，
    **`<` 之前的正文永遠不會進 `self.lines`**（無字元級 fallback）。
    故 `健康面板.<LINE>` 會讓「健康面板.」整段消失，寫成 `健康面板. <LINE>` 才安全。

    2026-08-09 新增：逐字空格清理曾把 `板 .<LINE>`（只吃 1 字）變成 `板.<LINE>`（吃整句），
    24 個鍵共 975 字元從畫面上消失，而當時的 fix-check 全綠——本檢查即為補上該盲點。
    """
    left, cur, drop, guard = value, 0, 0, 0
    while True:
        guard += 1
        if guard > 20000:  # 病態輸入保險，不該發生
            return drop
        idx = left.find(" ", max(cur, 0))
        if idx < 0:
            break  # 收尾分支（RichTextLayout.lua:343）會渲染剩餘文字，不算損失
        cur = idx + 1
        token = left[:cur]
        if "<" in token and ">" in token:
            cur = token.index(">") + 2
            token = left[: cur - 1]
        left = left[cur - 1 :]
        cur = 1
        if "<" in token and ">" in token:
            drop += len(token[: token.index("<")].strip())
    return drop


# 走 RichText 渲染的檔案（其餘如 RadioData/DynamicRadio 的 <bzzt> 是字面狀聲詞，非標籤）
_RICHTEXT_FILES = {"UI.json", "IG_UI.json", "Tooltip.json", "Challenge.json",
                   "GameSound.json", "SurvivalGuide.json", "Print_Media.json"}


def check_richtext_eaten() -> list[str]:
    """找出正文緊貼 `<TAG>` 而會被 RichText 吞字的值（只報官方 EN 也有的活鍵）。"""
    issues: list[str] = []
    for lang, mod_dir in (("CH", MOD_CH), ("CN", MOD_CN)):
        for path in sorted(mod_dir.glob("*.json")):
            if path.name not in _RICHTEXT_FILES:
                continue
            try:
                data = read_translation(path)
            except Exception:  # noqa: BLE001
                continue
            official_en = _vanilla_lang_optional("EN").get(path.name, {})
            for key, value in data.items():
                if not isinstance(value, str) or "<" not in value:
                    continue
                if official_en and key not in official_en:
                    continue  # 官方 EN 無此鍵＝死鍵，不報
                n = richtext_eaten(value)
                if n > 0:
                    issues.append(f"  [{lang}] {path.name} | {key}: 會吞掉 {n} 字 — {value[:48]!r}")
    return issues


def _vanilla_lang_optional(lang: str) -> dict[str, dict[str, str]]:
    """讀 vanilla 同語系翻譯，回傳 {檔名: {鍵: 值}}；讀不到回空 dict（不中止）。

    與 `_vanilla_translate` 的差別：本函式供 fix-check 使用，未安裝遊戲的機器
    仍要能跑，故不 sys.exit。
    """
    root = VANILLA_PZ_DEFAULT / "media" / "lua" / "shared" / "Translate" / lang
    if not root.is_dir():
        return {}
    out: dict[str, dict[str, str]] = {}
    for f in root.glob("*.json"):
        if f.name == "language.json":
            continue
        try:
            data = json.loads(f.read_text(encoding="utf-8-sig"))
        except Exception:  # noqa: BLE001
            continue
        if isinstance(data, dict):
            out[f.name] = data
    return out


def check_cjk_spacing() -> list[str]:
    """逐字空格排版檢查。

    判準以「官方**同語系**同鍵」為基準：官方乾淨而我方有空格 = 我方倒退。

    2026-08-09 修正：原判準用「對側語言（CH↔CN）同鍵有無空格」，前提是
    「As1 原有排版兩語系都會帶空格」。實測推翻——官方 CH `UI_worldscreen_SavefileVersion`
    是乾淨的、官方 CN 帶空格，我方 CH 抄了 CN 的排版，舊判準因「對側也有空格」
    而放行，漏掉 83 筆真倒退。傳單／城鎮 description 這類官方自己就帶排版者，
    官方同語系同樣有空格，仍會正確放行。

    vanilla 目錄不存在時（未安裝遊戲）退回舊的對側判準，避免整個 fix-check 失效。
    這類值會遮蔽疊字偵測，屬硬性錯誤。
    """
    issues: list[str] = []
    vanilla = {lang: _vanilla_lang_optional(lang) for lang in ("CH", "CN")}
    for lang, mod_dir, other_dir in (("CH", MOD_CH, MOD_CN), ("CN", MOD_CN, MOD_CH)):
        for path in sorted(mod_dir.glob("*.json")):
            try:
                data = read_translation(path)
                other = read_translation(other_dir / path.name)
            except Exception:  # noqa: BLE001
                continue
            official = vanilla[lang].get(path.name, {})
            for key, value in data.items():
                if not isinstance(value, str) or not _SPACED_CJK.search(value):
                    continue
                ref = official.get(key)
                if isinstance(ref, str):
                    # 有官方同語系可比：官方也帶空格 = 繼承，放行
                    if _SPACED_CJK.search(ref):
                        continue
                else:
                    # 無官方可比（我方自有鍵／未安裝遊戲）→ 退回對側判準
                    peer = other.get(key)
                    if isinstance(peer, str) and _SPACED_CJK.search(peer):
                        continue
                issues.append(f"  [{lang}] {path.name} | {key}: {value[:56]!r}")
    return issues


# ============================================================
# 42.20.1 起 Translator 對所有 getText 結果強制跑 String.formatted()：
# 字面 % 必須寫成 %%，printf 式（%s/%d/%i/%.1f）官方已全改為 %1-%9 編號佔位。
# 裸 % 會拋 UnknownFormatConversionException（未被捕捉）→ 主選單黑畫面。
# ============================================================
_FORMAT_SAFE = re.compile(r"%%|%[1-9]")
# 單趟由左至右消耗：%% 與 %1-%9 優先於 printf，%%s 才不會被誤判成 printf
_FORMAT_TOKEN = re.compile(r"%%|%[1-9]|%(?:\.\d+)?[sdif]|%")


def sanitize_format_tokens(value: str, warn_key: str = "") -> str:
    """把翻譯值整理成 42.20.1 formatted() 安全形式（冪等）。

    1. printf 式佔位依出現順序轉編號 %1-%9
    2. 其餘孤立 % 一律逸出為 %%（%% 與 %1-%9 保留不動）

    無法「等價」轉換者（printf 與編號混用、printf 超過 9 個、%02d 之類變體）
    一律 raise ValueError fail-closed——逸出成字面會讓引數從畫面上消失，
    這種語義破壞不可以靜默寫回檔案，須入 cn_overrides 人工處理。
    """
    if "%" not in value:
        return value
    tokens = _FORMAT_TOKEN.findall(value)
    printf_count = sum(1 for t in tokens if len(t) > 2 or (len(t) == 2 and t[1] in "sdif"))
    if printf_count:
        if any(len(t) == 2 and t[1].isdigit() for t in tokens):
            raise ValueError(f"{warn_key}: 同時含編號與 printf 佔位，無法等價轉換，請人工處理")
        if printf_count > 9:
            raise ValueError(f"{warn_key}: printf 佔位超過 9 個（%10 起無效），請人工處理")
    counter = [0]

    def _tok(m: re.Match) -> str:
        t = m.group(0)
        if t == "%%" or (len(t) == 2 and t[1].isdigit()):
            return t
        if len(t) > 1:  # printf 佔位
            counter[0] += 1
            return f"%{counter[0]}"
        # 孤立 %：帶修飾符的 printf 變體（%02d、%-5s、%.2x）無歧義是格式模板，
        # 逸出會吃掉引數 → fail-closed；裸 %字母（%b、%off）視為散文照常逸出
        follow = m.string[m.end() : m.end() + 6]
        if re.match(r"(?:[-+#,0]\d*(?:\.\d+)?|\.\d+)[a-zA-Z]", follow or ""):
            raise ValueError(f"{warn_key}: 疑似 printf 變體 %{follow[:4]}…，無法等價轉換，請人工處理")
        return "%%"

    return _FORMAT_TOKEN.sub(_tok, value)


def _format_token_issues(value: str) -> list[str]:
    """單一翻譯值的危險 % 序列清單（check_format_tokens 的純函式核心）。"""
    issues: list[str] = []
    if re.search(r"%[1-9]\$", value):
        issues.append("%N$（Java 編號式，formatFixer 會疊成 %N$s$s）")
    if re.search(r"%[1-9](?=\d|\.\d)", value):
        issues.append("%N 後緊接數字（formatFixer 只認 %1-%9，殘位變字面）")
    residue = _FORMAT_SAFE.sub("", value)
    issues += [f"%{m.group(1) or '<行尾>'}" for m in re.finditer(r"%(.)?", residue, re.S)]
    return issues


def check_format_tokens() -> list[str]:
    """掃出 formatted() 會炸或吃不掉的 % 序列（CH + CN）。

    移除安全 token（%% 與 %1-%9）後殘留的任何 % 都是問題：
    行尾孤立 %、'% '、%CJK 會直接 crash；%s/%d 類會被吞參數顯示原文。
    """
    issues: list[str] = []
    for lang, mod_dir in (("CH", MOD_CH), ("CN", MOD_CN)):
        for path in sorted(mod_dir.glob("*.json")):
            try:
                data = read_translation(path)
            except Exception as exc:  # noqa: BLE001
                issues.append(f"  [{lang}] {path.name}: 無法解析（{exc}）")
                continue
            # city 檔（僅 title/description 兩鍵）走 readMapTranslation 原樣取值，
            # 不經 formatted()，裸 % 安全——與 cmd_sync_cn 的 city 豁免對稱
            if data and set(data) <= {"title", "description"}:
                continue
            for key, value in data.items():
                if not isinstance(value, str) or "%" not in value:
                    continue
                bad = _format_token_issues(value)
                if bad:
                    issues.append(f"  [{lang}] {path.name} | {key}: {' '.join(bad)} ← {value[:48]!r}")
    return issues


def cmd_fix_check():
    """檢查 OpenCC 轉換常見錯誤"""
    print("=" * 60)
    print("OpenCC 轉換結果檢查（CH 翻譯檔 + CH Lua）")
    print("=" * 60)

    all_issues: list[str] = []

    # Check CH translation JSON files（跳過 .omc 等工具 runtime state 目錄）
    for ch_file in sorted(MOD_CH.rglob("*.json")):
        if ".omc" in ch_file.parts:
            continue
        data = read_translation(ch_file)
        # Check values for suspicious patterns
        content = "\n".join(data.values())
        rel_path = ch_file.relative_to(MOD_CH)
        issues = check_suspicious(content, str(rel_path))
        all_issues.extend(issues)

    # Check Print_Media _info values for truncation (CH + CN)
    for lang, mod_dir in [("CH", MOD_CH), ("CN", MOD_CN)]:
        pm_file = mod_dir / "Print_Media.json"
        if pm_file.exists():
            pm_data = read_translation(pm_file)
            for key, value in pm_data.items():
                err = _validate_print_media_info(key, value)
                if err:
                    all_issues.append(f"  [{lang}] {key}: {err}")

    # Check remaining .txt files (streets.txt, credits.txt)
    for ch_file in sorted(MOD_CH.rglob("*.txt")):
        if ch_file.name in {"language.txt"} or ".omc" in ch_file.parts:
            continue
        content = ch_file.read_text(encoding="utf-8-sig")
        rel_path = ch_file.relative_to(MOD_CH)
        issues = check_suspicious(content, str(rel_path))
        all_issues.extend(issues)

    # Check Flx Lua scripts
    for flx in FLX_FILES:
        lua_f = MOD_LUA / flx
        if lua_f.exists():
            content = lua_f.read_text(encoding="utf-8-sig")
            issues = check_suspicious(content, flx)
            all_issues.extend(issues)

    if all_issues:
        print(f"\n⚠️ 發現 {len(all_issues)} 處可能需要人工檢查：")
        for issue in all_issues:
            print(issue)
    else:
        print("\n✅ 未發現可疑的轉換錯誤")

    # % 格式 token（42.20.1 formatted() 硬性；裸 % 會黑畫面 crash）
    print("\n" + "=" * 60)
    print("% 格式 token 檢查（CH + CN，42.20.1 Translator.formatted() 相容性）")
    print("=" * 60)
    fmt_issues = check_format_tokens()
    if fmt_issues:
        print(f"❌ 發現 {len(fmt_issues)} 處危險 % 序列（裸 % 會使遊戲主選單 crash）：")
        for issue in fmt_issues:
            print(issue)
    else:
        print("✅ 所有 % 序列皆為 formatted() 安全形式")
    # 唯一 crash 級守門：其餘檢查屬外觀類照舊只列印，這類必須讓執行失敗
    format_gate_failed = bool(fmt_issues)

    # 片段重複（潤色擴寫時貼兩次）
    print("\n" + "=" * 60)
    print("譯文片段重複檢查（CH + CN）")
    print("=" * 60)
    dupes = check_duplicated_fragments()
    if dupes:
        print(f"⚠️ 發現 {len(dupes)} 處疑似片段重複（多為擴寫短譯時貼兩次）：")
        for issue in dupes:
            print(issue)
    else:
        print("✅ 未發現片段重複")

    # 逐字空格排版（硬性；會遮蔽疊字偵測）
    print("\n" + "=" * 60)
    print("逐字空格排版檢查（CH + CN，官方同語系同鍵乾淨者＝我方倒退）")
    print("=" * 60)
    spaced = check_cjk_spacing()
    if spaced:
        print(f"⚠️ 發現 {len(spaced)} 處逐字空格排版（重譯產物；會遮蔽疊字偵測，應剝除）：")
        for issue in spaced:
            print(issue)
    else:
        print("✅ 未發現逐字空格排版")

    # RichText 吞字（硬性；正文緊貼 <TAG> 會讓整段從畫面消失）
    print("\n" + "=" * 60)
    print("RichText 吞字檢查（CH + CN，正文緊貼 <TAG> 者）")
    print("=" * 60)
    eaten_issues = check_richtext_eaten()
    if eaten_issues:
        print(f"⚠️ 發現 {len(eaten_issues)} 處會被 processCommand 吞掉正文（標籤前需補空白）：")
        for issue in eaten_issues:
            print(issue)
    else:
        print("✅ 未發現 RichText 吞字")

    # 單字／雙字疊段（僅提示；中文大量正常疊用，須人工複核）
    print("\n" + "=" * 60)
    print("單字／雙字疊段待複核（CH + CN，對側語言同鍵未疊者）")
    print("=" * 60)
    singles = check_dup_single()
    if singles:
        print(f"ℹ️ {len(singles)} 處單字疊字待人工複核（正常疊字如 可可粉／謝謝／咩咩叫 屬誤報）：")
        for note in singles:
            print(note)
    else:
        print("✅ 無待複核項")

    # 跨專案字典一致性（模組包 repo 不存在時跳過）
    print("\n" + "=" * 60)
    print("跨專案 opencc_fixes.json 一致性檢查（本體 vs 模組包）")
    print("=" * 60)
    if not SIBLING_FIXES_JSON.exists():
        print(f"ℹ️ 跳過（找不到 {SIBLING_FIXES_JSON}）")
    else:
        sync_issues = check_dict_sync()
        if sync_issues:
            print(f"⚠️ 字典分岔 {len(sync_issues)} 處（新規則應兩邊同步；語境分岔須在 note 註記「分岔」或「勿移植」）：")
            for issue in sync_issues:
                print(issue)
        else:
            print("✅ 兩專案字典一致（已註記的語境分岔除外）")

    if format_gate_failed:
        print("\n❌ % 格式 token 檢查未通過（會使遊戲黑畫面），以失敗狀態結束")
        sys.exit(1)


_ = (
    PREFIX_STRIP_CATEGORIES,
    detect_category,
    parse_lua_translation,
    parse_recorded_media,
)

def cmd_sync_lua():
    """同步 Lua 腳本

    策略：
    - Flx Lua：直接從 REF 複製（雙語通用）
    - MOD 的其他 _Flx.lua 腳本由 MOD 自行維護，不從 REF 同步
    """
    print("=" * 60)
    print("同步 Lua 腳本")
    print("=" * 60)

    updated = 0

    # 同步 Flx 腳本（允許新增）
    for flx in FLX_FILES:
        ref_f = REF_LUA / flx
        if not ref_f.exists():
            continue
        mod_f = MOD_LUA / flx
        if not mod_f.exists() or sha256(ref_f) != sha256(mod_f):
            mod_f.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ref_f, mod_f)
            status = "新增" if not mod_f.exists() else "更新"
            print(f"  ✅ Flx ({status}): {flx}")
            updated += 1
    
    if updated == 0:
        print("  ℹ️ 沒有需要同步的腳本")
    print(f"\n完成：{updated} 個 Lua 腳本已同步")


def cmd_sync_all():
    """執行全部同步（CH/CN 已凍結，不在此列）"""
    cmd_sync_lua()
    print()
    cmd_fix_check()


# ============================================================
# gen-vehicle-map：從 vanilla EN/IG_UI.json 生成英文車名 → IGUI key 反查表
# ------------------------------------------------------------
# 目的：修復車鑰匙名稱在 Java 生成時被寫入 InventoryItem.name 後，
#   於多人 server 英文環境或舊存檔中持久化為英文/raw key 的問題。
#   VehicleKey_Flx.lua 會用此映射反查英文車名對應的 IGUI_VehicleName* key，
#   再用玩家端當前語言 getTextOrNull() 重組顯示名稱。
# ============================================================
VANILLA_PZ_DEFAULT = Path("D:/SteamLibrary/steamapps/common/ProjectZomboid")
VEHICLE_KEY_LUA_PATH = MOD_BASE / "lua" / "shared" / "Items" / "VehicleKey_Flx.lua"
GEN_BLOCK_START = "-- <AUTO-GEN:VEHICLE_NAME_MAP START>"
GEN_BLOCK_END = "-- <AUTO-GEN:VEHICLE_NAME_MAP END>"


def _lua_string(value: str) -> str:
    """將 Python 字串轉成 Lua 雙引號字串內容。"""
    return (
        value.replace("\\", "\\\\")
        .replace("\r", "\\r")
        .replace("\n", "\\n")
        .replace("\t", "\\t")
        .replace('"', '\\"')
    )


def cmd_gen_vehicle_map(pz_path: Path | None = None):
    """從 vanilla EN IG_UI.json 生成英文車名 → IGUI key 反查表"""
    pz_path = pz_path or VANILLA_PZ_DEFAULT
    en_file = pz_path / "media" / "lua" / "shared" / "Translate" / "EN" / "IG_UI.json"

    print("=" * 60)
    print("生成車輛英文名反查表（VehicleKey_Flx）")
    print("=" * 60)
    print(f"Vanilla EN 來源：{en_file}")

    if not en_file.exists():
        print(f"❌ 找不到 vanilla EN IG_UI.json：{en_file}")
        print("   請確認 PZ 安裝路徑，或用 --pz-path 指定")
        sys.exit(1)

    en_data = read_translation(en_file)
    vehicle_entries = OrderedDict(
        (key, value)
        for key, value in en_data.items()
        if key.startswith("IGUI_VehicleName") and value
    )
    print(f"讀取到 {len(vehicle_entries)} 個 IGUI_VehicleName* 條目")

    # 建立 {英文值 → IGUI key} 反查表。
    # 多個 key 共用同一英文值時 deterministic 地保留第一個 key；
    # 這些通常是多個外觀/編號共享相同顯示名稱（例如 Race Car），
    # VehicleKey_Flx 只需要任一能翻譯到同名值的 key。
    en_to_key: dict[str, str] = {}
    duplicate_values: dict[str, list[str]] = {}
    for key, en_value in vehicle_entries.items():
        if en_value not in en_to_key:
            en_to_key[en_value] = key
        else:
            duplicate_values.setdefault(en_value, [en_to_key[en_value]]).append(key)

    print(f"去重後共 {len(en_to_key)} 個獨立英文車名")
    if duplicate_values:
        print(f"⚠️  {len(duplicate_values)} 個英文車名對應多個 key，已保留第一個 key")

    lines = [GEN_BLOCK_START]
    lines.append("-- 由 scripts/sync_translations.py gen-vehicle-map 自動產生，請勿手動編輯")
    lines.append(f"-- 來源：vanilla EN/IG_UI.json（共 {len(en_to_key)} 條）")
    if duplicate_values:
        lines.append("-- 注意：重複英文車名已保留第一個 vanilla key；詳見 generator 執行輸出")
    lines.append("VehicleKeyFlx = VehicleKeyFlx or {}")
    lines.append("VehicleKeyFlx.EN_TO_KEY = {")
    for en_value in sorted(en_to_key):
        key = en_to_key[en_value]
        lines.append(f'    ["{_lua_string(en_value)}"] = "{_lua_string(key)}",')
    lines.append("}")
    lines.append(GEN_BLOCK_END)
    generated_block = "\n".join(lines)

    if not VEHICLE_KEY_LUA_PATH.exists():
        print(f"❌ 找不到目標 Lua 檔：{VEHICLE_KEY_LUA_PATH}")
        print("   請先建立 VehicleKey_Flx.lua 並包含 AUTO-GEN 標記區塊")
        sys.exit(1)

    original = VEHICLE_KEY_LUA_PATH.read_text(encoding="utf-8-sig")
    pattern = re.compile(
        re.escape(GEN_BLOCK_START) + r".*?" + re.escape(GEN_BLOCK_END),
        re.DOTALL,
    )
    if not pattern.search(original):
        print(f"❌ {VEHICLE_KEY_LUA_PATH.name} 內找不到 AUTO-GEN 標記區塊")
        sys.exit(1)

    updated = pattern.sub(lambda _m: generated_block, original)
    if updated != original:
        VEHICLE_KEY_LUA_PATH.write_text(updated, encoding="utf-8", newline="\n")
        print(f"✅ 已更新 {VEHICLE_KEY_LUA_PATH.relative_to(PROJECT_ROOT)}")
    else:
        print(f"ℹ️  內容未變動：{VEHICLE_KEY_LUA_PATH.relative_to(PROJECT_ROOT)}")


# ============================================================
# gen-item-name-map：從 vanilla EN/ItemName.json 生成
#   fullType → 英文 DisplayName 反查表（ItemNameFix_Flx）
# ------------------------------------------------------------
# 目的：修復食物/採集物名稱被以英文持久化的問題。
#   InventoryItem.name 是「建立當下語言」的欄位且會跨機器同步
#   （save 僅在 name != originalName 時寫入、load 先重置為本機名），
#   dedicated server 以英文重建物品時 client 便收到固化英文名；
#   採集另有 forageSystem.lua:2270 setName(displayName .. " (Wild)")。
#   ItemNameFix_Flx.lua 用此表辨識「恰為英文建構形」的名稱並以
#   玩家端語言重建（精確匹配才動手，不碰自訂名/演化食譜名）。
# ============================================================
ITEM_NAME_FIX_LUA_PATH = MOD_BASE / "lua" / "shared" / "Items" / "ItemNameFix_Flx.lua"
ITEM_GEN_BLOCK_START = "-- <AUTO-GEN:ITEM_NAME_MAP START>"
ITEM_GEN_BLOCK_END = "-- <AUTO-GEN:ITEM_NAME_MAP END>"


def cmd_gen_item_name_map(pz_path: Path | None = None):
    """從 vanilla EN ItemName.json 生成 fullType → 英文 DisplayName 反查表"""
    pz_path = pz_path or VANILLA_PZ_DEFAULT
    en_file = pz_path / "media" / "lua" / "shared" / "Translate" / "EN" / "ItemName.json"
    ui_file = pz_path / "media" / "lua" / "shared" / "Translate" / "EN" / "UI.json"

    print("=" * 60)
    print("生成物品英文名反查表（ItemNameFix_Flx）")
    print("=" * 60)
    print(f"Vanilla EN 來源：{en_file}")

    for required in (en_file, ui_file):
        if not required.exists():
            print(f"❌ 找不到 vanilla 檔案：{required}")
            sys.exit(1)

    en_data = read_translation(en_file)
    ui_data = read_translation(ui_file)
    wild_en = ui_data.get("UI_foraging_WildFood")
    if not wild_en:
        print("❌ vanilla EN UI.json 缺 UI_foraging_WildFood（採集字尾），中止")
        sys.exit(1)
    stash_file = en_file.parent / "Stash.json"
    annotated_en = read_translation(stash_file).get("Stash_AnnotedMap") if stash_file.exists() else None
    if not annotated_en:
        print("❌ vanilla EN Stash.json 缺 Stash_AnnotedMap（藏寶圖名），中止")
        sys.exit(1)
    ig_file = en_file.parent / "IG_UI.json"
    ig_data = read_translation(ig_file) if ig_file.exists() else {}
    key_suffixes: dict[str, str] = {}
    for k in sorted(ig_data):
        if re.fullmatch(r"IGUI_\w*Key", k) and ig_data[k] and ig_data[k] not in key_suffixes:
            key_suffixes[ig_data[k]] = k   # EN 場所名 → IGUI key（重複值保留第一個）
    if not key_suffixes:
        print("❌ vanilla EN IG_UI.json 找不到 IGUI_*Key 場所鍵，中止")
        sys.exit(1)
    # 鑰匙圈（A25）：IsoGameCharacter.createKeyRing 以生成端語言 getText 後 setName，
    # MP 由伺服器觸發故固化英文。這裡直接產出「EN 字面後綴」而非格式字串——
    # Lua 端不可自行解析格式：Translator.tryFillMapFromFile 在載入期會把 %N 改寫成
    # %N$s，getText 拿到的已是 "%1$s %2$s's Key Ring"，與檔案原文形態不同。
    keyring_en = ig_data.get("IGUI_KeyRingName", "")
    keyring_suffix = keyring_en[len("%1 %2"):] if keyring_en.startswith("%1 %2") else ""
    if not keyring_suffix:
        print(f"❌ vanilla EN IG_UI.json 的 IGUI_KeyRingName 缺失或格式改變（{keyring_en!r}），中止")
        sys.exit(1)

    entries = OrderedDict(
        (key, value) for key, value in en_data.items()
        if value and "." in key  # fullType 形如 Base.Bacon
    )
    print(f"讀取到 {len(entries)} 個 fullType 條目；Wild 字尾 EN = {wild_en!r}；藏寶圖 EN = {annotated_en!r}；場所鍵 {len(key_suffixes)} 條")

    lines = [ITEM_GEN_BLOCK_START]
    lines.append("-- 由 scripts/sync_translations.py gen-item-name-map 自動產生，請勿手動編輯")
    lines.append(f"-- 來源：vanilla EN/ItemName.json（共 {len(entries)} 條）＋ EN UI_foraging_WildFood")
    lines.append("ItemNameFixFlx = ItemNameFixFlx or {}")
    lines.append(f'ItemNameFixFlx.WILD_EN = "{_lua_string(wild_en)}"')
    lines.append(f'ItemNameFixFlx.ANNOTATED_EN = "{_lua_string(annotated_en)}"')
    lines.append(f'ItemNameFixFlx.KEYRING_EN_SUFFIX = "{_lua_string(keyring_suffix)}"')
    lines.append("-- keyNamerBuilding 場所後綴：EN 場所名 → IGUI_*Key（重複 EN 值保留第一個 key）")
    lines.append("ItemNameFixFlx.KEY_SUFFIX = {")
    for en_value, igui_key in sorted(key_suffixes.items()):
        lines.append(f'    ["{_lua_string(en_value)}"] = "{_lua_string(igui_key)}",')
    lines.append("}")
    lines.append("ItemNameFixFlx.EN_NAME = {")
    for full_type, en_value in sorted(entries.items()):
        lines.append(f'    ["{_lua_string(full_type)}"] = "{_lua_string(en_value)}",')
    lines.append("}")
    lines.append(ITEM_GEN_BLOCK_END)
    generated_block = "\n".join(lines)

    if not ITEM_NAME_FIX_LUA_PATH.exists():
        print(f"❌ 找不到目標 Lua 檔：{ITEM_NAME_FIX_LUA_PATH}")
        sys.exit(1)

    original = ITEM_NAME_FIX_LUA_PATH.read_text(encoding="utf-8-sig")
    pattern = re.compile(
        re.escape(ITEM_GEN_BLOCK_START) + r".*?" + re.escape(ITEM_GEN_BLOCK_END),
        re.DOTALL,
    )
    if not pattern.search(original):
        print(f"❌ {ITEM_NAME_FIX_LUA_PATH.name} 內找不到 AUTO-GEN 標記區塊")
        sys.exit(1)

    updated = pattern.sub(lambda _m: generated_block, original)
    if updated != original:
        ITEM_NAME_FIX_LUA_PATH.write_text(updated, encoding="utf-8", newline="\n")
        print(f"✅ 已更新 {ITEM_NAME_FIX_LUA_PATH.relative_to(PROJECT_ROOT)}")
    else:
        print(f"ℹ️  內容未變動：{ITEM_NAME_FIX_LUA_PATH.relative_to(PROJECT_ROOT)}")


# ============================================================
# gen-media-map：從 vanilla recorded_media.lua + EN Recorded_Media.json
#   生成英文媒體物品名 → {RM key, media guid} 反查表
# ------------------------------------------------------------
# 目的：修復媒體物品（VHS/CD）在 load 時 media index 解析失敗後，
#   名稱永久保留生成端英文的問題。index 有效者 vanilla load 會以載入端
#   當下翻譯自行重刷（InventoryItem.load → setRecordedMediaIndex），
#   不在修補範圍；詳見 HARDCODE_REGISTRY.md A17 / C7。
#   RecordedMediaName_Flx.lua 用此表把英文名反查回 RM key（顯示層改名）
#   與 media guid（SP 端 setRecordedMediaData 重連結、恢復媒體功能）。
# ============================================================
MEDIA_NAME_LUA_PATH = MOD_BASE / "lua" / "shared" / "Items" / "RecordedMediaName_Flx.lua"
MEDIA_GEN_BLOCK_START = "-- <AUTO-GEN:MEDIA_NAME_MAP START>"
MEDIA_GEN_BLOCK_END = "-- <AUTO-GEN:MEDIA_NAME_MAP END>"


def cmd_gen_media_map(pz_path: Path | None = None):
    """從 vanilla recorded_media.lua + EN Recorded_Media.json 生成英文媒體名反查表"""
    pz_path = pz_path or VANILLA_PZ_DEFAULT
    rm_lua = pz_path / "media" / "lua" / "shared" / "RecordedMedia" / "recorded_media.lua"
    en_file = pz_path / "media" / "lua" / "shared" / "Translate" / "EN" / "Recorded_Media.json"

    print("=" * 60)
    print("生成媒體物品英文名反查表（RecordedMediaName_Flx）")
    print("=" * 60)
    print(f"Vanilla 媒體定義：{rm_lua}")
    print(f"Vanilla EN 翻譯：{en_file}")

    for required in (rm_lua, en_file):
        if not required.exists():
            print(f"❌ 找不到 vanilla 檔案：{required}")
            print("   請確認 PZ 安裝路徑，或用 --pz-path 指定")
            sys.exit(1)

    en_data = read_translation(en_file)
    content = rm_lua.read_text(encoding="utf-8-sig")

    # RecMedia["<guid>"] = { ... itemDisplayName = "RM_..." ... };（區塊以行首 }; 結束）
    block_re = re.compile(r'RecMedia\["([0-9a-fA-F\-]+)"\]\s*=\s*\{(.*?)\n\};', re.DOTALL)
    display_re = re.compile(r'itemDisplayName\s*=\s*"(RM_[^"]+)"')

    # {EN 物品名 → (rm_key, guid)}；同名不同媒體 → 歧義剔除，避免誤連結
    en_to_media: dict[str, tuple[str, str]] = {}
    ambiguous: set[str] = set()
    total = 0
    missing_en = 0
    for m in block_re.finditer(content):
        guid, body = m.group(1), m.group(2)
        dm = display_re.search(body)
        if not dm:
            continue
        total += 1
        rm_key = dm.group(1)
        en_name = en_data.get(rm_key)
        if not en_name:
            missing_en += 1
            continue
        existing = en_to_media.get(en_name)
        if existing is None:
            en_to_media[en_name] = (rm_key, guid)
        elif existing != (rm_key, guid):
            ambiguous.add(en_name)
    for name in ambiguous:
        en_to_media.pop(name, None)

    # 格式漂移防護（fail-closed）：以容忍空白的獨立 regex 計數原始區塊，
    # 與嚴格 parser 的解析數交叉比對；不一致或零條目時在寫檔前中止，
    # 避免 vanilla 排版變動（如 }; 改縮排、括號加空白）時把不完整/空表覆寫進 Lua
    raw_block_count = len(re.findall(r'RecMedia\s*\[\s*"', content))
    if total == 0 or raw_block_count != total:
        print(
            f"❌ RecMedia 原始區塊 {raw_block_count} 個、成功解析 {total} 個——"
            "vanilla recorded_media.lua 排版可能已變動，請更新 block regex 後重跑（未覆寫任何檔案）"
        )
        sys.exit(1)

    print(
        f"解析 {total} 個媒體定義；EN 缺譯名 {missing_en}；"
        f"同名歧義剔除 {len(ambiguous)}；產出 {len(en_to_media)} 條"
    )

    lines = [MEDIA_GEN_BLOCK_START]
    lines.append("-- 由 scripts/sync_translations.py gen-media-map 自動產生，請勿手動編輯")
    lines.append(f"-- 來源：vanilla recorded_media.lua + EN/Recorded_Media.json（共 {len(en_to_media)} 條）")
    if ambiguous:
        lines.append(f"-- 注意：{len(ambiguous)} 個英文名對應多個媒體，已剔除避免誤連結")
    lines.append("RecordedMediaNameFlx = RecordedMediaNameFlx or {}")
    lines.append("RecordedMediaNameFlx.EN_TO_MEDIA = {")
    for en_name in sorted(en_to_media):
        rm_key, guid = en_to_media[en_name]
        lines.append(
            f'    ["{_lua_string(en_name)}"] = {{ key = "{_lua_string(rm_key)}", id = "{_lua_string(guid)}" }},'
        )
    lines.append("}")
    lines.append(MEDIA_GEN_BLOCK_END)
    generated_block = "\n".join(lines)

    if not MEDIA_NAME_LUA_PATH.exists():
        print(f"❌ 找不到目標 Lua 檔：{MEDIA_NAME_LUA_PATH}")
        print("   請先建立 RecordedMediaName_Flx.lua 並包含 AUTO-GEN 標記區塊")
        sys.exit(1)

    original = MEDIA_NAME_LUA_PATH.read_text(encoding="utf-8-sig")
    pattern = re.compile(
        re.escape(MEDIA_GEN_BLOCK_START) + r".*?" + re.escape(MEDIA_GEN_BLOCK_END),
        re.DOTALL,
    )
    if not pattern.search(original):
        print(f"❌ {MEDIA_NAME_LUA_PATH.name} 內找不到 AUTO-GEN 標記區塊")
        sys.exit(1)

    updated = pattern.sub(lambda _m: generated_block, original)
    if updated != original:
        MEDIA_NAME_LUA_PATH.write_text(updated, encoding="utf-8", newline="\n")
        print(f"✅ 已更新 {MEDIA_NAME_LUA_PATH.relative_to(PROJECT_ROOT)}")
    else:
        print(f"ℹ️  內容未變動：{MEDIA_NAME_LUA_PATH.relative_to(PROJECT_ROOT)}")


# ============================================================
# gen-radio-map：從 RadioData EN/CH/CN 生成英文台詞 → RD key 反查表
# ------------------------------------------------------------
# 目的：修復多人 server 英文環境下，live radio/TV broadcast 由 server
#   先以英文 Translator.getText("RD_*") 固化後再傳給 client 的問題。
#   Java WaveSignal packet 不攜帶 RD guid，client 只收到最終字串，因此
#   RadioData_Flx.lua 需要用「英文原文 → RD key」反查，再用 UTF-8 reader
#   讀取 CH/CN RadioData.json，避免把大量中文 literals 寫進 Lua source 造成亂碼。
# ============================================================
RADIO_DATA_LUA_PATH = MOD_BASE / "lua" / "shared" / "RadioData_Flx.lua"
RADIO_GEN_BLOCK_START = "-- <AUTO-GEN:RADIO_TEXT_MAP START>"
RADIO_GEN_BLOCK_END = "-- <AUTO-GEN:RADIO_TEXT_MAP END>"


RADIO_POSITIONAL_TOKEN = re.compile(r"%[1-9]")


def _build_radio_en_to_key(
    en_data: dict[str, str], ch_data: dict[str, str], cn_data: dict[str, str]
) -> tuple["OrderedDict[str, str]", dict[str, str], dict[str, list[str]], set[str]]:
    """建立 runtime-EN → RD key 反查表。

    表鍵一律用執行期形（%% → %）：42.20.1+ getText 一律 formatted()，server 烘進
    RadioLine.text 的是 formatted 後文字，raw JSON 形（42.20.2 現有 4 筆 %%）永遠 miss。
    未譯判定用 raw 值比對（CH/CN 與 EN JSON 同形即未譯，不得混用 runtime 形）。
    fail-closed：值含 %1–%9（反查表僅支援靜態文本），或不同 raw EN 正規化成同一
    runtime 鍵且譯文不同（無法安全 first-wins），一律 ValueError 中止。
    """
    en_to_key: OrderedDict[str, str] = OrderedDict()
    duplicate_values: dict[str, list[str]] = {}
    ambiguous_duplicates: set[str] = set()
    first_key_by_en: dict[str, str] = {}
    translations_by_en: dict[str, set[tuple[str, str]]] = {}
    raw_by_runtime: dict[str, str] = {}
    first_pair_by_runtime: dict[str, tuple[str, str]] = {}

    for key, raw_en in en_data.items():
        if not raw_en or raw_en == "~":
            continue
        ch_value = ch_data[key]
        cn_value = cn_data[key]
        for label, value in (("EN", raw_en), ("CH", ch_value), ("CN", cn_value)):
            if RADIO_POSITIONAL_TOKEN.search(value):
                raise ValueError(f"{key} 的 {label} 值含 %N 佔位符，RadioData 靜態反查不支援：{value!r}")
        runtime_en = raw_en.replace("%%", "%")
        translations_by_en.setdefault(runtime_en, set()).add((ch_value, cn_value))
        if runtime_en in first_key_by_en:
            if (
                raw_by_runtime[runtime_en] != raw_en
                and (ch_value, cn_value) != first_pair_by_runtime[runtime_en]
            ):
                raise ValueError(
                    f"正規化碰撞且譯文不同：{raw_by_runtime[runtime_en]!r} 與 {raw_en!r}"
                    f"（{key}）皆對應 runtime 鍵 {runtime_en!r}"
                )
            duplicate_values.setdefault(runtime_en, [first_key_by_en[runtime_en]]).append(key)
            if len(translations_by_en[runtime_en]) > 1:
                ambiguous_duplicates.add(runtime_en)
            continue

        first_key_by_en[runtime_en] = key
        raw_by_runtime[runtime_en] = raw_en
        first_pair_by_runtime[runtime_en] = (ch_value, cn_value)
        if ch_value != raw_en or cn_value != raw_en:
            en_to_key[runtime_en] = key

    return en_to_key, first_key_by_en, duplicate_values, ambiguous_duplicates


def cmd_gen_radio_map(pz_path: Path | None = None):
    """從 vanilla/MOD RadioData.json 生成 live radio/TV 英文→RD key 反查表"""
    pz_path = pz_path or VANILLA_PZ_DEFAULT
    en_file = pz_path / "media" / "lua" / "shared" / "Translate" / "EN" / "RadioData.json"
    xml_file = pz_path / "media" / "radio" / "RadioData.xml"
    ch_file = MOD_CH / "RadioData.json"
    cn_file = MOD_CN / "RadioData.json"

    print("=" * 60)
    print("生成 radio/TV 英文台詞反查表（RadioData_Flx）")
    print("=" * 60)
    print(f"Vanilla EN 來源：{en_file}")
    print(f"Vanilla XML 來源：{xml_file}")
    print(f"MOD CH 來源：{ch_file.relative_to(PROJECT_ROOT)}")
    print(f"MOD CN 來源：{cn_file.relative_to(PROJECT_ROOT)}")

    for file in (en_file, xml_file, ch_file, cn_file):
        if not file.exists():
            print(f"❌ 找不到來源檔：{file}")
            sys.exit(1)

    en_data = read_translation(en_file)
    ch_data = read_translation(ch_file)
    cn_data = read_translation(cn_file)

    missing_ch = [key for key in en_data if key not in ch_data]
    missing_cn = [key for key in en_data if key not in cn_data]
    if missing_ch or missing_cn:
        print(f"❌ RadioData 翻譯缺失：CH={len(missing_ch)}, CN={len(missing_cn)}")
        for key in (missing_ch[:10] + missing_cn[:10]):
            print(f"  - {key}")
        sys.exit(1)

    try:
        en_to_key, first_key_by_en, duplicate_values, ambiguous_duplicates = _build_radio_en_to_key(
            en_data, ch_data, cn_data
        )
    except ValueError as exc:
        print(f"❌ RadioData 反查表生成中止：{exc}")
        sys.exit(1)

    print(f"讀取到 {len(en_data)} 個 RD_* 條目")
    print(f"去重後英文原文：{len(first_key_by_en)} 條")
    print(f"輸出英文→RD key 反查：{len(en_to_key)} 條")
    if duplicate_values:
        print(f"⚠️  {len(duplicate_values)} 個英文原文對應多個 RD key，已保留第一個 key 的譯文")
    if ambiguous_duplicates:
        print(f"⚠️  其中 {len(ambiguous_duplicates)} 個重複英文原文有不同譯文，已保留第一個 key 的譯文")

    xml_root = ET.parse(xml_file).getroot()
    advert_categories: OrderedDict[str, list[dict]] = OrderedDict()
    adverts_node = xml_root.find("Adverts")
    if adverts_node is not None:
        for script_node in adverts_node.findall("ScriptEntry"):
            category_id = script_node.get("ID")
            if not category_id:
                continue
            segments: list[dict] = []
            for broadcast_node in script_node.findall("BroadcastEntry"):
                segment_id = broadcast_node.get("ID")
                if not segment_id:
                    continue
                lines_data = []
                for line_node in broadcast_node.findall("LineEntry"):
                    line_id = line_node.get("ID")
                    if not line_id:
                        continue
                    key = f"RD_{line_id}"
                    lines_data.append(
                        {
                            "key": key,
                            "r": int(line_node.get("r") or 255),
                            "g": int(line_node.get("g") or 255),
                            "b": int(line_node.get("b") or 255),
                            "codes": line_node.get("codes"),
                        }
                    )
                if lines_data:
                    segments.append({"id": segment_id, "lines": lines_data})
            if segments:
                advert_categories[category_id] = segments

    broadcast_advert_categories: OrderedDict[str, str] = OrderedDict()
    for broadcast_node in xml_root.iter("BroadcastEntry"):
        broadcast_id = broadcast_node.get("ID")
        advert_cat = broadcast_node.get("advertCat")
        is_segment = (broadcast_node.get("isSegment") or "").lower() == "true"
        if (
            broadcast_id
            and advert_cat
            and advert_cat.lower() != "none"
            and not is_segment
            and advert_cat in advert_categories
        ):
            broadcast_advert_categories[broadcast_id] = advert_cat

    advert_line_count = sum(
        len(segment["lines"])
        for segments in advert_categories.values()
        for segment in segments
    )
    print(f"讀取到 {len(advert_categories)} 個 advert category、{sum(len(v) for v in advert_categories.values())} 個 advert segment、{advert_line_count} 條 advert line")
    print(f"可重建 translated advert segment 的主 broadcast：{len(broadcast_advert_categories)} 個")

    lines = [RADIO_GEN_BLOCK_START]
    lines.append("-- 由 scripts/sync_translations.py gen-radio-map 自動產生，請勿手動編輯")
    lines.append(f"-- 來源：vanilla EN/RadioData.json + MOD CH/CN RadioData.json（EN 共 {len(en_data)} 條）")
    lines.append("-- 用途：server/SP 載入 live radio/TV scripts 後，將英文 RadioLine.text 反查回 RD key。")
    lines.append("RadioDataFlx = RadioDataFlx or {}")
    lines.append("RadioDataFlx.EN_TO_KEY = {")
    for en_value, key in sorted(en_to_key.items()):
        lines.append(f'    ["{_lua_string(en_value)}"] = "{_lua_string(key)}",')
    lines.append("}")
    lines.append("")
    lines.append("RadioDataFlx.ADVERT_CATEGORIES = {")
    for category_id, segments in advert_categories.items():
        lines.append(f'    ["{_lua_string(category_id)}"] = {{')
        for segment in segments:
            lines.append("        {")
            lines.append(f'            id = "{_lua_string(segment["id"])}",')
            lines.append("            lines = {")
            for line in segment["lines"]:
                parts = [
                    f'key = "{_lua_string(line["key"])}"',
                    f'r = {line["r"]}',
                    f'g = {line["g"]}',
                    f'b = {line["b"]}',
                ]
                if line["codes"]:
                    parts.append(f'codes = "{_lua_string(line["codes"])}"')
                lines.append("                { " + ", ".join(parts) + " },")
            lines.append("            },")
            lines.append("        },")
        lines.append("    },")
    lines.append("}")
    lines.append("")
    lines.append("RadioDataFlx.BROADCAST_ADVERT_CATEGORIES = {")
    for broadcast_id, category_id in broadcast_advert_categories.items():
        lines.append(f'    ["{_lua_string(broadcast_id)}"] = "{_lua_string(category_id)}",')
    lines.append("}")
    lines.append(RADIO_GEN_BLOCK_END)
    generated_block = "\n".join(lines)

    if not RADIO_DATA_LUA_PATH.exists():
        print(f"❌ 找不到目標 Lua 檔：{RADIO_DATA_LUA_PATH}")
        print("   請先建立 RadioData_Flx.lua 並包含 AUTO-GEN 標記區塊")
        sys.exit(1)

    original = RADIO_DATA_LUA_PATH.read_text(encoding="utf-8-sig")
    pattern = re.compile(
        re.escape(RADIO_GEN_BLOCK_START) + r".*?" + re.escape(RADIO_GEN_BLOCK_END),
        re.DOTALL,
    )
    if not pattern.search(original):
        print(f"❌ {RADIO_DATA_LUA_PATH.name} 內找不到 AUTO-GEN 標記區塊")
        sys.exit(1)

    updated = pattern.sub(lambda _m: generated_block, original)
    if updated != original:
        RADIO_DATA_LUA_PATH.write_text(updated, encoding="utf-8", newline="\n")
        print(f"✅ 已更新 {RADIO_DATA_LUA_PATH.relative_to(PROJECT_ROOT)}")
    else:
        print(f"ℹ️  內容未變動：{RADIO_DATA_LUA_PATH.relative_to(PROJECT_ROOT)}")


# ============================================================
# gen-dynamic-name-map：從 vanilla EN 翻譯生成 DynamicItemName_Flx 反查表
# ------------------------------------------------------------
# 目的：修復 ItemCodeOnCreate / Fishing Lua 在物品生成時把翻譯結果烘焙進
#   InventoryItem.name 的殘留（雪花玻璃球、舊報紙、寵物牌、股票、信件、名片等）。
#   modData 只存烘焙文字的類型需要「英文原文 → IGUI key」反查表，
#   DynamicItemName_Flx.lua 解析名稱後反查 key 再以當前語言重組。
# ============================================================
DYNAMIC_NAME_LUA_PATH = MOD_BASE / "lua" / "shared" / "Items" / "DynamicItemName_Flx.lua"
DYN_GEN_BLOCK_START = "-- <AUTO-GEN:DYNAMIC_NAME_MAP START>"
DYN_GEN_BLOCK_END = "-- <AUTO-GEN:DYNAMIC_NAME_MAP END>"

# 需要 EN 顯示名的物品（解析殘留名稱時的錨點；來源：42.19.0 generation/*.java）
DYN_EN_NAME_FULLTYPES = [
    "Base.SnowGlobe",
    "Base.Newspaper",
    "Base.StockCertificate",
    "Base.DogTag_Pet",
    "Base.BusinessCard",
    "Base.BusinessCard_Nolans",
    "Base.ScratchTicket_Winner",
    # 印章戒指（onCreateMonogram）
    "Base.Ring_Left_MiddleFinger_Signet",
    "Base.Ring_Left_RingFinger_Signet",
    "Base.Ring_Right_MiddleFinger_Signet",
    "Base.Ring_Right_RingFinger_Signet",
    # 證件類（onCreateIDCard*）
    "Base.Badge",
    "Base.BrassNameplate",
    "Base.BusinessCard_Personal",
    "Base.CreditCard",
    "Base.CreditCard_Stolen",
    "Base.IDcard",
    "Base.IDcard_Stolen",
    "Base.IDcard_Female",
    "Base.IDcard_Male",
    "Base.Necklace_DogTag",
    "Base.Necklace_DogTag_Female",
    "Base.Necklace_DogTag_Male",
    "Base.Passport",
    "Base.PressID",
    # 超速罰單（vanilla SpawnItems.lua nameAfterDescriptor，非 generation/*.java）
    "Base.SpeedingTicket",
    # 魚（Fishing.onCreateFish / Fish.lua 動態大小命名）
    "Base.AligatorGar",
    "Base.BlackCrappie",
    "Base.BlueCatfish",
    "Base.Bluegill",
    "Base.ChannelCatfish",
    "Base.FlatheadCatfish",
    "Base.FreshwaterDrum",
    "Base.GreenSunfish",
    "Base.LargemouthBass",
    "Base.Muskellunge",
    "Base.Paddlefish",
    "Base.RedearSunfish",
    "Base.Sauger",
    "Base.SmallmouthBass",
    "Base.SpottedBass",
    "Base.StripedBass",
    "Base.Walleye",
    "Base.WhiteBass",
    "Base.WhiteCrappie",
    "Base.YellowPerch",
]

# Letter 註冊表 id（zombie/scripting/objects/Letter.java 42.19.0；key = "IGUI_" + id）
DYN_LETTER_IDS = [
    "AcceptanceLetter", "ApplicationLetter", "BankLetter", "Bill",
    "BusinessLetter", "CharityLetter", "ChildsLetter", "CondolenceLetter",
    "EmploymentLetter", "FriendlyLetter", "GovernmentLetter", "InvitationLetter",
    "LegalLetter", "Letter", "OfficialLetter", "OverdueBill",
    "RejectionLetter", "ResignationLetter", "RomanticLetter", "RudeLetter",
    "SadLetter", "ScamLetter", "ThankYouLetter", "ThreateningLetter",
]

# Business 註冊表 id（zombie/scripting/objects/Business.java 42.19.0；key = "IGUI_" + id）
DYN_BUSINESS_IDS = [
    "McCoyLogging", "ValuTech", "Egenerex", "UnitedShippingLogistics",
    "PerfickPotatoCo", "HerrFlickKnives", "CobberMetals", "BansheeHolloway",
    "BeringCompany", "YuriDesign", "NewcastlePaperandInk", "BusanTelecommunications",
    "KittenKnives", "ButterflyMachinery", "WirklichlangeswortAG", "SanchezGoldberg",
    "Beanz", "BruceySoups", "FellowsInc", "InvisibleSledgehammerCorp",
    "PantherMotors", "KillianFoodstuffs", "GrennadeChemicals", "ReallyHardSteel",
    "ChinesePetroleum", "BankofKentucky", "LoveheartShipbuilding", "DoubleEntryAccounting",
    "SwiftThompsonAerospace", "FunXtremeInc", "Imekagi", "WolframWaffen",
    "Fossoil", "SpiffoCorp", "GigaMart", "KirrusInc",
    "FranklinMotors", "GlobalComputerSolutions", "ParasolInc", "TISConstruction",
    "PremiumTechnologies", "MmmInc", "AlgolElectronics", "Fibroil",
    "SeahorseCoffeeCorp", "HawthornOil", "PopCo", "Chrysalis",
    "Nikoda", "ValuInsurance", "Zippee", "Pharmahug",
    "SpecificElectric", "HallowayFramer", "RedmondRedmond", "HavishamHotels",
    "AmericanTire", "AmeriGlobeInc", "MassGenfacCo", "FinneganGroup",
    "PalmTravel", "GeneralBroadcastCorporation", "ScittWilkerFirearms",
]

# Job 註冊表 id（zombie/scripting/objects/Job.java 42.19.0；key = "IGUI_" + id）
DYN_JOB_IDS = [
    "Accountant", "Actor", "AlarmInstaller", "AnimalExpert", "Architect",
    "Artist", "Babysitter", "Barber", "Bodyguard", "Builder",
    "BusinessCardMaker", "BusinessConsultant", "BusinessOwner", "Butcher",
    "CarSalesperson", "Carpenter", "Cleaner", "ClothingDesigner", "Clown",
    "Coder", "Cook", "CultDeprogrammer", "Dancer", "Dentist",
    "Dermatologist", "Dietician", "DIY", "Doctor", "Drafter", "Driver",
    "DryCleaner", "EfficiencyExpert", "Electrician", "Engineer", "Escort",
    "Exorcist", "ExoticDancer", "Exterminator", "FactoryManager", "Fencer",
    "Film/TVCrew", "FinancialAdvisor", "FitnessInstructor", "Floorer",
    "FortuneTeller", "Framer", "Gardener", "GeneralManager", "GraphicDesigner",
    "Hairdresser", "HeadChef", "Historian", "HumorousFakeOccupationName",
    "Hunter", "InsuranceAgent", "IntimateDiseaseSpecialist", "ITTechnician",
    "JackofallTrades", "Journalist", "Laborer", "Lawyer", "Lecturer",
    "LocalHistoryExpert", "LocalPolitician", "Locksmith", "Logger",
    "LogisticsExpert", "MachineOperator", "MakeupArtist", "Masseuse",
    "Mechanic", "Metalworker", "Midwife", "Nanny", "Nurse", "Optician",
    "Orthodontist", "Painter", "Pediatrician", "PersonalTrainer", "Pharmacist",
    "Photographer", "Physiotherapist", "Pilot", "Plumber", "PrivateInvestigator",
    "Producer", "Psychiatrist", "Psychic", "Publisher", "RealEstateAgent",
    "Rehab", "Repairman", "Sailor", "Salesperson", "Scientist",
    "ScrapyardWorker", "Secretary", "SecurityGuard", "Singer",
    "StockMarketExpert", "Stonemason", "Tailor", "TaxExpert", "TaxiDriver",
    "Teacher", "Technician", "TourGuide", "TravelAgent", "Tutor",
    "Undertaker", "Veterinarian", "Welder", "WindowFitter", "Writer",
]


def _build_en_to_key_map(entries: dict, keys: list[str]) -> "OrderedDict[str, str]":
    """以 EN 值為索引建立反查表；重複 EN 值 deterministic 地保留第一個 key。"""
    en_to_key: "OrderedDict[str, str]" = OrderedDict()
    for key in keys:
        value = entries.get(key)
        if not value:
            continue
        if value not in en_to_key:
            en_to_key[value] = key
    return en_to_key


def _emit_lua_map(lines: list[str], name: str, mapping: dict, indent: str = "    "):
    lines.append(f"{indent}{name} = {{")
    for map_key in sorted(mapping):
        lines.append(f'{indent}    ["{_lua_string(map_key)}"] = "{_lua_string(mapping[map_key])}",')
    lines.append(f"{indent}}},")


def cmd_gen_dynamic_name_map(pz_path: Path | None = None):
    """從 vanilla EN 翻譯生成 DynamicItemName_Flx 的反查表"""
    pz_path = pz_path or VANILLA_PZ_DEFAULT
    en_dir = pz_path / "media" / "lua" / "shared" / "Translate" / "EN"
    ig_ui_file = en_dir / "IG_UI.json"
    item_name_file = en_dir / "ItemName.json"
    print_media_file = en_dir / "Print_Media.json"

    print("=" * 60)
    print("生成動態命名反查表（DynamicItemName_Flx）")
    print("=" * 60)
    print(f"Vanilla EN 來源：{en_dir}")

    for required in (ig_ui_file, item_name_file, print_media_file):
        if not required.exists():
            print(f"❌ 找不到 vanilla EN 翻譯檔：{required}")
            print("   請確認 PZ 安裝路徑，或用 --pz-path 指定")
            sys.exit(1)

    ig_ui = read_translation(ig_ui_file)
    item_names = read_translation(item_name_file)
    print_media = read_translation(print_media_file)

    # 物品 EN 顯示名（fullType → EN 名）
    en_item_names = OrderedDict()
    missing_items = []
    for full_type in DYN_EN_NAME_FULLTYPES:
        value = item_names.get(full_type)
        if value:
            en_item_names[full_type] = value
        else:
            missing_items.append(full_type)
    if missing_items:
        print(f"⚠️  {len(missing_items)} 個 fullType 在 EN ItemName.json 查不到：{missing_items}")

    # 各反查表（EN 值 → IGUI key）
    place_keys = [key for key in ig_ui if key.startswith("IGUI_Photo_")]
    newspaper_keys = [key for key in ig_ui if key.startswith("IGUI_NewspaperTitle_")]
    petname_keys = [key for key in ig_ui if key.startswith("IGUI_PetName_")]
    letter_keys = [f"IGUI_{letter_id}" for letter_id in DYN_LETTER_IDS]
    business_keys = [f"IGUI_{business_id}" for business_id in DYN_BUSINESS_IDS]
    job_keys = [f"IGUI_{job_id}" for job_id in DYN_JOB_IDS]

    place_map = _build_en_to_key_map(ig_ui, place_keys)
    newspaper_map = _build_en_to_key_map(ig_ui, newspaper_keys)
    petname_map = _build_en_to_key_map(ig_ui, petname_keys)
    letter_map = _build_en_to_key_map(ig_ui, letter_keys)
    business_map = _build_en_to_key_map(ig_ui, business_keys)
    job_map = _build_en_to_key_map(ig_ui, job_keys)

    # BusinessCard_Nolans 的職業欄位用 Flier.NOLANS_USED_CARS 的 Print_Media 標題
    nolans_key = "Print_Media_NolansUsedCars_title"
    nolans_value = print_media.get(nolans_key)
    if nolans_value and nolans_value not in job_map:
        job_map[nolans_value] = nolans_key

    stats = {
        "EN_ITEM_NAMES": len(en_item_names),
        "PLACE": len(place_map),
        "NEWSPAPER_TITLE": len(newspaper_map),
        "PETNAME": len(petname_map),
        "LETTER": len(letter_map),
        "BUSINESS": len(business_map),
        "JOB": len(job_map),
    }
    for name, count in stats.items():
        print(f"  {name}: {count} 條")

    lines = [DYN_GEN_BLOCK_START]
    lines.append("-- 由 scripts/sync_translations.py gen-dynamic-name-map 自動產生，請勿手動編輯")
    lines.append(f"-- 來源：vanilla EN/IG_UI.json、ItemName.json、Print_Media.json（{'、'.join(f'{k} {v}' for k, v in stats.items())}）")
    lines.append("DynamicItemNameFlx = DynamicItemNameFlx or {}")
    lines.append("DynamicItemNameFlx.MAPS = {")
    _emit_lua_map(lines, "EN_ITEM_NAMES", en_item_names)
    _emit_lua_map(lines, "PLACE", place_map)
    _emit_lua_map(lines, "NEWSPAPER_TITLE", newspaper_map)
    _emit_lua_map(lines, "PETNAME", petname_map)
    _emit_lua_map(lines, "LETTER", letter_map)
    _emit_lua_map(lines, "BUSINESS", business_map)
    _emit_lua_map(lines, "JOB", job_map)
    lines.append("}")
    lines.append(DYN_GEN_BLOCK_END)
    generated_block = "\n".join(lines)

    if not DYNAMIC_NAME_LUA_PATH.exists():
        print(f"❌ 找不到目標 Lua 檔：{DYNAMIC_NAME_LUA_PATH}")
        print("   請先建立 DynamicItemName_Flx.lua 並包含 AUTO-GEN 標記區塊")
        sys.exit(1)

    original = DYNAMIC_NAME_LUA_PATH.read_text(encoding="utf-8-sig")
    pattern = re.compile(
        re.escape(DYN_GEN_BLOCK_START) + r".*?" + re.escape(DYN_GEN_BLOCK_END),
        re.DOTALL,
    )
    if not pattern.search(original):
        print(f"❌ {DYNAMIC_NAME_LUA_PATH.name} 內找不到 AUTO-GEN 標記區塊")
        sys.exit(1)

    updated = pattern.sub(lambda _m: generated_block, original)
    if updated != original:
        DYNAMIC_NAME_LUA_PATH.write_text(updated, encoding="utf-8", newline="\n")
        print(f"✅ 已更新 {DYNAMIC_NAME_LUA_PATH.relative_to(PROJECT_ROOT)}")
    else:
        print(f"ℹ️  內容未變動：{DYNAMIC_NAME_LUA_PATH.relative_to(PROJECT_ROOT)}")


# ============================================================
# 入口
# ============================================================
# ============================================================
# 凍結後維護：官方 EN 快照 / en-diff / ch-lint / import-new
# ------------------------------------------------------------
# 凍結後「只看 CH git diff」不夠：官方同鍵改英文內容時 CH 完全不可見。
# 維護迴路 = en-snapshot 立基準 → 官方更新後 en-diff 出佇列 →
# 人工修 CH（新鍵可用 import-new 產提案）→ en-snapshot 更新基準。
# ============================================================
EN_SNAPSHOT_JSON = Path(__file__).resolve().parent / "en_snapshot.json"
IMPORT_PROPOSALS_JSON = Path(__file__).resolve().parent / "import_proposals.json"


def _vanilla_translate(pz_path: Path | None, lang: str) -> dict[str, str]:
    """讀 vanilla 安裝目錄的翻譯語料，回傳 {檔名|鍵: 值}。"""
    root = (pz_path or VANILLA_PZ_DEFAULT) / "media" / "lua" / "shared" / "Translate" / lang
    if not root.exists():
        print(f"❌ 找不到 vanilla {lang} 目錄：{root}")
        sys.exit(1)
    out: dict[str, str] = {}
    for f in sorted(root.glob("*.json")):
        if f.name == "language.json":
            continue
        try:
            data = json.loads(f.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError) as exc:
            print(f"❌ vanilla {lang}/{f.name} 解析失敗：{exc}（fail-closed，不產出殘缺結果）")
            sys.exit(1)
        for k, v in data.items():
            if isinstance(v, str):
                out[f"{f.name}|{k}"] = v
    return out


def _mod_ch_values() -> dict[str, str]:
    out: dict[str, str] = {}
    for f in sorted(MOD_CH.glob("*.json")):
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        for k, v in data.items():
            if isinstance(v, str):
                out[f"{f.name}|{k}"] = v
    return out


def cmd_en_snapshot(pz_path: Path | None = None):
    """保存官方 EN 全鍵快照（存完整值，en-diff 才能顯示改了什麼）。"""
    import datetime

    en = _vanilla_translate(pz_path, "EN")
    payload = {
        "_meta": {
            "generated_at": datetime.date.today().isoformat(),
            "keys": len(en),
            "note": "官方 EN 快照，en-diff 的比對基準。維護佇列處理完後重跑本命令更新基準。",
        },
        "values": en,
    }
    EN_SNAPSHOT_JSON.write_bytes(
        (json.dumps(payload, ensure_ascii=False, indent=1) + "\n").encode("utf-8")
    )
    print(f"✅ EN 快照已保存：{len(en)} 鍵 → {EN_SNAPSHOT_JSON.name}")


def cmd_en_diff(pz_path: Path | None = None):
    """官方 EN 現況 vs 快照 → 新增/改值/刪除 維護佇列。"""
    if not EN_SNAPSHOT_JSON.exists():
        print("❌ 尚無 EN 快照，先跑 en-snapshot")
        sys.exit(1)
    snap = json.loads(EN_SNAPSHOT_JSON.read_text(encoding="utf-8"))["values"]
    live = _vanilla_translate(pz_path, "EN")
    ch = _mod_ch_values()

    added = sorted(k for k in live if k not in snap)
    removed = sorted(k for k in snap if k not in live)
    changed = sorted(k for k in live if k in snap and live[k] != snap[k])
    print(f"官方 EN：快照 {len(snap)} 鍵 → 現況 {len(live)} 鍵")
    print(f"  新增 {len(added)} / 改值 {len(changed)} / 刪除 {len(removed)}")
    queue_path = Path(__file__).resolve().parent / "en_diff_queue.json"
    if not (added or removed or changed):
        print("✅ 無變動，CH 無需維護")
        if queue_path.exists():
            queue_path.unlink()
            print(f"已清除過期的 {queue_path.name}")
        return
    for k in added[:20]:
        mark = "（CH 已有）" if k in ch else "（CH 缺，待翻）"
        print(f"  ＋ {k} {mark}: {live[k][:60]!r}")
    for k in changed[:20]:
        print(f"  ～ {k}:")
        print(f"      舊 EN: {snap[k][:70]!r}")
        print(f"      新 EN: {live[k][:70]!r}")
        print(f"      現行 CH: {ch.get(k, '(缺)')[:70]!r}")
    for k in removed[:20]:
        print(f"  － {k}（CH 仍出貨: {'是' if k in ch else '否'}）")
    if len(added) + len(changed) + len(removed) > 60:
        print("  …（僅顯示前 20 筆/類）")
    queue = {
        "added": {k: {"en": live[k], "ch_exists": k in ch} for k in added},
        "changed": {k: {"en_old": snap[k], "en_new": live[k], "ch": ch.get(k)} for k in changed},
        "removed": {k: {"ch_still_shipped": k in ch} for k in removed},
    }
    out = queue_path
    out.write_bytes((json.dumps(queue, ensure_ascii=False, indent=1) + "\n").encode("utf-8"))
    print(f"維護佇列已寫入 {out.name}；處理完後跑 en-snapshot 更新基準")


def cmd_ch_lint():
    """術語引擎巡檢 CH 語料（select/lint 詞提示，不改檔）。"""
    import terminology as _T

    try:
        eng = _T.load()
    except (OSError, ValueError) as exc:
        print(f"❌ terminology.json 載入失敗：{exc}")
        sys.exit(1)
    from collections import Counter

    counts: Counter[str] = Counter()
    samples: dict[str, str] = {}
    for key, v in _mod_ch_values().items():
        for issue in eng.scan(v):
            counts[issue.rule] += 1
            samples.setdefault(issue.rule, f"{key}: …{issue.excerpt}…")
    if not counts:
        print("✅ 無 select/lint 詞命中")
        return
    print(f"術語巡檢（提示性，共 {sum(counts.values())} 處 / {len(counts)} 規則）：")
    for rule, n in counts.most_common():
        print(f"  {rule} ×{n}   例 {samples[rule][:80]}")


def cmd_import_new(pz_path: Path | None = None):
    """官方有、我方 CH 缺的鍵 → 術語引擎產出提案（人工簽核，不直接入庫）。"""
    import terminology as _T

    eng = _T.load()
    en = _vanilla_translate(pz_path, "EN")
    och = _vanilla_translate(pz_path, "CH")
    ch = _mod_ch_values()
    # 刻意不出貨的鍵（裁定紀錄）：官方繁中譯者署名經 fallback 原樣顯示，
    # 我方署名走 Credits.json 自有鍵，不得覆蓋官方譯者名單。
    IMPORT_EXCLUDE = {"Credits_Translator.json|Translator"}
    missing = sorted(k for k in en if k not in ch and k not in IMPORT_EXCLUDE)
    if not missing:
        print("✅ 官方 EN 鍵已全數涵蓋（含刻意排除清單），無新鍵")
        if IMPORT_PROPOSALS_JSON.exists():
            IMPORT_PROPOSALS_JSON.unlink()
            print(f"已清除過期的 {IMPORT_PROPOSALS_JSON.name}")
        return
    proposals: dict[str, dict] = {}
    for k in missing:
        base = och.get(k)
        if base is None:
            proposals[k] = {"en": en[k], "proposal": None, "note": "官方 CH 亦無此鍵，需全人工翻譯"}
            continue
        text, issues = eng.convert(base, key=k)
        proposals[k] = {
            "en": en[k],
            "official_ch": base,
            "proposal": text,
            "flags": [f"{i.kind}:{i.rule}" for i in issues],
        }
    IMPORT_PROPOSALS_JSON.write_bytes(
        (json.dumps(proposals, ensure_ascii=False, indent=1) + "\n").encode("utf-8")
    )
    n_flag = sum(1 for p in proposals.values() if p.get("flags"))
    print(f"新鍵 {len(missing)} 筆 → 提案已寫入 {IMPORT_PROPOSALS_JSON.name}（{n_flag} 筆帶語境待選旗標）")
    print("人工逐筆簽核後，直接寫入 MOD CH 檔（CH 檔即真相）。")



def main():
    parser = argparse.ArgumentParser(
        description="PZ 翻譯同步工具",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
使用範例：
  uv run scripts/sync_translations.py compare     # 查看差異
  uv run scripts/sync_translations.py sync-cn      # （已凍結）顯示 CN 維護流程說明
  uv run scripts/sync_translations.py sync-ch      # （已凍結）顯示 CH 維護流程說明
  uv run scripts/sync_translations.py sync-lua     # 只同步 Lua
  uv run scripts/sync_translations.py sync-all     # 全部同步
  uv run scripts/sync_translations.py fix-check    # 檢查轉換錯誤
  uv run scripts/sync_translations.py gen-vehicle-map --pz-path "D:/SteamLibrary/steamapps/common/ProjectZomboid"
  uv run scripts/sync_translations.py gen-radio-map --pz-path "D:/SteamLibrary/steamapps/common/ProjectZomboid"
  uv run scripts/sync_translations.py gen-dynamic-name-map --pz-path "D:/SteamLibrary/steamapps/common/ProjectZomboid"
  uv run scripts/sync_translations.py gen-media-map --pz-path "D:/SteamLibrary/steamapps/common/ProjectZomboid"
        """,
    )
    parser.add_argument(
        "command",
        nargs="?",
        default="compare",
        choices=[
            "compare",
            "sync-cn",
            "sync-ch",
            "sync-lua",
            "sync-all",
            "fix-check",
            "en-snapshot",
            "en-diff",
            "ch-lint",
            "import-new",
            "gen-vehicle-map",
            "gen-item-name-map",
            "gen-radio-map",
            "gen-dynamic-name-map",
            "gen-media-map",
        ],
        help="執行的命令（預設：compare）",
    )
    parser.add_argument(
        "--pz-path",
        type=Path,
        default=None,
        help="vanilla Project Zomboid 安裝路徑（gen-vehicle-map / gen-radio-map / gen-dynamic-name-map / gen-media-map 使用）",
    )
    args = parser.parse_args()

    if args.command not in {"gen-vehicle-map", "gen-item-name-map", "gen-radio-map", "gen-dynamic-name-map", "gen-media-map", "en-snapshot", "en-diff", "ch-lint", "import-new", "sync-ch"}:
        if not REF_CN.exists():
            print(f"❌ 參考目錄不存在：{REF_CN}")
            sys.exit(1)
        if not MOD_CN.exists():
            print(f"❌ MOD CN 目錄不存在：{MOD_CN}")
            sys.exit(1)

    match args.command:
        case "compare":
            cmd_compare()
        case "sync-cn":
            cmd_sync_cn()
        case "sync-ch":
            cmd_sync_ch()
        case "sync-lua":
            cmd_sync_lua()
        case "sync-all":
            cmd_sync_all()
        case "fix-check":
            cmd_fix_check()
        case "en-snapshot":
            cmd_en_snapshot(args.pz_path)
        case "en-diff":
            cmd_en_diff(args.pz_path)
        case "ch-lint":
            cmd_ch_lint()
        case "import-new":
            cmd_import_new(args.pz_path)
        case "gen-vehicle-map":
            cmd_gen_vehicle_map(args.pz_path)
        case "gen-item-name-map":
            cmd_gen_item_name_map(args.pz_path)
        case "gen-radio-map":
            cmd_gen_radio_map(args.pz_path)
        case "gen-dynamic-name-map":
            cmd_gen_dynamic_name_map(args.pz_path)
        case "gen-media-map":
            cmd_gen_media_map(args.pz_path)


if __name__ == "__main__":
    main()
