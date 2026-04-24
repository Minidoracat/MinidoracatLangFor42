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
# language.txt: CH 版本有自己的語言定義，不能從 CN 轉換
SKIP_CH_CONVERT = {"language.txt"}

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

    # Process .txt translation files (legacy format)
    for ref_file in sorted(REF_CN.glob("*.txt")):
        if not ref_file.is_file():
            continue
        filename = ref_file.name

        if filename in PZ_SKIP_FILES:
            # language.txt, credits.txt — copy as-is
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

    # Process .json translation files (new format)
    for ref_file in sorted(REF_CN.glob("*.json")):
        if not ref_file.is_file():
            continue
        filename = ref_file.name
        json_name = filename
        mod_file = MOD_CN / json_name

        ref_data = read_translation(ref_file)

        # 保留 MOD 中有但 REF 中沒有的自訂 keys
        if mod_file.exists():
            mod_data = read_translation(mod_file)
            extra_keys = OrderedDict(
                (k, v) for k, v in mod_data.items() if k not in ref_data
            )
            if extra_keys:
                if json_name == "Print_Media.json":
                    for k in list(extra_keys):
                        err = _validate_print_media_info(k, extra_keys[k])
                        if err:
                            print(f"  ⚠️  移除截斷的自訂 key: {k} ({err})")
                            del extra_keys[k]
                merged = OrderedDict(ref_data)
                merged.update(extra_keys)
                ref_data = merged
        else:
            mod_data = None

        # Compare with existing
        if mod_data is not None:
            if mod_data == ref_data:
                continue
            added = len(set(ref_data) - set(mod_data))
            removed = len(set(mod_data) - set(ref_data))
            print(f"  📝 更新: {json_name} ({len(ref_data)} keys, +{added}/-{removed})")
        else:
            print(f"  ➕ 新增: {json_name} ({len(ref_data)} keys)")

        write_translation_json(ref_data, mod_file)
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


def cmd_sync_ch():
    """同步 CH 翻譯檔：REF CN → OpenCC s2twp → MOD CH .json"""
    print("=" * 60)
    print("同步 CH 翻譯檔（REF CN → OpenCC s2twp → MOD CH .json）")
    print("=" * 60)

    updated = 0
    skipped = 0
    unchanged = 0
    all_issues: list[str] = []

    # Process .txt translation files (legacy format)
    for ref_file in sorted(REF_CN.glob("*.txt")):
        if not ref_file.is_file():
            continue

        filename = ref_file.name

        # language.txt: CH has its own definition, don't convert
        if filename in SKIP_CH_CONVERT:
            print(f"  ⏭️ 跳過: {filename} (CH 版本保持不變)")
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
        ],
        help="執行的命令（預設：compare）",
    )
    parser.add_argument(
        "--pz-path",
        type=Path,
        default=None,
        help="vanilla Project Zomboid 安裝路徑（gen-vehicle-map / gen-radio-map 使用）",
    )
    args = parser.parse_args()

    if args.command not in {"gen-vehicle-map", "gen-radio-map"}:
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


if __name__ == "__main__":
    main()
