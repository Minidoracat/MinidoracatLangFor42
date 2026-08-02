# 硬編碼追蹤登記簿（Hardcode Registry）

本檔是全專案「官方硬編碼英文殘留」的唯一集中紀錄。凡是官方 Java / Lua 寫死英文、翻譯 JSON 無從介入、需要 Lua 修補或持續追蹤的項目，一律登記在此。

## 使用規則

1. **調查未翻譯回報前先讀本檔**——先確認是否為已知項目（A 已修補 / B 待修補 / C 修不到‧不修（含第三方）/ D 已淘汰）。
2. **新增任何硬編碼修補（`_Flx.lua` 或翻譯繞路）時，必須同步在本檔登記**：官方來源錨點（檔案 + 方法/可 grep 字串，行號僅供參考）、修補檔、症狀。
3. **每次 PZ 版本更新（如 42.19 → 42.20）後，執行下方「更新盤查 SOP」**，逐條重新驗證所有條目並更新各表「最後驗證版本」。
4. 行號會隨官方更新漂移，**以錨點字串 grep 為準**，不要依賴行號。

## 更新盤查 SOP（PZ 版本更新後執行）

```bash
# 1. 重建反編譯快照
uv run scripts/decompile.py build --version {新版本}
uv run scripts/decompile.py verify {新版本}

# 2. 逐條 grep 錨點字串：
#    - A 表（已修補）：官方來源是否還在？官方是否已自己掛翻譯鍵（可能可淘汰修補）？
#      修補檔覆寫的官方函式簽名 / 實作是否變更（需對版）？
#    - B 表（待修補）：錨點字串還在原檔嗎？官方是否已掛鍵（改為直接補翻譯）？
#    - C 表（修不到）：Translator.getTextInternal 前綴路由是否新增 fallback？偽 key 是否改為正規 key？
# 3. 更新各表的「最後驗證版本」；官方已修復的條目移到 D 表（已淘汰）留檔。
```

---

## 0. 42.20 翻譯載入機制變更（影響全表判讀，先讀這段）

2026-07-29 以 42.20.0 反編譯快照逐條查證，三件事改變了「未翻譯」的判讀前提：

1. **MOD 與 vanilla 是逐鍵合併，不是整檔取代**（`Translator.java` 錨點 `if (!map.containsKey(k) || !StringUtils.isNullOrEmpty(v.toString()))`）。`loadFiles()` 對每個檔跑 `forLanguageStack`，順序為「EN → 目標語言」，每輪內是「vanilla base 目錄 → 依 `getModIDs()` 各 MOD」。**我方檔案缺的鍵會沿用 vanilla 官方 CH 譯文，不會露英文**；只有 vanilla CH 也沒有的鍵才會退到 EN。判讀玩家回報時務必先確認是「真英文」還是「官方譯文非我方風格」。
2. **`language.txt` 與 `credits.txt` 已完全失效**。`Languages.java` 錨點 `Files.exists(entry.resolve("language.json"))` 只認 `language.json`；`tryFillMapFromFile` 的路徑模板寫死 `.../%s.json`；42.20 全快照 grep `language.txt`、`credits.txt` 皆零命中。兩檔已於本次刪除（CH/CN 各一份）。**MOD 不需要也不應該提供 `language.json`**——`loadTranslateDirectory` 對已存在語言是 `languages.set(index, lang)` 直接覆蓋本體定義。
3. **`Credits_Translator.json`（42.20 新增）MOD 版永遠讀不到**。`CreditsRole.java` 錨點 `TRANSLATION_FOLDER = Path.of("media/lua/shared/Translate")` 用相對於遊戲執行目錄的原生 `Files` API，不走 `ZomboidFileSystem` 的 mod 疊加。漢化組署名已改以 `credits_CatLangFor42_group` / `_names` 兩個自有鍵（走 `credits_` 前綴路由）存於 `Credits.json`，由 `CreditsScreen_Flx.lua` 包裝 `doCreditsText` 接回**主選單製作人員名單**；另由 `MainOptions_Flx.lua` 包裝 `MainOptions.getGeneralTranslators` 接回**遊戲設定→使用者介面→語言**的譯者清單（該處同樣走 `CreditsRole.getTranslatorCreditsList`，只讀本體目錄）。兩個消費端格式不同：CreditsScreen 吃 richText 的 `<LINE>`，語言頁是「一行一字串」的清單、必須自行拆行。

另：`Translator.getTextInternal` 的前綴路由 42.19→42.20 一字未改（整份 `Translator.java` 只有 4 處反編譯層差異），**仍無泛用 fallback 表**，C 表偽 key 的結論全部維持。載入期 `%` 正規化（`Translator.java:251`）亦逐字未變，既有 `%1%`、`%.1f %%` 寫法在 42.20 行為一致。

---

## A. 已修補（現行 `_Flx.lua`，PZ 更新後逐條對版）

最後驗證版本：**42.20.0**（全部，2026-07-29）

