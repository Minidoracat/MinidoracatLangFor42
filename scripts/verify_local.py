# -*- coding: utf-8 -*-
"""LangFor42 專屬的檢查：scripts/verify_mod.py 第 19 項會呼叫；單獨跑 `python scripts/verify_local.py`。
2026-11-26 verify_mod.py 換成家族模板時，從舊副本原樣搬來（門檻與掃描範圍不變）：

 12. 地圖註記鍵覆蓋         — worldmap-annotations.lua 以 addUntranslatedText 引用的
                           MapLabel_* 鍵必須存在於各語系 MapLabel.json。引擎按前綴
                           路由到 per-file map（Translator.getTextInternal：
                           MapLabel_ → mapLabel，僅由各 mod／本體的 MapLabel.json
                           填充；跨 mod 同檔名合併、不跨檔名），鍵放錯檔照樣裸 key。
                           56 個引用鍵有 42 個官方 EN 亦無（39 個 POI＋3 個森林），
                           miss 時 fallback 無值可退，直接畫裸 key。4e9ce58 死鍵清理
                           以「官方 EN 有無」判死鍵誤刪其中 39 鍵，隨 1.15.1 上線
                           當日玩家即於 Steam 回報（後提交 GitHub issue #2）
 13. 街名翻譯資料閘門       — 委派 scripts/test_streets_sync.py：官方街名文字鍵全覆蓋、
                           CH/CN 鍵集一致、譯值有效，MOD 樹不再夾帶街道 XML 副本。
 14. 街名載入行為測試       — 委派 scripts/test_map_streets.lua：顯示譯名、原名與
                           split 還原、重入／語系／失敗清理；不清已顯示玩家地圖。
 15. 印刷品分語系圖片       — CH/CN 的 Print_Media 指向 printMedia/<類別>_CH|_CN/ 下的圖要存在、語系對、沒有多餘檔
"""
import json
import os
import re
import shutil
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

passed, failed, skipped = [], [], []

# 豁免清單與 verify_mod.py 共用：scripts/verify_ignore.txt，每行一個子字串樣式（# 開頭為註解）。
IGNORE_PATTERNS = []
_ign = os.path.join(os.path.dirname(os.path.abspath(__file__)), "verify_ignore.txt")
if os.path.isfile(_ign):
    with open(_ign, encoding="utf-8") as _fh:
        for _line in _fh:
            _line = _line.strip()
            if _line and not _line.startswith("#"):
                IGNORE_PATTERNS.append(_line)


def ok(label):
    passed.append(label)
    print(f"  PASS  {label}")


def fail(label, details=None):
    details = details or []
    kept = [d for d in details if not any(p in d for p in IGNORE_PATTERNS)]
    waived = [d for d in details if any(p in d for p in IGNORE_PATTERNS)]
    for d in waived:
        print(f"  WAIVE {label}: {d}（verify_ignore.txt 豁免）")
    if not kept:
        if waived:
            ok(f"{label}（{len(waived)} 筆豁免）")
        else:
            ok(label)
        return
    failed.append(label)
    print(f"  FAIL  {label}")
    for d in kept:
        print(f"        {d}")


def skip(label, why):
    skipped.append(label)
    print(f"  SKIP  {label} — {why}")


def find_media():
    hits = []
    mod_root = os.path.join(REPO, "MOD")
    if os.path.isdir(mod_root):
        for folder in os.listdir(mod_root):
            p = os.path.join(mod_root, folder, "Contents", "mods")
            if not os.path.isdir(p):
                continue
            for inner in os.listdir(p):
                media = os.path.join(p, inner, "42", "media")
                if os.path.isdir(media):
                    hits.append(media)
    return hits


MEDIA_DIRS = find_media()
if not MEDIA_DIRS:
    print("找不到 MOD/*/Contents/mods/*/42/media，中止")
    sys.exit(2)

