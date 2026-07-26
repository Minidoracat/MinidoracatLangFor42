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

## A. 已修補（現行 `_Flx.lua`，PZ 更新後逐條對版）

最後驗證版本：**42.19.0**（全部）

| # | 修補檔（`MOD_ROOT/media/lua/`） | 官方硬編碼來源（錨點） | 症狀 |
|---|---|---|---|
| A1 | `shared/Items/VehicleKey_Flx.lua` | Java `BaseVehicle.keyNamerVehicle`、`ItemPickerJava` 車鑰匙生成（42.17 官方已改 `Translator.getText`，本檔保留作舊存檔/MP 遷移層） | 車鑰匙固化英文名 `Vehicle Key - Chevalier Dart` |
| A2 | `shared/Items/SpawnItems_Flx.lua` | Java `nameAfterDescriptor()` 英文前綴 | ID 卡/護照顯示 `Passport: 角色名` |
| A3 | `shared/Items/DynamicItemName_Flx.lua` | Java `ItemCodeOnCreate` / `RecipeCodeHelper`、官方 Lua `Fishing`——生成時把當下語言烘焙進 `InventoryItem.name` | 照片/書刊/證件/刮刮樂/魚等動態命名殘留英文 |
| A4 | `shared/Items/RecipeLiterature_Flx.lua` | Java `ItemCodeOnCreate` literature `"{物品名}: {配方名}"` | 配方圖紙/剪報英文殘留 |
| A5 | `shared/Items/AnimalProductName_Flx.lua` | Java 動物死亡把 `died.getFullName()` 烘焙進 `IsoDeadBody.customName`；另含活體動物顯示名 | 動物屍體/屠宰肉品顯示 `Gray Female Raccoon (Sow)` |
| A6 | `shared/PerkName_Flx.lua` | Java `IsoGameCharacter.LevelPerk()` 組合 `"+1 " .. perk.getName()` | 技能升級 halo 顯示 `+1 Agriculture` |
| A7 | `shared/RadioData_Flx.lua` | Java 載入 RadioData.xml 時以 `Translator.getText("RD_"..)` 固化 `RadioLine.text` 為載入端語言 | 英文 server 對中文 client 送英文字幕 |
| A8 | `client/RadioCom/RadioWindowModules/RadioChannelNames_Flx.lua` | 官方 Lua `client/RadioCom/RadioWindowModules/RWMChannel*.lua` 顯示層 + Java 把頻道名複製進 `DeviceData` presets 持久化 | 收音機/電視頻道下拉選單英文 |
| A9 | `client/ISRolesList_Flx.lua` | 官方 Lua `ISRolesList` 直接畫 server 端角色欄位 | 內建角色名/預設身分標籤英文 |
| A10 | `client/ISUsersList_Flx.lua` | 官方 Lua `ISUsersList` 硬編碼 `Online` / `Offline` / `Set Role` | 管理員使用者列表英文 |
| A11 | `client/ISUI/Gamepad/GameOptionControllerTab_Flx.lua` | 官方 Lua `client/ISUI/Gamepad/GameOptionControllerTab.lua` `createGamepadBindingPresetsCBox` preset 標籤硬編碼 | 控制器預設集標籤英文 |
| A12 | `client/PlayerStatsXP_Flx.lua` ＋ `server/PlayerStatsXP_Flx.lua` | MP server 回送英文升級 halo（管理面板技能升降；server 端 `setPerkLevelWithoutHalo`） | 管理面板調技能時英文 halo |
| A13 | `client/FishWindow_Flx.lua` | 官方 Lua `client/PZAPI/ui/organisms/FishWindow.lua:109/122/265` 硬編碼 `"Fishing Panel"`、`"Info"`、`"Guide"` | 釣魚視窗標題/分頁英文 |
| A14 | `client/ISWidgetRecipeCategories_Flx.lua` | 官方 Lua `client/Entity/ISUI/CraftRecipe/ISWidgetRecipeCategories.lua:88` 硬編碼 `"-- ALL --"` 及英文分類名 | 製作配方分類英文 |
| A15 | `client/ISBuildWindowHeader_Flx.lua` | 官方 Lua `ISBuildWindowHeader` 標題為英文字串（以 `IGUI_BuildWindow_*` 反查翻譯） | 建造視窗標題英文 |
| A16 | `client/DebugUIs/DebugContextMenu_Flx.lua` ＋ CH/CN `ContextMenu.json` 的 `ContextMenu_CatDebug_*`（336 鍵） | 原 B1-B11、B13 全區：`DebugContextMenu.lua`／`AdminContextMenu.doMenu`／`doBrushToolOptions`／`buildRampsMenu` 的 `addOption("英文")`；Java `getName()` 故事名（RB 33、RVS 23、RZS 41、RDS 31）；Java/Lua 偽 key 選項（Tile/Room/Coordinates Report、loot distro——顯示層 pattern 修補）；**2026-07-14 二批**：`Foraging/ISSearchManager.lua:1608-1635`（搜尋圖示除錯選單）、`ISFarmingMenu.lua:377-402/984-985`（農作 Cheat 區）、`ISFeedingTroughMenu.lua:54-65`、`ISAnimalContextMenu.lua:47/327-413/694`（動物 Debug 區，含 `Make Invincible`/`Remove Invicibility`（官方拼字）於 394-398 以變數組裝；**限世界選單路徑**——動物「物品欄」選單因 `ISInventoryPaneContextMenu.lua:142` 在事件觸發前 early-return 而不涵蓋，見 B15）、`ISHutchMenu.lua:39-40`、`ISVehicleMenu.lua:718-747/923-931`（車輛 debug 區）、`ISInventoryPaneContextMenu.lua:4697`、`ISUI/Maps/ISWorldMap.lua:907-980`（大地圖右鍵選單 17 條，Show Cell Grid／Virtual Animals／Add Tracks 等）；**2026-07-27 三批**：`Context/Inventory/InvContextMedia.lua:16/20`（媒體物品 `prefix .. ": Change recording"` 動態前綴組字（ADMIN/DBG 兩形）＋子選單 `<NONE>`，鍵表 +3 = 339 鍵）。機制：包裝 `doDebugMenu` ＋ `OnFillWorldObjectContextMenu` ＋ `OnFillInventoryObjectContextMenu` ＋ 包裝 `ISWorldMap.onRightMouseUp`（大地圖選單為視窗內自建，走玩家選單單例 `getPlayerContextMenu(0)`）後處理走訪選單樹，英文→自動推導 key（+→Plus、-→Minus、:→Colon、去非英數）查表，miss 原樣保留。第三方字串僅在與已登記官方字串逐字相同時被同譯文命中（語義相同）；pattern 有 guard。gate＝admin/moderator/UseDebugContextMenu/SP debug/各作弊旗標（`ISFarmingMenu.cheat` 等，對齊 `ISAdminPowerUI` 切換），一般玩家近零開銷。`ISVehicleMenu` 的 `ISVehicleMechanics.cheat=false/true` 為技術切換標籤，刻意保留 | 管理員/除錯右鍵選單整棵英文 |
| A17 | `shared/Items/RecordedMediaName_Flx.lua` | Java `InventoryItem.load()` 中 `getMediaDataFromIndex` 解析失敗路徑：index 被重設 -1、存檔英文舊名保留、`getMediaData()` 為 null（錨點 `setRecordedMediaIndex`；index **有效**者 load 會自行以載入端翻譯重刷，非本修補範圍，見 C7）| **僅治 index 失效的殭屍媒體物品**：英文名反查表（gen-media-map 自 vanilla recorded_media.lua＋EN Recorded_Media.json 產生，352 條）比對 `getName()`。**重連結（恢復播放功能＋現行翻譯名）僅限單機 SP**（含分割畫面；`setRecordedMediaData(getMediaData(guid))`，guid 查無時保留反查資格不改名）；MP client（含 co-op host 的遊戲進程——host 實為 client＋獨立 server 進程）僅 `setName()` 顯示遷移；dedicated server 進程整檔跳過。跳過 `isCustomName`（flag 64 序列化、跨存檔持久）、跳過名稱帶 getName 前綴（磨損/破損/血跡）者（已知缺口，僅漏修不誤傷）。PZ 更新後重跑 `gen-media-map` 再生反查表（生成器 fail-closed：排版漂移偵測不符即中止不覆寫） | 舊存檔 media index 失效的 VHS/CD 名稱英文殘留 |
> 其餘 `_Flx` 檔（MapStreets、MapLabel、ISRichTextPanel、MainScreen、MapSpawnSelect、ModInfoPanel、CreditsScreen、CatLang*）屬 UI 行為/顯示修補，非硬編碼英文殘留，見 `AGENTS.md` LUA FILES QUICK REFERENCE。

