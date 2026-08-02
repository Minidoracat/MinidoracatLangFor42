# Changelog

所有重要的變更都會記錄在此檔案中。

格式基於 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)，版本號遵循 `{PZ版本}-{Mod主版本}.{次版本}.{修訂}` 格式。

## [42.20.0-1.13.2] - 2026-08-02

### Fixed

- **世界容器（垃圾桶、木箱等）內的名稱修復實際從未生效**（玩家回報 MP 垃圾桶內車鑰匙整串英文）：`OnContainerUpdate` 事件在 42.20 的全部 51 個觸發點皆不帶 `ItemContainer` 參數，1.13.0 起 `ItemNameFix_Flx`（登記簿 A20）的容器掛勾 guard 恆為 false、整段死碼——食物／採集物／藏寶圖／建築鑰匙的世界容器修復從未執行過。本版改採 `DynamicItemName_Flx` 等四檔已驗證的「掃當前開啟物品欄／戰利品面板」寫法（`OnContainerUpdate` 無參數＋`OnRefreshInventoryWindowContainers`＋`EveryOneMinute` 兜底），並為車鑰匙（`VehicleKey_Flx`，A1）補上原本就缺的世界容器路徑。MP 機制上限不變：server 端資料永遠是生成端語言（client 改名不回傳、不外洩給其他玩家），顯示層「重建→再修」為常態。
- **超速罰單（`Base.SpeedingTicket`）名稱修復漏收**：`nameAfterDescriptor` 動態命名物品中唯一不在 A3（`DynamicItemName_Flx`）反查表的型別，已補進 generator 與 type set（`gen-dynamic-name-map` 重生，EN_ITEM_NAMES 45→46）。
- 登記簿 `BrushTool_Flx` 條目原與 `ItemNameFix_Flx` 重複編號 A20，改為 A21（本 CHANGELOG 歷史條目指標同步更新）。

## [42.20.0-1.13.1] - 2026-07-31

### Fixed

- **建築門鑰匙固化英文名**（`Key - Army Surplus Store`、`Key - Police Station` 等整串英文）：`ItemPickerJava.keyNamerBuilding` 以生成端語言組名後寫死——1.13.0 的 A20 修補只涵蓋食物／採集物／藏寶圖，本版補上這個與車鑰匙（A1）孿生的缺口。`gen-item-name-map` 新增 161 條「EN 場所名 → `IGUI_*Key`」反查表，名稱恰為「EN 物品名 - 已知場所名」才重建為「譯名 - 場所譯名」；車鑰匙後綴為車名不在表中，與既有 `VehicleKey_Flx` 零衝突。已在物品欄／鑰匙圈裡的鑰匙會自動修復，無需重拿。

## [42.20.0-1.13.0] - 2026-07-31

### Added

- **`ItemNameFix_Flx.lua` 固化英文名修復（登記簿 A20）**：修復 MP 伺服器環境下物品名稱被以英文寫死的官方機制問題（玩家回報「培根煮前中文、煮後英文」）。根因：`InventoryItem.name` 是「建立當下語言」的欄位且跨機器同步，dedicated server（英文環境）重建／同步物品時客戶端收到固化英文名；狀態字（陳腐、已烹飪）即時翻譯，故呈「Bacon (陳腐, 已烹飪)」混血。涵蓋三種病徵：
  - 食物經伺服器烹飪後名稱固化英文（`Bacon` → 培根）
  - 採集物 `forageSystem` 主動組名（`Poppies (Wild)` → 罌粟 (野生)）
  - 藏寶圖 `StashSystem` 寫死名稱（`Annotated Map` → 有註記的地圖，125 個 stash 共用單一鍵）
  修補採精確匹配英文建構形才動手——玩家自訂名、演化食譜句式名、媒體名、動物名天然不受影響，零誤傷。已知限制：演化食譜（湯／沙拉）句式名刻意不處理，需另案設計。
- **`gen-item-name-map` 產生器指令**：自 vanilla EN/ItemName.json 產生 4,889 條 `fullType→英文原名` 反查表（比照 `gen-vehicle-map` 模式，PZ 更新後重跑一次即可，fail-closed）。

## [42.20.0-1.12.0] - 2026-07-31

### Added