# ---- 12. 地圖註記鍵覆蓋 ----
# 引擎按前綴路由到 per-file map（Translator.getTextInternal：MapLabel_ →
# mapLabel，該 map 僅由 Translate/<lang>/MapLabel.json 填充；跨 mod 同檔名
# 合併、不跨檔名）——鍵搬去別的 json 遊戲內照樣裸 key，故限定 MapLabel.json。
ANNO_LABEL = "地圖註記鍵覆蓋（worldmap-annotations → MapLabel.json）"
anno_details, anno_files = [], 0
for m in MEDIA_DIRS:
    maps_root = os.path.join(m, "maps")
    troot = os.path.join(m, "lua", "shared", "Translate")
    if not (os.path.isdir(maps_root) and os.path.isdir(troot)):
        continue
    refs = set()
    for base, _, files in os.walk(maps_root):
        for name in files:
            if name != "worldmap-annotations.lua":
                continue
            anno_files += 1
            rel = os.path.relpath(os.path.join(base, name), REPO)
            with open(os.path.join(base, name), encoding="utf-8") as fh:
                src = fh.read()
            calls = len(re.findall(r"addUntranslatedText\s*\(", src))
            found = re.findall(r"""addUntranslatedText\s*\(\s*(['"])([^'"]+)\1""", src)
            if len(found) != calls:
                anno_details.append(f"{rel}: {calls} 處呼叫僅擷取 {len(found)} 鍵——掃描失明（字串引號形式漂移？）")
            refs |= {k for _, k in found}
    for k in sorted(refs):
        # MapLabel_Flx.lua 只保留 ^MapLabel_[^%s<>]+$ 的非玩家符號，其餘刪除——
        # 非此前綴的引用鍵會被靜默移除（標籤消失，比裸 key 更難查）
        if not re.fullmatch(r"MapLabel_[^\s<>]+", k):
            anno_details.append(f"引用鍵 {k} 非 MapLabel_ 前綴——會被 MapLabel_Flx.lua 過濾刪除")
    if not refs:
        continue
    for l in sorted(d for d in os.listdir(troot) if os.path.isdir(os.path.join(troot, d))):
        p = os.path.join(troot, l, "MapLabel.json")
        try:
            with open(p, encoding="utf-8") as fh:
                data = json.load(fh)
        except Exception:
            data = {}   # 缺檔/壞檔 ⇒ 引用鍵全數列缺（壞檔另由 verify_mod.py「翻譯 JSON 可解析」標出）
        anno_details.extend(f"{l} 缺 {k}" for k in sorted(refs - set(data)))
        for k in sorted(refs & set(data)):
            v = data[k]
            # 空值/非字串/值＝鍵名 都等同缺譯——引擎照樣畫空白或裸 key
            if not isinstance(v, str) or not v.strip() or v.strip() == k:
                anno_details.append(f"{l} 的 {k} 譯值無效（空值或等於鍵名）")
if anno_files == 0:
    skip(ANNO_LABEL, "未發現 worldmap-annotations.lua")
elif anno_details:
    fail(ANNO_LABEL, anno_details)
else:
    ok(ANNO_LABEL)

# ---- 13. 街名翻譯資料閘門 ----
# 不再同步官方幾何；只驗文字覆蓋與語系一致性，拒絕重新夾帶 XML 道路副本。
STREETS_LABEL = "街名翻譯資料閘門（test_streets_sync）"
_streets_test = os.path.join(os.path.dirname(os.path.abspath(__file__)), "test_streets_sync.py")
if not os.path.isfile(_streets_test):
    fail(STREETS_LABEL, ["scripts/test_streets_sync.py 不存在"])