| # | 修補檔（`MOD_ROOT/media/lua/`） | 官方硬編碼來源（錨點） | 症狀 |
|---|---|---|---|
| A1 | `shared/Items/VehicleKey_Flx.lua` | Java `BaseVehicle.keyNamerVehicle`、`ItemPickerJava` 車鑰匙生成（42.17 官方已改 `Translator.getText`，本檔保留作舊存檔/MP 遷移層）。**2026-08-02 補世界容器顯示修復**：MP 世界容器（垃圾桶、木箱）內容從 server 位元組重建後，client 端修過的名稱被 server 固化英文名蓋回（`InventoryItem.setName` 純本機不同步、`save` 僅 `name != originalName` 時序列化、`load` 套回傳來的名稱；`SyncItemFieldsPacket` 只同步玩家自訂名）——原掛勾只覆蓋玩家物品欄＋loot 生成，鑰匙躺在世界容器內無人再修（玩家 titan 2026-08-02 回報垃圾桶內車鑰匙英文）。機制採 A3 等四檔已驗證 idiom：`fixOpenInventoryPages` 掃當前開啟的物品欄/戰利品面板＋`OnContainerUpdate`（**無參數**——42.20 全部 51 個觸發點皆不帶 `ItemContainer`：45 個無參數、6 個傳 `Food`/`IsoGridSquare`/`IsoDeadBody`/`IsoObject` 系物件，事件 handler 裡任何 `instanceof(container, "ItemContainer")` guard 都是死碼，勿再複製）＋`OnRefreshInventoryWindowContainers`（`state == "end"`）＋`EveryOneMinute` 兜底。顯示層治標為機制上限：server 那份資料永遠是生成端語言，「重建→再修」循環是常態。**遊戲內驗證待進行**（MP dedicated EN 伺服器丟鑰匙進垃圾桶、關閉重開確認中文；console 應出現 `[VehicleKey] Open-page repair path active`） | 車鑰匙固化英文名 `Vehicle Key - Chevalier Dart`；MP 世界容器內回復英文 |
| A2 | `shared/Items/SpawnItems_Flx.lua` | Java `nameAfterDescriptor()` 英文前綴。**2026-08-02 查核**：MP 世界容器重建缺口（同 A1）對證件類**不存在**——A3 的 `NAMED_DESCRIPTOR_TYPE_SET` 已涵蓋 IDcard 全變體/Passport/Badge/DogTag 且容器路徑可運作，本檔維持原範圍（玩家出生物品，OnCreatePlayer/OnGameStart）；唯一漏網的 `Base.SpeedingTicket`（vanilla `SpawnItems.lua:186` 同走 `nameAfterDescriptor`）已補進 A3（generator `DYN_EN_NAME_FULLTYPES`＋`NAMED_DESCRIPTOR_TYPE_SET`）。兩檔輸出逐字相同（CH `IGUI_ItemWithDisplayName`＝`"%1: %2"`），冪等不互搶 | ID 卡/護照顯示 `Passport: 角色名` |
| A3 | `shared/Items/DynamicItemName_Flx.lua` | Java `ItemCodeOnCreate` / `RecipeCodeHelper`、官方 Lua `Fishing`——生成時把當下語言烘焙進 `InventoryItem.name`。**2026-08-02 擴充**：`NAMED_DESCRIPTOR_TYPE_SET`＋generator `DYN_EN_NAME_FULLTYPES` 補 `Base.SpeedingTicket`（vanilla `SpawnItems.lua:186` `nameAfterDescriptor`，原 A3 漏收——A2 的玩家出生物品路徑本已涵蓋此型別，缺的是本檔的世界容器／既存物品路徑；`gen-dynamic-name-map` 已重生，EN_ITEM_NAMES 45→46） | 照片/書刊/證件/刮刮樂/魚等動態命名殘留英文 |
| A4 | `shared/Items/RecipeLiterature_Flx.lua` | Java `ItemCodeOnCreate` literature `"{物品名}: {配方名}"` | 配方圖紙/剪報英文殘留 |
| A5 | `shared/Items/AnimalProductName_Flx.lua` | Java 動物死亡把 `died.getFullName()` 烘焙進 `IsoDeadBody.customName`；另含活體動物顯示名。**42.20 實作變更（不影響現況）**：`IsoAnimal.getFullName` 由 42.19 的 `getText("IGUI_Breed_"..) + " " + name` 硬串接改為 `getText("IGUI_AnimalFullName", 品種, 名字)`（新鍵，EN/CH/CN 現值皆 `"%1 %2"`）。我方 patch 三處 `breedName .. " " .. typeName`（:185/:391/:464）與 `sourceAnimalNameMatches`（:152/:161）輸出仍逐字相同。**約束：CH/CN 的 `IGUI_AnimalFullName` 不得改成非 `"%1 %2"`（例如中文去空格），否則重組與比對雙雙失準**；真要改須同步改這 5 處。另 `AnimalInventoryItem.initAnimalData` 官方只改一半，仍是硬串接。`IsoDeadBody` 新增 `createdCorpseItem` 快取（屍體物品只建立一次），經查我方不依賴重建，反而更穩定 | 動物屍體/屠宰肉品顯示 `Gray Female Raccoon (Sow)` |
| A6 | `shared/PerkName_Flx.lua` | Java `IsoGameCharacter.LevelPerk()` 組合 `"+1 " .. perk.getName()` | 技能升級 halo 顯示 `+1 Agriculture` |
| A7 | `shared/RadioData_Flx.lua` | Java 載入 RadioData.xml 時以 `Translator.getText("RD_"..)` 固化 `RadioLine.text` 為載入端語言 | 英文 server 對中文 client 送英文字幕 |
| A8 | `client/RadioCom/RadioWindowModules/RadioChannelNames_Flx.lua` | 官方 Lua `client/RadioCom/RadioWindowModules/RWMChannel*.lua` 顯示層 + Java 把頻道名複製進 `DeviceData` presets 持久化 | 收音機/電視頻道下拉選單英文 |
| A9 | `client/ISRolesList_Flx.lua` | 官方 Lua `ISRolesList` 直接畫 server 端角色欄位 | 內建角色名/預設身分標籤英文 |
| A10 | `client/ISUsersList_Flx.lua` | 官方 Lua `ISUsersList` 硬編碼 `Online` / `Offline` / `Set Role` | 管理員使用者列表英文 |
| A11 | `client/ISUI/Gamepad/GameOptionControllerTab_Flx.lua` | 官方 Lua `client/ISUI/Gamepad/GameOptionControllerTab.lua` `createGamepadBindingPresetsCBox` preset 標籤硬編碼（根因未除：`gamepadBinding:addInputSet` 仍以 `labelText = setName` 存原文名，非翻譯鍵）。**42.20 半修復**：`CharacterInputBindingSet.getUniqueSetName` 由字面 `"Custom"` 改為 `getText("IGUI_Custom")`，故 42.20 之後**新建**的預設集名為譯文、不會命中我方 `presetKey == "Custom"` 與 `^Custom(_%d+)$`。已於 2026-07-29 補 `IGUI_Custom`＝「自訂」到 CH/CN（官方 CH 為「自定義」），新舊預設用詞因此一致，修補不需改碼；**42.19 或更早建立的 `Custom` / `Custom_N` 仍是英文，修補必須保留** | 控制器預設集標籤英文 |
| A12 | `client/PlayerStatsXP_Flx.lua` ＋ `server/PlayerStatsXP_Flx.lua` | 官方錨點：`client/ISUI/PlayerStats/ISPlayerStatsUI.lua` 的 `ISPlayerStatsUI:onOptionMouseDown`／`SendCommandToServer("/addxp ...")`、Java `IsoGameCharacter.LevelPerk` 觸發 `LuaEventManager.triggerEvent("LevelPerk", ...)`。（原登記的 `setPerkLevelWithoutHalo` **不是官方符號**，是我方 server 端 local 函式名，2026-07-29 更正）。**42.20 危險實作變更**：`AntiCheatXPUpdate` 整支重寫——判定由「全技能 XP 總和 delta > 1000×全域倍率」改為**逐技能** `xpDelta > 1000 × 該技能倍率 × XP boost 倍率`，且 `getMaxPerkXpBoostMultiplier` 在無 boost 時落到 default `0.25F`（門檻可低至 250 XP）；基準快照搬進 `NetworkCharacterAI.XpChecker`（60 秒 `UpdateLimit`），只能由新方法 `updateXpChecker()` 重設。官方同步替所有加 XP 路徑補上（`AddXPCommand.java:83`、`GameServer.java:1848`、`IsoGameCharacter.java:17578`）。我方 client 修補繞過 `/addxp` 走自有 module command，server 端未重設 → 觸發後經 `AntiCheat.java:97` `act()`，累計達 `maxSuspiciousCounter=2` 即依 `antiCheatXp` 設定**踢除或封鎖被調整技能的玩家**。**2026-07-29 已修**：`server/PlayerStatsXP_Flx.lua` 的 `syncXp()` 內以獨立 `pcall` 加上 `ai:updateXpChecker()`（獨立 pcall 是為了 42.19 伺服器無此方法時不連帶影響 `syncXp`） | 管理面板調技能時英文 halo；42.20 起另有踢人風險 |
| A13 | `client/FishWindow_Flx.lua` | 官方 Lua `client/PZAPI/ui/organisms/FishWindow.lua:109/122/265` 硬編碼 `"Fishing Panel"`、`"Info"`、`"Guide"` | 釣魚視窗標題/分頁英文 |
| ~~A14~~ | ~~`client/ISWidgetRecipeCategories_Flx.lua`~~ | **官方 42.20 已修復，見 D2** | — |
| ~~A15~~ | ~~`client/ISBuildWindowHeader_Flx.lua`~~ | **官方 42.20 已修復，見 D3** | — |
| A16 | `client/DebugUIs/DebugContextMenu_Flx.lua` ＋ CH/CN `ContextMenu.json` 的 `ContextMenu_CatDebug_*`（336 鍵） | 原 B1-B11、B13 全區：`DebugContextMenu.lua`／`AdminContextMenu.doMenu`／`doBrushToolOptions`／`buildRampsMenu` 的 `addOption("英文")`；Java `getName()` 故事名（RB 33、RVS 23、RZS 41、RDS 31）；Java/Lua 偽 key 選項（Tile/Room/Coordinates Report、loot distro——顯示層 pattern 修補）；**2026-07-14 二批**：`Foraging/ISSearchManager.lua:1608-1635`（搜尋圖示除錯選單）、`ISFarmingMenu.lua:377-402/984-985`（農作 Cheat 區）、`ISFeedingTroughMenu.lua:54-65`、`ISAnimalContextMenu.lua:47/327-413/694`（動物 Debug 區，含 `Make Invincible`/`Remove Invicibility`（官方拼字）於 394-398 以變數組裝；**限世界選單路徑**——動物「物品欄」選單因 `ISInventoryPaneContextMenu.lua:142` 在事件觸發前 early-return 而不涵蓋，見 B15）、`ISHutchMenu.lua:39-40`、`ISVehicleMenu.lua:718-747/923-931`（車輛 debug 區）、`ISInventoryPaneContextMenu.lua:4697`、`ISUI/Maps/ISWorldMap.lua:907-980`（大地圖右鍵選單 17 條，Show Cell Grid／Virtual Animals／Add Tracks 等）；**2026-07-27 三批**：`Context/Inventory/InvContextMedia.lua:16/20`（媒體物品 `prefix .. ": Change recording"` 動態前綴組字（ADMIN/DBG 兩形）＋子選單 `<NONE>`，鍵表 +3 = 339 鍵）。機制：包裝 `doDebugMenu` ＋ `OnFillWorldObjectContextMenu` ＋ `OnFillInventoryObjectContextMenu` ＋ 包裝 `ISWorldMap.onRightMouseUp`（大地圖選單為視窗內自建，走玩家選單單例 `getPlayerContextMenu(0)`）後處理走訪選單樹，英文→自動推導 key（+→Plus、-→Minus、:→Colon、去非英數）查表，miss 原樣保留。第三方字串僅在與已登記官方字串逐字相同時被同譯文命中（語義相同）；pattern 有 guard。gate＝admin/moderator/UseDebugContextMenu/SP debug/各作弊旗標（`ISFarmingMenu.cheat` 等，對齊 `ISAdminPowerUI` 切換），一般玩家近零開銷。`ISVehicleMenu` 的 `ISVehicleMechanics.cheat=false/true` 為技術切換標籤，刻意保留。**42.20 對版：四個包裝點簽名一字未變**（`DebugContextMenu.doDebugMenu(player, context, worldobjects, test)`、Java 端 `ISWorldObjectContextMenuLogic.java:688` 仍以同樣四參數 `callLuaClass` 呼叫；`OnFillWorldObjectContextMenu` / `OnFillInventoryObjectContextMenu` 仍註冊；`ISWorldMap.onRightMouseUp` 仍在），修補完全有效不需對版 | 管理員/除錯右鍵選單整棵英文 |
| A17 | `shared/Items/RecordedMediaName_Flx.lua` | Java `InventoryItem.load()` 中 `getMediaDataFromIndex` 解析失敗路徑：index 被重設 -1、存檔英文舊名保留、`getMediaData()` 為 null（錨點 `setRecordedMediaIndex`；index **有效**者 load 會自行以載入端翻譯重刷，非本修補範圍，見 C7）| **僅治 index 失效的殭屍媒體物品**：英文名反查表（gen-media-map 自 vanilla recorded_media.lua＋EN Recorded_Media.json 產生，352 條）比對 `getName()`。**重連結（恢復播放功能＋現行翻譯名）僅限單機 SP**（含分割畫面；`setRecordedMediaData(getMediaData(guid))`，guid 查無時保留反查資格不改名）；MP client（含 co-op host 的遊戲進程——host 實為 client＋獨立 server 進程）僅 `setName()` 顯示遷移；dedicated server 進程整檔跳過。跳過 `isCustomName`（flag 64 序列化、跨存檔持久）、跳過名稱帶 getName 前綴（磨損/破損/血跡）者（已知缺口，僅漏修不誤傷）。PZ 更新後重跑 `gen-media-map` 再生反查表（生成器 fail-closed：排版漂移偵測不符即中止不覆寫）。**42.20 對版：Java 側逐字未變**（`setRecordedMediaIndex` / `getMediaData` / `setRecordedMediaData` / `load()` 的 flag 4194304 分支僅行號 +16 漂移），**且不需重跑 `gen-media-map`**（已逐條驗證輸出與現表 100% 相同） | 舊存檔 media index 失效的 VHS/CD 名稱英文殘留 |