- **SurvivorNames 6,003 個官方繁中人名採用**：此檔 6,008 鍵過去與官方 EN 逐字相同——本 MOD 實際上把官方既有的中文名蓋回英文（NPC 名、殭屍屍體名牌、建角隨機名）。整批採官方繁中；CN 側官方本身未翻（全英文），以 t2s 由繁中轉出。官方未翻的 5 筆（`Bender`/`JC` 等）維持英文。
- **官方音譯選字修正 18 個名字／22 鍵**：官方選字不作姓氏的硬錯（`Pham 範→范`、`Chau 紂→周`、`Phan 幡→潘`、`Do 督→杜`、`Tran/Chan 辰→陳`、`Le 勒→黎`、`Vo/Vu→武`、`Dang 唐→鄧`、`Ly 賴→李`）與官方自身前後不一致（`Yang/Duong 陽→楊`、`Ng 黃→吳`、`Lam 蘭→林`、`Li 利→李`、`Yu 悠→余` 僅姓氏）。鍵定位、非值取代——`黃` 家族（Huynh/Hoang/Hwang/Huang）零誤傷。
- **三方比對稽核**（官方 EN＝裁判、官方 CH＝對照、我方 CH＝受審）：21,383 筆分歧按風險分帶，core 高風險 1,695 鍵**全量**＋med/flav/lo 抽樣 660 鍵逐筆判讀，每筆 ours_wrong 經獨立對抗複核（推翻誤報 6 筆）。判讀防錨定：第一輪隱藏官方 CH，避免錨定在官方自身的錯譯上。
- **術語真相表與引擎**（`scripts/terminology.json`＋`terminology.py`）：以顯式規則取代 OpenCC s2twp 隱式詞庫——charfix 23 條異體字、replace 129 條（regex 護欄必附正反例，載入時端對端 selftest：pattern 命中＋`convert()` 實跑＋collision 偵測）、select 32 條語境敏感詞禁自動改（通過/透過、高級/高階、性能/效能、打開/開啟、質量/品質、計算機/電腦…）。淘汰規則記 `_dropped`（發佈→釋出、循環→迴圈、壁紙→桌布、鏡像→映象等 s2twp 有害行為），等價裁定記 `_equivalence_adjudication`。經 codex 獨立 review 12 findings 全數修復（`激光標靶` 撞規則 collision、`太陽能計算機`、`泄殖腔`、`發送一隻信鴿` 等 guard 誤傷實證）。
- **outcome-equivalence 等價證明**（`scripts/test_terminology_equivalence.py`）：新術語管線 vs 舊 OpenCC 管線對 REF 全語料 47,677 值逐值比對，1,016 個差異桶全數裁定 PASS。insert/delete opcode 合併成桶（只收 replace 曾漏 432 值假 PASS）、REF 語料下限 gate、ClassC 一簡對多繁收窄至 ≤2 字核心。
- **凍結後維護迴路**：`en-snapshot`（官方 EN 47,251 鍵基準快照，入版控）、`en-diff`（官方更新後產維護佇列——只看 git diff 會漏掉官方改英文原文）、`import-new`（官方 CH 底稿＋術語引擎產新鍵提案，人工簽核入檔；`Credits_Translator` 列刻意排除：官方譯者署名經 fallback 顯示不覆蓋）、`ch-lint`（select/lint 詞巡檢）。
- **`suspicious_patterns` 支援 `skip_files` 整檔豁免**：SurvivorNames 全為人名音譯，「里」恆為正解——62 筆固定誤報歸零。

### Changed

- **CH 凍結**：CH 成品即人工真相，不再由 REF 全量再生——`sync-ch` 墓碑化（顯示維護流程說明，不寫入）、`sync-all`＝CN＋Lua＋fix-check、OpenCC 自本體管線移除（PEP 723 依賴清空）。`ch_overrides.json` 封存為歷史紀錄（值已全數實體化進 CH 檔）。修 CH 一律直接改 MOD CH 檔。CN 管線不變（sync-cn＋cn_overrides 照舊）。

### Fixed

- **三方稽核確認錯誤 114 鍵＋姊妹鍵擴展（CH 約 259 鍵、CN 73 鍵）**：
  - 語意錯譯：`Full Top 頭頂→全上身`、`Ear Top 耳罩→上耳部`、`RESUME 返回→繼續遊戲`、`Clean Burn 清潔傷口→清理燒傷`、`Old Stove 壁爐→舊式火爐`、`Chalk Board 粉筆板→黑板`、`Wanted Notices 懸賞令→通緝令`、`invisible 無敵→隱形`（管理員會誤解指令）、引爆／啟用時間區分、喉縮 (擴散)→(改良縮口)（兩款皆縮小散布，原標註為事實錯誤）、緊身褲→長褲（EN=Pants）等
  - 壞文本：車名後綴重複 **15 鍵跨三車系**（`(東南油漆) (東南油漆)`）、AntiCheat 機翻碎句 20 鍵、`塊石堆步→快石堆步`（同音誤植，含 CN）、逐字空格與標點空格殘留（含 StarterCondition 家族、大型伺服器警告整段）
  - Stash 藏寶圖：空值出貨 22 鍵（官方 CH 有內容我們空白）、`Vicky 維科→薇琪`、`June 桑德拉→茱恩`、`catfish restaurant 酒吧→鯰魚餐廳`、`barricade 架設路障→加固防禦`
  - 名著引文：魯濱遜漂流記對仗、婚誓 `forsaking all others`、Amazing Grace `now I'm found 現在堅定→今被尋回`
  - 台灣用語家族：文胸→胸罩 17、曲奇→餅乾 7、創可貼→OK繃 6、西葫蘆→櫛瓜 7、半身裙→裙子 4、易拉罐 6、懸掛→懸吊 3、僵毀→殭毀 3、格子鬆餅、美式鬆餅、彈珠台、棧板、雪梨、全身鏡
- **舊管線 s2twp 盲轉產物 92 鍵**（術語分類過程的語料稽核挖出，逐筆判讀修復）：`宣告→聲明` 29（新聞/官方 statement）、`釋出→發布` 21（新聞發布會→記者會；釋出僅軟體 release 義）、`社群→社區` 20（住宅/地理）、`效能→性能` 9（汽車）、`高階→高級` 5、`連線→連接` 4（物理）、`繫結→綁定` 4、`區域性→局部`／`全域性→全域` 各 3、`支援→支持` 2 等；以及切詞災難 `河流部分割槽域氾濫`→`部分區域`。
- **needs_human 15 筆全數以遊戲資料實證結案**（tile 定義／藏寶圖腳本座標／媒體 UUID 序列前後文）：修 9 鍵（`斯皮福大牆紙→大型斯皮福牆飾`、`井噴銷售→清倉特賣標牌`、`粗製書架→粗製木層架`、`木製紀念樁→木製墓標`、`None 禁用→無`、LVMap16 兒子遇害讀法等）；6 筆查證後確認原譯正確維持。
- **補譯與其他**：未翻譯 16＋1 鍵（`Accept`、雜誌名 `GameZ/Merc!/Sixteen`、SCBA）、人名 `拉託亞→拉托亞` 5 鍵、`SurvivalGuide_WindowTitle` 逐字空格。

## [42.20.0-1.11.0] - 2026-07-30

### Added

