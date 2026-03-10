# [B42] 繁體/簡體中文完全翻譯

**By Minidoracat × 如一漢化組**

Project Zomboid Build 42 繁體中文 / 簡體中文完全翻譯模組。

[![Steam Workshop](https://img.shields.io/badge/Steam_Workshop-3386633401-blue?logo=steam)](https://steamcommunity.com/sharedfiles/filedetails/?id=3386633401)

## 功能特色

- 繁體中文 / 簡體中文完整支援
- 出生點地圖漢化（城市名稱、世界地圖標籤）
- 報紙 / 傳單內容漢化（135 張傳單圖片）
- 技能書書名漢化
- 新手引導漢化
- CJK 字元換行處理（無需空格斷行）
- 配方分類、建造視窗、釣魚視窗等 UI 翻譯修補

## MOD 資訊

| 項目 | 值 |
|------|-----|
| **Mod ID** | `CatLangFor42` |
| **Workshop ID** | `3386633401` |
| **支援版本** | Build 42.13.1+ |
| **Mod 版本** | 42-1.1.0 |

## 專案結構

```
MinidoracatLangFor42/
├── link_workshop.bat              # Workshop 符號連結管理（雙擊啟動）
├── PZ_Test.bat                    # PZ 本地測試啟動器（雙擊啟動）
├── scripts/
│   ├── sync_translations.py    # 翻譯同步工具（uv run）
│   ├── opencc_fixes.json       # OpenCC 後處理修正字典
│   ├── link_workshop.ps1       # 符號連結管理腳本（PowerShell）
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
            │   ├── client/        # UI 覆寫腳本（10 個檔案）
            │   └── shared/Translate/
            │       ├── CH/        # 繁體中文翻譯（37 檔）
            │       └── CN/        # 簡體中文翻譯（37 檔）
            ├── maps/              # 地圖漢化（出生點 + 世界地圖標籤）
            └── textures/          # 傳單圖片（135 張）
```

## 本地開發

### 前置需求

- Windows 10/11
- Project Zomboid Build 42（Steam 版）

### 快速開始

#### 1. 掛載到 Workshop 目錄

雙擊 `link_workshop.bat`，選擇 **[1] 掛載**。

腳本會建立符號連結：

```
%UserProfile%\Zomboid\Workshop\MinidoracatLangFor42
  → <專案目錄>\MOD\MinidoracatLangFor42
```

> 如果權限不足，會自動彈出 UAC 提示，不需要手動以管理員啟動。
>
> 或者啟用 **Windows 開發人員模式**（設定 → 系統 → 開發人員專用）即可免提示。

#### 2. 啟動遊戲測試

雙擊 `PZ_Test.bat`，選擇啟動模式：

| 選項 | 說明 |
|------|------|
| **1** | 啟動客戶端 |
| **2** | 啟動客戶端（Debug 模式） |
| **3** | 啟動專用伺服器 |
| **4** | 一鍵：伺服器 + 1 客戶端 |
| **5** | 一鍵：伺服器 + 2 客戶端 |
| **6** | 兩個客戶端（Host 模式） |

> 首次使用請修改 `scripts/PZ_Test.ps1` 頂部的 `$PZ_PATH` 為你的 PZ 安裝路徑。

### 卸載

雙擊 `link_workshop.bat`，選擇 **[2] 卸載** 即可移除符號連結（不會刪除原始檔案）。

## 翻譯流程

### 簡繁轉換

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

## 問題回報 & 交流

- [Discord 伺服器](https://discord.gg/Gur2V67)
- [Twitch 直播頻道](https://www.twitch.tv/minidoracat)

## 合作

本 MOD 與[統一中文漢化](https://steamcommunity.com/sharedfiles/filedetails/?id=3556544454)進行合作，配合「統一中文漢化 × 如一漢化組」持續更新校對。