| A18 | `client/DebugUIs/DebugContextMenu_Flx.lua`（同檔延伸） | 原 B15-c/d/e、B16、B18、B19：視窗自己呼叫 `ISContextMenu.get(playerNum, ...)` 建選單、不走事件鏈的 7 個掛鉤點——`ISHutchNestBox:onRightMouseUp`、`ISHutchRoost:onRightMouseUp`、`ISAnimalInVehiclePanel:onRightMouseUp`、`ISMiniScoreboardUI:doPlayerListContextMenu`、`ISUsersList:doContextMenu`、`ISCharacterScreen:hairMenu`/`:beardMenu`、`ISVehicleMechanics:doPartContextMenu`/`:onRightMouseUp`。以 `wrapWindowMenu` 包裝後對同一選單物件跑既有 walker（`ISVehicleMechanics` 取 `self.context` 比玩家單例可靠）。walker 另擴充為一併走訪 `option.toolTip` 的標題（涵蓋 B9 的 `Zone not valid`/`Building not valid` 與 `ISWorldObjectContextMenu.lua:234` 的 `Tile params:`）。新增 19 鍵。`require` 全部 pcall 包住，vanilla 路徑異動不會拖垮 A16 主體 | 雞舍/車載動物/記分板/使用者清單/髮型鬍子/車輛機械視窗的除錯選單英文 |
| A19 | `client/DialogText_Flx.lua` | 原 B9 殘餘、B17、B20、B21：官方以字面英文直接建構 `ISTextBox` / `ISModalDialog`。包裝兩者的 `:new`，以「官方英文原句 → 我方鍵」精確查表＋2 條 PATTERNS（`Fuel (0-N):`、`Change <allele>`），miss 原樣保留。**本檔刻意不做權限 gate**——B20 的 MOD 預設集分享/匯入對話框沒有任何 debug/admin gate，是一般玩家在主選單就會看到的英文 | 主選單 MOD 預設集對話框、除錯對話框標題（鑰匙 ID/燃料/堆肥/物品類型/基因顯性）英文 |
| A20 | `shared/Items/ItemNameFix_Flx.lua` | Java `InventoryItem.name` 語言漂移（42.20 反編譯）：建構子 655 行 `name=originalName=建立端語言 DisplayName`；`save` 1708 行僅 `name != originalName` 才序列化；`load` 1947 行先重置為本機 originalName——dedicated server（EN）重建/同步物品時 client 收到固化英文名。`Food.getName()` 1408 行以 `this.name` 為基底名、狀態字即時翻譯，故呈「Bacon (陳腐, 已烹飪)」混血。採集另有 `forageSystem.lua:2270` `setName(getDisplayName() .. " (Wild)")`，伺服器端執行時整串英文。藏寶圖另有 `Stash.java:46` 載入時 `Translator.getText("Stash_AnnotedMap")` 解析＋`StashSystem.doStashItem:153` `setName()`——伺服器生成的藏寶圖固化「Annotated Map」（125 個 stash 共用單一鍵）。建築鑰匙另有 `ItemPickerJava.keyNamerBuilding`（42.20 :2362-2367，zone 分支 Prison/Police/Army :2380-2403）以生成端語言組「物品名 - IGUI_*Key 場所名」後 `setName()`——固化「Key - Army Surplus Store」整串（2026-07-31 玩家回報；A1 僅涵蓋 keyNamerVehicle，本條補其孿生缺口；EN 161 個去重場所名→IGUI_*Key 反查，我方 CH 178 鍵全有譯）。修補：反查表（`gen-item-name-map` 自 vanilla EN/ItemName.json 產生，4,889 條 fullType→EN 名＋EN Wild 字尾）**精確匹配英文建構形才動手**——名稱==該物品 EN 原名→`setName(本地 DisplayName)`；==EN 原名+" (Wild)"→本地名+" (野生)"。名稱==「Annotated Map」（EN Stash_AnnotedMap 值，generator 一併產出）→`setName(getText("Stash_AnnotedMap"))`。名稱==「EN 物品名 - 已知場所 EN 名」→`譯名 - getText(對應 IGUI_*Key)`（僅場所名精確命中反查表才動；車鑰匙後綴為車名不在表中，與 A1 無衝突）。玩家自訂名/演化食譜句式名/媒體名/動物名皆不等於單一 EN 原名，天然不受影響。已知限制：演化食譜（湯/沙拉）句式名伺服器產生亦英文，刻意不處理（需句式反查、誤傷風險高）。dedicated server 進程跳過；掛勾 OnCreatePlayer/OnGameStart/OnFillContainer/OnContainerUpdate/OnRefreshInventoryWindowContainers/EveryOneMinute。**2026-08-02 修正**：原 `onContainerUpdate(container)` 的 `instanceof(container, "ItemContainer")` guard 是死碼（事件不帶 `ItemContainer`，見 A1 註記），世界容器覆蓋自 276c3c5 起實際未生效；已改為 A3 等四檔 idiom（`fixOpenInventoryPages`＋`OnRefreshInventoryWindowContainers`＋`EveryOneMinute` 兜底），console 驗證訊息 `[ItemNameFix] Open-page repair path active`。PZ 更新後重跑 `gen-item-name-map` | MP 伺服器煮食後食物名固化英文、採集物 `Poppies (Wild)` 整串英文（2026-07-31 玩家 titan 回報，伺服器實測煮前中文煮後英文）|
| A21 | `client/DebugUIs/BrushTool_Flx.lua` | 原 B12（2026-08-02 自重複的 A20 改編號為 A21）：Brush Tool 視窗的 `ISButton` 建構參數、`ISComboBox` 選項與視窗 `title`，非選單 `addOption`，walker 結構上涵蓋不到。包裝 `BrushToolManager:createChildren`、`FireBrushUI:createChildren`、`BrushToolChooseTileUI:new` 後改寫既有元件。注意 `ISComboBox:addOption(option)` 是 `table.insert` **原始字串**（`addOptionWithData` 才產生 `{text=...}` 表），故兩種形態都處理且不動索引順序（FireBrushUI 靠 selected 索引判斷類型）。**Help 視窗內的 `Controls:\n...` 長段自由文字刻意不譯** | Brush Tool 視窗按鈕/下拉/標題英文 |