- **`scripts/cn_overrides.json` CN 人工覆寫層**：比照 `ch_overrides.json`，讓 CN 的人工修正在 `sync-cn` 全量再生後保留（schema `{"檔名|鍵": {"value", "ref"}}`，`ref` 供 REF 原文變動時提醒重審）。在此之前 CN 沒有真相層，任何手改都會被 REF 打回，這是 CN 長期累積錯誤而修不掉的結構原因。
- **deny-list 機制**（兩個覆寫層共用 `{"drop": true}`）：登記官方 42.20 已移除／改鍵名的死鍵，防止 `sync` 從凍結在 As1 42.0 的 REF 把它們復活。目前登記 34 筆（`UI_CraftCat_*` → 官方改為 `IGUI_CraftCategory_*`）。**刻意不用「官方 EN 有無」當自動閘門**——實測 REF 有 1320 鍵官方 EN 沒有，其中 1286 鍵仍在正常出貨（`Recipes.json` 一檔 512），自動閘會誤刪。
- **`fix-check` 兩道新檢查**：
  - 逐字空格排版（硬性）：只報「對側語言同鍵無空格」者，故 As1 原有的排版（傳單、城鎮描述）不誤報。這類值會遮蔽疊字偵測，必須守住。
  - 單字／雙字疊段待複核（提示性）：以對側語言交叉過濾，不計成敗——中文正常疊字太多（可可粉／謝謝／咩咩叫），硬擋會逼人關掉檢查。
- **`scripts/test_dupe_patterns.py` 回歸測試**（17 案例）：把片段重複偵測的三類歷史漏檢與兩個「刻意不放寬」的決定鎖住。

### Changed

- **`sync-cn` / `sync-all` 從不可執行修為冪等**：先前跑下去會動 23 檔／2400 行，把 CN 打回 As1 42.0。現在乾淨 tree 上跑為 0 diff——**有 diff 即代表有人改了譯文卻沒登記 override**。
- **字典護欄**（`opencc_fixes.json`）：`圖標→圖示` 加 lookbehind 防吃掉「地圖+標記/標籤」（原會把 `小地圖標記` 寫成 `小地圖示記`）、`里面→裡面` 防吃掉人名「阿里+面前」、`拖動→拖曳` 採用模組包既有的 `(?!\s*物)` 護欄。新增 `許可權→權限`（s2twp 把 `权限` 轉成微軟術語，語料 10 處全為管理員權限語境）。邊界誤傷用 regex 修；語義歧義（`沒通過`/`透過`、餐廳`菜單`/UI`選單`）一律走 override，不疊脆弱前綴護欄。

### Fixed

- **疊字誤植 126 鍵**（CH 88＋38、CN 12＋14 等，可追到 `698c262` 全量潤色）：`白白糖`→`白糖`、`負負八`→`負八`（24 鍵）、`木木吉他`、`丙烷丙烷噴燈`、`為瓦斯噴槍為瓦斯噴槍補充燃料`、`256x256 像素 像素` 等。同一次 commit 造成的損壞有單字、多字、帶分隔符三種形態，只跑一種 pattern 會漏另外兩種。
- **逐字空格排版 1291 筆**（`白 糖` 這種字間有縫的顯示，同樣來自 `698c262`）：只剝「對側語言無空格」者，As1 原有的 305 筆不動；保留 `<SIZE:medium>`、`%1`、`\n` 等標記周圍的空白。此問題還會**遮蔽疊字偵測**（`彈 匣 退 出 退 出` 掃不到），剝除後又浮出 16 筆疊字與漏譯（`與與玩家 N 一起一起`、`中型中型手柄`、`9mm 彈匣退出退出`、CN `攻击距离距离`）。
- **CN 對版官方 42.20（約 430 鍵）**：`db1109f` 的 42.20 對版只做了 CH，CN 從未對版。病徵有三類——舊版資料（`美国 60 号公路` vs 官方 `KY-79` 共 8 處、`Spiffos_Floor` 官方已改名 `Green Diagonal Tiles`、售屋傳單 `2 房 2 衛 1840 平方英尺` vs 官方 `1 房 1 衛 810`）、**多行序列整體錯位一格**（葉慈《The Second Coming》全詩、佛經段落、歌詞、球賽轉播、廣播對話，每行被放到相鄰的鍵上）、零星誤譯（`hitting 305` 打擊率譯成「击出了305」、`Ten-four` 譯成「0-4」、`June 1993` 譯成「5月刊」、`Siberian` 譯成「希伯来」、`Buzz` 人名譯成「嗡嗡声」）。全部逐筆對照官方 EN 判定。
- **CN 未翻譯英文 28 筆**：含 `UI_prof_Tailor` = `Tailor`（角色創建的職業名）、`UI_credits_Design1` = `The Team`，以及大量 `*rooster crows*` 類音效標記。
- **placeholder 不一致 4 筆**（顯示異常風險）：`Tooltip_food_Slice` CH 的 `%1` 被重複成 `%1%1`、CN 完全漏掉；`IGUI_CraftingUI_KnownRecipes` CN 多出遊戲不提供的 `%2`；`Tooltip_Vehicle_WashWaterRequired2` CN 把 `%1` 寫死成字面「1」；`UI_coopscreen_delete_world_prompt` CN 漏掉 `%2`。修後 CH/CN/EN 全語料 placeholder 集合 0 不一致。
- **過時的 joypad 按鍵提示**：`IGUI_Tutorial1_Shotgun1bJoypad`／`GUI_Tutorial1_Shotgun4Joypad` 的 CN 仍用 `<JOYPAD:BButton>`，官方已改為 `ClimbThrough`＋`Interact`——手把玩家會看到錯的按鍵。
- **伺服器選項說明缺值**：`UI_ServerOption_MapRemotePlayerVisibility_tooltip` 官方有 4 個值，CN 只列 3 個且把 `3` 標成「显示所有人」，會誤導伺服器管理員。
- **公司名被誤譯**：`General Arcade`→「通用游戏厅」、`The Tea Division`→「茶水部门」改回原文，與同表的 `Vertex Break`、`Formosa Interactive` 一致（該表 46 筆中，42 筆職務類別翻譯、4 筆外部公司名保留原文）。
- **CH 誤譯 2 處**：`Print_Text_HouseforSale895_info` 的 garage 譯成「房屋」（應為車庫）；`RadioData` 5 個鍵的「…展現遠見卓識和奉獻精神」是上一句的內容且漏掉 exemplary career（此處 CN 反而正確）。
- **`許可權`／`權限` 用詞不統一**（10 處 vs 13 處）：全部統一為 `權限`。

