# PROJECT KNOWLEDGE BASE

**Generated:** 2026-03-10
**Commit:** 8c6b397
**Branch:** master

## OVERVIEW

Project Zomboid Build 42 繁體/簡體中文完全翻譯模組。Mod ID: `CatLangFor42`，Workshop ID: `3386633401`。
核心技術棧：Lua（客戶端 UI 覆寫）+ PZ 翻譯框架（`Translate/*.txt` 鍵值對）+ 自訂中文字型。
合作專案：與「統一中文漢化 × 如一漢化組」。

## STRUCTURE

```
./
├── link_workshop.bat              # Workshop 符號連結啟動器（雙擊）
├── PZ_Test.bat                    # 遊戲測試啟動器（雙擊）
├── README.md                      # 專案說明
├── STEAM_DESCRIPTION.md           # Steam 商店頁面描述（BBCode）
├── scripts/
│   ├── link_workshop.ps1          # 符號連結管理（掛載/卸載 Workshop 目錄）
│   └── PZ_Test.ps1                # 遊戲啟動器（客戶端/伺服器/多人，需改 $PZ_PATH）
├── docs/
│   └── translation-fixes.md       # OpenCC 轉換錯誤修正紀錄（61 處）
├── translation-reference/         # 外部簡體翻譯參考倉庫（gitignored，有獨立 .git）
└── MOD/MinidoracatLangFor42/      # Workshop 上傳根目錄
    ├── workshop.txt               # Workshop 元資料
    ├── preview.png                # 預覽圖
    └── Contents/mods/MinidoracatLangFor42/42/  # ← PZ 模組根目錄
        ├── mod.info               # 模組識別（版本 42-1.1.0，最低 42.0.0）
        └── media/
            ├── fonts/
            │   ├── CH/            # 繁體中文字型（fonts.txt + 1x~4x DPI）
            │   ├── CN/            # 簡體中文字型（與 CH 同結構同內容）
            │   └── zomboid*.fnt/png  # ⚠️ 根目錄殘留字型（42 檔，潛在衝突）
            ├── lua/
            │   ├── client/        # Lua UI 覆寫腳本（9 個檔案）
            │   │   ├── ISUI/      #   ISRichTextPanel_CH, Maps/ISMapDefinitions_CH
            │   │   └── OptionScreens/  #   MainScreen_CH, MapSpawnSelect_Flx
            │   └── shared/Translate/
            │       ├── CH/        # 繁體中文翻譯（32 txt + 5 城市目錄）
            │       └── CN/        # 簡體中文翻譯（CH 完全鏡像）
            ├── maps/Riverside, KY/  # 地圖漢化（出生點 + 世界地圖標籤 708 行）
            └── textures/printMedia/FlyerPics/  # 傳單圖片（135 張）
```

> **路徑簡寫**：以下用 `MOD_ROOT` 代表 `MOD/MinidoracatLangFor42/Contents/mods/MinidoracatLangFor42/42`

## WHERE TO LOOK

| 任務 | 位置 | 備註 |
|------|------|------|
| 新增/修改翻譯文字 | `MOD_ROOT/media/lua/shared/Translate/{CH,CN}/` | CH 和 CN 必須同步修改 |
| UI 行為修補 | `MOD_ROOT/media/lua/client/` | 含子目錄 ISUI/、OptionScreens/ |
| 字型配置 | `MOD_ROOT/media/fonts/{CH,CN}/fonts.txt` | CH/CN 內容完全相同，修改需同步 |
| 地圖標籤翻譯 | `MOD_ROOT/media/maps/Riverside, KY/worldmap-annotations.lua` | 包含所有城市標籤（非僅 Riverside） |
| 城市名稱/描述 | `Translate/{CH,CN}/{城市名, KY}/title.txt` + `description.txt` | 5 個城市 |
| 翻譯修正紀錄 | `docs/translation-fixes.md` | OpenCC 轉換錯誤追蹤（61 處修正） |
| Workshop 上傳設定 | `MOD/MinidoracatLangFor42/workshop.txt` | 手動透過 PZ 內建工具上傳 |
| Mod 版本更新 | `MOD_ROOT/mod.info` | `modversion` 格式：`{遊戲版本}-{Mod版本}` |
| 本地開發環境 | `scripts/link_workshop.ps1` | Workshop 符號連結管理（掛載/卸載） |
| 遊戲測試 | `scripts/PZ_Test.ps1` | 客戶端/伺服器/多人啟動（首次需改 `$PZ_PATH`） |
| 翻譯參考來源 | `translation-reference/` | 簡體中文原始翻譯（gitignored，獨立 .git） |

