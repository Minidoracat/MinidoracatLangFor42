# /// script
# dependencies = ["opencc-python-reimplemented"]
# requires-python = ">=3.10"
# ///
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
import difflib
import hashlib
import json
import re
import shutil
import sys
from pathlib import Path

import opencc

# ============================================================
# 路徑配置
# ============================================================
PROJECT_ROOT = Path(__file__).resolve().parent.parent

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

# 這些檔案沒有 Lua 表頭（第一行不是 `XXX_CN = {`）
NO_LUA_HEADER = {"streets.txt", "credits.txt", "language.txt"}

# Recorded_Media 是自動生成格式，第一行是 `// Auto-generated file`
AUTO_GENERATED_PREFIX = "// Auto-generated file"

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


def cn_to_ch_filename(name: str) -> str:
    """將 CN 檔名轉換為 CH 檔名"""
    return name.replace("_CN", "_CH")


def cn_to_ch_path(cn_path: Path, cn_dir: Path, ch_dir: Path) -> Path:
    """將 CN 檔案路徑轉換為對應的 CH 路徑"""
    rel = cn_path.relative_to(cn_dir)
    ch_rel = Path(cn_to_ch_filename(str(rel)))
    return ch_dir / ch_rel


def convert_s2twp(text: str) -> str:
    """簡體 → 繁體（台灣用語）轉換 + 後處理修正"""
    result = CONVERTER.convert(text)
    for pattern, replacement, _desc in POST_FIXES:
        result = pattern.sub(replacement, result)
    return result


def convert_translation_header(line: str, from_suffix: str = "CN", to_suffix: str = "CH") -> str:
    """轉換翻譯檔表頭的語言後綴
    
    處理多種格式：
    - `ItemName_CN = {`  → `ItemName_CH = {`
    - `RecipesCN {`      → `RecipesCH {`
    - `ContextMenu_CN = {` → `ContextMenu_CH = {`
    """
    # 格式1: XXX_CN = { 或 XXX_CN {
    line = re.sub(
        rf"^(\w+)_{from_suffix}(\s*=?\s*\{{)",
        rf"\1_{to_suffix}\2",
        line,
    )
    # 格式2: XXXCN { （無底線，如 RecipesCN {）
    line = re.sub(
        rf"^(\w+){from_suffix}(\s+\{{)",
        rf"\1{to_suffix}\2",
        line,
    )
    return line


def convert_cn_to_ch_content(cn_content: str, filename: str) -> str:
    """將 CN 翻譯內容轉換為 CH 版本
    
    處理：
    1. OpenCC s2twp 轉換
    2. 表頭語言後綴替換
    3. 後處理修正
    """
    # OpenCC 轉換（已含後處理修正）
    ch_content = convert_s2twp(cn_content)
    
    # 處理表頭
    lines = ch_content.split("\n")
    
    if filename in NO_LUA_HEADER:
        # streets.txt, credits.txt 等沒有 Lua 表頭，直接返回
        return ch_content
    
    if lines and lines[0].startswith(AUTO_GENERATED_PREFIX):
        # Recorded_Media 等自動生成檔案，只轉換內容即可
        return ch_content
    
    # 標準翻譯檔：轉換第一行的語言後綴
    if lines:
        lines[0] = convert_translation_header(lines[0])
        ch_content = "\n".join(lines)
    
    return ch_content


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
    """找出有差異的翻譯檔案（僅比對 *.txt）"""
    changes: dict[str, dict] = {}
    
    for ref_file in sorted(ref_dir.rglob("*.txt")):
        if not ref_file.is_file():
            continue
        rel = str(ref_file.relative_to(ref_dir))
        mod_file = mod_dir / rel
        
        if not mod_file.exists():
            changes[rel] = {
                "status": "new",
                "ref_path": ref_file,
                "mod_path": mod_file,
                "ref_size": ref_file.stat().st_size,
            }
            continue
        
        if sha256(ref_file) != sha256(mod_file):
            ref_lines = ref_file.read_text(encoding="utf-8-sig").splitlines()
            mod_lines = mod_file.read_text(encoding="utf-8-sig").splitlines()
            changes[rel] = {
                "status": "modified",
                "ref_path": ref_file,
                "mod_path": mod_file,
                "ref_size": ref_file.stat().st_size,
                "mod_size": mod_file.stat().st_size,
                "ref_lines": len(ref_lines),
                "mod_lines": len(mod_lines),
                "line_delta": len(ref_lines) - len(mod_lines),
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
                print(f"  ➕ {name} (新增, {info['ref_size']}B)")
            elif info["status"] == "modified":
                delta = info["line_delta"]
                sign = "+" if delta > 0 else ""
                print(f"  📝 {name} (ref={info['ref_lines']}L mod={info['mod_lines']}L {sign}{delta}L)")
    
    # CN vs CH (line count only)
    print(f"\n📁 REF CN vs MOD CH（簡繁比對，僅行數差異）")
    print("-" * 40)
    for ref_file in sorted(REF_CN.rglob("*.txt")):
        rel = ref_file.relative_to(REF_CN)
        # 跳過不需要 CH 轉換的檔案（如 language.txt）
        if ref_file.name in SKIP_CH_CONVERT:
            continue
        ch_rel = Path(cn_to_ch_filename(str(rel)))
        ch_file = MOD_CH / ch_rel
        if not ch_file.exists():
            print(f"  ❌ {rel} → {ch_rel} (CH 不存在)")
            continue
        ref_lines = len(ref_file.read_text(encoding="utf-8-sig").splitlines())
        ch_lines = len(ch_file.read_text(encoding="utf-8-sig").splitlines())
        if ref_lines != ch_lines:
            delta = ref_lines - ch_lines
            sign = "+" if delta > 0 else ""
            print(f"  📝 {rel} → {ch_rel} (CN={ref_lines}L CH={ch_lines}L {sign}{delta}L)")
    
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
    """同步 CN 翻譯檔：REF CN → MOD CN（直接複製）"""
    print("=" * 60)
    print("同步 CN 翻譯檔（REF CN → MOD CN）")
    print("=" * 60)
    
    changes = find_changed_files(REF_CN, MOD_CN)
    updated = 0
    
    for name, info in sorted(changes.items()):
        if info["status"] in ("new", "modified"):
            ref_path: Path = info["ref_path"]
            mod_path: Path = info.get("mod_path", MOD_CN / name)
            mod_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ref_path, mod_path)
            status = "新增" if info["status"] == "new" else "更新"
            print(f"  ✅ {status}: {name}")
            updated += 1
    
    if updated == 0:
        print("  ℹ️ 沒有需要同步的檔案")
    print(f"\n完成：{updated} 個檔案已同步")