## [42.20.0-1.10.1] - 2026-07-30

### Fixed

- **選 Riverside 開局時，出生點被本 MOD 覆蓋成 B41 舊座標**：模組目錄誤留了一份 `maps/Riverside, KY/spawnpoints.lua`（自初版即存在，從未更新）。PZ 的 `ZomboidFileSystem` 會讓 MOD 檔覆寫同相對路徑的官方檔，而 `LuaManager.createRegionFile()` 正是逐一讀取各城鎮目錄下的 `spawnpoints.lua` 來組出生區域，因此這份舊檔實際生效。舊檔只有 10 個職業（官方 42.20 為 25 個）、座標為 B41 時代資料：這 10 個職業被送往舊座標，其餘 15 個（木匠、農夫、漁夫、伐木工、金屬工、鐵匠、老兵等 B42 職業）則依 `CharacterCreationProfession.lua` 的 fallback 全部沿用「無業」的舊座標。移除後改由官方檔提供出生點。純翻譯 MOD 不應動到出生點。
- **7 個僅限沙盒的城鎮會出現在非沙盒模式的出生城鎮清單**：`MapSpawnSelect_Flx.lua` 覆寫 `fillList()` 時，漏抄了官方 42.20 新增的 `only_for_game_mode` 過濾條件。官方把 Brandenburg、Echo Creek、Ekron、Fallas Lake、Irvington、March Ridge、Valley Station 標記為 `only_for_game_mode=Sandbox`，未過濾時這 7 個城鎮在末日／生存等模式下也會被列出。

### Removed

- **再次清除誤留在模組目錄內的開發工具狀態檔**（2 個 `.omc/` 目錄、5 個檔案）。這些檔案已隨 1.10.0 上傳到 Workshop，內容僅為開發工具自身的執行計數與提示節流時間戳，不含任何個人資料或對話內容。Workshop 上傳是整包打包、不參照 `.gitignore`，發布流程已加入 `MOD/` 隱藏檔檢查以免重演。

### Notes

- 本次未新增或修改任何譯文。
- 一併核對其餘 18 個覆寫檔是否有同類「複製官方函式後未跟進版本」的問題：`MapSpawnSelect_Flx.lua` 為唯一一例，其餘不是保存原函式再包裝，就是刻意重寫且功能與官方 42.20 對等。

## [42.20.0-1.10.0] - 2026-07-29

### Added

- **42.20 新文本補譯**（繁簡各 452 鍵）：可搬運物件 223（監獄設施招牌、紡織／皮革／陶藝製作站、遮陽棚與地毯燈具等，搬運與拆卸時直接可見）、遊戲內 UI 111（製作分類 31、流體單位 14、動物與物品名前綴等）、右鍵選單 29、UI 21（含 42.20 新增的**光敏性癲癇警告整頁 8 行**，遊戲啟動即顯示）、製作人員名單 16、挑戰模式 4（「世界之巔」「28分鐘毀滅倒數」）、沙盒 3、提示 1，另含硬編碼修補所需的 40 鍵與漢化組署名 2 鍵。譯文以官方繁中為底稿再套本 MOD 的台灣用語規則，非機器直轉。
- **補上官方漏掉的讀檔畫面模式名**：`IGUI_Gametime_Top Of The World` 與 `IGUI_Gametime_28 Minutes Later` 在官方 EN 就不存在，導致玩過這兩個新挑戰後，讀檔畫面的「遊戲模式」欄直接印出英文字面。
- **視窗內自建選單翻譯接線**（登記簿 A18）：雞舍、車載動物、管理員小記分板、管理員使用者清單、角色資訊視窗髮型／鬍子、車輛機械視窗共 7 個掛鉤點，並擴充為一併翻譯選項的 tooltip 標題。這些視窗自建情境選單、不走事件鏈，原本的選單走訪器結構上涵蓋不到。
- **`DialogText_Flx.lua`**（A19）：攔截 `ISTextBox` / `ISModalDialog` 建構層的硬編碼英文提示。其中**主選單 MOD 預設集的分享／匯入對話框沒有任何權限限制，是一般玩家就會看到的英文**，其餘為除錯對話框標題（鑰匙 ID、燃料、堆肥、物品類型、基因顯性）。
- **`BrushTool_Flx.lua`**（A21，原誤編 A20、2026-08-02 於登記簿改號）：Brush Tool 除錯視窗的按鈕、類型下拉與視窗標題。
- **`MainOptions_Flx.lua`**：在「遊戲設定→使用者介面→語言」的譯者清單補回漢化組署名。
- **`check_debug_menu_coverage.py`**：除錯／管理員選單硬編碼涵蓋率檢查工具，PZ 升版後重跑即可看出官方是否新增或移除硬編碼選單項。涵蓋率自 65.5% 提升至 **99.4%**（167/168，唯一未涵蓋者為伺服器預設集識別字，本就不該翻譯）。
- **`fix-check` 新增譯文片段重複檢查**：偵測潤色擴寫短譯時把新增片段貼兩次的錯誤，附注入式回歸測試。

### Fixed

