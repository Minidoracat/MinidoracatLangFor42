# Changelog

所有重要的變更都會記錄在此檔案中。

格式基於 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)，版本號遵循 `{PZ版本}-{Mod主版本}.{次版本}.{修訂}` 格式。

## [42.19.0-1.6.3] - 2026-06-10

### Fixed

- 修復 PZ 42.19 官方 Java / Lua 在生成動物屍體與屠宰肉品時，會把當下語言組成的動態名稱保存到 item custom name，導致 MP server、舊存檔或其他語言生成的 `Dead ...`、`Mutton (Poor Cut)` 等名稱在中文 client 仍顯示來源語言的問題。
- 新增 client 端重新套用目前語言翻譯的顯示修補，涵蓋 `Base.CorpseAnimal` 動物屍體 / 骨架，以及屠宰產出的牛肉、牛排、豬肉、豬排、羊排、兔肉與鹿肉肉質名稱。
- 保留玩家自訂動物名稱，只翻譯外層「死 %1 / %1 骨架」與官方自動產生的品種、種類、肉質文字；這不是補缺漏翻譯鍵，而是修復官方動態命名結果被保存後的顯示遷移層。

## [42.19.0-1.6.2] - 2026-06-09

### Fixed

- 針對 PZ 42.19 官方 Java `ItemCodeOnCreate` 在生成配方圖紙、工具鍛造計劃、縫紉圖紙與烹飪食譜剪輯時，會把當下語言組成的動態物品名稱寫入 item custom name；其中烹飪食譜剪輯還會把當下語言的 recipe name 寫入 `learnedRecipes`，導致 MP server 或舊存檔保留生成端語言的情況，新增 client 端重新套用目前語言翻譯的修補。
- 修復物品放在已開啟容器、背包或地板容器時，PZ 只刷新 inventory UI 而不重新套用動態名稱，造成拿到身上才翻譯、放回容器又顯示來源語言的問題。
- 這次修補不是補缺漏翻譯鍵，而是針對官方 Java 動態命名結果被保存後的顯示遷移層，避免玩家誤會是 MOD 翻譯檔漏翻。

## [42.19.0-1.6.1] - 2026-06-09

### Fixed

- 修復配方圖紙、工具鍛造計劃、縫紉圖紙與烹飪食譜剪輯在 MP 或舊存檔中保留生成端英文名稱的問題。
- 修復烹飪食譜剪輯由 EN / CH / CN 任一語言生成後，切換到其他中文語言時配方名稱無法重新套用目前 client 翻譯的問題。

## [42.19.0-1.6.0] - 2026-06-02

### Added

- 補齊 PZ 42.19.0 vanilla 新增的 CH / CN 翻譯鍵，包含控制器按鍵預設、安全屋管理指令、Steam Deck 按鍵樣式、紀念名單與新物品文字。
- 新增控制器預設下拉選單的窄 wrapper，翻譯原版 `Create New`、`Default`、`Original` 與自訂預設標籤。

### Changed

- `mod.info` 版本：`42.18.0-1.5.1` → `42.19.0-1.6.0`。
- 支援版本更新為 Build 42.19.0+。
- 將管理員使用者列表硬編碼文字修補改為窄 wrapper，避免整段複製 PZ 42.19.0 的 `ISUsersList` 實作。

### Fixed

- 修復管理員使用者列表中的 `Online`、`Offline`、`Set Role` 在 CH / CN 介面仍顯示英文的問題。
- 修復控制器預設選單新增的 PZ 42.19.0 文字在 CH / CN 介面仍顯示英文的問題。

## [42.18.0-1.5.1] - 2026-05-12

### Added

- 補齊 PZ 42.18.0 vanilla 新增的 13 個 CH / CN 翻譯鍵，包含簡易防毒面具濾布、地圖暫停選項、安全屋設定提示、坐在地上的按鍵綁定與管理 / debug UI 文字。

### Changed

- `mod.info` 版本：`42.18.0-1.5.0` → `42.18.0-1.5.1`。
- 記錄 PZ 42.18.0 `Translator` 百分比 placeholder 規則，後續新增含 `%` 的翻譯時需保留 `%1`、`%s`、`%.1f` 等原始 placeholder，並避免 `%1%.` 類格式。

### Fixed

- 修復世界地圖被禁用或尚未建立時，地圖標籤清理可能呼叫不存在的 world map instance 並導致進入遊戲錯誤的問題。
- 修復車鑰匙名稱遷移修補在 B42 戰利品分配流程中收到非 `ItemContainer` 物件時可能崩潰的問題。

