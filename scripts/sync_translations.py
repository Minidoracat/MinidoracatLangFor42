# /// script
# dependencies = ["opencc-python-reimplemented"]
# requires-python = ">=3.10"
# ///
# pyright: reportMissingImports=false, reportMissingTypeArgument=false
"""
PZ 翻譯同步工具
用途：將 translation-reference (簡體中文) 同步到 MOD 目錄（CN + CH）
使用方式：uv run scripts/sync_translations.py [命令]

命令：
  compare         - 比對差異（預設）
  sync-cn         - 同步 CN 翻譯檔（REF CN → MOD CN）
  sync-ch         - 同步 CH 翻譯檔（REF CN → OpenCC s2twp → MOD CH）
  sync-lua        - 同步 Lua 腳本
  sync-all        - 執行全部同步
  fix-check       - 檢查 OpenCC 轉換常見錯誤
  gen-vehicle-map - 從 vanilla EN IG_UI.json 生成 VehicleKey_Flx 反查表
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

import opencc

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
    write_translation_json,
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
# OpenCC 轉換器
# ============================================================
CONVERTER = opencc.OpenCC("s2twp")

# ============================================================
# OpenCC 後處理修正規則（從 JSON 字典載入）
# ============================================================
FIXES_JSON = Path(__file__).resolve().parent / "opencc_fixes.json"


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
        })

    return post_fixes, suspicious


POST_FIXES, SUSPICIOUS_PATTERNS = _load_fixes()

# ============================================================
# 人工覆寫層（ch_overrides.json / cn_overrides.json）
# ------------------------------------------------------------
# sync-ch / sync-cn 機轉全量再生後套用的人工真相檔。schema：
#   {"<檔名>|<鍵>": "<人工值>"}                        （簡式，無過時偵測）
#   {"<檔名>|<鍵>": {"value": "<人工值>", "ref": "<登記時 REF 原文 hash>"}}
#   {"<檔名>|<鍵>": {"drop": true, "note": "<理由>"}}   （deny-list：不得輸出此鍵）
# ref = _ref_hash(REF 原文)；發現 REF 原文已變更時提醒重審，
# 鍵已從 REF 消失時提醒清理。缺檔即報錯（防止誤跑同步洗掉人工潤飾）。
#
# drop 的用途：REF（As1 42.0）仍有、但官方 42.20 已移除／改鍵名的死鍵。
# 不用「官方 EN 有無」當自動閘門——實測 REF 有 1320 鍵官方 EN 沒有，其中 1286
# 鍵仍在出貨（Recipes.json 一檔 512），自動閘會誤刪；死鍵須逐案登記。
# ============================================================
OVERRIDES_JSON = Path(__file__).resolve().parent / "ch_overrides.json"
CN_OVERRIDES_JSON = Path(__file__).resolve().parent / "cn_overrides.json"

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


def _ref_hash(value: str) -> str:
    """REF 原文的短 hash，登記於 override 條目供過時偵測。"""
    return hashlib.sha256(value.encode("utf-8")).hexdigest()[:16]


def _load_overrides(path: Path = OVERRIDES_JSON) -> dict[str, dict]:
    """載入人工覆寫檔；缺檔或格式錯誤即終止，不自動建骨架。"""
    name = path.name
    if not path.exists():
        print(f"❌ 人工覆寫檔不存在：{path}", file=sys.stderr)
        print(f"  同步需要 {name} 才能保留人工潤飾，請先建立（勿用空猜測值）。", file=sys.stderr)
        sys.exit(1)
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"❌ {name} 讀取失敗：{exc}", file=sys.stderr)
        sys.exit(1)

    overrides: dict[str, dict] = {}
    for ov_key, ent in data.items():
        if ov_key.startswith("_"):
            continue  # _comment 等說明欄位
        if "|" not in ov_key:
            print(f"❌ {name} 鍵格式錯誤（應為 <檔名>|<鍵>）：{ov_key}", file=sys.stderr)
            sys.exit(1)
        if isinstance(ent, str):
            overrides[ov_key] = {"value": ent, "ref": None, "drop": False}
        elif isinstance(ent, dict) and ent.get("drop") is True:
            overrides[ov_key] = {"value": None, "ref": ent.get("ref"), "drop": True}
        elif isinstance(ent, dict) and isinstance(ent.get("value"), str):
            overrides[ov_key] = {
                "value": ent["value"],
                "ref": ent.get("ref"),
                "drop": False,
            }
        else:
            print(f"❌ {name} 條目格式錯誤：{ov_key} = {ent!r}", file=sys.stderr)
            sys.exit(1)
    return overrides


def _group_overrides(overrides: dict[str, dict]) -> dict[str, dict[str, dict]]:
    """{"檔名|鍵": ent} → {"檔名": {"鍵": ent}}"""
    by_file: dict[str, dict[str, dict]] = {}
    for ov_key, ent in overrides.items():
        fname, _, key = ov_key.partition("|")
        by_file.setdefault(fname, {})[key] = ent
    return by_file


def _apply_overrides(
    json_name: str,
    ref_data: "OrderedDict[str, str]",
    ch_data: "OrderedDict[str, str]",
    ov_for_file: dict[str, dict],
    used_ov: set[str],
    stale_warnings: list[str],
) -> int:
    """機轉結果套用人工覆寫（僅 REF 衍生鍵；MOD 自訂鍵不經此層）。"""
    applied = 0
    for key, ent in ov_for_file.items():
        if ent["drop"]:
            continue  # deny-list 由 _apply_drops 處理
        if key not in ch_data:
            continue  # 鍵不在本次機轉輸出 → 留給收尾的未命中報告
        ch_data[key] = ent["value"]
        used_ov.add(f"{json_name}|{key}")
        applied += 1
        if ent["ref"]:
            cur = _ref_hash(ref_data.get(key, ""))
            if cur != ent["ref"]:
                stale_warnings.append(
                    f"  {json_name}|{key}: REF 原文已變更（登記 {ent['ref']} ≠ 現值 {cur}），請重審此 override"
                )
    return applied


def _apply_drops(
    json_name: str,
    data: "OrderedDict[str, str]",
    ov_for_file: dict[str, dict],
    used_ov: set[str],
) -> int:
    """移除 deny-list 登記的死鍵（官方已移除／改鍵名，REF 仍殘留）。

    須在「保留 MOD 自訂鍵」的合併**之後**呼叫，否則被移除的鍵會被舊檔內容
    當成自訂鍵補回來。
    """
    dropped = 0
    for key, ent in ov_for_file.items():
        if not ent["drop"] or key not in data:
            continue
        del data[key]
        used_ov.add(f"{json_name}|{key}")
        dropped += 1
    return dropped


def sha256(path: Path) -> str:
    """計算檔案 SHA256"""
    h = hashlib.sha256()
    h.update(path.read_bytes())
    return h.hexdigest()


def convert_s2twp(text: str) -> str:
    """簡體 → 繁體（台灣用語）轉換 + 後處理修正"""
    result = CONVERTER.convert(text)
    for pattern, replacement, _desc in POST_FIXES:
        result = pattern.sub(replacement, result)
    return result

# Print_Media <type:text, ...> 中文字內容的提取模式
# 匹配 <type:text, ...> 標記後面到下一個 <type: 標記之前（或字串結尾）的文字
_PRINT_MEDIA_TEXT_RE = re.compile(
    r'(<type:text\b[^>]*>)'   # group 1: <type:text, ...> 標記本身
    r'([^<]*)'                 # group 2: 標記後的文字內容
)


def convert_print_media_value(value: str) -> str:
    """轉換 Print_Media _info 值中的中文文字。

    只對 <type:text, ...> 標記後面的文字做 OpenCC 簡繁轉換，
    不動 <type:parent/texture> 標記參數（座標、字型名、路徑等）。
    """
    if "<type:text" not in value:
        # 沒有 text 標記（純 texture/parent），直接回傳
        return value

    def _replace_text_content(m: re.Match) -> str:
        tag = m.group(1)    # <type:text, ...>
        text = m.group(2)   # 後面的文字
        if text:
            text = convert_s2twp(text)
        return tag + text

    return _PRINT_MEDIA_TEXT_RE.sub(_replace_text_content, value)


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
    """同步 CN 翻譯檔：REF CN → MOD CN（解析後輸出 JSON）"""
    print("=" * 60)
    print("同步 CN 翻譯檔（REF CN → MOD CN .json）")
    print("=" * 60)

    updated = 0

    overrides = _load_overrides(CN_OVERRIDES_JSON)
    ov_by_file = _group_overrides(overrides)
    used_ov: set[str] = set()
    stale_warnings: list[str] = []
    applied_total = 0
    dropped_total = 0

    # Process .txt translation files (legacy format)
    for ref_file in sorted(REF_CN.glob("*.txt")):
        if not ref_file.is_file():
            continue
        filename = ref_file.name

        if filename in EXCLUDE_GENERATE or filename in MANUAL_MAINTAINED:
            continue

        if filename in PZ_SKIP_FILES:
            # language.txt — copy as-is
            mod_file = MOD_CN / filename
            if not mod_file.exists() or sha256(ref_file) != sha256(mod_file):
                mod_file.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ref_file, mod_file)
                print(f"  ✅ 複製: {filename}")
                updated += 1
            continue

        json_name = txt_to_json_filename(filename)
        mod_file = MOD_CN / json_name

        ref_data = read_translation(ref_file)
        out_data = OrderedDict(ref_data)

        # REF 之後、自訂鍵合併之前套用人工覆寫（僅 REF 衍生鍵）
        applied_total += _apply_overrides(
            json_name, ref_data, out_data, ov_by_file.get(json_name, {}), used_ov, stale_warnings
        )

        # 保留 MOD 中有但 REF 中沒有的自訂 keys
        mod_data = None
        if mod_file.exists():
            mod_data = read_translation(mod_file)
            extra_keys = OrderedDict(
                (k, v) for k, v in mod_data.items() if k not in out_data
            )
            if extra_keys:
                if json_name == "Print_Media.json":
                    for k in list(extra_keys):
                        err = _validate_print_media_info(k, extra_keys[k])
                        if err:
                            print(f"  ⚠️  移除截斷的自訂 key: {k} ({err})")
                            del extra_keys[k]
                out_data.update(extra_keys)

        # deny-list：合併自訂鍵之後才移除，否則舊檔會把死鍵當自訂鍵補回
        dropped_total += _apply_drops(
            json_name, out_data, ov_by_file.get(json_name, {}), used_ov
        )

        # Compare with existing
        if mod_data is not None:
            if mod_data == out_data:
                continue
            added = len(set(out_data) - set(mod_data))
            removed = len(set(mod_data) - set(out_data))
            print(f"  📝 更新: {filename} → {json_name} ({len(out_data)} keys, +{added}/-{removed})")
        else:
            print(f"  ➕ 新增: {filename} → {json_name} ({len(out_data)} keys)")

        write_translation_json(out_data, mod_file)
        updated += 1

    # Process .json translation files (new format)
    for ref_file in sorted(REF_CN.glob("*.json")):
        if not ref_file.is_file():
            continue
        filename = ref_file.name
        json_name = filename
        mod_file = MOD_CN / json_name

        ref_data = read_translation(ref_file)
        out_data = OrderedDict(ref_data)

        # REF 之後、自訂鍵合併之前套用人工覆寫（僅 REF 衍生鍵）
        applied_total += _apply_overrides(
            json_name, ref_data, out_data, ov_by_file.get(json_name, {}), used_ov, stale_warnings
        )

        # 保留 MOD 中有但 REF 中沒有的自訂 keys
        mod_data = None
        if mod_file.exists():
            mod_data = read_translation(mod_file)
            extra_keys = OrderedDict(
                (k, v) for k, v in mod_data.items() if k not in out_data
            )
            if extra_keys:
                if json_name == "Print_Media.json":
                    for k in list(extra_keys):
                        err = _validate_print_media_info(k, extra_keys[k])
                        if err:
                            print(f"  ⚠️  移除截斷的自訂 key: {k} ({err})")
                            del extra_keys[k]
                out_data.update(extra_keys)

        # deny-list：合併自訂鍵之後才移除
        dropped_total += _apply_drops(
            json_name, out_data, ov_by_file.get(json_name, {}), used_ov
        )

        # Compare with existing
        if mod_data is not None:
            if mod_data == out_data:
                continue
            added = len(set(out_data) - set(mod_data))
            removed = len(set(mod_data) - set(out_data))
            print(f"  📝 更新: {json_name} ({len(out_data)} keys, +{added}/-{removed})")
        else:
            print(f"  ➕ 新增: {json_name} ({len(out_data)} keys)")

        write_translation_json(out_data, mod_file)
        updated += 1

    # Process city directories (legacy format)
    for city_dir in sorted(d for d in REF_CN.iterdir() if d.is_dir()):
        title_path = city_dir / "title.txt"
        desc_path = city_dir / "description.txt"
        if not title_path.exists() or not desc_path.exists():
            continue

        json_name = f"{city_dir.name}.json"
        mod_file = MOD_CN / json_name

        ref_data = parse_city_directory(city_dir)

        if mod_file.exists():
            mod_data = read_translation(mod_file)
            if ref_data == mod_data:
                continue
            print(f"  📝 更新: {city_dir.name}/ → {json_name}")
        else:
            print(f"  ➕ 新增: {city_dir.name}/ → {json_name}")

        write_translation_json(ref_data, mod_file)
        updated += 1

    if updated == 0:
        print("  ℹ️ 沒有需要同步的檔案")
    print(f"\n完成：{updated} 個檔案已同步")

    n_drop = sum(1 for e in overrides.values() if e["drop"])
    print(
        f"人工覆寫：套用 {applied_total} / {len(overrides) - n_drop} 筆 cn_overrides"
        f"；deny-list 移除死鍵 {dropped_total} / {n_drop} 筆"
    )
    unused_ov = sorted(set(overrides) - used_ov)
    if unused_ov:
        print(f"\n⚠️ {len(unused_ov)} 筆 override 未命中（鍵已從 REF 消失或檔名不符），請清理：")
        for k in unused_ov:
            print(f"  {k}")
    if stale_warnings:
        print(f"\n⚠️ {len(stale_warnings)} 筆 override 的 REF 原文已變更，請重審後更新 ref hash：")
        for w in stale_warnings:
            print(w)


def cmd_sync_ch():
    """同步 CH 翻譯檔：REF CN → OpenCC s2twp → MOD CH .json"""
    print("=" * 60)
    print("同步 CH 翻譯檔（REF CN → OpenCC s2twp → MOD CH .json）")
    print("=" * 60)

    updated = 0
    skipped = 0
    unchanged = 0
    all_issues: list[str] = []

    overrides = _load_overrides()
    ov_by_file = _group_overrides(overrides)
    used_ov: set[str] = set()
    stale_warnings: list[str] = []
    applied_total = 0
    dropped_total = 0

    # Process .txt translation files (legacy format)
    for ref_file in sorted(REF_CN.glob("*.txt")):
        if not ref_file.is_file():
            continue

        filename = ref_file.name

        if filename in EXCLUDE_GENERATE:
            print(f"  ⏭️ 跳過: {filename} (未版控且無消費端，不生成)")
            skipped += 1
            continue

        if filename in MANUAL_MAINTAINED:
            print(f"  ⏭️ 跳過: {filename} (人工維護檔，不從 REF 同步)")
            skipped += 1
            continue

        # Skip files that stay as .txt (credits.txt etc.)
        if filename in PZ_SKIP_FILES:
            ref_content = ref_file.read_text(encoding="utf-8-sig")
            ch_content = convert_s2twp(ref_content)
            ch_path = MOD_CH / filename
            if ch_path.exists():
                old_content = ch_path.read_text(encoding="utf-8-sig")
                if old_content == ch_content:
                    unchanged += 1
                    continue
            ch_path.parent.mkdir(parents=True, exist_ok=True)
            ch_path.write_text(ch_content, encoding="utf-8", newline="\n")
            print(f"  ✅ 轉換: {filename} (保留 .txt)")
            updated += 1
            continue

        json_name = txt_to_json_filename(filename)
        ch_path = MOD_CH / json_name

        ref_data = read_translation(ref_file)

        is_print_media = json_name == "Print_Media.json"
        ch_data: OrderedDict[str, str] = OrderedDict()
        for key, value in ref_data.items():
            if is_print_media and key.endswith("_info"):
                ch_data[key] = convert_print_media_value(value)
            else:
                ch_data[key] = convert_s2twp(value)

        # 機轉之後、自訂鍵合併之前套用人工覆寫
        applied_total += _apply_overrides(
            json_name, ref_data, ch_data, ov_by_file.get(json_name, {}), used_ov, stale_warnings
        )

        # 保留 MOD 中有但 REF 中沒有的自訂 keys
        if ch_path.exists():
            old_data = read_translation(ch_path)
            extra_keys = OrderedDict(
                (k, v) for k, v in old_data.items() if k not in ch_data
            )
            if extra_keys:
                if json_name == "Print_Media.json":
                    for k in list(extra_keys):
                        err = _validate_print_media_info(k, extra_keys[k])
                        if err:
                            print(f"  ⚠️  移除截斷的自訂 key: {k} ({err})")
                            del extra_keys[k]
                ch_data.update(extra_keys)
        else:
            old_data = None

        # deny-list：合併自訂鍵之後才移除，否則舊檔會把死鍵當自訂鍵補回
        dropped_total += _apply_drops(
            json_name, ch_data, ov_by_file.get(json_name, {}), used_ov
        )

        if old_data is not None:
            if old_data == ch_data:
                unchanged += 1
                continue
            added = len(set(ch_data) - set(old_data))
            removed = len(set(old_data) - set(ch_data))
            print(f"  📝 更新: {json_name} (+{added}/-{removed} keys)")
        else:
            ch_path.parent.mkdir(parents=True, exist_ok=True)
            print(f"  ➕ 新增: {json_name} ({len(ch_data)} keys)")

        write_translation_json(ch_data, ch_path)
        updated += 1

        ch_text = "\n".join(ch_data.values())
        issues = check_suspicious(ch_text, json_name)
        all_issues.extend(issues)

    # Process .json translation files (new format)
    for ref_file in sorted(REF_CN.glob("*.json")):
        if not ref_file.is_file():
            continue

        json_name = ref_file.name
        ch_path = MOD_CH / json_name

        ref_data = read_translation(ref_file)

        is_print_media = json_name == "Print_Media.json"
        ch_data: OrderedDict[str, str] = OrderedDict()
        for key, value in ref_data.items():
            if is_print_media and key.endswith("_info"):
                ch_data[key] = convert_print_media_value(value)
            else:
                ch_data[key] = convert_s2twp(value)

        # 機轉之後、自訂鍵合併之前套用人工覆寫
        applied_total += _apply_overrides(
            json_name, ref_data, ch_data, ov_by_file.get(json_name, {}), used_ov, stale_warnings
        )

        # 保留 MOD 中有但 REF 中沒有的自訂 keys
        if ch_path.exists():
            old_data = read_translation(ch_path)
            extra_keys = OrderedDict(
                (k, v) for k, v in old_data.items() if k not in ch_data
            )
            if extra_keys:
                if json_name == "Print_Media.json":
                    for k in list(extra_keys):
                        err = _validate_print_media_info(k, extra_keys[k])
                        if err:
                            print(f"  ⚠️  移除截斷的自訂 key: {k} ({err})")
                            del extra_keys[k]
                ch_data.update(extra_keys)
        else:
            old_data = None

        # deny-list：合併自訂鍵之後才移除，否則舊檔會把死鍵當自訂鍵補回
        dropped_total += _apply_drops(
            json_name, ch_data, ov_by_file.get(json_name, {}), used_ov
        )

        if old_data is not None:
            if old_data == ch_data:
                unchanged += 1
                continue
            added = len(set(ch_data) - set(old_data))
            removed = len(set(old_data) - set(ch_data))
            print(f"  📝 更新: {json_name} (+{added}/-{removed} keys)")
        else:
            ch_path.parent.mkdir(parents=True, exist_ok=True)
            print(f"  ➕ 新增: {json_name} ({len(ch_data)} keys)")

        write_translation_json(ch_data, ch_path)
        updated += 1

        ch_text = "\n".join(ch_data.values())
        issues = check_suspicious(ch_text, json_name)
        all_issues.extend(issues)

    # Process city directories (legacy format)
    for city_dir in sorted(d for d in REF_CN.iterdir() if d.is_dir()):
        title_path = city_dir / "title.txt"
        desc_path = city_dir / "description.txt"
        if not title_path.exists() or not desc_path.exists():
            continue

        json_name = f"{city_dir.name}.json"
        ch_path = MOD_CH / json_name

        # Skip if already handled by .json glob above
        if ch_path.exists() and any(
            ref_f.name == json_name for ref_f in REF_CN.glob("*.json")
        ):
            continue

        ref_data = parse_city_directory(city_dir)
        ch_data: OrderedDict[str, str] = OrderedDict()
        for key, value in ref_data.items():
            ch_data[key] = convert_s2twp(value)

        applied_total += _apply_overrides(
            json_name, ref_data, ch_data, ov_by_file.get(json_name, {}), used_ov, stale_warnings
        )

        if ch_path.exists():
            old_data = read_translation(ch_path)
            if old_data == ch_data:
                unchanged += 1
                continue
            print(f"  📝 更新: {json_name}")
        else:
            print(f"  ➕ 新增: {json_name}")

        write_translation_json(ch_data, ch_path)
        updated += 1

    print(f"\n完成：{updated} 個 CH 檔案已更新，{skipped} 個已跳過，{unchanged} 個無變化")
    n_drop = sum(1 for e in overrides.values() if e["drop"])
    print(
        f"人工覆寫：套用 {applied_total} / {len(overrides) - n_drop} 筆 ch_overrides"
        f"；deny-list 移除死鍵 {dropped_total} / {n_drop} 筆"
    )

    unused_ov = sorted(set(overrides) - used_ov)
    if unused_ov:
        print(f"\n⚠️ {len(unused_ov)} 筆 override 未命中（鍵已從 REF 消失或檔名不符），請清理：")
        for k in unused_ov:
            print(f"  {k}")
    if stale_warnings:
        print(f"\n⚠️ {len(stale_warnings)} 筆 override 的 REF 原文已變更，請重審後更新 ref hash：")
        for w in stale_warnings:
            print(w)

    if all_issues:
        print(f"\n⚠️ 發現 {len(all_issues)} 處可能需要人工檢查：")
        for issue in all_issues[:50]:
            print(issue)
        if len(all_issues) > 50:
            print(f"  ... 還有 {len(all_issues) - 50} 處")


# ============================================================
# 跨專案字典一致性檢查（fix-check 附掛）
# ------------------------------------------------------------
# 兩專案的 opencc_fixes.json 依 skill 進化協議應人工同步（新規則兩邊加）。
# 此檢查自動比對，抓出「無註記的分岔」。允許的差異：
#   - identity 規則（pattern == replacement，保護性文件規則，如 關係→關係）
#   - note 含「分岔」或「勿移植」的已裁決語境分岔（如 ^幹$、外掛；裁決記錄
#     見 pz-zhtw-polish skill 的 rules.md 移植警示表）
# ============================================================
SIBLING_FIXES_JSON = (
    PROJECT_ROOT.parent / "MinidoracatModLangFor42" / "sources" / "opencc_fixes.json"
)


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
                if not isinstance(value, str) or len(value) > _DUPE_MAX_LEN:
                    continue
                if f"{path.name}|{key}" in _DUPE_ALLOWLIST:
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


def check_cjk_spacing() -> list[str]:
    """逐字空格排版檢查：只報「對側語言同鍵沒有空格」者（= 我們帶進來的）。

    As1 原有的排版（傳單、城鎮 description）對側也帶空格，不報。
    這類值會遮蔽疊字偵測，屬硬性錯誤。
    """
    issues: list[str] = []
    for lang, mod_dir, other_dir in (("CH", MOD_CH, MOD_CN), ("CN", MOD_CN, MOD_CH)):
        for path in sorted(mod_dir.glob("*.json")):
            try:
                data = read_translation(path)
                other = read_translation(other_dir / path.name)
            except Exception:  # noqa: BLE001
                continue
            for key, value in data.items():
                if not isinstance(value, str) or not _SPACED_CJK.search(value):
                    continue
                peer = other.get(key)
                if isinstance(peer, str) and _SPACED_CJK.search(peer):
                    continue
                issues.append(f"  [{lang}] {path.name} | {key}: {value[:56]!r}")
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
    print("逐字空格排版檢查（CH + CN，對側語言同鍵無空格者）")
    print("=" * 60)
    spaced = check_cjk_spacing()
    if spaced:
        print(f"⚠️ 發現 {len(spaced)} 處逐字空格排版（重譯產物；會遮蔽疊字偵測，應剝除）：")
        for issue in spaced:
            print(issue)
    else:
        print("✅ 未發現逐字空格排版")

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
    """執行全部同步"""
    cmd_sync_cn()
    print()
    cmd_sync_ch()
    print()
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

    en_to_key: OrderedDict[str, str] = OrderedDict()
    duplicate_values: dict[str, list[str]] = {}
    ambiguous_duplicates: set[str] = set()

    first_key_by_en: dict[str, str] = {}
    translations_by_en: dict[str, set[tuple[str, str]]] = {}
    for key, en_value in en_data.items():
        if not en_value or en_value == "~":
            continue
        ch_value = ch_data[key]
        cn_value = cn_data[key]
        translations_by_en.setdefault(en_value, set()).add((ch_value, cn_value))
        if en_value in first_key_by_en:
            duplicate_values.setdefault(en_value, [first_key_by_en[en_value]]).append(key)
            if len(translations_by_en[en_value]) > 1:
                ambiguous_duplicates.add(en_value)
            continue

        first_key_by_en[en_value] = key
        if ch_value != en_value or cn_value != en_value:
            en_to_key[en_value] = key

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
def main():
    parser = argparse.ArgumentParser(
        description="PZ 翻譯同步工具",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
使用範例：
  uv run scripts/sync_translations.py compare     # 查看差異
  uv run scripts/sync_translations.py sync-cn      # 只同步 CN
  uv run scripts/sync_translations.py sync-ch      # 只同步 CH
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
            "gen-vehicle-map",
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

    if args.command not in {"gen-vehicle-map", "gen-radio-map", "gen-dynamic-name-map", "gen-media-map"}:
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
        case "gen-vehicle-map":
            cmd_gen_vehicle_map(args.pz_path)
        case "gen-radio-map":
            cmd_gen_radio_map(args.pz_path)
        case "gen-dynamic-name-map":
            cmd_gen_dynamic_name_map(args.pz_path)
        case "gen-media-map":
            cmd_gen_media_map(args.pz_path)


if __name__ == "__main__":
    main()