- **多人伺服器管理員調整玩家技能可能導致該玩家被踢除或封鎖**（登記簿 A12）：42.20 重寫了 XP 反作弊，判定改為逐技能、基準值需以新增的 `updateXpChecker()` 重設；官方替自家所有加 XP 路徑都補上了，但本 MOD 的技能同步修補繞過官方指令、未同步重設，會被判定為 XP 異常成長。
- **繁體中文包出現簡體字**：官方 42.20 把「補充容器」「開啟 LootZed 面板」兩個鍵的繁簡譯文放反（繁中檔放簡體、簡中檔放繁體），本 MOD 補上正確譯文覆蓋。
- **製作分類誤譯**：官方繁中把 `Welding` 譯為「金工」，與 `Metalworking`（金屬加工）撞義 → 更正為「焊接」；官方簡中更把兩者都寫成「金工」 → 分別更正。`Assembly` 統一為「組裝」。
- **14 處譯文片段重複**（既有問題，追溯至 1.8.0 的全量潤色）：「顯示與效能與效能」→「顯示與效能」、「以以新角色繼續繼續」→「以新角色繼續」，另有「縫補破洞破洞」「武器擊中車輛零件零件」「肉桂色肉桂色小抽屜桌」「紅橡木紅橡木辦公桌」「昂科牌業餘昂科牌業餘無線電臺」「草藥療法療法」「為瓦斯噴槍為瓦斯噴槍補充燃料」「無靠背無靠背橡木長椅」「在這裡加滿油加滿油」「驚嚇音效音量音量」「鐵匠知識知識」「將玩家將玩家傳送至此」。
- **媒體磁帶誤譯**：烹飪節目口頭禪 `Bam!` 原譯為「OK!」，更正為「砰!」。
- **漢化組署名在 42.20 消失**：官方移除了 `credits.txt` 的讀取，改為只讀遊戲本體目錄的譯者名單檔（MOD 無法覆寫）。署名改以自有翻譯鍵重新接回製作人員名單與語言設定頁。

### Changed

- **最低支援版本提升至 Build 42.20.0**。
- **台灣用語字典新增 4 條規則**（本體與模組包同步）：`墻→牆`、`坐標→座標`、`數據包→封包`、`拖動→拖曳`。

### Removed

- **`ISWidgetRecipeCategories_Flx.lua`、`ISBuildWindowHeader_Flx.lua`**：官方 42.20 已為製作分類與建造視窗標題掛上正式翻譯鍵，兩個修補已成空轉，連同 34 個孤兒鍵一併移除（台灣用詞已先遷移至翻譯檔覆蓋）。
- **`language.txt`、`credits.txt`（繁簡各一份）**：PZ 42.20 起完全不再讀取這兩個檔案。
- 清除誤留在模組目錄內的開發工具狀態檔（10 個檔案，原本會隨 Workshop 一併上傳）。

### Notes

- 本次以 42.20.0 反編譯快照對硬編碼追蹤登記簿全表逐條對版（A 表 17 條、B 表 21 條、C 表 8 條）。官方在 42.20 做了一輪「硬編碼英文改掛翻譯鍵」整理，但 `Translator` 的前綴路由仍無泛用 fallback，`Tile Report` 這類無前綴偽 key 依然無法以翻譯檔修復。
- 42.20 的翻譯載入為「逐鍵合併」而非整檔取代：本 MOD 未覆寫的鍵會沿用官方繁中譯文，不會顯示英文。

## [42.19.0-1.9.1] - 2026-07-27

### Fixed

- **釣魚視窗翻譯修補加入模板防護**（`FishWindow_Flx.lua`，玩家回報追查）：第三方 MOD 修改／損壞釣魚視窗（`PZAPI.UI.FishWindow`）結構時，不再產生 `attempted index: bar of non-table: null` 錯誤訊息——該視窗安靜維持原文並於 log 註明原因（模板缺節點時支援部分翻譯）。正常環境行為完全不變；未來 PZ 改版變更該視窗結構時同樣安靜降級。註：視窗結構被改壞本身屬該第三方 MOD 的相容性問題，需由其作者修復。

## [42.19.0-1.9.0] - 2026-07-27

### Added

- **殭屍磁帶名稱修復 `RecordedMediaName_Flx.lua`**（登記簿 A17）：修復 VHS/CD 媒體物品在 media index 失效後，名稱永久保留生成端英文的問題（玩家截圖回報追查）。單機端以 `setRecordedMediaData()` 重新連結媒體資料——**連播放功能一併恢復**；MP 客戶端做顯示層改名。index 有效的媒體物品由遊戲讀檔時自行以現行翻譯重刷、不受影響（C7 調查沿革：42.17.0-1.4.0 前生成的技能教學帶烙印英文，更新翻譯後讀檔即自癒；僅 index 失效的殭屍物品需本修補）。
- **`gen-media-map` 反查表生成工具**：自 vanilla 媒體定義＋EN 翻譯生成 352 條英文媒體名反查表（AUTO-GEN 注入 Lua，排版漂移偵測不符即中止不覆寫）。
- **fix-check 跨專案字典一致性檢查**：本體與模組包 `opencc_fixes.json` 的規則與 suspicious 排除清單自動比對，無註記分岔即報告（已裁決語境分岔以 note「分岔／勿移植」放行）；附回歸測試 `test_dict_sync.py`（9 案例）。

### Fixed

- **管理員／除錯媒體右鍵選單翻譯**（A16 三批，鍵表 336→339）：`ADMIN/DBG: Change recording`→「更換錄製內容」、`<NONE>`→「<無>」（`InvContextMedia.lua` 動態前綴組字硬編碼）。
- **簡中（CN）補齊 8 個世界物件繞路鍵**：窗戶、窗簾、營火、藍色復古燈、星球燈、咖啡機、烤麵包機、餵食——先前僅繁中有鍵，簡中玩家這些物件的右鍵選單標題顯示英文；CH/CN 鍵集恢復完全一致。

