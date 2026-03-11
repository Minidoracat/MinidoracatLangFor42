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
  compare   - 比對差異（預設）
  sync-cn   - 同步 CN 翻譯檔（REF CN → MOD CN）
  sync-ch   - 同步 CH 翻譯檔（REF CN → OpenCC s2twp → MOD CH）
  sync-lua  - 同步 Lua 腳本
  sync-all  - 執行全部同步
  fix-check - 檢查 OpenCC 轉換常見錯誤
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
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
# language.txt: CH 版本有自己的語言定義，不能從 CN 轉換
SKIP_CH_CONVERT = {"language.txt"}

# Lua 腳本中 As1 的版本註釋標記，合併時應跳過
AS1_COMMENT_PATTERN = re.compile(r"^--\s*As\s*1\s*--", re.MULTILINE)

# ============================================================
# Lua 腳本清單（資料驅動，唯一定義處）
# ============================================================
# 每組：(REF 中的檔名, MOD 中 CN 檔名, MOD 中 CH 檔名)
LUA_PAIRS: list[tuple[str, str, str]] = [
    ("FishWindow_CN.lua", "FishWindow_CN.lua", "FishWindow_CH.lua"),
    ("ISBuildWindowHeader_CN.lua", "ISBuildWindowHeader_CN.lua", "ISBuildWindowHeader_CH.lua"),
    ("ISWidgetRecipeCategories_CN.lua", "ISWidgetRecipeCategories_CN.lua", "ISWidgetRecipeCategories_CH.lua"),
    ("ISUI/ISRichTextPanel_CN.lua", "ISUI/ISRichTextPanel_CN.lua", "ISUI/ISRichTextPanel_CH.lua"),
    ("ISUI/Maps/ISMapDefinitions_CN.lua", "ISUI/Maps/ISMapDefinitions_CN.lua", "ISUI/Maps/ISMapDefinitions_CH.lua"),
    ("OptionScreens/MainScreen_CN.lua", "OptionScreens/MainScreen_CN.lua", "OptionScreens/MainScreen_CH.lua"),
]