## [42.18.0-1.5.0] - 2026-05-11

### Changed

- `mod.info` 版本：`42.17.0-1.4.2` → `42.18.0-1.5.0`。
- 支援版本更新為 Build 42.18.0+。
- 調整多人連線大型檔案下載進度文字，避免 PZ 42.18.0 `Translator` 百分比格式轉換將 `%1%.` 解析成無效 formatter 格式。
- 對齊 PZ 42.18.0 的百分比字串規則，修正音量提示與載入畫面濕度百分比顯示的跳脫方式。

### Fixed

- 修復使用漢化 MOD 進入多人伺服器時，`IGUI_MP_DownloadedLargeFile` 可能觸發 `UnknownFormatConversionException` 導致客戶端無法完成登入的問題。
- 修復音量提示與載入畫面濕度在 PZ 42.18.0 下可能顯示多餘 `%` 的問題。
- 修復傳單文字中 `6%.` 這類百分比加句點格式在新版 `Translator` 規則下的潛在解析風險。

## [42.17.0-1.4.2] - 2026-04-24

### Added

- 新增 vanilla `Kale Growing Season` 原始名稱 alias，補齊 VHS / media 顯示使用未正規化 recipe key 時的翻譯。
- 新增管理面板角色列表顯示修補，翻譯 vanilla 內建角色名稱、描述、唯讀標籤與預設身分標籤。
- 新增 `PerkName_Flx.lua`，重新套用 `IGUI_perks_*` 到 Java `PerkFactory.Perk.name`，修復技能升級 halo 使用 stale 技能名的情境。
- 新增 `PlayerStatsXP_Flx.lua` client/server 同步修補，避免多人管理面板提升 / 降低技能等級時 server 再回送英文升級 halo。

### Changed

- `mod.info` 版本：`42.17.0-1.4.1` → `42.17.0-1.4.2`。
- 管理面板技能升降級在多人模式改用自訂 server command 同步等級 / XP，不再透過 vanilla `/addxp` 產生第二次 server halo。

### Fixed

- 修復製作視窗仍顯示 `Furniture` / `carpentry` 英文分類名稱的問題。
- 修復管理面板角色列表內建角色、描述與 `[Read Only]` 標籤未翻譯的問題。
- 修復多人管理面板按「提升等級」時，已顯示一次中文升級提示後又收到一次英文 `+1 Aiming` 類 server 提示的問題。

## [42.17.0-1.4.1] - 2026-04-24

### Added

- 新增 `VehicleKey_Flx.lua` 舊存檔 / 多人伺服器車鑰匙名稱遷移修補，補回 server 端已寫入英文名稱時 client 無法靠翻譯 key 顯示中文的情境。
- 新增 `RadioData_Flx.lua` live radio / TV 修補：多人伺服器英文環境載入 `RadioData.xml` 後，會把 server 已固化的英文台詞反查為 CH/CN `RadioData.json` 譯文。
- 新增 radio / TV 頻道名稱 UI 修補，補齊 WBLN、生活與居家電視台、國家體育電視台、布倫南電影頻道等頻道名稱顯示。
- `scripts/sync_translations.py` 新增 / 恢復 `gen-vehicle-map` 與 `gen-radio-map`，可從 vanilla PZ 檔案重新產生車鑰匙與 radio/TV 反查資料。

### Changed

- `mod.info` 版本：`42.17.0-1.4.0` → `42.17.0-1.4.1`。
- radio / TV 頻道下拉選單改用 UTF-8 安全截斷，避免原版 byte-wise `s:sub(i,i)` 切斷中文字元。
- live radio / TV 廣告段落改用公開 `RadioBroadCast:setPreSegment()` / `setPostSegment()` 重新掛載中文 segment，避免讀取 Java private field 造成 server log spam。

### Fixed

- 修復多人遊戲中車鑰匙仍可能顯示 `Vehicle Key - ...` 英文車名的問題。
- 修復 admin 生成車輛下拉選單顯示 `IGUI_VehicleName...` 原始 key 的問題。
- 修復 TV / radio 頻道下拉選單中文名稱變成亂碼的問題。
- 修復 WBLN / PawsTV / 其他 live radio / TV 節目台詞在多人伺服器英文環境下仍顯示英文的問題。
- 修復 `RadioData_Flx.lua` 先前嘗試 Java reflection 讀取 `preSegment` / `postSegment` 導致 dedicated server log 大量 `getName/getSuperclass` 錯誤的問題。
- 修復主選單 credits 畫面解析度變更時 `CreditsScreen:onResolutionChange()` 可能因 `richText` 尚未初始化而報錯的問題。