### Notes

- 玩家回報的日系食品英文名（Ai Ocha 綠茶、Boss Black 咖啡、KatKot、Pukki 餅乾棒等）查證為第三方 MOD「Project Gurashi Megurigaoka」(3318210146) 內容：該 MOD 僅自帶 EN/JP/RU、無任何中文，非本 MOD 缺漏（登記簿 C8）。

## [42.19.0-1.8.2] - 2026-07-21

### Changed

- **泥作（plaster/trowel）家族台灣化**（玩家反饋裁決＋codex 交叉判讀，28 鍵）：
  - `PlasterTrowel`「鏝刀」→「**抹刀**」：「鏝刀」是台灣泥作正式術語但一般玩家陌生（社群反映「沒聽過」），依裁決改用通俗名；「石工抹刀」（Mason's Trowel）、「木製石工抹刀」（Wooden Trowel）EN 有別、維持不變。
  - 動詞 plaster「抹灰」（大陸用語）→「**上灰泥**」：建造選單、配方、tooltip 全面替換。
  - 桶裝 Plaster 成品「石膏」→「**灰泥**」：一桶 Plaster 可由「石膏粉＋水」或「生石灰＋水」兩條配方調成，生石灰調出的是石灰泥並非石膏，成品採泛稱「灰泥」才涵蓋兩條配方（Quicklime 提示「用作石膏」屬化學錯誤，修正為「調製成灰泥」）；原料 `PlasterPowder` 保留「袋裝**石膏粉**」——台灣五金行品名，原料用具體名、成品用泛稱。
  - paint 統一「**刷漆**」：「粉刷」依教育部辭典兼指灰作與油漆施工，與 plaster 易混淆，避用；Paintbrush 引用寫回「油漆刷」。
  - 「牆紙」→「**壁紙**」全家族統一（七色壁紙＋壁紙膠粉）。
  - 「塗鴉」（Paint Sign 骷髏／箭頭彩繪）全族既有一致，維持不動。

### Fixed

- `ContextMenu_CantPlaster` 指錯工具：EN 明示需要 Plaster Trowel，原譯寫成「石工抹刀」→「抹刀」，材料「石膏」→「灰泥」。
- legacy 灰泥配方鍵（`Recipe_Make_Bucket_of_Plaster` 系）「石膏」同步為「灰泥」。

## [42.19.0-1.8.1] - 2026-07-20

### Fixed

- **B42 冶金家族 EN 錨定殘漏補齊**（玩家回報追查，8 鍵）：小金屬板→小鋼板（Steel Sheet - Small）、金屬管 (斷裂)/(鐵軌釘)→鐵管（Broken Iron Pipe／Iron Pipe with Railspike）、金屬棒 (1/2)/(1/4)→鋼棒（Steel Rod Half/Quarter）、「將金屬板鋸成鋼片」→「將鋼板鋸成小鋼板」（原譯產物指錯物品）、「切割金屬板」→「將鋼板切割成小鋼板」、「鍛造小型鋼板」→「鍛造小鋼板」。SheetMetal＝鋼板（Steel Sheet）維持——B42 顯示名已區分鐵/鋼（Iron/Steel Bar・Ingot），「金屬片」提議經查證不採納。

## [42.19.0-1.8.0] - 2026-07-20

### Added

- **`scripts/ch_overrides.json` 人工覆寫層機制**：sync-ch 機轉全量再生後套用人工真相檔（6,449 筆，schema `{"檔名|鍵": {"value", "ref"}}`，ref 為登記時 REF 原文 hash）——REF 原文變更時提醒重審、鍵從 REF 消失時提醒清理、缺檔報錯不自動建骨架。sync-ch 自此**冪等可安全重跑**，人工潤飾不再被上游同步洗掉。streets.txt 不再誤生成（未版控無消費端）；credits.txt 標人工維護檔，sync-cn/sync-ch 雙向退出同步。

### Changed

- **As1 REF v3.20 甄選同步**：以 vanilla EN 42.19 錨定逐鍵判定（As1 倉庫疑遭歷史重寫、v3.19/v3.20 對 SurvivalGuide/Recorded_Media/城市描述/Credits 含大量舊譯回退，「REF 較新≠較好」）——接受真更新（地址修正、JOYPAD 語意 token 對齊 42.19 鍵位綁定、文案更新），以 override 保護高品質重譯版與既有人工修正；ContextMenu 新增 8 鍵。
- **全量術語統一**（40 組詞、448 鍵）：殭屍（含遊戲名「殭屍毀滅工程」）／選單／清單／目前／透過／倖存者／使用者／品質／資訊／介面／互動／建立／相容／載入／登入／預設／圖示／視窗／游標／搜尋／自訂／點擊／教學／控制器等；Moodles→狀態／狀態圖示、Workshop item→物品（Steam 官方譯法）、Valley Station 統一「山谷站」、城市描述專名依專案標準（星聚影城、爆紅錄影帶租賃、五級火辣餐館、歐文頓 Speedway 賽道、極限方程式）。
- **全量深度潤色**（一簡對多繁 62 組字表掃描＋1.9 萬鍵 EN/CN/CH 三方逐句審讀，6,500+ 條修正）：嚴重誤譯修正（DESTROY YOUR SAVIOURS、quiche 法式鹹派、Cock a Rifle 槍機上膛、pupil 義眼瞳孔、left it here 反譯、Man alive 慣用語）、漏譯補回（how and when、FCC 與 CDC、球賽局數）、Moodles 全系列語意校正（Exhausted／Hopeless／At Breaking Point 等）、農作物台灣名（青花菜／馬鈴薯／高麗菜／櫛瓜／地瓜）、字形修正（控制檯→控制台、櫃臺→櫃檯、天后→天後、遊泳／游泳分流、不準→不准、量詞隻）。

