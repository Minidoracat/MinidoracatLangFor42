# PROJECT KNOWLEDGE BASE

**Generated:** 2026-03-10
**Commit:** 4e21616
**Branch:** master

## OVERVIEW

Project Zomboid Build 42 繁體/簡體中文完全翻譯模組。Mod ID: `CatLangFor42`，Workshop ID: `3386633401`。
核心技術棧：Lua（客戶端 UI 覆寫）+ PZ 翻譯框架（`Translate/*.txt` 鍵值對）+ 自訂中文字型。

## STRUCTURE

```
./
├── docs/                          # 翻譯修正紀錄（OpenCC 錯誤追蹤）
├── STEAM_DESCRIPTION.md           # Steam 商店頁面描述（BBCode 格式）
└── MOD/MinidoracatLangFor42/      # Workshop 上傳根目錄
    ├── workshop.txt               # Workshop 元資料
    └── Contents/mods/MinidoracatLangFor42/42/  # ← PZ 模組根目錄
        ├── mod.info               # 模組識別（版本 42-1.1.0，最低 42.0.0）
        └── media/
            ├── fonts/             # 中文字型（CH/CN 各 4 DPI 縮放 1x-4x）
            ├── lua/
            │   ├── client/        # Lua UI 覆寫腳本（10 個檔案）
            │   └── shared/Translate/
            │       ├── CH/        # 繁體中文翻譯（37 檔）
            │       └── CN/        # 簡體中文翻譯（37 檔，CH 完全鏡像）
            ├── maps/Riverside, KY/  # 地圖漢化（出生點 + 世界地圖標籤）
            └── textures/printMedia/FlyerPics/  # 傳單圖片（135 張）
```

> **路徑簡寫**：以下用 `MOD_ROOT` 代表 `MOD/MinidoracatLangFor42/Contents/mods/MinidoracatLangFor42/42`

## WHERE TO LOOK

| 任務 | 位置 | 備註 |
|------|------|------|
| 新增/修改翻譯文字 | `MOD_ROOT/media/lua/shared/Translate/{CH,CN}/` | CH 和 CN 必須同步修改 |
| UI 行為修補 | `MOD_ROOT/media/lua/client/` | 覆寫原版遊戲 Lua 函式 |
| 字型配置 | `MOD_ROOT/media/fonts/{CH,CN}/fonts.txt` | 字型名稱映射 |
| 地圖標籤翻譯 | `MOD_ROOT/media/maps/Riverside, KY/worldmap-annotations.lua` | 包含所有城市標籤（非僅 Riverside） |
| 城市名稱/描述 | `Translate/{CH,CN}/{城市名, KY}/title.txt` + `description.txt` | 5 個城市 |
| 翻譯修正紀錄 | `docs/translation-fixes.md` | OpenCC 轉換錯誤追蹤 |
| Workshop 上傳設定 | `MOD/MinidoracatLangFor42/workshop.txt` | 手動透過 PZ 內建工具上傳 |
| Mod 版本更新 | `MOD_ROOT/mod.info` | `modversion` 格式：`{遊戲版本}-{Mod版本}` |

## INITIALIZATION FLOW

```
1. mod.info 被 PZ 引擎讀取
2. fonts/{CH,CN}/fonts.txt → 字型替換（最早生效）
3. shared/Translate/{CH,CN}/*.txt → 翻譯字串表載入
4. client/*.lua → UI 覆寫腳本載入（立即執行）
5. Events.OnGameStart → MapLabel_Flx.lua 清理非翻譯地圖標籤
```

唯一的事件掛鉤：`MapLabel_Flx.lua` 第 45 行 `Events.OnGameStart.Add(MapLabelEdit.applyChanges)`

## CONVENTIONS

### 翻譯檔格式
```lua
ItemName_CH = {
    -- Additional Translation --
ItemName_Base.CoffeeMachine = "咖啡機",
}
```
- 第 1 行：`{類別}_{語言} = {`
- 第 2 行：固定 `-- Additional Translation --`
- 鍵格式：`{類別}_{模組}.{物件ID} = "翻譯",`
- 編碼：UTF-8（無 BOM）

### Lua 覆寫模式
```lua
-- 標準：保存原始函式再覆寫
local _orig = ISBuildWindowHeader.createChildren
function ISBuildWindowHeader:createChildren()
    _orig(self)
    -- 中文化邏輯
end
```