**A16/A18 涵蓋率量化基準（42.20，供下次升版差異對版）**：以 `scripts/check_debug_menu_coverage.py` 掃描（推導規則與 `DebugContextMenu_Flx.lua` 的 `deriveKey` 共用一套）——扣除已知豁免後情境選單英文字面 **168 條，已涵蓋 167（99.4%）**；唯一未涵蓋的 `'servertest'`（`CoopOptionsScreen.lua`）是伺服器預設集識別字，不該譯。另計：開發者編輯器 32 條（B15-f 明確不修）、零呼叫點死碼 3 條（`doBedOption`）、拼接前綴 6 條（執行期由 PATTERNS 處理）、刻意保留 7 條、非選單接收者 31 處。**升版後重跑該腳本，未涵蓋數變動即代表官方新增/移除硬編碼選單項。** 該腳本回報的 178 個「未對應」鍵多半不是真孤兒（Java `getName()` 故事名、tooltip 走 `setName()`），刪鍵前須個別查證。

> **待另案處理（非硬編碼）**：vanilla `CH/Recorded_Media.json` 在 42.20 被官方更新（mtime 2026-07-29 20:02，EN 版未動），代表官方中文媒體名有改動；我方 CH/CN `Recorded_Media.json` 的覆寫值應另做一次差異比對，屬翻譯覆蓋品質議題，與 A17 的英文反查表無關。