### Fixed

- OpenCC 字典新增 50+ 條防護規則（制作、龍捲風、合並、型別、另一頭髮生等，含 CJK 空格版 pattern 與跨詞誤傷防護）；suspicious 巡檢排除清單擴充（秀髮／生髮／峇里島／蒂伯雷里／里子等正確用法不再誤報）。
- airmass「空氣質量」誤譯修正為「氣團」（ClimatePlotter 三鍵）；petting zoo 三鍵定名「可愛動物區」；Shotgun3 手把教學依 EN 重寫（原版紅圈誤作綠框、瞄準／射擊按鍵顛倒）；上游 typo 鍵 `GUI_Tutorial1_Shotgun4Joypad` 內容搬移至正確鍵（CH/CN）；`%1%` placeholder 崩潰修正與 `6%。` 安全標點持續受 override 保護。

## [42.19.0-1.7.0] - 2026-07-14

### Added

- 管理員/除錯右鍵選單完整翻譯（新增 `client/DebugUIs/DebugContextMenu_Flx.lua`）：官方在除錯/管理員選單大量直接 `addOption("英文")` 且無翻譯鍵，本版以「選單建好後走訪替換」機制在顯示層修復。四個掛載點涵蓋：世界右鍵除錯/管理員選單（除錯全區、AdminContextMenu 工具選單、筆刷工具、坡道、農作/畜牧/飼料槽/車輛除錯選項、搜尋圖示除錯選單）、物品欄除錯選單、大地圖右鍵選單。Randomized Building/Vehicle/Zone 故事名（RB 33、RVS 23、RZS 41、RDS 31，自反編譯 Java 提取全集）一併翻譯；共新增 336 個 `ContextMenu_CatDebug_*` 翻譯鍵（CH/CN 同步）。
- 連官方 `getText("Tile Report")`/`"Room Report"`/`"Coordinates Report"` 這類「英文原句偽 key」（Translator 前綴路由查不到、任何翻譯檔都攔不到、永遠顯示英文）也以 pattern 規則在選單顯示層翻出。
- 安全設計：僅在 admin/moderator/除錯模式/各作弊旗標啟用時執行，一般玩家零成本；查無翻譯一律原樣保留，第三方 mod 選單字串不受影響；後處理以 pcall 隔離，任何失敗不影響右鍵選單本體。
- 新增 `HARDCODE_REGISTRY.md` 硬編碼追蹤登記簿：官方 Java/Lua 硬編碼英文殘留的唯一集中紀錄（A 已修補 / B 待修補 / C 修不到‧不修 / D 已淘汰＋PZ 版本更新盤查 SOP），既有 15 個 `_Flx` 修補全數回填登記；「硬編碼修補登記制度」同步寫入 AGENTS.md。

### Fixed

- 修正 `scripts/sync_translations.py` fix-check 在掃到工具 runtime state（`.omc/`）JSON 時崩潰的問題（rglob 跳過 `.omc` 目錄）。

### Notes

- 玩家如回報管理員選單仍有英文：`Claimed Vehicles Manager`/`Admin Vehicles Manager` 來自第三方 mod「Mysterious Vehicle Claim Key」（Workshop 3643840023，有簡中無繁中），屬該 mod 範圍，建議向其作者回報補繁中。
- 已知刻意保留英文：筆刷工具「Copy/Destroy tile」子選單的 `[MAIN]`/`[OVERLAY]`/`[ATTACHED]`＋sprite 資源 ID（資源名，翻譯反妨礙除錯）、除錯工具視窗內部按鈕（Brush Tool 管理視窗、健康面板 Cheat 樹、載具機械 CHEAT 區等，見登記簿 B12/B15）。

## [42.19.0-1.6.7] - 2026-06-14

### Added

- 新增伺服器端與客戶端的 MOD 版本顯示：遊戲 / 伺服器啟動時於 console 與 DebugLog 印出 `CatLangFor42 v{版本} [Client/Server]`。版本動態讀取 `mod.info` 的 `modversion`（`getModInfoByID("CatLangFor42"):getModVersion()`），不寫死、不會過期，方便對照玩家回報時是否使用最新版本。新增 `shared/CatLangVersion_Flx.lua`（`getVersion` / `printBanner`）、`client/CatLangVersion_Client.lua`（`OnGameBoot`，含每 process 只印一次的旗標）、`server/CatLangVersion_Server.lua`（`OnServerStarted`）。

### Fixed

- 修正 `client/CatLangDiag.lua` 診斷工具開頭印出的版本字串寫死且過期（`42.15.1-1.2.0`），改為動態讀取 mod.info，與實際版本一致。
- 版本 banner 改為純 ASCII 輸出：PZ 的 Lua `print()` 寫入 DebugLog / console 不支援多位元組 UTF-8 中文（會變 `?` 亂碼），故 banner 內的中文標語改為 ASCII；版本號等關鍵資訊本即 ASCII、顯示正常。

### Notes

- 此版為工具 / 可維護性改善，未變動任何翻譯內容。
- AGENTS.md 新增「JDK 格式實證流程」：用本機 JDK 實跑 `String.formatted()` 驗證翻譯 `%` 格式是否會 crash 的方法與危險簽名（字面 `%.`）。

## [42.19.0-1.6.6] - 2026-06-13

### Fixed