### 翻譯 API
- `getText("KEY")` — 取得翻譯（保證有值）
- `getTextOrNull("KEY")` — 取得翻譯（可能 nil，用於 fallback）

### 檔案命名後綴
| 後綴 | 用途 | 範例 |
|------|------|------|
| `_CH` | 繁體中文 UI 修補 | `FishWindow_CH.lua` |
| `_Flx` | 功能修正（雙語通用） | `MapLabel_Flx.lua` |

### 簡繁轉換工具鏈
- **OpenCC** `s2twp`（簡體→繁體台灣用語）
- 轉換後**必須人工後處理**：干/乾/幹、发/發/髮、面/麵、系/係、里/裡
- 所有修正**必須記錄**到 `docs/translation-fixes.md`

## ANTI-PATTERNS (THIS PROJECT)

- **CH/CN 不同步**：新增或修改翻譯時，CH 和 CN 目錄必須同時更新
- **覆寫不保存原始函式**：`ISRichTextPanel_CH.lua` 和 `ModInfoPanel_FIx.lua` 直接覆寫全域函式而未保存原始版本，新增覆寫時應採用 `local _orig = ...` 模式
- **硬編碼路徑**：`MapSpawnSelect_Flx.lua:58` 使用 `\\` Windows 路徑分隔符，Linux 不相容
- **模組 ID 前置反斜線**：`MapSpawnSelect_Flx.lua:93` 的 `"\\CatLangFor42"` 格式需注意跨平台
- **字型根目錄殘留**：`media/fonts/` 根層有 `zomboid*.fnt/png` 檔案，可能與子目錄 `CH/CN` 字型衝突

## KNOWN ISSUES

| 問題 | 位置 | 說明 |
|------|------|------|
| 檔名拼寫錯誤 | `ModInfoPanel_FIx.lua` | `FIx` 應為 `Fix`，Linux 大小寫敏感 |
| FIXME: 地圖載入順序 | `MapSpawnSelect_Flx.lua:65,67` | 多地圖初始化順序影響結果 |
| FishWindow 無事件保護 | `FishWindow_CH.lua` | 載入時直接存取 `PZAPI.UI.FishWindow`，若 API 未就緒會報錯 |
| worldmap-annotations 位置 | `maps/Riverside, KY/` | 放在 Riverside 目錄但包含所有城市標籤 |
| 註解掉的 Joypad 邏輯 | `MainScreen_CH.lua:17-28` | 被 `--[[...--]]` 停用，待確認是否刻意 |

## COMMANDS

```bash
# 無 CI/CD、無建置腳本、無測試框架
# Workshop 上傳：透過 PZ 遊戲內建 Workshop 工具手動上傳
# 翻譯流程：OpenCC s2twp 轉換 → 人工校對 → 記錄修正到 docs/
```

## LUA FILES QUICK REFERENCE

| 檔案 | 用途 |
|------|------|
| `ISRichTextPanel_CH.lua` | CJK 字元換行處理（移除空格依賴，167 行） |
| `MapSpawnSelect_Flx.lua` | 出生點地圖選擇覆寫（指定 Riverside 圖像金字塔，95 行） |
| `MapLabel_Flx.lua` | 清理非 `MapLabel_*` 格式的地圖標籤（45 行） |
| `MainScreen_CH.lua` | 主選單教學啟動覆寫（31 行） |
| `ISWidgetRecipeCategories_CH.lua` | 配方分類翻譯（14 行） |
| `ISMapDefinitions_CH.lua` | 過濾 Muldraugh 街道資料避免衝突（14 行） |
| `ISBuildWindowHeader_CH.lua` | 建造視窗標題翻譯（11 行） |
| `FishWindow_CH.lua` | 釣魚視窗標籤翻譯（10 行） |
| `ModInfoPanel_FIx.lua` | Mod 資訊面板修復（3 行） |

## NOTES

- **791 個檔案**，其中 ~119K 行翻譯文字、~1.2K 行 Lua、135 張傳單圖片、253 個字型檔
- Git LFS 追蹤 `.rar` 檔案（地圖圖像金字塔）
- 版本命名格式：`{PZ版本}-{Mod主版本}.{次版本}.{修訂}` (如 `42-1.1.0`)
- 與「統一中文漢化 × 如一漢化組」合作專案