## INITIALIZATION FLOW

```
1. mod.info 被 PZ 引擎讀取
2. fonts/{CH,CN}/fonts.txt → 字型替換（引擎層，最早生效）
   └─ 22 個字型槽位映射到 3 個中文字型（Small/Medium/Large）
   └─ 根據 DPI 縮放載入 1x/2x/3x/4x 對應字型
3. shared/Translate/{CH,CN}/*.txt → 翻譯字串表載入
4. client/*.lua → UI 覆寫腳本載入（立即執行，無特定順序保證）
   ├─ 安全覆寫型：ISBuildWindowHeader, ISWidgetRecipeCategories, ISMapDefinitions（保存 _orig）
   ├─ 直接覆寫型：ISRichTextPanel, MainScreen, ModInfoPanel（⚠️ 無 _orig，破壞性）
   ├─ 條件覆寫型：MapSpawnSelect（檢查 mod ID 後才覆寫）
   └─ 危險型：FishWindow（⚠️ 無保護直接存取 PZAPI）
5. Events.OnGameStart → MapLabel_Flx.lua 清理非翻譯地圖標籤
```

唯一的事件掛鉤：`MapLabel_Flx.lua` 第 45 行 `Events.OnGameStart.Add(MapLabelEdit.applyChanges)`

## CONVENTIONS

### 翻譯檔格式

存在 6 種格式變體。最常見的標準格式：
```lua
ItemName_CH = {
    -- Additional Translation --
ItemName_Base.CoffeeMachine = "咖啡機",
}
```
- 第 1 行：`{類別}_{語言} = {`（或 `{類別}_{語言} {`）
- 第 2 行：`-- Additional Translation --`（11 個檔案有，15 個無）
- 鍵格式：`{類別}_{模組}.{物件ID} = "翻譯",`
- 編碼：UTF-8（無 BOM）
- 特殊檔案：`streets.txt`（XML）、`Recorded_Media`（自動生成，無 Lua 表）、`language.txt`、`credits.txt`