### Notes

- live radio / TV 的廣告 segment 會依 vanilla `RadioData.xml` 重建中文版本；因原版隨機抽到的 private segment 無法安全讀取，實際廣告片段可能和原本抽到的英文 segment 不完全相同，但會維持同類別與約略相同的掛載機率。

## [42.17.0-1.4.0] - 2026-04-23

### Added

- 新增 7 個翻譯檔（CH + CN 各 7 份，共 14 份），對應 PZ 42.17 內容
  - 6 個新城市資訊：Brandenburg / Ekron / Fallas Lake / Irvington / March Ridge / Valley Station
  - `Credits.json`：vanilla 42.17 從 `credits.txt` 遷移為結構化 JSON（78 個職稱 key）
- 既有 6 個翻譯檔補齊 38 個缺失 key（CH + CN 各 38，共 76）
  - `UI.json`（+7）：`UI_Pause` / `UI_Resume` / `UI_mainscreen_credits` / `UI_optionscreen_populateServerListOnStart` 等
  - `IG_UI.json`（+24）：`IGUI_Key_L/RCONTROL/MENU/META/SHIFT/SPACE` / `IGUI_mouse_btn_0-8` / `IGUI_PetName_*` / `IGUI_BookTitle_the_moments_of_darius` / `IGUI_Moveables_BasementWallAdjacentToTheVoid`
  - `Tooltip.json`（+1）：`Tooltip_DoorIsLocked`
  - `ContextMenu.json`（+2）：`ContextMenu_ChangeRadius` / `ContextMenu_TooSimple`
  - `Moveables.json`（+2）：`Fence_Post` / `Green_Fancy_Lamp`
  - `Print_Text.json`（+2）：`Print_Text_FourthofJulyCelebrationDixieMobilePark_info/title`
- **`Recorded_Media.json`（+347）**：全部 42.17 新增的廣播/VHS 錄影帶內容（CH 手譯 + OpenCC tw2sp 反向產 CN）
  - VHS 標題：居家焊接指南 / 緊急急救 / 諾克斯持槍俱樂部槍械指南 / 居家陶藝 / 居家種植蔬果 / 居家香草栽培 / 從礦石到商店 / 居家壽司製作 / 打石術 等 22 支
  - 節目旁白、對話、教學台詞完整翻譯，音效標籤（`<gunshot>`, `*lamb bleats*` 等）保留原樣
- **`SurvivalGuide.json`（+228）**：全部 42.17 新增的生存指南條目（97 個 title + 97 個 description + 34 個 joypad/category_image）
  - 涵蓋 PVP / 釣魚 / 瞄準 / 畜牧 / 建造 / 戰鬥 / 烹飪 / 製作 / 農業 / 採集 / 急救 等全領域
  - PZ 格式標籤（`<LINE>` / `<IMAGECENTRE>` / `%1` 等）全部保留
- 修正 `IGUI_PlayerText_BookObsolete` 翻譯不貼切問題（「我已經理解了」→「這本書的內容已經過時了」）
- `opencc_fixes.json`：新增「達」/「歐斯」例外避免「達里歐斯」名字被誤判為「裡」

### Removed（破壞性變更）

- **完全移除 `VehicleKey_Flx.lua`**：
  - 反編譯確認 42.17 `BaseVehicle.java:10810` 已改用 `Translator.getText("IGUI_VehicleName" + carName)` 做完整 i18n
  - 新 spawn 的車鑰匙名稱由 Java 端直接寫入當前語言，Lua 修復已無存在必要
  - **對舊存檔影響**：從 42.16 或更早版本升級上來的存檔，其既有車鑰匙名稱仍保持英文（已 persist 到存檔）。玩家需在 42.17 中讓該車鑰匙從存檔中消失並重新 spawn 才會變中文。**如需保留舊存檔的中文車鑰匙名稱，請在升級前先移除並重新撿取**。
- 同步移除 `scripts/sync_translations.py` 的 `gen-vehicle-map` 命令（連同 `--pz-path` 參數）
- `AGENTS.md` / `scripts/AGENTS.md` 清除相關文件

### Changed

- `mod.info` 版本：`42.16.1-1.3.0` → `42.17.0-1.4.0`（minor 升版；VehicleKey Lua 移除的破壞性影響僅限舊存檔車鑰匙名稱，詳見 Removed 段）
- 最低支援 Build 升至 42.17.0

### Fixed