def cmd_sync_ch():
    """同步 CH 翻譯檔：REF CN → OpenCC s2twp → MOD CH
    
    直接遍歷 REF CN 所有檔案進行轉換，不依賴 MOD CN 的差異狀態。
    這樣即使 CN 已經先同步完成，CH 仍能正確更新。
    """
    print("=" * 60)
    print("同步 CH 翻譯檔（REF CN → OpenCC s2twp → MOD CH）")
    print("=" * 60)
    
    updated = 0
    skipped = 0
    unchanged = 0
    all_issues: list[str] = []
    
    for ref_file in sorted(REF_CN.rglob("*.txt")):
        if not ref_file.is_file():
            continue
        
        filename = ref_file.name
        rel = ref_file.relative_to(REF_CN)
        ch_rel = Path(cn_to_ch_filename(str(rel)))
        ch_path = MOD_CH / ch_rel
        
        # language.txt 不轉換（CH 有自己的語言定義）
        if filename in SKIP_CH_CONVERT:
            print(f"  ⏭️ 跳過: {filename} (CH 版本保持不變)")
            skipped += 1
            continue
        
        # 讀取 REF CN 內容並轉換為 CH（utf-8-sig 自動跳過 BOM）
        cn_content = ref_file.read_text(encoding="utf-8-sig")
        ch_content = convert_cn_to_ch_content(cn_content, filename)
        
        # 與現有 CH 檔案比對，只有內容不同才更新
        if ch_path.exists():
            old_ch = ch_path.read_text(encoding="utf-8-sig")
            if old_ch == ch_content:
                unchanged += 1
                continue
            # 顯示 diff 摘要
            old_lines = old_ch.splitlines()
            new_lines = ch_content.splitlines()
            diff = list(difflib.unified_diff(old_lines, new_lines, lineterm="", n=0))
            added = sum(1 for line in diff if line.startswith("+") and not line.startswith("+++"))
            removed = sum(1 for line in diff if line.startswith("-") and not line.startswith("---"))
            print(f"  📝 更新: {ch_rel} (+{added}/-{removed} 行)")
        else:
            ch_path.parent.mkdir(parents=True, exist_ok=True)
            print(f"  ➕ 新增: {ch_rel}")
        
        ch_path.write_text(ch_content, encoding="utf-8")
        updated += 1
        
        # 檢查可疑模式
        issues = check_suspicious(ch_content, str(ch_rel))
        all_issues.extend(issues)
    
    print(f"\n完成：{updated} 個 CH 檔案已更新，{skipped} 個已跳過，{unchanged} 個無變化")
    
    if all_issues:
        print(f"\n⚠️ 發現 {len(all_issues)} 處可能需要人工檢查：")
        for issue in all_issues[:50]:  # 限制輸出
            print(issue)
        if len(all_issues) > 50:
            print(f"  ... 還有 {len(all_issues) - 50} 處")

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
        mod_f.write_text(ch_content, encoding="utf-8")
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


def cmd_fix_check():
    """檢查 OpenCC 轉換常見錯誤"""
    print("=" * 60)
    print("OpenCC 轉換結果檢查（CH 翻譯檔 + CH Lua）")
    print("=" * 60)
    
    all_issues: list[str] = []
    
    # 檢查 CH 翻譯檔
    for ch_file in sorted(MOD_CH.rglob("*.txt")):
        content = ch_file.read_text(encoding="utf-8-sig")
        rel_path = ch_file.relative_to(MOD_CH)
        issues = check_suspicious(content, str(rel_path))
        all_issues.extend(issues)
    
    # 檢查 CH Lua 腳本（從 LUA_PAIRS 衍生）
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