> 其餘 `_Flx` 檔（MapStreets、MapLabel、ISRichTextPanel、MainScreen、MapSpawnSelect、ModInfoPanel、CreditsScreen、CatLang*）屬 UI 行為/顯示修補，非硬編碼英文殘留，見 `AGENTS.md` LUA FILES QUICK REFERENCE。

---

## B. 已盤點、待修補（管理員/除錯右鍵選單，2026-07-14 以 42.19.0 全量盤點）

官方在下列位置直接 `addOption("英文")`，無任何翻譯鍵；翻譯 JSON 無從介入，須以 `_orig` 包裝或選單後處理方式修補。共約 126 條硬編碼（DebugContextMenu 鏈 103 ＋ AdminContextMenu 23），叢集如下（行號為 42.19.0）：

> **2026-07-29 二次更新：B 表大部分已修補完成。** 移入 A 表的有——**B12 → A21**（Brush Tool 視窗，原誤編為與 ItemNameFix 重複的 A20）、**B15-c/d/e、B16、B18、B19 → A18**（視窗自建選單接線）、**B9 殘餘對話框標題＋B17＋B20＋B21 → A19**（`ISTextBox`/`ISModalDialog` 建構層攔截）；B9 的 tooltip 三條（`Zone not valid`/`Building not valid`/`Tile params:`）由 A18 擴充 walker 涵蓋。
> **仍未修（刻意）**：B15-f 開發者編輯器群 32 條（純開發工具，投報比過低）、B17 的 `ISAnimalGenomeUI` Add/Remove 按鈕標題（在每幀更新路徑上 `setTitle`，為兩個通用詞付出逐幀成本不划算，其對話框已由 A19 涵蓋）、B12 的 Help 視窗長段說明文字、B10 的 sprite 資源 ID 與 `ISVehicleMechanics.cheat=` 技術切換標籤（本來就該保留原文）。

> **2026-07-29 42.20 對版結論**：B1~B11、B13、B14 **全部「仍存在未變」**——官方檔案路徑無一變動，錨點字串逐字仍在、仍是英文字面、零 `getText`，僅行號 +3～+8 漂移。B6 的 `doCheatMenu` 在 42.20 仍是零呼叫點死碼（vanilla Lua 全樹＋Java 全樹皆無命中）。**B15 拆出兩條移入 D 表**（D4 `ISHealthPanel`、D5 `ISInventoryPage`）。B9 的 `"Tile params:"` 錨點檔案歸屬更正：不在 `DebugContextMenu.lua`，實際位於 `ISUI/ISWorldObjectContextMenu.lua:234`（`option.toolTip:setName("Tile params:")`）。

> **2026-07-14 更新**：B1-B11、B13（右鍵選單本體）已由 **A16** 修補，下表留作官方來源錨點對版用。仍未修的只剩：**B12**（Brush Tool 視窗內部按鈕/標籤，非右鍵選單）、**B9 的非選單殘餘**（ISTextBox 對話框標題 `"Key ID:"`、`"Fuel (Minutes):"`、`"Compost (0-100):"`、`"Fuel (0-N):"`；tooltip `"Zone not valid"`/`"Building not valid"`/`"Tile params:"` 段落）、以及 **B10 的 Copy/Destroy tile 子選單項**（`"[MAIN] "`/`"[OVERLAY] "`/`"[ATTACHED] "` 技術標籤＋sprite 資源 ID，**刻意保留原文**——本體是資源名，翻譯反而妨礙除錯）。A16 的遊戲內驗證待進行（SP `-debug` ＋ MP admin）。

