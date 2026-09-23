# [B42] 繁體/簡體中文完全翻譯

**By Minidoracat × 如一漢化組**

Project Zomboid Build 42 繁體中文 / 簡體中文完全翻譯模組。

[![Steam Workshop](https://img.shields.io/badge/Steam_Workshop-3386633401-blue?logo=steam)](https://steamcommunity.com/sharedfiles/filedetails/?id=3386633401)

## 功能特色

- 繁體中文 / 簡體中文完整支援
- 出生點地圖漢化（城市名稱、世界地圖標籤、中文地圖圖片）
- 世界地圖街道名稱中文化（SP / MP 均支援；只翻文字，保留遊戲的道路資料）
- 地圖選項面板完整翻譯
- 動態命名物品翻譯修復（護照、身分證等）
- 報紙 / 傳單內容漢化（135 張傳單圖片）
- 技能書書名漢化
- 新手引導漢化
- CJK 字元換行處理（無需空格斷行）
- 釣魚視窗、管理面板、除錯選單等 UI 翻譯修補

### 街名翻譯

街名譯文放在 `Translate/{CH,CN}/UI.json` 的 `UI_WorldMapStreet_<原版街名>` 鍵；
不再附帶道路座標副本。官方改線會直接沿用，新街名缺譯時保留英文原名。
本包不依賴 MiniMap；若搭配使用，請更新至 MiniMap 42.20.4-0.27.1 或更新版本，以保留中英文街名搜尋。
Lua／翻譯變更需重新啟動遊戲，既有地圖不會在執行中強制重建。

## MOD 資訊

| 項目 | 值 |
|------|-----|
| **Mod ID** | `CatLangFor42` |
| **Workshop ID** | `3386633401` |
| **支援版本** | Build 42.20.4+ |
| **Mod 版本** | 42.20.4-1.26.1 |

## 專案結構

```
MinidoracatLangFor42/
├── link_workshop.bat              # 開發實體副本同步管理（雙擊啟動）
├── PZ_Test.bat                    # PZ 本地測試啟動器（雙擊啟動）
├── scripts/
│   ├── sync_translations.py    # 翻譯同步工具（uv run）
│   ├── convert_txt_to_json.py  # 格式轉換工具（.txt → .json）
│   ├── pz_translate.py         # 共用翻譯解析模組
│   ├── opencc_fixes.json       # OpenCC 後處理修正字典
│   ├── link_workshop.ps1       # 實體副本同步管理（PowerShell）
│   └── PZ_Test.ps1             # 遊戲測試啟動器（PowerShell）
├── STEAM_DESCRIPTION.md           # Steam 商店頁面描述
└── MOD/MinidoracatLangFor42/      # Workshop 上傳根目錄
    ├── workshop.txt
    ├── preview.png
    └── Contents/mods/MinidoracatLangFor42/42/  ← PZ 模組根目錄
        ├── mod.info
        └── media/
            ├── fonts/             # 中文字型（CH/CN 各 4 DPI）
            ├── lua/
            │   ├── client/        # UI 覆寫腳本（12 個檔案）
            │   ├── shared/Items/   # 動態物品命名修復
            │   └── shared/Translate/
            │       ├── CH/        # 繁體中文翻譯（34 json + 2 txt）
            │       └── CN/        # 簡體中文翻譯（34 json + 2 txt）
            ├── maps/              # 地圖漢化（出生點 + 世界地圖標籤）
            └── textures/          # 傳單圖片（135 張）
```

## 本地開發

### 前置需求

- Windows 10/11
- Project Zomboid Build 42（Steam 版）

### 快速開始

#### 1. 同步到遊戲目錄

首次可用 `link_workshop.bat` → **[1] 同步**，建立 `Zomboid\Workshop\MinidoracatLangFor42` 與 `Zomboid\mods\CatLangFor42` 的實體副本，不需符號連結或 UAC。
日常修改後直接用 `PZ_Test.bat`，啟動前會自動同步。來源、歸檔及執行中保護規則見 `../pz-family-docs/tools.md`。


#### 2. 啟動遊戲測試

雙擊 `PZ_Test.bat` 開啟暗色視窗，選擇連線模式、客戶端／伺服器／組合、客戶端數量及 Debug，再按 **同步並啟動**。首次預設 no-Steam，之後記住本專案上次的選擇；需要只更新副本時按 **只同步**。

Steam 需先登入且最多一個客戶端；no-Steam 可選兩個供 Host／Join。伺服器與客戶端模式必須一致，切換前先正常關服。遊戲路徑可透過環境變數 `PZ_PATH` 覆寫；快取與完整驗證的規則見 `../pz-family-docs/tools.md`。

### 卸載

`link_workshop.bat` → **[2] 歸檔卸載**，移出本 MOD 的受管副本，不刪除原始專案。

## 翻譯流程

### 簡繁轉換（歷史；2026-07-31 起 CH 已凍結）

CH 成品現為人工真相，不再由 OpenCC 再生：全域術語規則見 `scripts/terminology.json`
（`terminology.py` 引擎），新鍵匯入走 `en-diff`／`import-new`（官方繁中底稿＋術語引擎）。
以下為凍結前的產生方式紀錄：

1. 使用 **OpenCC** `s2twp`（簡體 → 繁體台灣用語）進行初步轉換
2. **人工後處理**以下常見錯誤：
   - 干 / 乾 / 幹
   - 发 / 發 / 髮
   - 面 / 麵
   - 系 / 係
   - 里 / 裡
3. 修正規則紀錄在 `scripts/opencc_fixes.json`，新增修正只需編輯此檔案

### 注意事項

- **CH 和 CN 必須同步**：新增或修改翻譯時，繁體（CH）和簡體（CN）目錄必須同時更新
- 翻譯檔編碼：**UTF-8（無 BOM）**
- 翻譯 API：`getText("KEY")` 取得翻譯、`getTextOrNull("KEY")` 取得可能為 nil 的翻譯

## ☕ 支持作者

MOD 永遠免費。喜歡的話可以請我喝杯咖啡，贊助會用在伺服器與 MOD 開發上。

[![Ko-fi](https://raw.githubusercontent.com/Minidoracat/workshop-resources/refs/heads/main/badges/badge_kofi.png)](https://ko-fi.com/minidoracat)

## 問題回報 & 交流

- [Discord 伺服器](https://discord.gg/Gur2V67)
- [Twitch 直播頻道](https://www.twitch.tv/minidoracat)

## 合作

本 MOD 與[統一中文漢化](https://steamcommunity.com/sharedfiles/filedetails/?id=3556544454)進行合作，配合「統一中文漢化 × 如一漢化組」持續更新校對。

### 發布到 Workshop

雙擊 `Publish_Workshop.bat`：先確認 Steam 用戶端已以作者帳號登入（未登入會喚起 Steam 並等你登入後重試），
再選擇更新 MOD 內容（含 `STEAM_CHANGELOG.md` 更新說明）／GIF 封面／簡介／全部；提交後回查 Steam，
任一不符即以非零碼結束。設定在 `scripts/workshop_publish.json`（Workshop ID、簡介語言槽來源、GIF 路徑）。

```
uv run --no-project python -B scripts/publish_workshop.py --mode all --yes       # 自動化／AI；或 content / preview / description
uv run --no-project python -B scripts/publish_workshop.py --mode all --dry-run   # 只檢查、顯示計畫
```

退出碼：`0` 成功／`2` 參數或取消／`3` 未登入、帳號不是擁有者／`4` 前置檢查失敗／`5` 提交失敗／`6` 已提交但回查不符。
網頁動態封面放 `MOD/<資料夾>/workshop/preview.gif`（不在 `Contents/`，不會下載給玩家）；遊戲內上傳器仍用 `preview.png`，
且每次會把網頁封面覆回靜態，需要動態封面時一律改用本工具發布。