- 修復「動物屍體」名稱在畜牧指定區視窗（`ISDesignationAnimalZoneUI` 屍體清單，紅字）、屍體右鍵選單 / 取骨選項、屠宰掛鉤 UI 等處，於 MP / 舊存檔 / dedicated server 仍顯示生成端語言（玩家回報「Gray Female Raccoon (Sow)」「Gray Male Raccoon (Boar)」）的動態命名殘留。官方在動物死亡時把 `died.getFullName()`（當下語言組譯結果）烘焙進 `IsoDeadBody.customName` 並存檔，而上述 UI 直接讀 `getCustomName()` 顯示，繞過 1.6.4 已加的 `IsoAnimal.getFullName` 顯示層包裝；該名稱也因走 `getCustomName` 路徑而不含 `(Wild)` 後綴。
- `AnimalProductName_Flx.lua` 新增 `IsoDeadBody.getCustomName` 與 `IsoAnimal.getCustomName` 兩個顯示層包裝：僅當原始 customName 完全比中系統生成名模式（`sourceAnimalNameMatches`，EN/CH/CN 來源名表）時，以當前語言重組「動物名本身」回傳；一併涵蓋動物資訊面板標題、基因面板、繫繩子選單、車輛拖車等同樣直接讀 `getCustomName` 的官方顯示面。重組只回傳動物名本身、不外加 `IGUI_Item_AnimalCorpse/Skeleton` 外殼（由各 UI 自行包），避免雙重包殼。
- 純顯示層：玩家自訂動物名一律透傳、零影響；不呼叫 `setCustomName`、不改寫存檔；存檔 / load / MP 同步皆走 `customName` 欄位（非 getter）不受 Lua 覆寫影響；dedicated server 不安裝（`shouldRunClientRepair`）。屍體物品名與既有 `getFullName` 覆寫相容、不重複翻譯。

### Notes

- 動物「頭頂世界浮動名牌」（`IsoAnimal.renderCustomName` 直接讀 customName 欄位、不經 getter）非 Lua 可攔截範圍，本次不涵蓋；如有此類回報需 Java patch（本 MOD 無此能力）。

## [42.19.0-1.6.5] - 2026-06-11

### Fixed

- 修復 MP 連線佇列畫面（LoadingQueueUI）溼度顯示的崩潰風險（玩家回報）：`UI_GameLoad_humidity` 原值「溼度: %.1f %」的裸尾 `%` 會原樣進入 Java `String.format` 並觸發 `UnknownFormatConversionException`（JDK `Formatter.parse` 對 trailing `%` 直接拋例外），CH / CN 均改為「%.1f %%」。
- 此字串不含 `%N` 編號佔位符，不在 Translator 載入期自動轉義的範圍，與 `%1%` 形式的規則不同——已同步修正 AGENTS.md 的百分比規則，明確區分兩種機制。vanilla EN 的 `Humidity: %.1f %` 帶有同樣的官方 bug，本次僅修正 CH / CN 側。

## [42.19.0-1.6.4] - 2026-06-11

### Fixed

- 全面修復 PZ 42.19 官方 Java `ItemCodeOnCreate` / `RecipeCodeHelper` 與官方 Lua `Fishing` 在物品生成時把當下語言名稱烘焙進 item name 的動態命名殘留（新增 `DynamicItemName_Flx.lua`）。涵蓋：雪花玻璃球、照片 / 隱密照片 / 限制級照片 / 老照片、明信片、塗鴉、墜飾、主題書籍與平裝書、主題雜誌 / 電視雜誌 / 火辣女郎雜誌、漫畫、新報紙 / 舊報紙、傳單 / 小冊、型錄 / RPG 手冊、股票、寵物狗牌、郵件 / 手寫信、名片、證件（身分證 / 護照 / 徽章 / 信用卡 / 記者證 / 軍牌等）/ 印章戒指、中獎刮刮樂、魚與魚餌底料。
- modData 保有翻譯 key 的類型直接以當前語言重建；只保存烘焙文字的類型（雪花玻璃球、舊報紙、寵物狗牌、股票、信件、名片）以名稱解析搭配「英文原文 → IGUI key」反查表重組，解析不到的名稱（含玩家自訂名）一律不動，亦不觸碰 collectibleKey / literatureTitle 等已讀與收藏追蹤 modData。
- 修正 `IGUI_SnowGlobeOf` 翻譯格式順序（原「%1 的 %2」會輸出「雪花玻璃球 的 摩洛哥」，改為與照片一致的「%1 (%2)」呈現「雪花玻璃球 (摩洛哥)」），舊格式殘留名稱由 Lua 修補自動遷移。
- 修復「活體動物」名稱在 MP / 舊存檔顯示生成端語言（如右鍵選單標題「Holstein Bull」）的問題：官方會在牧場世界生成幼崽、由屍體或抓取物重建動物、MP 同步時把組譯結果烘焙進活體動物 customName 並原樣存檔。`AnimalProductName_Flx.lua` 新增 `IsoAnimal.getFullName` 顯示層包裝，customName 匹配系統生成名模式（EN/CH/CN）時以當前語言重組，一次涵蓋右鍵選單、撿起/宰殺選項、動物資訊面板、畜牧區與雞舍 UI 等所有 Lua 顯示面；玩家自訂動物名不受影響，不改寫存檔資料。

### Added

- `scripts/sync_translations.py` 新增 `gen-dynamic-name-map` 子命令：從 vanilla EN 翻譯自動產生 `DynamicItemName_Flx.lua` 的 AUTO-GEN 反查表（EN 物品名 45、地名 900、舊報紙 25、寵物名 229、信件 24、公司 63、職業 116 條），PZ 版本更新後一鍵重生。

### Notes

- 玩家截圖中其餘英文項目經查證皆屬第三方 mod 範圍，本 MOD 僅涵蓋官方內容、不予處理：「Equipped Items」清單列為 CleanUI（有 CN 無 CH）、Rondel Dagger 與 Bastard Sword Sheath 為 MedievalZ（僅附英文）、原始 key `Fluid_Container_HydrationBackpackPlus` 為 BagUpgradePlus（未附任何 Fluids 翻譯，所有語言皆顯示 raw key）、Tactical Flashlight 推測為 KATTAJ1 系列 mod。請玩家向各 mod 作者或第三方 mod 漢化包回報。

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