### Lua 覆寫模式
```lua
-- 標準：保存原始函式再覆寫（新增覆寫時必須使用此模式）
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

### 開發工具
- `link_workshop.bat` → 雙擊啟動，選擇掛載/卸載 Workshop 符號連結
- `PZ_Test.bat` → 雙擊啟動，選擇測試模式（客戶端/伺服器/多人）
- 首次使用需修改 `scripts/PZ_Test.ps1` 頂部 `$PZ_PATH` 為本地 PZ 安裝路徑

## ANTI-PATTERNS (THIS PROJECT)

- **CH/CN 不同步**：新增或修改翻譯時，CH 和 CN 目錄必須同時更新
- **覆寫不保存原始函式**：`ISRichTextPanel_CH.lua`、`ModInfoPanel_FIx.lua`、`MainScreen_CH.lua` 直接覆寫全域函式而未保存原始版本，新增覆寫時應採用 `local _orig = ...` 模式
- **硬編碼路徑**：`MapSpawnSelect_Flx.lua:58` 使用 `\\` Windows 路徑分隔符，Linux 不相容
- **模組 ID 前置反斜線**：`MapSpawnSelect_Flx.lua:93` 的 `"\\CatLangFor42"` 格式需注意跨平台
- **字型根目錄殘留**：`media/fonts/` 根層有 42 個 `zomboid*.fnt/png` 檔案，可能與子目錄 `CH/CN` 字型衝突
- **fonts.txt 同步**：CH 和 CN 的 `fonts.txt` 內容完全相同，修改時必須同步

## KNOWN ISSUES

| 問題 | 位置 | 說明 |
|------|------|------|
| 檔名拼寫錯誤 | `ModInfoPanel_FIx.lua` | `FIx` 應為 `Fix`，Linux 大小寫敏感 |
| 翻譯表頭 ID 錯誤 | `Recipes_CH.txt`、`RecipeGroups_CH.txt` | CH 檔案表頭寫成 `CN`（`RecipesCN {`） |
| 翻譯值缺少引號 | `UI_CH.txt:11` | `= 顯示隱藏建築面板,` 缺少引號包裝 |
| FIXME: 地圖載入順序 | `MapSpawnSelect_Flx.lua:65,67` | 多地圖初始化順序影響結果 |
| FishWindow 無事件保護 | `FishWindow_CH.lua` | 載入時直接存取 `PZAPI.UI.FishWindow`，若 API 未就緒會報錯 |
| worldmap-annotations 位置 | `maps/Riverside, KY/` | 放在 Riverside 目錄但包含所有城市標籤 |
| 註解掉的 Joypad 邏輯 | `MainScreen_CH.lua:17-28` | 被 `--[[...--]]` 停用，待確認是否刻意 |
| CN language.txt 格式差異 | `Translate/CN/language.txt` | 有尾隨空格和多餘空行，CH 版本無 |

## COMMANDS

```bash
# 無 CI/CD、無建置腳本、無測試框架

# 本地開發
# 1. 掛載：雙擊 link_workshop.bat → 選 [1]（建立 %UserProfile%\Zomboid\Workshop 符號連結）
# 2. 測試：雙擊 PZ_Test.bat → 選模式（客戶端/伺服器/多人）
# 3. 卸載：雙擊 link_workshop.bat → 選 [2]

# Workshop 上傳：透過 PZ 遊戲內建 Workshop 工具手動上傳
# 翻譯流程：OpenCC s2twp 轉換 → 人工校對 → 記錄修正到 docs/
```

## LUA FILES QUICK REFERENCE

| 檔案 | 路徑 | 行數 | 覆寫模式 | 用途 |
|------|------|------|----------|------|
| `ISRichTextPanel_CH.lua` | `ISUI/` | 167 | ⚠️ 直接覆寫 | CJK 字元換行（`#token==3` 判斷 UTF-8） |
| `MapSpawnSelect_Flx.lua` | `OptionScreens/` | 94 | 條件覆寫 | 出生點地圖選擇（指定 Riverside 圖像金字塔） |
| `MapLabel_Flx.lua` | `/` | 44 | ✅ 事件掛鉤 | 清理非 `MapLabel_*` 格式地圖標籤 |
| `MainScreen_CH.lua` | `OptionScreens/` | 30 | ⚠️ 直接覆寫 | 主選單教學啟動覆寫 |
| `ISWidgetRecipeCategories_CH.lua` | `/` | 14 | ✅ _orig | 配方分類翻譯 |
| `ISMapDefinitions_CH.lua` | `ISUI/Maps/` | 13 | ✅ _orig | 過濾 Muldraugh 街道資料避免衝突 |
| `ISBuildWindowHeader_CH.lua` | `/` | 11 | ✅ _orig | 建造視窗標題翻譯 |
| `FishWindow_CH.lua` | `/` | 10 | ⚠️ 無保護 | 釣魚視窗標籤翻譯 |
| `ModInfoPanel_FIx.lua` | `/` | 2 | ⚠️ 直接覆寫 | Mod 資訊面板修復 |

路徑相對於 `MOD_ROOT/media/lua/client/`。`ISRichTextPanel_CH.lua` 為最高維護風險（PZ 更新 `paginate()` 時需手動同步）。

## NOTES

- **~798 個追蹤檔案**：~120K 行翻譯文字、385 行 Lua（9 檔）、414 行 PowerShell（2 檔）、135 張傳單圖片、~550 個字型檔
- Git LFS 追蹤 `.rar` 檔案（唯一：`spawnSelectImagePyramid.rar` 地圖圖像金字塔）
- 版本命名格式：`{PZ版本}-{Mod主版本}.{次版本}.{修訂}` (如 `42-1.1.0`)
- `translation-reference/` 為外部參考倉庫（有獨立 `.git`），被 `.gitignore` 忽略
- 翻譯行數 Top 3：RadioData（13K 行）、streets（8.7K 行）、IG_UI（7.8K 行）