| # | 官方檔案 | 叢集（錨點字串） | 行號範圍 |
|---|---|---|---|
| B1 | `client/DebugUIs/DebugContextMenu.lua` | `"Brush Tool"`、`"Ramps"` 入口 | 127、132 |
| B2 | 同上 | Dev Mode CSV 四項（`"Tailoring to CSV"` 等） | 121-124 |
| B3 | 同上 | Objects 子選單（Window/Door/BBQ/Fireplace/Campfire/Mannequin/Fence/Compost） | 354-463 |
| B4 | 同上 | DeadBody 區 | 485-505 |
| B5 | 同上 | Zombies 子選單多數項 | 523-562 |
| B6 | 同上 | Cheat 區（`doCheatMenu`，定義於 1094；vanilla Lua/Java 均無呼叫點，疑為保留函式，修補前先確認是否可達） | 1095-1108 |
| B7 | 同上 | Randomized Building 區（`"Randomized Building"`、`"Survivor Stories"`、`"Profession"`、`"Basic Randomized Building (including table stories)"`） | 1309-1346 |
| B8 | 同上 | Survivor Swap 區 | 1374-1385 |
| B9 | 同上 | 零星：`"Add "` 前綴(269)、`"Skeleton"`(280)、`"Set Alarm "`(155)、對話框標題 `"Key ID:"`(797)、`"Fuel (Minutes):"`、`"Compost (0-100):"`、tooltip `"Zone not valid"`/`"Building not valid"` | 見括號 |
| B10 | `client/ISUI/ISWorldObjectContextMenu.lua` | `"Brush Tool Manager"`、`"Copy tile"`、`"Destroy tile"`（`doBrushToolOptions`） | 1959-1965 |
| B11 | `client/BuildingObjects/ISUI/ISBuildMenu.lua` | Ramps 四項（`"20 North"` 等，`buildRampsMenu`） | 5-8 |
| B12 | `client/DebugUIs/BrushTool/FireBrushUI.lua`、`BrushToolManager.lua`、`BrushToolChooseTileUI.lua` | Brush Tool 視窗按鈕/標籤（`"Choose tile"`、`"Control fire"`、`"Help"`、`"Fire"/"Smoke"/"Explosion"`、`"Add by click"` 等） | 全檔零星 |
| B13 | `client/DebugUIs/AdminContextMenu.lua` | `AdminContextMenu.doMenu` 管理員工具選單 23 處（`"Tools"`、`"Teleport"`、`"Remove item tool"`、`"Spawn Vehicle"`、`"Horde Manager"`、`"Trigger Thunder"`、`"Make noise"`＋`"Radius: N"`×6、`"Vehicle:"`/`"HSV & Skin UI"`/`"Blood UI"`/`"Remove"`、Door 鑰匙區 `"Get Door Key"`/`"Set Door Key ID (%d)"` 等） | 39-84 |
| B14 | ~~`client/Vehicles/ISUI/ISVehicleMenu.lua` 的 `addOption("Vehicle")`~~ | **已結案（2026-07-14 複查）**：`:597` 為 `--[[ ]]` 註解死碼；`:718` 在 `getDebug() or ISVehicleMechanics.cheat` gate 內，屬 debug 選單，已由 A16 二批涵蓋 | 597（死碼）、718 |
| B15 | 視窗內部選單彙總（同 B12 類，非右鍵選單事件鏈，A16 walker 不涵蓋） | ~~`ISUI/Maps/ISWorldMap.lua`~~（已移入 A16）、~~`XpSystem/ISUI/ISHealthPanel.lua`~~（**官方 42.20 已修，見 D4**）、~~`ISUI/ISInventoryPage.lua`~~（**官方 42.20 已修，見 D5**）、`ISUI/AdminPanel/ISMiniScoreboardUI.lua`（`"Check Stats"`；同選單另四項 Teleport/TeleportToYou/Invisible/GodMod 都已 `getText(UI_Scoreboard_*)`，唯獨這條沒補）、`Vehicles/ISUI/ISVehicleMechanics.lua`（**23 條**：377-404 的 11 CHEAT＋2 DBG、1035-1059 的 8 CHEAT＋2 DBG；DBG 那 4 條屬技術切換標籤建議保留原文，實需譯 19 條）、`ISUI/Hutch/ISHutchUI.lua`（**官方只修一半**：`:450` 已改 `getText("ContextMenu_RemoveAnimal")`，隔壁 `:449` 的 `"Kill"` 沒動；仍硬編碼 5 條，且用的是 **`addDebugOption`** 不是 `addOption`（掃描 pattern 要含這個），譯鍵 `ContextMenu_CatDebug_AddAnimal`/`_RemoveEgg`/`_Forceeggnow`/`_Kill` 早已備妥待接線）、動物「物品欄」選單（`ISInventoryPaneContextMenu.lua:142` 事件前 early-return）、DebugUIs 編輯器群（AttachmentEditorUI 7 條／ObjectViewer 5 條／WatchWindow 4 條／SpriteModelEditor 1 條，另 SeamEditor 4 檔、TileGeometryEditor 7 檔） | 各檔零星 |
| B16 | `client/ISUI/ISVehicleAnimalUI.lua`（2026-07-29 新登記） | `:50` `context:addDebugOption("Kill", ...)`，gate 為 `AnimalContextMenu.cheat and not animal:isDead()`。視窗自建選單不走事件鏈；同選單其餘項已 `getText`。**可直接複用既有 `ContextMenu_CatDebug_Kill` 鍵**，與 ISHutchUI 同一批接線即可 | 車載動物 debug 選單英文 |
| B17 | `client/ISUI/Animal/ISAnimalGenomeUI.lua`（2026-07-29 新登記） | `gene.gd1Btn:setTitle("Add")`、`setTitle("Remove")`、`"Dominant?"`、`"Change " .. allele:getName()`；入口為動物右鍵 `debugSubMenu`（選單項本身有 `ContextMenu_ModifyGenome` 鍵）。同檔群另有 `ISAnimalContextMenu.lua` 的 `"Set Stress"` ISTextBox 標題 | 動物基因編輯視窗英文（僅管理員/除錯） |
| B18 | `client/XpSystem/ISUI/ISCharacterScreen.lua`（2026-07-29 新登記） | `hairMenu`（L334 起）與 `beardMenu`（L479 起）在 `if isDebugEnabled() then` 內 `addOption` 純英文：`"[DEBUG] Grow Long2"`（L360/438）、`"[DEBUG] Grow Fabian"`（L362/440）、`"[DEBUG] Grow Long"`（L493/526），共 6 出現點 3 唯一字串。視窗自建選單，walker 不涵蓋 | 角色資訊視窗髮型/鬍子除錯選單英文 |
| B19 | `client/ISUI/AdminPanel/ISUsersList.lua`（2026-07-29 新登記） | `:476` `context:addOption('Set Role'` 為單引號英文字面，**其子選單反而已用 `getText("IGUI_UserList_SetRole", role:getName())`**——父英文子中文的混雜。gate 為 `Capability.ChangeAccessLevel`。由 `ISUsersList:doContextMenu` 內 `ISContextMenu.get` 自建，可與 B15 的 ISMiniScoreboardUI 合併為「管理員面板視窗內選單」一次處理 | 管理員使用者清單「Set Role」英文 |
| B20 | `client/OptionScreens/ModSelector/ModListPresets.lua`（2026-07-29 新登記，**唯一一般玩家可見**） | `"Mods preset text copied to clipboard"`（SHARE 後的 `ISModalDialog`）、`"Paste here mods preset text:"`（ADD 後的 `ISTextBox` 標題）。按鈕本身有 `getText("UI_btn_share")` / `getText("UI_btn_add")`，但彈窗文字直接寫死，**無任何 debug/admin gate**。非 42.20 新增，是登記簿此前未收錄。修需 Lua 包裝 `ModListPresets.onPresetButton` | 主選單 MOD 預設集分享/匯入對話框英文 |
| B21 | `client/Foraging/ISSearchManager.lua`（2026-07-29 新登記） | `"Enter Item Type:", "Base."` 的 ISTextBox 標題——觸發它的選單項（`"Add Forage Icon Here (x1)"` 等）已由 A16 二批涵蓋，但點下去開的視窗標題 walker 碰不到，屬 B9「對話框標題」同類。同檔另有 `ISSearchWindow.lua` 的 `self:setTitle("DEBUG: "` | 採集除錯對話框標題英文 |