---

## B. 已盤點、待修補（管理員/除錯右鍵選單，2026-07-14 以 42.19.0 全量盤點）

官方在下列位置直接 `addOption("英文")`，無任何翻譯鍵；翻譯 JSON 無從介入，須以 `_orig` 包裝或選單後處理方式修補。共約 126 條硬編碼（DebugContextMenu 鏈 103 ＋ AdminContextMenu 23），叢集如下（行號為 42.19.0）：

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
| B15 | 視窗內部選單彙總（同 B12 類，非右鍵選單事件鏈，A16 walker 不涵蓋） | ~~`ISUI/Maps/ISWorldMap.lua`~~（已移入 A16，2026-07-14 以 `onRightMouseUp` 包裝涵蓋）、`XpSystem/ISUI/ISHealthPanel.lua`（24 條：Cheat 樹 Toggle Bleeding 等）、`ISUI/AdminPanel/ISMiniScoreboardUI.lua`（`"Check Stats"`）、`Vehicles/ISUI/ISVehicleMechanics.lua`（`"CHEAT: ..."`/`"DBG: ..."` 區，377-404/1028-1052）、`ISUI/ISInventoryPage.lua`（`"Refill container"`:1390、`"Open LootZed"`:1433，loot 視窗容器選單）、`ISUI/Hutch/ISHutchUI.lua`（:155-454 `Add Animal`/`Remove Egg`/`Force egg now`/`Kill`，雞舍 UI 內自建 `ISContextMenu.get`，不走事件鏈；譯鍵已備妥待接線）、動物「物品欄」選單（`ISInventoryPaneContextMenu.lua:142` 事件前 early-return `AnimalContextMenu.doInventoryMenu`，其 `Feed` 等僅世界路徑有翻）、DebugUIs 編輯器群（AttachmentEditorUI/SeamEditor/TileGeometryEditor/ObjectViewer/WatchWindow/SpriteModelEditor 零星） | 各檔零星 |