- 專有名詞一致性回歸修復（與既有 `MapLabel.json` / `Print_Media.json` / `ItemName.json` 語料對齊）：
  - Brandenburg → 勃蘭登堡（非布蘭登堡）
  - March Ridge → 三月嶺（非馬奇嶺）
  - 迪莉婭號蒸汽船（非德莉拉）
  - 邦德唯優購物中心（非池景購物中心）
  - Riverside → 河畔鎮（Fallas Lake 內引用）
  - 巫師寶庫（Irvington 內引用）
  - 迪克西拖車公園（`Print_Text_FourthofJulyCelebrationDixieMobilePark_*`）
- `IG_UI.json` 書名格式統一為《書名》作者 著（與既有 140+ 本書 key 對齊）
- `Credits.json` 遊戲名改為「殭屍毀滅工程」（與 `IG_UI.json:813` 一致）

### Notes

- **保留 `SpawnItems_Flx.lua`**：ID Card / Passport 等動態命名物品的 Lua 遷移修補仍保留。雖然 Java 42.17 `nameAfterDescriptor` 也已 i18n，但這個修補是 SIMPLIFY 後的低成本路徑（僅 OnCreatePlayer + OnGameStart），繼續做舊存檔遷移。
- **翻譯漏譯 baseline**：703 → **0**（完全補齊，100% 覆蓋 vanilla EN 42.17 所有 key）。
- **翻譯品質原則**：CH 繁中品質優先（手譯），CN 簡中透過 OpenCC tw2sp 從 CH 反向生成；既有 SurvivalGuide 採 CN 手譯 + OpenCC s2twp 轉 CH。OpenCC `fix-check` 零警告。

## [42.16.1-1.3.0] - 2026-04-03

### Changed

- 同步簡體翻譯參考源（如一漢化組）v3.14（對應 B42.16）
  - 更新 21 個翻譯檔（CN + CH 各 21 個），新增 key：ContextMenu +5, IG_UI +12, Moveables +40, Recipes +55, Sandbox +3, UI +12
  - 刪除孤兒 `streets.txt`（CN/CH），參考源已移除此檔案
- `sync_translations.py` 重構：
  - 新增 `.json → .json` 同步支援（參考源已全面從 .txt 遷移至 .json）
  - 移除 `LUA_PAIRS` CN/CH 分離邏輯，統一使用 `_Flx.lua` 雙語方案
- `pz_translate.py`：新增 trailing comma 容錯（PZ 原生 JSON 格式）
- `opencc_fixes.json`：修正 `幹→乾` 獨立值 pattern（溫度狀態 Dry）

### Fixed

- 修復 UI.json 載入存檔屬性時 crash（移除 14 個帶多餘引號的錯誤 key，如 `"map"` → `map`）
- 修正 CH `IG_UI.json` 溫度狀態 `幹` → `乾`（Dry）

## [42.15.1-1.2.2] - 2026-03-11

### Fixed

- 修復多人遊戲世界地圖街道名稱英文與中文重疊顯示
  - 重寫 `MapStreets_Flx.lua`：先 `clearStreetData()` 再載入中文版（`addStreetData()` 是疊加而非覆蓋）
  - 使用固定路徑 `Riverside, KY/streets.xml`，不依賴 `getLotDirectories()`（MP client 不回傳 Riverside）
- 修復單人遊戲建築物不載入問題
  - 刪除 MOD 中的 `Muldraugh, KY/` 目錄（`map.info` 導致 PZ 認為 MOD 是地圖資料來源）
- 修復 Sandbox 「隨機開門數量」選項版面跨版（`\n` 原樣顯示）
  - `Sandbox_ZDoorOpeningPercentage` 標籤改為簡短文字（CH: 隨機開門數量 / CN: 随机开门数量）

### Changed

- `AGENTS.md` 新增版本發布流程、地圖目錄規則、Sandbox 翻譯規則、MapStreets 載入機制等文件

## [42.15.1-1.2.1] - 2026-03-11

### Fixed

- 修復報紙/傳單閱讀時 crash（`startLoadingPrintMediaTextures` nil 呼叫）
  - 根因：4 個 `_info` 翻譯值被截斷，`loadstring()` 回傳 nil
  - 修復檔案：`Print_Media.json`（CH/CN 各 4 筆：PonyRoamO、McCoyLoggingCorp、NolansUsedCars、BensCabin）
- 修復 `pz_translate.py` 解析器無法處理 Lua `..` 多行字串拼接的問題

### Changed