**觀察項（不修，但升版必看）**：`client/ISUI/ISWorldObjectContextMenu.lua:2634` 的 `doBedOption` 內有 3 條**無 gate** 的英文 `addOption`（`"Get On Bed"`、`"Bed: Awake To Asleep"`、`"Bed: Asleep To Awake"`）。全 media 目錄與 42.20 Java 快照搜尋 `doBedOption` 只有這一行定義、**零呼叫點**（同 B6 的 `doCheatMenu`，推測是 WIP 保留函式），故現況 impact 為零。但這是唯一一組沒有 debug/admin gate 的字串，**官方哪天接上呼叫點就會直接變成一般玩家可見的英文**，每次升版務必重查。

**半可修**：B7 的 RB 故事/職業名（Safehouse、Burnt、Looted Shop、Stripclub、School、Spiffo Restaurant⋯）來自 Java 端 `getName()` 動態值，Lua 修補需建「英文名 → 譯文」查表（同 `VehicleKey_Flx` 模式）。

---

## C. 修不到／不修（持續觀察，官方修復後移出）

最後驗證版本：**42.20.0**（全部，2026-07-29）

> **42.20 對版結論：C1~C8 沒有任何一條可移到 D 表。** 核心問題的答案是否定的——`Translator.getTextInternal` 的前綴清單與 42.19 完全相同、**仍無泛用 fallback 表**，無前綴偽 key 依然永遠 miss 回傳原文；vanilla EN 翻譯 JSON 全域 grep 也查不到這些字串的任何 key，官方一個都沒改成正規鍵。C2、C5 標「實作變更」但**變的是 gate 不是字串**：42.20 把 `Core.debug || isUnstableScriptNameSpam()` 從內層 if 上移併進外層 `uiShowContextMenuReportOptions`（四種真值組合逐一驗過，可見性完全等價），`String.format` 格式一字未改。**我方 A16 在 `DebugContextMenu_Flx.lua` 的五條 pattern（TileReport / RoomReportxyz / CoordinatesReportxyz / Nolootdistroforin / Nolootdistrofor）在 42.20 仍逐字吻合，不需對版。**

| # | 項目 | 來源 | 原因 |
|---|---|---|---|
| C1 | `Tile Report` | Lua `ISWorldObjectContextMenu.lua:226` + Java `ISWorldObjectContextMenuLogic.java:5119` | `getText("英文原句")` 偽 key：`Translator.getTextInternal`（42.19.0 反編譯 324-407 行）按 key 前綴 startsWith 路由（`IGUI_`/`ContextMenu_`⋯），**無 fallback 泛用表**，無前綴 key 永遠 miss 回傳原文。任何 JSON 加 key 均無效。**選單顯示層已由 A16 pattern 修補**；官方改掛正規 key 後可淘汰 |
| C2 | `Room Report` | Java `ISWorldObjectContextMenuLogic.java:666` | 同 C1（**選單顯示層已由 A16 pattern 修補**） |
| C3 | `Item Report` | Java `InventoryItem.java:810` | 同 C1（物品 tooltip debug 標籤） |
| C4 | `Calculate Length` | Java `RagdollDebugWindow.java:323` | 同 C1（ImGui debug 視窗） |
| C5 | `Coordinates Report x/y/z`、loot distro 字串、`Add Fluid` 流體名 | Java `ISWorldObjectContextMenuLogic.java`（42.20：Coordinates 在 :677、Add Fluid 子選單在 :4201/4209/4212）、loot distro 在 `ItemPickerJava.getLootDebugString`（42.20 :2164，五則訊息 :2174-2188） | Java 層硬編碼 + 動態組字。**Coordinates Report 與 loot distro 選單顯示已由 A16 pattern 修補**；`Add Fluid` 流體名（`fluidType.toString()` enum 名）仍未修。**錨點更正（2026-07-29）**：登記簿原記的 `ItemPickerJava.java:2173-2186` 對 `Add Fluid` 是錯的——`Add Fluid` 從來不在 ItemPickerJava，它在 `ISWorldObjectContextMenuLogic` 的 `addFluidSubmenu.addOption(fluidType.toString(), ...)`；父選項 `ContextMenu_AddFluid` 本來就有正規鍵（EN/ContextMenu.json:841）。`ItemPickerJava` 那組行號對應的是 loot distro 五則訊息（42.19→42.20 逐字未變，整檔差異只有 `NO_GENERIC_LOOT_CONTAINERS.add(ContainerType.MEDICINE)` 與槍櫃彈藥常數 4/8→2/4） |
| C6 | `Claimed Vehicles Manager`、`Admin Vehicles Manager` | 第三方 Workshop mod「Mysterious Vehicle Claim Key」(3643840023)，key `ContextMenu_MVCK_ClientUserUI/AdminUserUI` | 該 mod 有 CN 無 CH，繁中回退英文。依「翻譯範圍邊界」不處理；可建議玩家向 mod 作者回報補 CH |
| C7 | 舊存檔 VHS/CD 磁帶名稱英文殘留（2026-07-25 玩家截圖：同櫃技能教學帶英文、Z-小隊中文並存） | Java `InventoryItem.load()`：讀回舊 `name` 後呼叫 `setRecordedMediaIndex`，index 有效即 `this.name = mediaData.getTranslatedItemDisplayName()`（42.19.0 反編譯錨點 `setRecordedMediaIndex`、`getTranslatedItemDisplayName`） | **非永久烙印，勿再寫 media data 重刷修補**（2026-07-26 三 lane 對抗驗證一致：42.19 每次讀檔與 MP 反序列化都以載入端當下翻譯重刷媒體名稱；曾實作 `RecordedMediaName_Flx.lua` 經驗證證實無效後撤回——能修的 vanilla 已自修、修不了的〔`getMediaDataFromIndex` 回 null → index 重設 -1、舊名保留〕該修補的 `getMediaData()` nil guard 同樣修不到）。殘留英文僅兩種成因：(a) 載入當下翻譯版本較舊（42.17.0-1.4.0 前無技能帶 RM 鍵）→ 更新 mod 重啟即自癒；(b) media index 解析失敗的殭屍物品（連帶失去媒體功能，vanilla bug）→ **已由 A17 反查表修補處理（2026-07-27）**。診斷：重啟後仍英文 → 右鍵確認有無媒體互動選項 |
| C8 | `Ai Ocha Bottled Green Tea`、`Boss Black Canned Coffee`、`KatKot`、`Chocolate/Strawberry Pukki` 等日系食品名 | 第三方 Workshop mod「Project Gurashi Megurigaoka」(3318210146)，物品定義 `ProjectGurashiItems.txt` | 該 mod 僅自帶 EN/JP/RU 翻譯、無 CN/CH（2026-07-27 查證）；As1 統一漢化亦未收錄（模組包 sources/mods 471 個無此 mod）。依「翻譯範圍邊界」本體不處理。**2026-07-27 使用者核准為模組包原創翻譯首案**（own-mod lane，113 個 mod 自有鍵；SurvivorNames 與 vanilla-override UI 鍵依共存原則排除，詳見模組包 AGENTS.md 原創節） |