else:
    _r = subprocess.run([sys.executable, _streets_test], capture_output=True, text=True, encoding="utf-8", errors="replace")
    if _r.returncode == 0:
        ok(STREETS_LABEL)
    elif _r.returncode == 2:
        skip(STREETS_LABEL, (_r.stdout or "").strip().splitlines()[-1] if _r.stdout else "官方檔不存在")
    else:
        # 非零退出無條件 FAIL：details 為空時（如未捕捉例外只寫 stderr）補
        # stderr 尾行與 return code，避免 fail() 的空 details 分支反向 ok()
        _details = [l for l in (_r.stdout or "").strip().splitlines() if l][:12]
        if not _details:
            _details = [l for l in (_r.stderr or "").strip().splitlines() if l][-6:]
        _details.append(f"test_streets_sync.py exit code {_r.returncode}")
        fail(STREETS_LABEL, _details)

# ---- 14. 街名載入行為測試 ----
LUA_STREETS_LABEL = "街名載入行為（test_map_streets.lua）"
_lua = shutil.which("lua")
_lua_streets_test = os.path.join(os.path.dirname(os.path.abspath(__file__)), "test_map_streets.lua")
if not os.path.isfile(_lua_streets_test):
    fail(LUA_STREETS_LABEL, ["scripts/test_map_streets.lua 不存在"])
elif not _lua:
    skip(LUA_STREETS_LABEL, "PATH 沒有 lua")
else:
    _r = subprocess.run([_lua, _lua_streets_test], cwd=REPO,
                        capture_output=True, text=True, encoding="utf-8", errors="replace")
    if _r.returncode == 0 and _r.stdout.strip():
        ok(LUA_STREETS_LABEL)
    else:
        _details = (_r.stdout or _r.stderr or "測試無輸出").strip().splitlines()[-8:]
        _details.append(f"test_map_streets.lua exit code {_r.returncode}")
        fail(LUA_STREETS_LABEL, _details)

# ---- 15. 印刷品分語系圖片 ----
# CH/CN 的 Print_Media 各自指向 printMedia/<類別>_CH|_CN/ 下的中文圖；打錯檔名、
# 漏放檔案或指到另一語系的資料夾，遊戲內會變成空白或看到錯的字體，離線看不出來。
# 官方自己就有指向不存在檔案的佔位路徑（TEST.png 等），所以只驗本包的分語系資料夾。
PM_LABEL = "印刷品分語系圖片（Print_Media → printMedia/*_CH|_CN）"
pm_details, pm_refs_total = [], 0
_pm_re = re.compile(r"texture:\s*(media/textures/printMedia/([A-Za-z]+)_(CH|CN)/[^,>]+?\.png)")
for m in MEDIA_DIRS:
    troot = os.path.join(m, "lua", "shared", "Translate")
    pm_root = os.path.join(m, "textures", "printMedia")
    base42 = os.path.dirname(m)
    for lang in ("CH", "CN"):
        p = os.path.join(troot, lang, "Print_Media.json")
        if not os.path.isfile(p):
            continue
        with open(p, encoding="utf-8") as fh:
            values = [v for v in json.load(fh).values() if isinstance(v, str)]
        used = set()
        for v in values:
            for path, _cat, ref_lang in _pm_re.findall(v):
                pm_refs_total += 1
                used.add(path)
                if ref_lang != lang:
                    pm_details.append(f"{lang}/Print_Media.json 指到 {ref_lang} 的圖：{path}")
                if not os.path.isfile(os.path.join(base42, path)):
                    pm_details.append(f"{lang}/Print_Media.json 引用的圖不存在：{path}")
        if os.path.isdir(pm_root):
            for d in sorted(os.listdir(pm_root)):
                if not d.endswith(f"_{lang}"):
                    continue
                for name in sorted(os.listdir(os.path.join(pm_root, d))):
                    path = f"media/textures/printMedia/{d}/{name}"
                    if path not in used:
                        pm_details.append(f"{path} 沒有被 {lang}/Print_Media.json 引用（多餘檔案）")
if pm_details:
    fail(PM_LABEL, pm_details)
elif pm_refs_total == 0:
    skip(PM_LABEL, "Print_Media 尚未引用分語系圖片")
else:
    ok(PM_LABEL)

sys.exit(1 if failed else 0)