- 傳單圖片批量縮小：764MB → 120MB（-84%），對齊原版尺寸的 50%，遊戲內無視覺差異
- `sync_translations.py` 改進：
  - 新增 Print_Media `_info` 截斷偵測（未閉合 `getTexture()` / `<type:...>` 標籤）
  - 新增 `convert_print_media_value()` 僅轉換 `<type:text>` 內容，保留標記參數
  - 同步時保留 MOD 自訂 key（不在參考來源中的 key 不被覆蓋）

### Added

- `scripts/resize_flyers.py` — 傳單圖片批量縮小工具（對齊原版尺寸 + Lanczos + PNG 壓縮）

## [42.15.1-1.2.0] - 2026-03-11

### Added

- 世界地圖街道名稱中文化（單人 / 多人均支援）
- 地圖選項面板完整翻譯（35 個 `IGUI_MapOption_*` key）
- 動態命名物品翻譯修復（護照、身分證、超速罰單、徽章、軍牌）
- 管理面板使用者列表硬編碼翻譯覆寫（Online / Offline / Set Role）
- 17 個管理面板缺失翻譯 key（PVP Log、Roles List、Users List 等）
- `CatLangDiag.lua` — MOD 載入診斷腳本（版本橫幅 + 翻譯載入驗證）
- `MapStreets_Flx.lua` — 覆寫 `initDefaultStreetData` 修復 MP 街道載入
- `SpawnItems_Flx.lua` — 透過事件掛鉤修復動態物品英文前綴
- `ISUsersList_Flx.lua` — 管理面板使用者列表翻譯覆寫
- `scripts/convert_txt_to_json.py` — 翻譯格式轉換工具
- `scripts/pz_translate.py` — 共用翻譯解析模組
- `.gitattributes` — LF 行尾強制規則 + `*.zip` Git LFS 追蹤
- `CHANGELOG.md` — 變更紀錄（本檔案）

### Changed

- 翻譯格式從 Lua `.txt` 遷移至 B42.15+ `.json`（68 個檔案）
- 所有 JSON 翻譯檔行尾從 CRLF 轉換為 LF（PZ 解析器僅接受 LF）
- 出生點地圖圖片從 `.rar` 改為 `.zip`（PZ 僅自動偵測 `.zip`）
- `streets.txt` 從 `Translate/` 遷移至 `maps/` 目錄並改名為 `streets.xml`
- `link_workshop.ps1` 同時管理 `Workshop/` 和 `mods/` 雙符號連結
- `MapSpawnSelect_Flx.lua` 重寫中文地圖金字塔路徑覆寫
- 補齊 821 個缺失翻譯 key（Recipes 777 + UI/Sandbox/ItemName 等 44）
- 合併 CH/CN 相同 Lua 腳本為語言無關的 `_Flx` 檔案：
  - `ISRichTextPanel_CH/CN` → `ISRichTextPanel_Flx`
  - `FishWindow_CH/CN` → `FishWindow_Flx`
  - `ISBuildWindowHeader_CH/CN` → `ISBuildWindowHeader_Flx`
  - `ISWidgetRecipeCategories_CH/CN` → `ISWidgetRecipeCategories_Flx`
  - `MainScreen_CH/CN` → `MainScreen_Flx`
  - `ISUsersList_CH` → `ISUsersList_Flx`

### Fixed

- 翻譯無法載入：所有 JSON 檔案為 CRLF 行尾導致 PZ 靜默忽略
- 舊版 MOD 快取：`Zomboid\mods\CatLangFor42` 殘留舊版優先載入
- 出生點地圖圖片不顯示：Git LFS pointer 未拉取 + `.rar` 格式不被偵測
- MP 街道名稱不顯示：`ISMapDefinitions_CH.lua` 阻擋所有街道資料載入
- `SpawnItems_Flx.lua` 存取 `local SpawnItems` 造成 crash（改用事件掛鉤）

### Removed

- `ISMapDefinitions_CH.lua` / `ISMapDefinitions_CN.lua`（阻擋街道資料）
- 所有 `*_CH.txt` / `*_CN.txt` 翻譯檔（已遷移至 `.json`）
- 重複的 CH/CN Lua 腳本（已合併為 `_Flx`）

## [42-1.1.0] - 2025-xx-xx

### Added

- 初始版本
- 繁體中文 / 簡體中文完整翻譯
- 出生點地圖漢化（城市名稱、世界地圖標籤）
- 報紙 / 傳單內容漢化（135 張傳單圖片）
- 技能書書名漢化
- 新手引導漢化
- CJK 字元換行處理
- 配方分類、建造視窗、釣魚視窗等 UI 翻譯修補
- 中文字型支援（CH/CN 各 4 DPI）