| C9 | `Seed: %s`（世界產生種子） | Java `ISWorldObjectContextMenuLogic` 的 report 區塊尾端，42.20 新增 `contextWrapper.addDebugOption(String.format("Seed: %s", WorldGenParams.INSTANCE.getSeedString()), null, null)`（42.19 全快照零命中） | 42.20 新增硬編碼，不走 Translator。本體是技術值（世界種子），比照 B10 的 sprite 資源 ID 判例**刻意保留原文**。gate 同 C2/C5。若日後想譯前綴，可在 A16 walker 加 `^Seed: ` pattern |
| C10 | 車輛音效 debug 疊圖 `Engine Running` / `Alarm Active` / `Siren Active`＋YES/NO | Java 以 `ui.drawTextWithBackground` 直接畫在滑鼠所指車輛上方（42.20 車輛重構隨附） | Java 直接繪製，Lua 無介入點；debug-only |
| C11 | 崩潰畫面紅色 `ERROR` 標題 | Java 例外堆疊疊圖 | 對 539 個 42.19→42.20 有變更的 Java 檔逐檔 diff，篩「新增行 ∩ 顯示層呼叫 ∩ 英文字面 ∩ 無 Translator」後**全快照只命中這一條**。刻意不譯（英文利於玩家回報比對） |

---

## D. 已淘汰（官方修復留檔）

| # | 項目 | 淘汰版本 | 備註 |
|---|---|---|---|
| D1 | `BaseVehicle.keyNamerVehicle` 生成端硬編碼 | 42.17.0 官方改 `Translator.getText` | 修補檔 `VehicleKey_Flx.lua` 降級為舊存檔/MP 遷移層（見 A1），暫不移除。42.20 對版：`keyNamerVehicle` 與 42.19 逐字相同；EN 的 213 個 `IGUI_VehicleName*` 去重後 144 個唯一車名，與我方 `EN_TO_KEY` 的 144 條雙向比對差集皆空，**不需重跑 `gen-vehicle-map`** |
| D2 | `ISWidgetRecipeCategories` 的 `"-- ALL --"` 與英文分類名（原 A14） | 42.20 官方改掛 `IGUI_CraftingCategories_*` | `populateCategoryList` 三處全走 `getText`；實測 29 個製作分類 100% 有鍵。**修補檔 `ISWidgetRecipeCategories_Flx.lua` 與 33 個 `UI_CraftCat_*` 孤兒鍵已於 2026-07-29 刪除**。刪除前已把台灣用詞遷移到 `IG_UI.json` 覆寫，並修正官方兩處誤譯：`Welding` 官方 CH 譯「金工」與 `Metalworking`（金屬加工）撞義 → 改「焊接」；官方 **CN** 更把 `Metalworking` 與 `Welding` **都**譯成「金工」→ 分別改「金属加工」「焊接」。`Assembly` 官方 CH「裝配」（官方 CN 自己是「组装」）→ 統一「組裝」 |
| D3 | `ISBuildWindowHeader` 標題英文（原 A15） | 42.20 官方改掛 `IGUI_BackButton_Building` | `createChildren` 內 `local titleStr = getText("IGUI_BackButton_Building")`；另一來源 `ISBuildWindow.lua:36` 的 `self.windowHeader.titleStr = header .. surface` 兩段也都是翻譯鍵（`IGUI_BuildingWindow_Header` / `_Surface`）。我方修補組出的 `IGUI_BuildWindow_建築` 必 miss 已成 no-op。**修補檔 `ISBuildWindowHeader_Flx.lua` 與孤兒鍵 `IGUI_BuildWindow_Building` 已於 2026-07-29 刪除** |
| D4 | `ISHealthPanel` Cheat 樹 24 條（原 B15 子項） | 42.20 官方改掛 `ContextMenu_*` / `IGUI_Toggle*` / `IGUI_HealthFull*` | 全檔英文字面 `addOption` 命中數為 0，僅剩 `item:getName()` 這類本來就會翻的動態值。我方零接線零補鍵，無修補檔可刪 |
| D5 | `ISInventoryPage` 的 `"Refill container"` / `"Open LootZed"`（原 B15 子項） | 42.20 官方在原行號 1390/1433 就地改 `getText("ContextMenu_RefillContainer")` / `getText("ContextMenu_LootZed")` | ⚠️ **官方把 CH/CN 兩鍵的譯文放反了**：vanilla `CH/ContextMenu.json:858-859` 是簡體「补充容器」「打开 LootZed面板」，`CN/ContextMenu.json:858-859` 反而是繁體「補充容器」「打開LootZed界面」。因翻譯是逐鍵合併、我方原本沒這兩鍵，繁中包玩家會直接看到簡體。**2026-07-29 已補進我方 CH/CN**（CH：補充容器／開啟 LootZed 面板）。A16 walker 涵蓋不到此路徑（非事件鏈，且字面已非英文），只能靠補鍵 |