**半可修**：B7 的 RB 故事/職業名（Safehouse、Burnt、Looted Shop、Stripclub、School、Spiffo Restaurant⋯）來自 Java 端 `getName()` 動態值，Lua 修補需建「英文名 → 譯文」查表（同 `VehicleKey_Flx` 模式）。

---

## C. 修不到／不修（持續觀察，官方修復後移出）

最後驗證版本：**42.19.0**（全部）

| # | 項目 | 來源 | 原因 |
|---|---|---|---|
| C1 | `Tile Report` | Lua `ISWorldObjectContextMenu.lua:226` + Java `ISWorldObjectContextMenuLogic.java:5119` | `getText("英文原句")` 偽 key：`Translator.getTextInternal`（42.19.0 反編譯 324-407 行）按 key 前綴 startsWith 路由（`IGUI_`/`ContextMenu_`⋯），**無 fallback 泛用表**，無前綴 key 永遠 miss 回傳原文。任何 JSON 加 key 均無效。**選單顯示層已由 A16 pattern 修補**；官方改掛正規 key 後可淘汰 |
| C2 | `Room Report` | Java `ISWorldObjectContextMenuLogic.java:666` | 同 C1（**選單顯示層已由 A16 pattern 修補**） |
| C3 | `Item Report` | Java `InventoryItem.java:810` | 同 C1（物品 tooltip debug 標籤） |
| C4 | `Calculate Length` | Java `RagdollDebugWindow.java:323` | 同 C1（ImGui debug 視窗） |
| C5 | `Coordinates Report x/y/z`、loot distro 字串、`Add Fluid` 流體名 | Java `ISWorldObjectContextMenuLogic.java:677/789/4202`、`ItemPickerJava.java:2173-2186` | Java 層硬編碼 + 動態組字。**Coordinates Report 與 loot distro 選單顯示已由 A16 pattern 修補**；`Add Fluid` 流體名（`fluidType.toString()` enum 名）仍未修 |
| C6 | `Claimed Vehicles Manager`、`Admin Vehicles Manager` | 第三方 Workshop mod「Mysterious Vehicle Claim Key」(3643840023)，key `ContextMenu_MVCK_ClientUserUI/AdminUserUI` | 該 mod 有 CN 無 CH，繁中回退英文。依「翻譯範圍邊界」不處理；可建議玩家向 mod 作者回報補 CH |
| C7 | 舊存檔 VHS/CD 磁帶名稱英文殘留（2026-07-25 玩家截圖：同櫃技能教學帶英文、Z-小隊中文並存） | Java `InventoryItem.load()`：讀回舊 `name` 後呼叫 `setRecordedMediaIndex`，index 有效即 `this.name = mediaData.getTranslatedItemDisplayName()`（42.19.0 反編譯錨點 `setRecordedMediaIndex`、`getTranslatedItemDisplayName`） | **非永久烙印，勿再寫 media data 重刷修補**（2026-07-26 三 lane 對抗驗證一致：42.19 每次讀檔與 MP 反序列化都以載入端當下翻譯重刷媒體名稱；曾實作 `RecordedMediaName_Flx.lua` 經驗證證實無效後撤回——能修的 vanilla 已自修、修不了的〔`getMediaDataFromIndex` 回 null → index 重設 -1、舊名保留〕該修補的 `getMediaData()` nil guard 同樣修不到）。殘留英文僅兩種成因：(a) 載入當下翻譯版本較舊（42.17.0-1.4.0 前無技能帶 RM 鍵）→ 更新 mod 重啟即自癒；(b) media index 解析失敗的殭屍物品（連帶失去媒體功能，vanilla bug）→ **已由 A17 反查表修補處理（2026-07-27）**。診斷：重啟後仍英文 → 右鍵確認有無媒體互動選項 |
| C8 | `Ai Ocha Bottled Green Tea`、`Boss Black Canned Coffee`、`KatKot`、`Chocolate/Strawberry Pukki` 等日系食品名 | 第三方 Workshop mod「Project Gurashi Megurigaoka」(3318210146)，物品定義 `ProjectGurashiItems.txt` | 該 mod 僅自帶 EN/JP/RU 翻譯、無 CN/CH（2026-07-27 查證）；As1 統一漢化亦未收錄（模組包 sources/mods 471 個無此 mod）。依「翻譯範圍邊界」本體不處理；模組包依 As1 授權模型待上游收錄自然帶入，或使用者明確要求才做原創相容翻譯 |

---

## D. 已淘汰（官方修復留檔）

| # | 項目 | 淘汰版本 | 備註 |
|---|---|---|---|
| D1 | `BaseVehicle.keyNamerVehicle` 生成端硬編碼 | 42.17.0 官方改 `Translator.getText` | 修補檔 `VehicleKey_Flx.lua` 降級為舊存檔/MP 遷移層（見 A1），暫不移除 |