# Flx 腳本（雙語通用，直接複製）
FLX_FILES: list[str] = [
    "MapLabel_Flx.lua",
    "ModInfoPanel_FIx.lua",
    "OptionScreens/MapSpawnSelect_Flx.lua",
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
    """Find changed translation files (REF .txt vs MOD .json)"""
    changes: dict[str, dict] = {}

    # Process .txt files in REF
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

    # Process city directories in REF
    for city_dir in sorted(d for d in ref_dir.iterdir() if d.is_dir()):
        title_path = city_dir / "title.txt"
        desc_path = city_dir / "description.txt"
        if not title_path.exists() or not desc_path.exists():
            continue

        rel = city_dir.name + "/"
        json_name = f"{city_dir.name}.json"
        mod_file = mod_dir / json_name

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
    for ref_file in sorted(REF_CN.glob("*.txt")):
        if ref_file.name in SKIP_CH_CONVERT:
            continue
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

    # Also check city directories
    for city_dir in sorted(d for d in REF_CN.iterdir() if d.is_dir()):
        title_path = city_dir / "title.txt"
        if not title_path.exists():
            continue
        json_name = f"{city_dir.name}.json"
        ch_file = MOD_CH / json_name
        if not ch_file.exists():
            print(f"  ❌ {city_dir.name}/ → {json_name} (CH 不存在)")

    # Lua 腳本（從 LUA_PAIRS / FLX_FILES 衍生）
    print(f"\n📁 Lua 腳本比對")
    print("-" * 40)
    for ref_name, _cn_name, ch_name in LUA_PAIRS:
        ref_f = REF_LUA / ref_name
        mod_f = MOD_LUA / ch_name
        if not ref_f.exists():
            print(f"  ❌ {ref_name} (REF 不存在)")
            continue
        if not mod_f.exists():
            print(f"  ➕ {ref_name} → {ch_name} (MOD 不存在)")
            continue
        ref_lc = len(ref_f.read_text(encoding="utf-8-sig").splitlines())
        mod_lc = len(mod_f.read_text(encoding="utf-8-sig").splitlines())
        ref_size = ref_f.stat().st_size
        mod_size = mod_f.stat().st_size
        if ref_size != mod_size or ref_lc != mod_lc:
            print(f"  📝 {ref_name} → {ch_name} (ref={ref_lc}L/{ref_size}B mod={mod_lc}L/{mod_size}B)")
        elif sha256(ref_f) != sha256(mod_f):
            print(f"  📝 {ref_name} → {ch_name} (同尺寸但內容不同)")
        else:
            print(f"  ✅ {ref_name} → {ch_name}")
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

    # Process .txt translation files
    for ref_file in sorted(REF_CN.glob("*.txt")):
        if not ref_file.is_file():
            continue
        filename = ref_file.name

        if filename in PZ_SKIP_FILES:
            # language.txt, credits.txt, streets.txt — copy as-is
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

        # 保留 MOD 中有但 REF 中沒有的自訂 keys
        if mod_file.exists():
            mod_data = read_translation(mod_file)
            extra_keys = OrderedDict(
                (k, v) for k, v in mod_data.items() if k not in ref_data
            )
            if extra_keys:
                # 驗證 Print_Media _info 自訂 keys 是否被截斷
                if json_name == "Print_Media.json":
                    for k in list(extra_keys):
                        err = _validate_print_media_info(k, extra_keys[k])
                        if err:
                            print(f"  ⚠️  移除截斷的自訂 key: {k} ({err})")
                            del extra_keys[k]
                merged = OrderedDict(ref_data)
                merged.update(extra_keys)
                ref_data = merged

        # Compare with existing
        if mod_file.exists():
            if mod_data == ref_data:
                continue
            added = len(set(ref_data) - set(mod_data))
            removed = len(set(mod_data) - set(ref_data))
            print(f"  📝 更新: {filename} → {json_name} ({len(ref_data)} keys, +{added}/-{removed})")
        else:
            print(f"  ➕ 新增: {filename} → {json_name} ({len(ref_data)} keys)")

        write_translation_json(ref_data, mod_file)
        updated += 1

    # Process city directories
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


def cmd_sync_ch():
    """同步 CH 翻譯檔：REF CN → OpenCC s2twp → MOD CH .json"""
    print("=" * 60)
    print("同步 CH 翻譯檔（REF CN → OpenCC s2twp → MOD CH .json）")
    print("=" * 60)

    updated = 0
    skipped = 0
    unchanged = 0
    all_issues: list[str] = []

    # Process .txt translation files
    for ref_file in sorted(REF_CN.glob("*.txt")):
        if not ref_file.is_file():
            continue

        filename = ref_file.name

        # language.txt: CH has its own definition, don't convert
        if filename in SKIP_CH_CONVERT:
            print(f"  ⏭️ 跳過: {filename} (CH 版本保持不變)")
            skipped += 1
            continue

        # Skip files that stay as .txt (streets.txt, credits.txt)
        if filename in PZ_SKIP_FILES:
            # For these, just do text-level OpenCC conversion and copy
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

        # Parse REF .txt → dict
        ref_data = read_translation(ref_file)

        # OpenCC convert VALUES only
        # Print_Media _info 值需要特殊處理：只轉換 <type:text> 中的文字
        is_print_media = json_name == "Print_Media.json"
        ch_data: OrderedDict[str, str] = OrderedDict()
        for key, value in ref_data.items():
            if is_print_media and key.endswith("_info"):
                ch_data[key] = convert_print_media_value(value)
            else:
                ch_data[key] = convert_s2twp(value)

        # 保留 MOD 中有但 REF 中沒有的自訂 keys
        if ch_path.exists():
            old_data = read_translation(ch_path)
            extra_keys = OrderedDict(
                (k, v) for k, v in old_data.items() if k not in ch_data
            )
            if extra_keys:
                # 驗證 Print_Media _info 自訂 keys 是否被截斷
                if json_name == "Print_Media.json":
                    for k in list(extra_keys):
                        err = _validate_print_media_info(k, extra_keys[k])
                        if err:
                            print(f"  ⚠️  移除截斷的自訂 key: {k} ({err})")
                            del extra_keys[k]
                ch_data.update(extra_keys)
        else:
            old_data = None

        # Compare with existing CH
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

        # Check suspicious patterns in values
        ch_text = "\n".join(ch_data.values())
        issues = check_suspicious(ch_text, json_name)
        all_issues.extend(issues)

    # Process city directories
    for city_dir in sorted(d for d in REF_CN.iterdir() if d.is_dir()):
        title_path = city_dir / "title.txt"
        desc_path = city_dir / "description.txt"
        if not title_path.exists() or not desc_path.exists():
            continue

        json_name = f"{city_dir.name}.json"
        ch_path = MOD_CH / json_name

        ref_data = parse_city_directory(city_dir)
        ch_data: OrderedDict[str, str] = OrderedDict()
        for key, value in ref_data.items():
            ch_data[key] = convert_s2twp(value)

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

    if all_issues:
        print(f"\n⚠️ 發現 {len(all_issues)} 處可能需要人工檢查：")
        for issue in all_issues[:50]:
            print(issue)
        if len(all_issues) > 50:
            print(f"  ... 還有 {len(all_issues) - 50} 處")


def cmd_fix_check():
    """檢查 OpenCC 轉換常見錯誤"""
    print("=" * 60)
    print("OpenCC 轉換結果檢查（CH 翻譯檔 + CH Lua）")
    print("=" * 60)

    all_issues: list[str] = []

    # Check CH translation JSON files
    for ch_file in sorted(MOD_CH.rglob("*.json")):
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
        if ch_file.name in {"language.txt"}:
            continue
        content = ch_file.read_text(encoding="utf-8-sig")
        rel_path = ch_file.relative_to(MOD_CH)
        issues = check_suspicious(content, str(rel_path))
        all_issues.extend(issues)

    # Check CH Lua scripts
    for _ref_name, _cn_name, ch_name in LUA_PAIRS:
        lua_f = MOD_LUA / ch_name
        if lua_f.exists():
            content = lua_f.read_text(encoding="utf-8-sig")
            issues = check_suspicious(content, ch_name)
            all_issues.extend(issues)

    if all_issues:
        print(f"\n⚠️ 發現 {len(all_issues)} 處可能需要人工檢查：")
        for issue in all_issues:
            print(issue)
    else:
        print("\n✅ 未發現可疑的轉換錯誤")


_ = (
    PREFIX_STRIP_CATEGORIES,
    detect_category,
    parse_lua_translation,
    parse_recorded_media,
)

def cmd_sync_lua():
    """同步 Lua 腳本
    
    策略：
    - CN Lua：直接從 REF 複製
    - CH Lua：從 REF CN 版本轉換，但移除 As1 版本註釋
    - Flx Lua：直接從 REF 複製（雙語通用），新檔案也會建立
    """
    print("=" * 60)
    print("同步 Lua 腳本")
    print("=" * 60)
    
    updated = 0
    
    # 同步 CN Lua
    for ref_name, cn_name, _ch_name in LUA_PAIRS:
        ref_f = REF_LUA / ref_name
        mod_f = MOD_LUA / cn_name
        if ref_f.exists():
            if not mod_f.exists() or sha256(ref_f) != sha256(mod_f):
                mod_f.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ref_f, mod_f)
                print(f"  ✅ CN: {cn_name}")
                updated += 1
    
    # 同步 CH Lua（轉換 + 移除 As1 註釋）
    for ref_name, _cn_name, ch_name in LUA_PAIRS:
        ref_f = REF_LUA / ref_name
        mod_f = MOD_LUA / ch_name
        if not ref_f.exists():
            continue
        
        cn_content = ref_f.read_text(encoding="utf-8-sig")
        
        # OpenCC 轉換
        ch_content = convert_s2twp(cn_content)
        
        # 替換語言後綴（函式名、變數名中的 _CN → _CH）
        ch_content = ch_content.replace("_CN", "_CH")
        
        # 移除 As1 版本註釋（`-- As 1 --` 及其後的說明行）
        lines = ch_content.split("\n")
        cleaned_lines = []
        skip_next = False
        for line in lines:
            if AS1_COMMENT_PATTERN.match(line.strip()):
                skip_next = True
                continue
            if skip_next and line.strip().startswith("--"):
                continue  # 跳過 As1 註釋後的說明行
            skip_next = False
            cleaned_lines.append(line)
        ch_content = "\n".join(cleaned_lines)
        
        # 確保檔案以 newline 結尾（但不要多餘的空行）
        ch_content = ch_content.rstrip("\n") + "\n"
        
        if mod_f.exists():
            old_content = mod_f.read_text(encoding="utf-8-sig")
            if old_content == ch_content:
                continue
        
        mod_f.parent.mkdir(parents=True, exist_ok=True)
        mod_f.write_text(ch_content, encoding="utf-8", newline="\n")
        print(f"  ✅ CH: {ch_name}")
        updated += 1
    
    # 同步 Flx 腳本（允許新增，不再要求 MOD 已存在）
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
        """,
    )
    parser.add_argument(
        "command",
        nargs="?",
        default="compare",
        choices=["compare", "sync-cn", "sync-ch", "sync-lua", "sync-all", "fix-check"],
        help="執行的命令（預設：compare）",
    )
    args = parser.parse_args()
    
    # 驗證路徑
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


if __name__ == "__main__":
    main()
