# Changelog

所有重要的變更都會記錄在此檔案中。

格式基於 [Keep a Changelog](https://keepachangelog.com/zh-TW/1.1.0/)，版本號遵循 `{PZ版本}-{Mod主版本}.{次版本}.{修訂}` 格式。

## [42.20.4-1.22.1] - 2026-08-26

### Fixed

- **修正 1993 年 7 月 6 日《路易斯維爾太陽時報》的報社名仍顯示英文**。原本會顯示成「Louisville Sun Times - 1993年7月6日」，現在繁中與簡中都會完整顯示中文。
  > 技術要點：不是 Java／Lua 硬編碼。`RecipeCodeHelper.nameNewspaper` 正確以 `newspaper.getTitle(issue)` 取得 `Print_Media_LouisvilleSunTimes_July6_title`，再交給 `Translator.getText`；問題是我方 CH/CN 同鍵都把英文報社名直接寫進值裡，且官方 CH 自己也有同一錯誤（官方 CN 正確）。已用 `IGUI_NewspaperTitle_*` 對全 22 期報紙標題逐筆核對，CH/CN 各只命中這一筆錯位，並新增回歸守門。

## [42.20.4-1.22.0] - 2026-08-26

### Fixed

- **修復更新 42.20.4 後報紙、傳單可能只剩空白或排版錯亂**。官方這次更換了印刷品版面的讀取方式，舊格式不再相容；模組原有的中文資料會蓋過官方已更新的資料，導致圖片、字型或顏色讀不到。現在繁中與簡中印刷品已全部換成新版格式，既有中文內容沒有改動。由於新舊格式互不相容，最低支援版本同步提高為 Build 42.20.4。
  > 技術要點：官方 `PrintMedia.lua`／`ISReadABook.lua` 移除翻譯值內的 `loadstring`，改用 `tonumber`、`UIFont.FromString` 與 `getTexture(value)`。官方 EN 0 新增／162 改值／14 刪除，162 筆 `<type:text>` 內文逐段零變；我方 CH/CN 各遷移 165 個保留值，另刪除無任何 Java／Lua 消費端的 `FlyerTemplate1–14_info`。
  > 技術要點（守門）：`sync_translations.py fix-check` 現會依 42.20.4 的實際解析契約檢查 Print Media 標記，拒絕舊式 `getTexture(...)`、`UIFont.*`、算式／布林等 `tonumber` 無法讀取的值，避免下次同步把舊格式帶回。
- **修復做菜後菜名出現英文代碼**（例如「Base.FishFingers 三明治」「Base.MincedMeat 漢堡」「Base.Oysters 三明治」）。用魚條、牡蠣、絞肉、兔肉等食材做三明治、漢堡、沙拉、燉菜這類料理時，菜名裡的食材部分會顯示成遊戲內部代碼而不是中文。這是遊戲本身的問題——官方只替英文版準備了這份食材簡稱對照表，中文版只有少數幾筆，繁中有 148 種食材、簡中有 162 種食材會中招（不只玩家回報的那三個）。現在已把全部 173 種食材的簡稱補齊，菜名會正常顯示「魚條 三明治」「牛肉 漢堡」「兔肉 燉菜」。
  > 技術要點（根因）：script 的 `EvolvedRecipeName` 值由 `Item.java:2730-2732` 在解析期處理，但 `Translator.setDefaultItemEvolvedRecipeName` 的第一行就是 `if (getLanguage() == getDefaultLanguage())`——**只有 EN 會把英文字面填進 `itemEvolvedRecipeName`**，非英文語言一律 no-op。接著 `getItemEvolvedRecipeName` 查不到鍵就 fallback 到 `scriptItem.getDisplayName()`，而 42.x generated script **零 `DisplayName=`**（`food.txt` 命中 0），`Item.getDisplayName()` 於 `displayName` 為 null 時回傳 `getFullName()`，於是拿到裸 `Base.XXX` 並 `put` 進 map 永久快取。消費端是官方 Lua `ISAddItemInRecipe.lua:115/174`。**官方 bug、全非英語語系通病**：法文組自行補到 174 鍵（覆蓋 173/173）、UA 69，而 vanilla CH 僅 32 鍵（扣 7 個死鍵有效 25）、CN/RU/DE/ES 僅 11 鍵。
  > 技術要點（非本模組造成）：`Translator.tryFillMapFromFile` 是逐鍵 merge（`toMap().forEach` → `map.put`），MOD 只覆蓋同鍵、不取代整檔；修補前我方 11 鍵是 vanilla CH 32 鍵的子集，未砍掉任何官方鍵。補鍵即生效的依據是 `Core.java:3925 Translator.loadFiles()` 早於 `:3931 ScriptManager.instance.Load()`——翻譯表先填好就不會走 fallback、不會被快取污染。
  > 技術要點（修法）：CH/CN 各自持有全部 173 鍵，值為**食材簡稱**（依官方 EN 的 `EvolvedRecipeName` 值翻譯，非物品全名——`MincedMeat` 的簡稱是 `Beef`→「牛肉」而非「碎牛肉」），117 個相異英文簡稱逐一定譯。刻意不依賴 vanilla 補的那 14 鍵，避免官方值與我方 `ItemName` 用語脫鉤（如 `CannedMilkOpen` 官方譯「煉乳」而我方物品名為「淡奶罐頭」）。登記簿新增 A31。
- **修正 7 個食材名多出空格**：沙拉、派這類料理的菜名會顯示成「番 茄 沙拉」「胡 蘿 蔔 沙拉」。涉及番茄、胡蘿蔔、玉米、豌豆、馬鈴薯、沙丁魚、鹹牛肉。
  > 技術要點：我方舊值 `番 茄`／`胡 蘿 蔔` 等 7 筆帶多餘空白，且因逐鍵覆蓋反而蓋掉了官方 CH 原本乾淨的值。簡中側另有沿用物品全名的問題（`番茄罐头 (已打开) 沙拉`），同批改為簡稱。

## [42.20.3-1.21.1] - 2026-08-25

### Fixed

- **修復刮刮樂刮開後名字變成中英夾雜**（例如「刮刮樂彩票 - Winner $1」「刮刮樂彩票 - Loser」）。遊戲 42.20 起，多人伺服器上刮開刮刮樂時，票券名字改由伺服器決定並蓋回玩家畫面；伺服器語言不是中文時就會產生中英夾雜的名字，而且會永久留在票券上。現在模組會自動把這些票券修回中文——中獎顯示「刮刮樂 (贏家 $金額)」、未中獎顯示「刮刮樂 (輸家)」，之前已經變英文的舊票券也會一併修好。
  > 技術要點（根因）：`RecipeCodeOnCreate.scratchTicket` 只 `setName`/`setTexture` 不換型別，刮開後 fullType 仍是 `Base.ScratchTicket`；42.20.0 起尾端新增 `GameServer.server` 分支 `sendReplaceItemInContainer`，MP 由 server 端 `Translator.getText` 組名推送覆蓋（`getDisplayName()` 回傳既存 `this.name`，故產生「中文基底名＋EN 格式」混血）。42.19 無此推送、client 端組名全中文——正是玩家回報「原本中文、現在變英文」的時間點。翻譯檔本身無恙：CH/CN 的 `ItemName` 三鍵與 `IGUI_ScratchingTicketNameWinner/Loser` 格式鍵自 As1 42.0 起齊全。
  > 技術要點（修法）：`DynamicItemName_Flx.lua`（登記簿 A3）dispatch 原只認世界生成的 `Base.ScratchTicket_Winner`，現放行 `Base.ScratchTicket`＋官方同函式寫入的 `modData.scratched == true`（fail-closed，未刮不碰）；名含 `$N`（官方金額集合 `$1`–`$10000`，語言中立）走 `IGUI_ScratchingTicketNameWinner`，否則走 `IGUI_ScratchingTicketNameLoser`，以現行譯名重組。回歸測試 `scripts/test_dynamic_item_name.lua` 11→18 案。
- **消除啟動時的 4 條錯誤訊息**。遊戲每次啟動都會到每個模組裡找動畫資料夾，找不到就在紀錄檔印一條錯誤。本模組是純翻譯包、本來就沒有動畫檔，於是每次啟動固定產生 4 條無意義的錯誤訊息，把紀錄檔塞滿、真正的問題反而不好找。現在補上佔位檔讓那些資料夾存在，錯誤歸零；遊戲功能完全不受影響。
  > 技術要點：`AdvancedAnimator.java:771-798` 對每個啟用 MOD 無條件走訪 `common/` 與 `42/` 的 `media/AnimSets`、`media/actiongroups`，拼路徑前不檢查目錄是否存在，不存在則 `visitFileFailed` 印 ERROR 後 CONTINUE（:752-754），每 MOD 每次啟動固定 4 條。修法：四個目錄各放一個佔位 txt 讓目錄存在（同 NeatUI 解法），實測家族 12 MOD log 全數歸零。

## [42.20.3-1.21.0] - 2026-08-18

### Fixed

- **修復大地圖路名中英文混雜**。遊戲更新到 42.20.3 後，大地圖上會出現英文和中文疊在一起的路名（例如「Spring Dr凱利大道」），也有整條路只顯示英文（例如「Winter Lane」）。這是官方兩次改動疊加造成的：官方更新了街道資料（新增了不少街道、也改了一些路名），同時改了遊戲內部的資源回收方式，讓舊的翻譯載入流程留下英文殘影。現在已改用新的載入方式從源頭避免英文殘留，並把全部街道翻譯更新到最新版——官方新社區的路名也都翻好了（春日大道、夏日苑、秋日路、冬日巷、四季巷等）。
  > 技術要點（根因）：`WorldMapStreets.clear()`（Java）只清 street list 並 release 回 `WorldMapStreet.s_pool`，不清 `StreetLookup` 空間索引，而渲染 `getStreetsOverlapping` 走的正是該索引；42.20.3 `ObjectPool` 新增 `DEFAULT_MAX_SIZE = 1024`（超限 `release` 直接丟棄），官方檔 1098 條 clear 後尾端物件永不被 alloc 重用改寫，名稱停在英文。官方 `Muldraugh, KY/streets.xml` 自 42.20.0 改版：+144/-133 條、部分改名（如 Kaylee Ave 段改名 Spring Dr）。
  > 技術要點（修法）：`MapStreets_Flx.lua` 重寫為 add-only：先顯式載入 `Riverside, KY/streets.xml` 中文（pcall 保護，失敗印錯誤並退回原版流程；原版路徑亦以 pcall 防護，雙重失敗時放棄街道資料、保住 `initDataAndStyle` 其餘地圖初始化），再依 `getLotDirectories()` 逐目錄 pcall 載入其他地圖 MOD 街道、唯獨跳過 `Muldraugh, KY`（大小寫不敏感）；中文檔缺失時同樣走受防護的原版 fallback。
  > 技術要點（資料同步帳目）：全 1098 條 = 954 條（幾何與舊版完全相同，沿用既有譯名）＋ 144 條官方新增或改線的條目（27 條街名沿用既有同名映射；117 條逐一人工決策，涉及 113 個不重複街名：81 個沿用改線前的既有譯名、32 個全新翻譯）。完整帳目見 `HARDCODE_REGISTRY.md` 42.20.3 對版結論。
  > 技術要點（守門）：新增資料閘門 `scripts/test_streets_sync.py`（幾何／寬度與官方**逐位**一致、無未譯街名、官方承載目錄仍唯一、CRLF 無 BOM），已掛進 `verify_mod.py` 第 13 項隨發版必跑；另有行為回歸測試 `scripts/test_map_streets.lua`（add-only／跳過清單／pcall 隔離／fallback 例外攔截，7 案例）。
- **修正三個路名翻譯**：「Ram Road」之前一直沒翻譯，現在譯為「公羊路」；「弗雷德裡克巷」改正為「弗雷德里克巷」（簡轉繁誤字，人名音譯應該用「里」）；「Doe Valley Walk Road」譯為「雌鹿谷步道」，與周邊的雌鹿谷大道、雌鹿谷森林、雌鹿谷湖用同一個地名。

### Notes

- 本次官方 42.20.3 更新已全面檢查：官方這次只更新了遊戲程式本體，沒有動任何翻譯文本，本模組所有既有的修補（硬編碼英文修復等）也全部確認仍然有效，不需要調整。
  > 技術要點：官方本次僅動 jar（`ObjectPool` 容量上限與 MP 連線槽位 512→255），官方 EN 翻譯 47251 鍵零增減改、vanilla Lua／scripts 零變更；`HARDCODE_REGISTRY.md` 全部 A／B／C 表錨點逐條重驗通過（Java 錨點檔與 42.20.2 bit-identical、Lua 錨點逐條 grep 命中）。除錯選單涵蓋率基準不變（168 條涵蓋 167、唯一未涵蓋為不該譯的 `'servertest'`）。

## [42.20.2-1.20.0] - 2026-08-16

### Fixed

- **管理員替玩家調技能，反而會害那位玩家被反作弊踢除或封鎖（登記簿 A12）**。42.20 起遊戲把「經驗成長是否異常」的比對基準搬到新位置，官方每一條加經驗的路徑都會順手重設它，但本模組的修補繞過官方指令、沒有重設——於是管理員的調整被當成那位玩家自己的異常成長，累計兩次就依伺服器的反作弊設定處置**被調整的那個人**。上一版曾試著修，但當時呼叫的方法在遊戲的腳本環境裡根本取不到，那一行是死的，每次操作還額外丟一個例外（正式服紀錄檔每天約 24 次）。現在改走唯一可行的官方入口，**特質增刪也一併重設**——原本判斷「特質只改經驗加成，基準過期只會讓門檻更寬鬆」是錯的：「快速學習者」與「手巧」的加成直接讀當下狀態、沒有新舊取大的保護，移除後門檻立刻變嚴而基準還停在移除前，同樣會誤判。
  > 技術要點（死碼）：舊版在 `syncXp()` 內以獨立 `pcall` 呼叫 `ai:updateXpChecker()`——`NetworkCharacterAI`／`NetworkPlayerAI` 都沒有 setExposed 到 Lua，Kahlua 索引不到其上任何方法，`pcall` 又把錯誤吞掉所以表面看不出來。唯一 Lua 可及、且內部會呼叫 `updateXpChecker()` 的官方入口是全域 `addXpNoMultiplier` → `GameServer.addXp`（`GameServer.java:1842-1851`，:1848 呼叫；:1845 的 `canModifyPlayerStats` 因 `c` 是目標自己的連線、`havePlayer` 恆真而不擋）。量給 0：`AddXP` 的升降級迴圈條件（`IsoGameCharacter.java:17443-17470`）兩側都不成立，不觸發 `LevelPerk`，也就沒有伺服器端以英文組出的升級浮字；等級改用 `setPerkLevelDebug`（:4759-4773，該方法本身不發浮字、伺服器端也不 `sendPerks`）＋`setXPToLevel`。
  > 技術要點（反作弊邊界）：42.20 的 `AntiCheatXPUpdate` 改為逐技能判定 `xpDelta > 1000 × 技能倍率 × boost 倍率`，無 boost 時落到 default `0.25F`，門檻可低至 250 XP／60 秒（`NetworkCharacterAI.java:422` 的 `UpdateLimit(60000L)`）。boost 數值層有 `Math.max(newXpBoost, oldXpBoost)` 保護（`AntiCheatXPUpdate.java:22-25`），但 `FAST_LEARNER`／`CRAFTY` 的 1.3 倍直接讀當前 `characterTraits`（:33-40）**沒有**同等保護——這正是原本判斷失誤之處。
- **管理員增刪特質時，會把那位玩家連線後練到的一切打回舊值**。原版的特質按鈕會把管理員手上那份「玩家連線當下」的舊副本整包推回伺服器，伺服器收到就清空重建——玩家這段時間練的經驗、升的等級、拿到的特質全部倒退。現在特質變更改由伺服器依自己的權威資料套用，那條回推路徑整個關閉。
- **調完體能到 10，玩家身上卻還掛著「體能不佳」**（跑速、耐力、負重、近戰維持舊檔位並寫進存檔）。原本的改法不會觸發原版的升級後處理，現已補上——力量／體能的檔位特質、農業與機械電工的門檻配方都會正確跟著變。
- **管理員自己的技能摘要被掛上別人的資料**。舊版對「別人」做樂觀加經驗，跨級時會以管理員自己的連線槽位送出技能摘要。
- **簡中三處未翻譯與佔位符殘留**。《廚藝秀》的一句台詞顯示成 `OK!`，《哞哞牛》與飛行教學各有一句整句留著英文原文，現已補上譯文（繁中側原本就正確，本次僅修簡中）。
- **製作人員名單兩個團隊名補字**。`VERTEX BREAK`／`GENERAL ARCADE` 補上「團隊／团队」，與官方中文一致。

### Changed

- **管理面板的技能升降級與特質增刪改為伺服器權威**。點下去畫面會先動（樂觀顯示），實際變更由伺服器判定並回報：成功就顯示伺服器的權威數值，失敗會跳提示浮字說明原因（權限不足、目標離線、目標已死亡、已達上下限、身分不符等 10 種，繁簡皆備），伺服器沒回應則在 8 秒後還原顯示並註明「實際結果未知」。同一格技能／同一個特質在回覆到達前不受理第二次點擊，避免連點在畫面上留下伺服器從未確認過的中間值。
- **上下限一律交給伺服器判定**。管理員面板的數值停在「玩家連線當下」，可能比伺服器舊；先前版本會在畫面看起來已達上下限時直接不送出，於是畫面顯示 0 而伺服器其實是 1 時，按降級毫無反應。
  > 技術要點（權威在哪）：`addXp`／`addXpNoMultiplier` 的 Lua 綁定是 `if GameServer.server ... elseif not GameClient.client ...`（`LuaManager.java:11803-11825`），多人遊戲的 client 上兩個分支都不成立、整個呼叫是 no-op；伺服器端 `AddXP` 算加成（`IsoGameCharacter.java:17359-17373`）與反作弊算門檻（`AntiCheatXPUpdate.java:23` → :17262-17263）讀的是同一張伺服器 `descriptor.XPBoostMap`，同源不可能分岔。等級與特質由官方每秒的 `PlayerXpPacket`（`NetworkPlayerManager.java:10`／:36 → `NetworkPlayerAI.java:697-704`）單向推給目標玩家自己，內容是 `XP.save()`、不含 boost map。
  > 技術要點（狀態機）：以 requestId 對帳，不能靠 `ISPlayerStatsUI.instance`——它每幀被最後 render 的面板覆寫，且 `ISMiniScoreboardUI.lua:77` 可對同一目標開多個面板；single-flight 因此鎖 `(目標 onlineID, perk／trait)` 而非面板實例。失敗回覆分「已提交」（`noop`／`xpchecker`，不回捲）與「未提交」（權限／參數／身分／離線／死亡，回捲到上一筆伺服器確認過的值）；`revertTrait` 只反向特質本身、不反向加成（加成從頭就只在伺服器端動，client 反向會讓數值單向漂移）。

### Notes

- **特質的經驗加成在原版多人遊戲從來沒生效過**：原版只對管理員手上的遠端副本套用加成，而回推用的封包不含那張表，所以伺服器端的加成表從未被更新過。本次改在伺服器端套用，等於一併補上這個原版缺陷。
- 已知限制兩項，都不影響實際計算：目標玩家 client 端的加成表要重連才刷新（多人遊戲的經驗由伺服器計算，client 那份不參與）；管理員面板的特質圖示不會反映伺服器端衍生出來的變化（例如把體能調到 10 之後的檔位特質），重開面板即可，而玩家自己看到的一直是正確的。
- 另登記一條「修不到」（登記簿 C14）：把農業調到 10 這類會觸發「學會配方」浮字的操作，在英文伺服器上那行浮字會是英文——伺服器組好成品字串才送出，client 無從還原。**原版玩家自己練到該等級同樣如此**，非本次引入。
- 審查歷程：Claude 端獨立驗證（13 項介面契約全部對 42.20.2 反編譯快照與原版原始碼逐條核對）＋ codex `review-plus` 兩輪 ＋ 第三方交叉檢視，共修掉 8 項。其中兩次推翻了先前自己的結論——「伺服器不該寫加成表，否則會與 client 分岔」被「多人遊戲的經驗是伺服器權威」證偽；「連點節流已完成」被「同一玩家可開多個面板」證偽。兩次的錯誤結論與推翻它的證據都留在 `HARDCODE_REGISTRY.md` A12 與開發筆記中，避免後人照舊結論改回去。
- 反作弊那一項屬**弱驗證**：要壓到誤判邊界，必須在同一個 60 秒檢查窗內密集練同一技能、且期間由管理員移除加成特質，才會出現「基準停在變更前、門檻已按變更後算」的跨界狀況；而全域經驗倍率會同時放大成長與門檻，調高倍率並不會更容易觸發。因此「沒有觸發」不等於證明修對了，真正的依據是程式碼層的論證。
- 新增一道稽核閘門的雛形：以**官方中文**為第三方對照，掃出「官方有中文、本包卻是英文」的品質回歸。全庫 49,847 鍵僅命中 6 筆，即本次修正來源。既有 gate 全都只做 CH↔CN 交叉或 EN 單邊比對，看不見這一類。
- **官方中文不可盲抄**：`RadioData.RD_8bddd749`（EN `Bam!`）官方簡中作「脚步轻盈!」，經上下文比對確認那是**下一句**的譯文——官方簡中在《廚藝秀》該段整體錯位一格，故本次刻意不採用，維持現值。同段 `RD_13e9fac4` 亦為 `Bam!` → `OK!`（官方繁簡皆同），屬既有上游用語問題，待風格定案後另行處理。
- 玩家回報的三個 Workshop MOD 衝突（Detailed Descriptions for Occupations and Traits、Moodle Descriptions Expanded、Named Skill VHS Tapes）**經查證非本包缺陷**：三者皆以改寫原版翻譯鍵為功能主體，與任何完整中文化在同鍵上必然碰撞，PZ 依 mod 載入順序決定勝負（`Translator.tryFillMapFromFile`：後載入的非空值覆蓋前值）。三者自訂的新鍵本包一個都沒有定義。解法為調整載入順序。

## [42.20.2-1.19.0] - 2026-08-13

### Added

- **多人伺服器天氣廣播英文修復（登記簿 A30）**。玩家回報在伺服器上把收音機轉到 97.6 MHz 時，自動緊急廣播系統的天氣預報整段是英文（「輕霧」「明天平均氣溫…」「東北風…」），其他介面卻都是正常中文。現在客戶端會把收到的廣播還原成你自己的語言。
  - **不是翻譯漏了**。這段廣播的 78 個詞條在本翻譯包裡全部都有中文。問題出在「誰把字組好」：天氣預報是**伺服器**每小時先組成完整句子、再把組好的文字送給每個玩家，所以伺服器跑英文環境時，送出來的就是英文——跟客戶端裝了什麼翻譯包無關。單人遊戲不受影響，也不是舊存檔殘留。
  - **修復方式**：客戶端收到廣播後，先把英文還原回對應的詞條，再用你自己的語言重新組句。伺服器語言不同、或伺服器沒裝翻譯包，都不影響顯示。
  - **順手修掉一個原版缺陷**：某類隨機軍事通報的內容原本在**任何語言**下都會顯示成一串識別碼而不是文字，現已一併補正。
  - **已知上限**：只修好聊天視窗裡的字幕。收音機**旁邊**浮動的那一行仍會是伺服器語言——那條由遊戲底層直接繪製，模組無法介入。開伺服器的人可在啟動參數加上 `-Duser.language=CH`，讓兩個地方一起變中文（代價是全伺服器統一語言），與本修復互補。
  > 技術要點（根因）：天氣播報由 `server/radio/ISWeatherChannel.lua` 的 `OnEveryHour` 每遊戲小時以 `getText()` 組成**成品字串**，再經 `ZomboidRadio.SendTransmission` 的 `GameMode.Server` 分支 `GameServer.sendIsoWaveSignal(..., msg, guid, ...)` 把最終文字送給 client。專用伺服器啟動時只跑 `Languages.init()` ＋ `Translator.loadFiles()`，**不載入 options.ini**，`optionLanguageName` 預設空字串（`Core.java:307`），`Translator.getLanguage()` 因此退回 `System.getProperty("user.language").toUpperCase()` 去比對 **Translate 目錄名**（`Language.name` ＝ 目錄名，繁中為 `CH`）——中文 Windows 主機的 `user.language` 是 `zh`、對不上 `CH` 仍落回 EN，故伺服器端解法是 `-Duser.language=CH` 這類 JVM 參數而非系統語系。單機走 `GameMode.SinglePlayer` 分支直接用本機生成的文字，不受影響；`RadioBroadCast` 無任何序列化方法、每小時重生成，故非舊存檔殘留。封包的 `guid` 由 `RadioChannel` 硬帶 `null`，client 無從反查翻譯 key，只能對字串本身反解——與 A7（live radio/TV 字幕）同一根因族，但 A7 只查靜態 `RD_` 整句表，涵蓋不到本項的參數化模板。
  > 技術要點（攔截點）：`RadioChat.showMessage()` 只觸發 `OnAddMessage`、自身不渲染，實際渲染在 Lua 的 `ISChat.addLineInChat`，且 `ChatMessage.setText()` 為 public。vanilla 的 `Events.OnAddMessage.Add(ISChat.addLineInChat)` 寫在 `ISChat.createChat` 內、由 `OnGameStart` 觸發，**晚於 mod 載入**，因此直接覆寫該函式即可被註冊進事件，沒有 hook 順序問題。反解後一律以 `getText(key, ...)` 用客戶端語言重組，故 CH/CN 共用同一份表、日後調整譯文不需重新生成。浮動文字那條走 `ChatElement.addChatLine()`，該路徑沒有任何 `triggerEvent`、`ChatElement` 也無 `@UsedFromLua` 且公開 API 只有 `addChatLine`／`clear(playerIndex)`（沒有讀取或修改單行的方法），渲染由 Java 的 `IsoGameCharacter.render()`／`IsoWaveSignal.render()` 直呼 `renderBatched()`，Lua 攔不到；`OnDeviceText` 雖會觸發（`codes` 為 `""` 非 `null`）但在兩處顯示之後，靠 `clear()`＋重加會清掉整個元件的行、淡出計時歸零，裝備中的收音機還會誤刪玩家對話，不划算故不做。
  > 技術要點（原版缺陷）：`WeatherChannel.Init()` 在 `OnLoadRadioScripts` 時把檔頭那兩張表整個換掉——`activity` 從裸英文換成 **key 字面**（`"AEBS_rand_pre_0"`…），`zones[i].name` 同樣換成 key。兩者結局不同：`AEBS_random_0` 那側寫的是 `getText(zone.name)`，成品已是譯文；但 `AEBS_random_3` **直接把 key 塞進 `%1` 而未經 `getText`**，vanilla 在任何語言下都顯示裸 key。反解時由 `BARE_KEYS`（12 條，generator 自動產生）認出並補譯。讀碼陷阱：只看檔頭的 `local activity = {"anomalous", ...}` 會誤判成裸英文字串，必須讀到 `Init()`。
  > 技術要點（反解）：分四段——剝離行首前綴（`AEBS_Pre_*`）→ 7 條 `$` 錨定模板依固定文字長度降序匹配 → 17 條「單獨成行」片語全等查表 → 3 條開放式續接前段；模板捕獲到的參數再走 greedy 逐段吃掉已知片語（69 條，數值原樣保留，`25.09MpH` → `25.09英里/小時`，`Clear skies. Periodical cloudy spells.` 兩句串接可正確拆解）。**兩個陷阱**：(a) `GetForecastString` 的 type 4/5 會在 `AEBS_weather_0_a/b/c` 之後直接續接後綴，整行不等於任何單一 key；更糟的是這三個 key 的參數後方固定文字正是 `...`、而後綴也以 `...` 收尾，`$` 錨定版本的 `(.-)` 會為了讓行尾對上錨點而把整段後綴吞進參數（比不匹配更糟），故 generator 刻意不為這三個 key 產生錨定版本，只走 `string.find` 取結束位置＋剩餘交給 greedy。(b) 整行全等表**嚴格限縮到 17 個會由 `AddRadioLine` 單獨送出的 key**——初版收錄全部 69 條片語，導致 `North`／`Mild`／`unknown`／`class 5` 這類短詞會匹配整行，玩家在聊天打同樣的字就被改寫；短詞現在只供模板參數內的 greedy 使用，另加 `getRadioChannel() > 0` 閘門（`ChatMessage.radioChannel` 預設 `-1`，僅電台訊息會設值）擋掉一般聊天。17 個 `AddRadioLine` 呼叫點已逐一與反解表核對，無遺漏。
  > 技術要點（fail-closed）：新增 `sync_translations.py gen-aebs-map`，輸出**只含英文原文 → 翻譯 key**、不含譯文。generator 以 producer 契約守門：78 個 key 的完整分類清單（前綴／單獨成行／開放式續接／帶參數／裸 key／方位／風力／雲量／時段／單位／天氣後綴），EN 鍵集必須與之完全相等，任何增刪都 exit 1 強制人工對版；另檢查帶參數 key 集合、EN 的 `%N` 首次出現順序須 1..n 連續遞增（否則捕獲會錯位）、runtime 形英文原文不得碰撞、CH/CN 值非空非佔位非等於鍵名、佔位符集合與 EN 一致。
  > 技術要點（測試）：新增 `scripts/test_aebs_restore.lua`（51 案，`dofile` 生產 Lua，涵蓋 10 個模板全部、參數個數守門、23 個短詞不得整行匹配、一般聊天不得被改寫）與 `scripts/test_aebs_generator.py`（11 組 mutation，逐項證明契約漂移會 fail-closed；每個 mutation 皆確認由對應的檢查攔截）。既有 Lua/Python 測試無迴歸，verify_mod.py 12/12 PASS。
  > 技術要點（review）：Claude 端與 codex 端各自獨立 review-plus 兩輪。type 4/5 續接缺陷由 Claude 端自查抓出；codex 端第一輪推翻了兩處判讀——`WeatherChannel.Init()` 會把 `activity`／`zones` 換成 key 字面（只看檔頭的 `local activity = {"anomalous", ...}` 會誤判成裸英文，`zones` 那側有 `getText` 所以正常、`activity` 那側沒有才是真缺陷），以及整行全等表會誤改玩家聊天；第二輪以 mutation probe 實證 generator 六個 fail-closed 缺口，本次一併補上並改由 `test_aebs_generator.py` 守門。
  > 技術要點（待驗）：MP 實機驗證尚未進行——需英文 dedicated server ＋ 中文客戶端收聽 AEBS 頻道（隨機頻率，落在 88.0–108.0 MHz），確認聊天視窗字幕為中文、console 無 `Missing arguments`。
- `versionMin` 維持 42.20.1。

## [42.20.2-1.18.2] - 2026-08-11

### Fixed

- **修復物品欄掃描灌爆 console 紀錄的警告洪水**。42.20 起，動態物品名修復（寵物牌、名片、證件、雪花球、舊報紙、股票等）向引擎索取名稱句型的方式會觸發「Missing arguments」警告，且物品欄每次刷新、每件相關物品都觸發一次——正式服玩家的紀錄檔 223 秒內被灌 1 萬 5 千條（佔整份紀錄 96%），把其他錯誤訊息全部淹掉。現改以帶占位參數的方式取句型、並於整場遊戲內快取，警告歸零，掃描負擔同步下降。
  > 技術要點：玩家 log 223 秒 13,758 條 `Missing arguments for "IGUI_ItemWithDisplayName"`＋1,299 條 `IGUI_ItemWithDisplayNameAndJob`（60+ 條/秒）。機制經 42.20.2 反編譯查證：`Translator.getText`／`getTextOrNull` 一律經 `reportMissingArgumentsFromPastAbuse`，對含佔位符的翻譯在參數不足時逐次拋 `MissingFormatArgumentException` 逐次警告——無狀態、非「標記後全噴」制，帶齊參數的呼叫不觸發；洪水 100% 來自 `matchKnownFormats` 每次呼叫 `rawFormat(formatKey)` 無參數取原始格式，掛在 `OnContainerUpdate`／`OnRefreshInventoryWindowContainers`／`EveryOneMinute` × 每件物品。修法比照 `ItemNameFix_Flx.lua` 的 `keyRingSuffixLocal` 既例：`rawFormat` 改帶哨兵參數（`"\1\2"` 系）讓官方自己格式化——走 `text.formatted` 成功路徑、警告歸零（非僅降頻）——再把哨兵換回 `%N`，加 module-level memoize（查無翻譯的 nil 以 false 佔位、同樣只查一次）與 nil-key 守衛。五個涉事 key（`ItemWithDisplayName`／`AndJob`／`NoQuote`／`SnowGlobeOf`／`Newspaper_Name`）CH/CN 佔位符數量與 vanilla EN 逐一核對一致——警告純屬無參數呼叫，非翻譯格式錯誤；log 只見兩個 key 是因為另外三個的物品（雪花球／舊報紙／股票）沒出現在該玩家背包，同路徑一體修復。
- **修復雪花球混語名稱**。「雪花玻璃球 (Louisville)」這類半中半英的殘留名稱自 42.20 起一直修不到，本次連帶修復，地名會正確補翻成中文。
  > 技術要點：`Translator.tryFillMapFromFile` 載入期把 `%N` 改寫成 `%N$s`（`formatFixer`，`Translator.java:894`；repo 內 `test_item_name_fix.lua:19` 早已記載此行為），`rawFormat` 拿回的實為 `%1$s (%2$s)` 形態，而 `buildCapturePattern` 只認 `%N`——pattern 要求字面 `$s`、永不命中，currentFormat 解析分支 42.20 起全滅。格式與 EN 相同的 key（`%1: %2` 系）被「EN 格式＋當前錨點」交叉分支掩護僥倖可達，CH/EN 格式相異的 `IGUI_SnowGlobeOf`（CH `%1 (%2)` vs EN `%1 of %2`）則徹底修不到。哨兵版 `rawFormat` 由官方格式化結果換回 `%N`，天然拿回正確格式且不依賴 `formatFixer` 實作細節（TIS 改寫格式規格也不再靜默失效），`matchKnownFormats` 邏輯零改動。
- 本次修復經離線回歸測試（88 案）與雙邊獨立 review 驗證，寵物牌／名片／報紙等既有翻譯功能無迴歸。
  > 技術要點（測試）：新增 `scripts/test_dynamic_item_name.lua`（11 案），鑑別力已對修復前版本驗證——7 案紅（三個 key 各 50 次裸查 vs 歸零斷言、三個 key 窗內格式擷取 vs memoize 恰一次斷言、混語雪花球不可達），修復後全綠；EN 烘焙殘留、三參數名片、交叉分支僥倖路徑、冪等性（直呼 `computeFixedName` 繞過 pcall，快取層拋錯顯性可見）等守門案照舊。裸查與格式擷取分開計數——哨兵路徑帶參數，只算裸查會讓 cache 失效時測試假綠（codex 以 mutation 實證後補上）。既有 `test_item_name_fix.lua`（20 案）、`test_evolved_recipe_name.lua`（57 案）無迴歸，verify_mod.py 12/12 PASS。實機驗證（2026-08-11，debug 生成寵物牌／名片／股票／雪花球／舊報紙五類並反覆刷新物品欄）：console 零 `Missing arguments`、零本 mod ERROR，中文顯示照舊。
  > 技術要點（review）：Claude base＋tests／errors／comments／performance 五 lane、codex review-plus 獨立 lane。哨兵改法出自 base lane 對照 `ItemNameFix` 既例駁回初版 memoize＋gsub 解法（初版警告僅降頻不歸零、且綁死 `formatFixer` 實作細節）；nil-key 守衛由 errors lane 抓出（`rawFormatCache[nil]` 寫入拋錯會被上層 pcall 吞成靜默 no-op、每 tick 重試）；測試 stub 單層計數與檔頭舉例修正由 tests／comments lane 抓出。
  > 技術要點（取捨）：語言切換走完整 Lua reset、快取隨之重建（與同檔既有 `lazyDomainMaps` 同一取捨）；debug 用 `Translator.loadFiles()` 熱重載不重建快取，屬開發期限定風險，接受。
- `versionMin` 維持 42.20.1。

## [42.20.2-1.18.1] - 2026-08-11

### Fixed

- **路易斯維爾地圖 39 個地標鍵誤刪回滾（GitHub issue #2）**。玩家回報世界地圖多處直接顯示裸 key（`MapLabel_LouisvilleTrainStation`、`MapLabel_IroquoisPark` 等）。根因：`4e9ce58`（隨 1.15.1 上線）的死鍵清理以「官方 EN 有無」判死鍵，把 `worldmap-annotations.lua` 以 `addUntranslatedText` 引用的 56 個 `MapLabel_*` 鍵中的 39 個 POI 鍵誤判為死鍵刪除——這批鍵官方 EN 亦無（官方 `MapLabel.json` 僅 14 個城鎮鍵），引擎查無鍵時 fallback 無值可退、直接畫裸 key；且 `MapLabel_Flx.lua` 本就會移除官方原文字標籤，缺鍵時連英文都不剩。POI 地標絕大多數（31/39）僅在 zoom 13.5–16.5 帶渲染，街名層級的近距檢視踩不到，故發版驗證未抓到——上線當日玩家即於 Steam 留言回報、翌日提交 issue 截圖。修法：整檔還原 `4e9ce58~1` 的 CH/CN `MapLabel.json`（倖存 17 鍵清理前後值零異動，無潤色損失），56 鍵與 annotations 引用逐鍵對齊、零缺零餘。還原時順修 5 組舊值缺陷（雙邊 review 抓出，皆有同實體既有定譯佐證）：CN `IrvingtonSpeedway`「欧文顿Speedway赛道」→「欧文顿赛车场」（英文殘留，對齊 CH）；CH/CN `FossoilField`「福索球場」→「**福索石油**球場」（Fossoil＝福索石油，全庫定譯）；`CardinalPlaza`「主教廣場」→「**紅雀**廣場」（對齊 `Print_Media_CardinalPlaza_title`，Cardinal 為紅雀非主教）；`LouisvilleBruiserFactory`「布魯瑟**棒球**工廠」→「布魯瑟工廠」（該廠產品是球棒，對齊 `Print_Media_LouisvilleBruiser_title`）；`PSDelilah`「迪莉婭號**水上餐廳**」→「迪莉婭號**蒸汽船**」（PS＝Paddle Steamer，對齊 `Print_Media_Delilah_title`）。

### Added

- **verify_mod.py 檢查 12「地圖註記鍵覆蓋」**：掃 `media/maps/` 下各 `worldmap-annotations.lua` 的 `addUntranslatedText` 引用，逐語系與該語系 `MapLabel.json` 比對——引擎按鍵前綴路由到 per-file map（`Translator.getTextInternal`：`MapLabel_` 只查 `MapLabel.json` 填的表，跨 mod 同檔名合併、不跨檔名），鍵搬錯檔照樣裸 key，故不能拿全 json 鍵聯集當存在判準。除缺鍵外亦驗**譯值有效性**（空值／非字串／值等於鍵名都等同缺譯），另備兩道自失明防護：擷取數與呼叫數交叉比對（掃描 regex 失配即 FAIL）、非 `MapLabel_` 前綴引用即 FAIL（該類鍵會被 `MapLabel_Flx.lua` 過濾靜默刪除）。鑑別力已驗證：對修復前狀態跑出 CH/CN 各 39 筆缺鍵 FAIL（exit 1），修復後全數 PASS。死鍵稽核紀錄 `scripts/dead_keys_audit_42.20.2.json` 同步回填（39 鍵 delete→keep_alive、存活判定 method 補掃 annotations 引用）。

## [42.20.2-1.18.0] - 2026-08-10

### Added

- **演化食譜句式名固化英文修復（登記簿 A29，新增 `EvolvedRecipeName_Flx.lua`）**。玩家回報冰箱裡的鍋菜叫 `Game and Fish Roast with Soy Sauce (新鮮, 已烹飪)`——外層狀態字是中文、內層菜名整串英文。
  - **不是硬編碼**。官方 `ISAddItemInRecipe.lua` 的 `checkName` 本身正確使用 `getText`（`ContextMenu_FoodType_*` ＋ `ContextMenu_EvolvedRecipe_*` ＋ `RecipeName`／`RecipeNameNew` 模板）組名；問題在組完之後 `setName`：`InventoryItem.save` 在 `name != originalName` 時把**成品字串整串**序列化（flag 8），`load` 原樣讀回不重譯。語言在「做菜當下」被烘死，MP dedicated server（EN）煮的菜就永遠是英文。外層「(新鮮, 已烹飪)」仍是中文，是因為那由 `Food.getName()` 每次即時組——這個混血正是烘死的特徵。
  - **修法不做句式反查**：`Food` 的 `extraItems`／`spices` 存的是 fullType 字串列表（跨語言不變，且各自過 save/load），`ScriptManager` 可由 resultItem 反查所屬食譜，兩者湊齊即可**以本機語言原樣重跑官方 `checkName`**——結果與本機新煮的逐字一致，零反查表、零 generator、第三方 MOD 的食材與食譜自動涵蓋。這也解除了 A20 條尾原記的「演化食譜句式名刻意不處理（需句式反查、誤傷風險高）」。
  - **⚠️ 最大的坑是官方的 `dirtyUI`**：`checkName` 三個出口有兩個**無條件**呼叫 `ISInventoryPage.dirtyUI()`，而 `dirtyUI` → `refreshBackpacks()` → `triggerEvent("OnRefreshInventoryWindowContainers", …, "end")`——正是本修補掛勾的事件之一。不擋就是無限遞迴，且逐物品觸發整組背包 UI 重建。故以 `runRepair` 包住每一輪：重入旗標擋第二層、整批期間把 `dirtyUI` 換成 no-op、只有真的改過名字才補呼叫一次真的（且補呼叫必須在旗標仍生效時進行，否則終止性只能仰賴官方函式的冪等性）。
  - **索引鍵是 fullType，不是 bare type**。中途曾依 `EvolvedRecipe.isResultItem` 的 bare-type 比對改成 bare type，被 codex 端 review 以反例駁回：決定「哪個食譜適用於這個物品」的**權威**路徑是 `RecipeManager.getEvolvedRecipe` 的 `baseItem.getFullType().equals(recipe.resultItem)`，用 bare type 會讓 `SomeMod.PanFriedVegetables2` 誤配到 vanilla 食譜、把第三方物品改名。已改回並補測試，教訓寫進 A29 升版 SOP。
  - **同 resultItem 時比最終顯示字串，相同才合併、不同就整個跳過**（初版是 first-wins，等於主動把玩家的菜改成另一道菜的名字）。判準必須是 `getText("ContextMenu_EvolvedRecipe_" .. getUntranslatedName())` 而非 key 本身——實機 log 抓到拿 key 比會把 vanilla **唯二**的一對多（`Base.BucketOfSoup` ← SoupBucket/SoupBucket2、`Base.BucketOfStew` ← StewBucket/StewBucket2，key 不同但譯文都是「燉湯」「燉菜」）整組誤判成不可判，桶裝湯／桶裝燉菜等於完全沒被涵蓋。vanilla 63 個 evolvedrecipe／61 個相異 resultItem；**基準須掃全 `media/scripts`**，只看 `evolvedrecipes.txt` 會漏掉 fishing 的 `AddBaitToChum` 而少算成 62／60。
  - **所有失效路徑都留 console 訊號**（`checkName` 缺失／拋錯、`dirtyUI` 缺失、索引為空各一次性告警；正常啟動印 `Repair path active (N ...)`）——A20 曾自 `276c3c5` 起靜靜失效數月，這是同型防護。
  - 回歸測試 `scripts/test_evolved_recipe_name.lua`（57 案，**載入 vanilla 真實 `checkName`** 跑重算；找不到 vanilla 時 exit 2 而非綠燈）。鑑別力以 mutation testing 量化，當時 15 個變異體殺 12，存活的 3 個都是測試盲點且已補上斷言。

### Fixed

- **`ContextMenu_EvolvedRecipe_*` 七個鍵（CH/CN 各 7）**。A29 把這組鍵的曝光面從「本機現煮」擴大到「所有 MP 食物」，順帶清掉既有問題：
  - `RecipeNameNew` 由「%1 %2 **和** %3」改為「配」——`%3` 是調味料，而 `_and`（並列連接詞）也是「和」，撞在一起會出現「野味 和 魚 燒烤 和 醬油」的歧義。（註：官方 CH 的 `_with` 是「與」，「配」是我方既有譯文，升版對照官方時勿誤判。）
  - **5 個選單動詞句改名詞**（官方 CH 原文照抄的問題，官方 EN 本來就全是名詞）：`AddBaitToChum`「向散餌中新增釣餌」→「散餌」、三個 Bagel「準備百吉餅…」→「貝果／罌粟籽貝果／芝麻貝果」（CN 沿用「百吉饼」系）、`Oatmeal`「碗 (燕麥片)」→「碗 (燕麥粥)」。這組鍵是**雙角色**——也是右鍵選單標題，非 `isResultItem` 時外層還包「製作 %1」，所以原本顯示的是「**製作準備**百吉餅」；改名詞對兩個角色都是淨改善。
  - `Stir fry Griddle Pan`「烤菜」→「炒菜」，與同 EN 值（`Stir-fry`）的 `Stir fry`／`Stir fry Forged` 統一。

### Notes

- **更正 A20 一句既有的錯誤斷言**：「演化食譜句式名不等於單一 EN 原名，天然不受影響」與事實不符——35 個演化食譜 EN 名有 **21 個逐字等於某物品 EN 名**（`Pizza`／`Burger`／`Roast`／`Sandwich`…），`checkName` 的 collapsed 分支（食材類型 > 3）會 `setName(裸食譜名)`，一直命中 A20 第一分支。不會 flip-flop（雙方都只匹配英文形態，一輪收斂），現由 A29 接手。
- **雙邊 review**：Claude 端跑 base／architecture／tests／errors／comments 五個 lane，codex 端獨立跑 `review-plus`。三個真 bug 分別由不同來源抓到——`dirtyUI` 無限遞迴是自查、重入旗標空窗是 base review＋errors lens 獨立實測、索引鍵用錯層級是 codex 推翻 Claude lane 的結論。tests lens 另做 mutation testing 量化鑑別力，architect 抓到「本修補放大了翻譯鍵曝光面」這個沒人想到的外部影響。
- **遊戲內實測抓到一個離線測試抓不到的 bug**：發布前跑 SP＋MP 實機，console 出現 `ambiguous resultItem, skipped: Base.BucketOfSoup, Base.BucketOfStew`——消歧判準原本比的是食譜 key，而 vanilla 唯二的一對多正好是 key 不同、譯文相同，於是唯一需要合併的兩組反被整組跳過。改比最終顯示字串後修正，測試也補上「key 不同但譯文相同」的案例（原測資是「key 相同」，天然測不到）。其餘實測結果：`Repair path active (61 evolved recipes indexed)` 與腳本掃描的 61 個相異 resultItem 吻合；dedicated server log 零筆 EvolvedRecipeName，驗證 server 端正確跳過；client 全程無本 MOD 相關 Lua 錯誤。
- **log 中其餘 1464 筆 ERROR/WARN 皆非本 MOD**：1242 筆 `ImportedSkeleton.collectBoneFrames`（vanilla 骨架）、36 筆 `AdvancedAnimator.visitFileFailed`（PZ 對每個 MOD 掃 `AnimSets`／`actiongroups`，所有 MOD 皆有）、4 筆 `FluidContainerScript.load` 的 `Sanitizing container name 'Fuel Pump'`（即 A26 已補鍵的那件事）、`Build_AnvilStone` 缺圖（vanilla 只有 `.fbx` 無 UI 圖示，本 MOD 未碰）、`Recipe Piano missing UiConfigScript`、`tiledef=LCtiles 9476`（第三方地圖 MOD）。
- **顯示層治標的機制上限仍在**：server 那份資料永遠是生成端語言，「重建→再修」是常態（同 A1）。
- `versionMin` 維持 42.20.1。

## [42.20.2-1.17.0] - 2026-08-09

### Added

- **擺放物顯示名補齊 115 鍵（CH/CN）**。玩家回報右鍵雙耳罐的子選單標題是英文 `Closed Amphora`。查證為**上游缺口而非我方漏譯**：擺放物名由 tile 的 `GroupName + " " + CustomName` 組成（`crafted_04_32` 即 `Closed` + `Amphora`），經 `Translator.getMoveableDisplayName`（`Translator.java:642`，空白→底線、連字號→底線、去單引號）查 `Moveables.json`，查不到就原樣回傳英文——而**官方 `EN/Moveables.json` 本身就沒有這些鍵**，官方繁中亦無，不裝本 MOD 的中文玩家同樣看得到英文。官方法文組早已自行補 `Closed_Amphora`／`Open_Amphora`，證明「只在自己語言檔補鍵」這條路可行。
  - **枚舉方法**：以嚴格 tdef v1 結構化解析掃全部 7 個 `media/*.tiles`（parse 到最後一個 byte 對齊，非 ASCII 平掃），得 **1320 個顯示名**；與官方 `.tiles.txt` companion 逐 `tile { }` 解析**雙向零差異**交叉驗證。比對後 123 個在官方 EN／官方 CH／我方三邊皆無鍵。（登記簿 A27 當時記的「真實組合 1043 個」偏低，本次已於稽核檔 method ⑬ 寫入完整枚舉法與格式規格。）
  - **譯名來源**：32 個作物／香草沿用 `Farming.json`；6 個無線電／電腦 `*_CustomName` 由 tile 的 `CustomItem` 指認實體後沿用同物件既有鍵；三張海報、鐵砧四件、原始鍛造爐、石磨、石塚沿用既有鍵；其餘依既有命名慣例組合（沙堆／礦石大小／教堂窗戶／三角旗串等）。`Closed_Amphora`／`Open_Amphora` → 加蓋雙耳罐／開蓋雙耳罐（與選單「開啟蓋子」呼應）。
  - **補完後**：CH/CN 各 1370 鍵、鍵序完全一致，官方 EN 1180 鍵 100% 覆蓋，tile 顯示名扣除刻意不補後**零未覆蓋**。

### Fixed

- **同物件兩個名字 5 組**（雙邊 review 抓出，逐條比對官方 EN 原文後修正）：`Cooking_Pit`／`Simple_Cooking_Pit` 蓋的時候叫「火坑 (石磚)／(石塊)」（`Recipes.CookingPit` = `Fire Pit (Stone Blocks)`）右鍵卻叫「烹飪坑」；`Pottery_Table` 與製作視窗的「陶藝工作臺」（`Recipes.PotteryBench`）對不上，且全 tile 集無獨立 Pottery Bench，確認同物；`Huge_Metal_Trough` 帶 `container=trough` 卻譯「巨型金屬槽」，丟失既有「飼料槽」語意；`Barricade_Military_Barrier` 與既有「空置軍用路障」無法區分（tile 對照：`Empty` 版帶 `IsMoveAble`、`Barricade` 版是 `solidtrans` 實心）；四個藝廊鍵 CH 譯「美術館」而 CN 譯「畫廊」，CH 既有 `Gallery_Bed`／`Gallery_Toilet` 都用「畫廊」。
- **四台發電機在世界上叫顏色、進背包叫品牌**。tile 的 `CustomItem` 直指 `Base.Generator{,_Old,_Yellow,_Blue}`，已對齊 `ItemName.json` 的「發電機 (極電製造／老式／昂科牌／廉科牌)」，與同批無線電的品牌對齊策略一致。
- **同批內部用詞不一 3 組**：`StoneTwigs` 用「樹枝」但其組成是 Twigs（同批 `Twigs` = 小樹枝）；`Small_LimestoneBoulder`／`Small_FlintBoulder` 用「石灰岩／燧石岩」但相鄰的 `Limestone` = 石灰石；`Medium[n]_Boulder` 譯「中型巨石」語意自相矛盾，改用 `巨石 (大)`／`巨石 (中)`。
- **CN `Empty_Military_Barrier`「空军事路障」→「空置军用路障」**（既有鍵，與新增的「设障军用路障」用詞統一）。

### Notes

- **刻意不補 8 鍵**（已登記於 `scripts/dead_keys_audit_42.20.2.json` 的 `Moveables.json._deliberately_not_added`，升版時勿誤判為缺漏）：`CustomName`（單一鍵橫跨 6 個不相干 tileset，給任何具體名都會誤標其中多數）、`bleh`、`location_entertainment_gallery_02_{3,11,18,30}_x`、`appliances_com_01_38_x`——皆為 TIS 未填好 `CustomName` 或外露資源識別字所產生的壞字串，補譯等於替上游資料 bug 化妝；`Small_Stump` 依 A22 尾註維持不補（名稱無渲染路徑，移除選項走已譯的 `ContextMenu_Remove_Stump`）。
- **登記簿 A27 第 7 鍵改判**：`US_ARMY_COMM._Ham_CustomName` 原記「刻意不補」，本版改為【補】。該 tile 的 `CustomItem = Base.HamRadio2` 唯一指認同一台實體無線電，沿用 `US_ARMY_COMM_Ham_Radio`（美國陸軍業餘無線電臺）既有譯文是**把物件正確命名**而非替 bug 化妝，bug 本身仍完整留在鍵名裡（登記簿與稽核檔都以鍵名追蹤）；且同批另 5 個同類鍵已補，漏這 1 個會造成同一 bug 類內部不一致。A27 同時寫入原則的適用邊界：**能由 `CustomItem` 或同義既有鍵唯一指認出實體物件者補，指認不到實體的純壞字串仍不補**。
- **稽核檔 `_meta.method` 新增第 ⑬ 條存活路徑**（tile `GroupName+CustomName` → Moveables 鍵）。我方 `Moveables.json` 有 190 個官方 EN 沒有的鍵（138 個可由 tile 名直接對上，另 52 個來自 `getMannequinScriptName` 等其他路徑），沒有這條記載，未來死鍵掃描會把它們整批誤判為死鍵——`MetalDoor` 誤刪事件（見 A28）就是同一類漏判。`keep_alive` 10 → 125。
- **雙邊 review**：Claude 端 `code-reviewer` 出 12 條（5 MEDIUM 全採，2 條經查證後不採並附理由）；codex 端 `review-plus` 在收尾前被中斷，但中途訊息指出**本批與登記簿 A27「刻意不補」決定衝突**——這是單邊 review 不會發現的，回溯掃描後另找到第二處（A22 的 `Small_Stump`），兩處都已依裁定處理。
- **`versionMin` 維持 42.20.1**；純翻譯鍵新增，零機制變更、未新增任何 Lua 修補檔。

### Fixed

- **玩家回報 8 項全數處理（本輪起點）**。逐項查證來源是本體或本 MOD：製作視窗需求列外露原鍵 `IGUI_CraftingWindow_StandingDrillPress`（**官方 EN 自己缺鍵**，英文玩家同樣看得到，但可由我方補鍵繞過）；配方名與產出物名對不上（見下）；「解包」「制動器」「輪胎 (高階) 類型」等陸港用語與簡中語序；技能「焊接」應為「金工」（見 Notes）。
- **配方名↔產出物名全量對齊，391 鍵**。玩家反應「做出來的東西跟配方寫的不同」。以 969 個 craftRecipe 逐一比對輸出物，並展開 `itemMapper` 的靜態映射（等號左值＋`default` 右值都會成為玩家可見名稱）。CN 側首次納入同批稽核，抓到 `制作垃圾袋无肩文胸` 實際產出裙子、`用带锯切割轮胎` 實際產出鋸片等內容錯位。
- **動態拼鍵三輪全量稽核，補 124 鍵**。官方多處以 `getText("PREFIX" .. 變數)` 組鍵，變數值域一旦超出鍵表就直接外露原鍵。
  - **Lua 側**：掃 1395 個 .lua 得 66 個前綴／232 個呼叫點，逐一枚舉 token 值域後補 39 鍵。含 `UI_optionscreen_gamepad_JoypadAxis1d_name_*` ×4（**無 gate，控制器綁定畫面直接外露原鍵**）、`IGUI_AnimalUI_Info_*` ×13、`IGUI_Gametime_*` ×3 等。
  - **Java 側**：以平衡括號解析 12997 個 .java，得 1025 個呼叫點／27 個入口方法（基準 regex 只命中 6.4%），補 11 鍵。最高嚴重度是 `Fluid_Container_FuelPump`——`ContainerName = Fuel Pump` 經 `removeWhitespace()` 成 `FuelPump`，**單人可達、零 gate**，加油站抽油時視窗標題直接顯示原鍵。
  - **`IGUI_Key_` 補 74 鍵**：不採信稽核報告的 token 清單（實查有誤），改自 `Keyboard.KEY_*` 常數過 `KeyCodes.toGlfwKey` 的實際轉換規則確定性枚舉，得穩定 token 83 個。另 47 個會被 `glfwGetKeyName` 依鍵盤配置改寫的 token 一律不補。
- **RichText 吞字回歸，76 鍵**。`RichTextLayout` 的 tokenizer 對同時含 `<` 與 `>` 的 token 會整段丟給 `processCommand`，**`<` 之前的正文永遠不會進 `self.lines`**。逐字空格清理把「健 康 面 板 .`<LINE>`」變成「健康面板.`<LINE>`」後，吞掉的字從 1 個變成整句——24 鍵共 975 字。以獨立 Python 複刻 tokenizer 量化後修正，並連同既有同型 52 鍵一併處理。
- **逐字空格排版倒退 110 筆**。判準原本比對「對側語言」，但官方 CH 乾淨、官方 CN 帶空格時，我方 CH 抄了 CN 的排版就會被放行。改以**官方同語系同鍵**為判準後重掃，區分出 341 筆繼承自官方與 83 筆我方倒退，並補回 35 個遺失的 `<SIZE:small>` 標記。
- **同名撞名 4 對＋配方↔擺放物異名 6 組**。`Base.WaterPot{,Forged}{Pasta,Rice}` 與 `{Pasta,Rice}Pot{,Forged}` 在 CH 四對全部同名（Forged 那兩對官方 CH 亦撞），改用既有的 `(水, 原料)` 軸區分。另六件物品在建造選單與擺放物名兩處叫法不同（EN 兩處字串相同），統一為攪乳桶／亞麻除籽梳／麻梳／單寧鞣製桶／木十字架／軟化樑。
- **官方 `Translator.getMoveableDisplayName` 的去句點失效，補 6 鍵**。`replace("\\.", "")` 是 `String.replace(CharSequence,CharSequence)`，`"\\."` 就是字面兩字元 `\.`，名稱裡永無反斜線故**永不命中**，句點原封留在查表鍵裡。官方翻譯檔只建了去句點版本，執行期查的卻是帶句點版本 → 顯示英文原名（`Dr. Oids Poster`、`Premium Tech. Walkie Talkie` 等）。補帶句點版本並保留原鍵。
- **陸港用語與正字**：CH 大米→白米 ×9、黃油→奶油 ×3、蒜蓉黃油→蒜香奶油、梁→樑 ×5（結構樑；姓氏「梁」不動）、`IGUI_CraftingWindow_Loom` 織機→織布機（與同 EN 值的 `_Weaving` 統一）。CN 側補齊無線電家族的內部矛盾（同一支美國陸軍設備，無線電叫「美国陆军」對講機卻叫「军用」）。
- **改到死鍵上的修正**：`CharcoalBurningPit` 在 `media/` 除翻譯檔外零引用，活鍵是 entity 名 `Charcoal_Pit`（經 `Literature.java` 顯示於配方書 tooltip）。CN 側原本改在死鍵上，已移到活鍵。
- **`Press` 缺鍵**：`ES_Hand_Press` 的元件顯示名去空格後仍是 `Press`，`Recipes.json` 無此鍵 → 工作站元件分頁顯示英文。已補。

### Added

- **兩道 `fix-check` 守門檢查**：RichText 吞字偵測（以複刻的 tokenizer 計算每個值會被吞掉的正文字元數）、實體工作站名稱涵蓋率。前者補上時 `fix-check` 原本是全綠的，等於這類回歸過去完全無人把關。
- **兩組可鑑別回歸測試**：`test_cjk_spacing.py`（直接呼叫產品函式，不複刻判定邏輯）、`test_xui_entity_names.py`（以大括號配對解析 xuiSkin，並從 Lua 原始碼抓 pattern 比對）。兩者皆以注入迴歸實測過會失敗。
- **`scripts/terminology.json` 新增 4 條規則**：大米→白米、黃油→奶油、蒜蓉→蒜末（replace），梁→樑（select，姓氏 `SurvivorSurname_Leung` 列入 cases 白名單禁自動替換）。
- **登記簿新增 A26／A27／A28**，涵蓋動態拼鍵缺鍵、去句點失效、以及 xuiSkin `DisplayName` 的實際翻譯路徑。

### Removed

- **`SurvivalGuide_*_entrieN*` 83 鍵**（CH/CN 各 83）。B41 舊體例；B42 改用 `SurvivalGuideEntry.registerBase(id)` 產生 `SurvivalGuide_{id}_title`／`_description`，舊體例在反編譯 Java 全樹只命中第三方函式庫、PZ 自身零引用。刪後 CH/CN 各 229 鍵，恰等於官方 EN 鍵數；B42 必要的 192 鍵與 19 個 `_description_joypad` 變體 100% 覆蓋。

### Notes

- **`versionMin` 維持 42.20.1**；零機制變更，未新增任何 Lua 修補檔。
- **技能「焊接」改回「金工」**（推翻 2026-07-29 的決定）。當初只看了 `IGUI_CraftingCategories_*` 一層，造成同一個技能在包內三種叫法——製作需求列「焊接」、技能書物品名與沙盒倍率「金工」、右鍵選單「金屬加工」。撞義顧慮亦不成立：官方本體 CH 自己就是「金工」（Welding）與「金屬加工」（Metalworking）並存。
- **一次自我推翻**：曾判定 xuiSkin 的 `DisplayName` 因 `Translator.getTextInternal` 是純前綴路由而永遠翻不到，據此寫了 Lua 修補與 88 個新鍵。實際上 `XuiSkinScript.java` 在**腳本解析期**就先做 `replace(" ", "")` → `getRecipeName()`，`Recipes.json` 才是真相來源，44 個名稱有 43 個本來就正常。整批已撤銷，教訓記於 A28。同源的 `MetalDoor(Poor)`／`(Shoddy)` 誤判為死鍵後亦已復原，並順修「門框」誤植與非官方詞彙「劣質」。
- 全程經 Claude 與 codex 雙邊 review-plus 獨立審查。兩邊互有補正：codex 抓到上述 xuiSkin 生產端與 A27 錨點引用錯誤，Claude 抓到 `CharcoalBurningPit` 改在死鍵上與第三顯示面漏對齊。
- **未做遊戲內實機驗證**（使用者指定）。本版全部變更為翻譯 JSON 與工具鏈，無 Lua 行為變更。
- 驗證：六組測試全綠、`terminology` selftest 通過、`fix-check` 五項全綠、CH/CN 各檔鍵集合完全對稱、`MOD/` 髒檔檢查無輸出。

## [42.20.2-1.15.3] - 2026-08-08

### Fixed

- **電視／廣播台詞 178 鍵校訂（RadioData + Recorded_Media）**。起因是模組翻譯包補譯 Emergency TV Channel 時發現：該模組把本體的電視節目搬到自己頻道重播，**同一批英文原文被翻了第二次**，兩包並存會讓同一句台詞出現兩種譯法。逐條比對後分兩批處理：
  - **客觀缺陷 88 鍵**：空白與標點正規化 48 條（`*砰**砰*`→`*砰* *砰*`、行尾多餘空格、`[img=music]木工` 缺空格）、陸港用語 31 條（珠峰大本營→聖母峰基地營、夏爾巴人→雪巴人、回形針→迴紋針、鐵鍬→鐵鏟、韭菜→韭蔥「leek 非 chive」）、內容錯位 9 條（`Now I love a BLT` 原譯「今天我想做三明治」、相鄰兩句被併成一句）。
  - **語氣與一致性 90 鍵**：原判為「主觀品味」而擱置，逐條查證後發現**多數其實是本包自己的內部不一致**——`Base.Twine` 本包譯「麻繩」但台詞寫「合股線」、`Base.PiePrep` 是「餡餅底餅」卻寫「餡餅皮」、`Base.TrapCage` 是「誘捕籠」卻寫「木籠陷阱」、作品名用《》是本包慣例（全庫 1,540 處）卻漏了兩檔節目名、`yee-hah` 本包已有 5 鍵譯「好耶」而「哈哈／歡呼聲／很激動」才是離群譯法。落地後《木工達人》11/11、《勇闖荒野》9/9、`yee-hah` 12/12 一致。
- **`Recorded_Media.json` 藏著同兩檔節目的完整錄影帶重播腳本**，與 `RadioData.json` 同英文異中文達 340 條。本次 37 條台詞在該檔**全部**都有對應，且該檔版本更糟（全形標點、「妳」、「回形針」、把 `Wooden Cage Trap` 譯成「陷阱箱」＝`Base.TrapCrate` 是另一個物品）。只改一邊等於做一半，故兩檔同步套用同一最終值。
- **`Knee-length Dress` 連衣裙→及膝洋裝，7 鍵**。「連衣裙」為大陸用語，台灣通稱洋裝。

### Notes

- **`versionMin` 維持 42.20.1**；純翻譯品質修訂版，零鍵增刪、零機制變更。
- 刻意未動：`RM_e97c2610`「深蹲鍛鍊臀部」與 `RM_626d5062`「讓臀部儘量往後伸」是健身指導，臀部才是正確的解剖用語（同批把 `rear` 統一為「翹臀」，但這兩鍵不適用）。
- 驗證：`ch-lint` 命中 287，與修改前**完全相同**（零新增）；5 支測試全過。

## [42.20.2-1.15.2] - 2026-08-06

### Fixed

- **採納玩家建議（水煮麵包）：鐵砧 tooltip 術語對齊**。`Tooltip_item_BlacksmithAnvil`「簡單或高階鍛造爐」→「**簡易**或高階鍛造爐」——與建造選單工作站定譯一致（`Recipes.json` `Forge`＝簡易鍛造爐；CN 同步 `简单→简易`，官方 CN 上游自身即不一致，照修）。句尾「單獨使用無用」（CN 直借翻譯腔）改「無法單獨使用」，`Tooltip_item_StoneAnvil`（石砧）同款句尾一併對齊。玩家引用的「用來建造鐵匠鐵砧」為官方本體 CH 的循環錯譯，本 MOD 自 .txt 時代即已修正；建造機制查證：簡易/高階鍛造爐建材各需鐵砧 ×1，EN 敘述與機制相符。
- **查證順帶挖出三處 Tooltip 缺陷**：CH `Tooltip_craft_wallLogDesc`（原木牆）「製作簡單但耗費資源」整句重複兩次（刪）；CN 同鍵整句漏翻（補）；CN `Tooltip_item_LargeBellows`（大風箱）「需要建造高级锻造炉或熔炉」依賴方向講反（改「建造高级锻造炉或熔炉所需」，對齊 EN "Needed to build…" 與 CH 既有正確譯法）。

### Added

- **疊句偵測補強 `_has_br_segment_dup()`**：`<br>` 切段後相鄰段全等即判「整句貼兩次」。wallLogDesc 這類錯誤過去全數漏檢——重複單元 9 字超出片段 regex 的 8 字上限、分隔又是多字元 `. <br>`，兩條 pattern 同時失效。新檢查不受 `_DUPE_MAX_LEN` 60 字閘門限制（段落全等無修辭誤報，全庫掃描 0 誤報）、respect allowlist/skip-file，接進 `check_duplicated_fragments` 隨 `fix-check` 把關。`test_dupe_patterns.py` 新增 BR_CASES 四案＋走 `check_duplicated_fragments()` 真入口的整合案例（>60 字命中／skip-file／allowlist 三契約）。

### Notes

- **versionMin 維持 42.20.1**；純翻譯品質與工具鏈修訂版。
- 經 Claude 與 codex 雙邊 review-plus 獨立審查（皆 COMMENT 無 blocking）；codex 指出的整合測試缺口已補。

## [42.20.2-1.15.1] - 2026-08-06

### Changed

- **42.20.2 對版確認：與官方 hotfix 完全相容，零缺鍵**。官方本次在 `Translator` 加入 `IllegalFormatException` 安全網（裸 `%` 不再黑畫面，降為 console warning）、讀取畫面 quick tips 改存翻譯鍵並於顯示時翻譯（`%%` 從此正確渲染為 `%`）、EN 剩餘 109 鍵完成格式遷移（`%s`/`%i`/`%.1f`→`%N`、`%`→`%%`）——零增刪鍵，本 MOD 已於 1.15.0 提前對齊，逐鍵驗證零改動。硬編碼修補全表 delta 驗證通過：`check_debug_menu_coverage` 與基準吻合（168/167）、42.20.2 變更的 9 個 vanilla Lua 檔錨點全在、五個 gen-* 查表冪等（詳 `HARDCODE_REGISTRY.md` §0 對版結論）。
- **死鍵大掃除：CH/CN 各移除 354 鍵**。對 2,746 個官方 EN 已無的多餘鍵做全量分類與動態組鍵存活查證（6 agent 對抗式查證＋抽樣複核 34 鍵零推翻）後，刪除 333 個確認死鍵（B41 `Recipe_*` 底線形 201、B41 已滅模組物品名 55、舊地圖標籤 39、`Moodles_Bleed`/`UI_Map_*` 等改鍵遺留）與 21 個官方已刪的舊版 joke tips（quick tips 對齊官方 65 鍵）。162 個「EN 沒有但遊戲動態組鍵仍查得到」的活鍵（大地圖 `IGUI_MapOption_*`、燒毀/砸毀車 `IGUI_VehicleName*`、Moveables tile 組鍵、`Moodles_Dead_desc_lvl1` 等）查證後保留。稽核紀錄與 keep_alive 清單入庫 `scripts/dead_keys_audit_42.20.2.json`，升版清鍵前必讀。
- **`gen-radio-map`（收音機/電視字幕反查表）對版與契約補強**：表鍵改用 `formatted()` 後的執行期形（`%%`→`%`），修正 42.20.2 EN 四筆 `%%` 廣告台詞在 A7 修補中永遠 miss 的隱患；生成器 raw/runtime 分離（未譯判定用 raw 值）、值含 `%N` 或正規化碰撞出不同譯文時 fail-closed 中止；`RadioData_Flx` 譯文快取同步轉執行期形（`setText` 直寫不經 `formatted()`）。新增 `scripts/test_radio_map_tokens.py` 回歸測試（6 案）。
- **sync-cn 凍結為墓碑（CN 側維護模式與 CH 對齊）**：As1 上游改為僅供參考、REF 更新後逐筆審查再手動入庫；`cn_overrides.json` 封存（值皆已實體化進 CN 檔，含本次死鍵 deny-list 306 筆）；修 CN＝直接改 MOD CN 檔即 durable，改後必跑 `fix-check`。`sync-all`＝Lua＋fix-check。

### Notes

- **versionMin 維持 42.20.1**；1.15.0 與 42.20.2 完全相容（官方安全網屬向下寬容），本版為對版維護與清理版，無 crash 級修復。
- 經 Claude 與 codex 雙邊 review-plus 獨立審查；codex 抓到 gen-radio-map raw/runtime 混比與 `setText` raw 寫回兩缺陷，均已修正並補測試。
- 另補錄兩批 2026-07-31 已隨先前版本出貨、依「發版時總整理」規則於本版寫入 CHANGELOG 的變更（見下）；同期另有術語增補 commits（7ad4037 車輛「桿」正字與四車廠名、312f5a6 發動機→引擎、夠不到→搆不到）。

<!-- 批次一：CH 凍結與術語引擎（2026-07-31） -->

### Added

- **術語真相表與引擎**（`scripts/terminology.json`＋`terminology.py`）：以顯式規則取代 OpenCC s2twp 隱式詞庫——charfix 24 條異體字、replace 約 122 條（regex 護欄必附正反例測試，載入時強制 selftest）、select 25 條（語境敏感禁自動改：通過/透過、高級/高階、性能/效能、社區/社群、連接/連線、保存/儲存…）。淘汰規則記 `_dropped`（發佈→釋出、循環→迴圈、壁紙→桌布、鏡像→映象等 s2twp 有害行為）。
- **outcome-equivalence 等價證明**（`scripts/test_terminology_equivalence.py`）：新術語管線 vs 舊 OpenCC 管線對 REF 全語料 47,677 值逐值比對，817 個差異桶全數裁定（select 設計預期／已裁定改進／淘汰／逐字空格變體／一簡對多繁 ClassC），**PASS**。
- **CH 凍結與新維護迴路**：`sync-ch` 墓碑化（CH 檔即人工真相，不再由 REF 全量再生）、OpenCC 自本體管線移除；新增 `en-snapshot`（官方 EN 47,251 鍵基準快照，入版控）、`en-diff`（官方更新後產維護佇列——只看 git diff 會漏掉官方改英文原文）、`import-new`（官方 CH 底稿＋術語引擎產新鍵提案，人工簽核入檔）、`ch-lint`（select/lint 詞巡檢）。`ch_overrides.json` 封存為歷史紀錄。CN 管線不變。

### Fixed

- **舊管線 s2twp 盲轉產物 91 鍵**（分類過程的語料稽核挖出，全部逐筆判讀＋對照修復）：`宣告→聲明` 29（新聞/官方 statement 語境：總統聲明、免責聲明、聯合聲明）、`釋出→發布` 21（新聞發布會→記者會、發布聲明；釋出僅軟體 release 義）、`社群→社區` 20（住宅/地理社區：以革倫社區大學、社區地圖）、`效能→性能` 9（汽車制動性能）、`高階→高級` 5（高級訂製）、`連線→連接` 4（物理連接）、`繫結→綁定` 4、`區域性→局部` 3、`全域性→全域` 3、`支援→支持` 2（政治表態）、`專案→項目`、`儲存→保存`、`廚房/工業裝置→設備` 2。
- **切詞災難**：`河流部分割槽域氾濫`→`部分區域`（舊管線把「部分＋區域」切成「部分割槽域」）。

<!-- 批次二：SurvivorNames 與三方稽核（2026-07-31） -->

### Added

- **SurvivorNames 6,003 個官方繁中人名採用**：此檔 6,008 鍵過去與官方 EN 逐字相同——本 MOD 實際上把官方既有的中文名蓋回英文（NPC 名、殭屍屍體名牌、建角隨機名）。整批採官方繁中進 `ch_overrides`；CN 側官方本身未翻（全英文），以 OpenCC t2s 由繁中轉出。官方未翻的 5 筆（`Bender`/`JC` 等）維持英文。
- **官方音譯選字修正 18 個名字／22 鍵**：官方選字不作姓氏的硬錯（`Pham 範→范`、`Chau 紂→周`、`Phan 幡→潘`、`Do 督→杜`、`Tran/Chan 辰→陳`、`Le 勒→黎`、`Vo/Vu→武`、`Dang 唐→鄧`、`Ly 賴→李`）與官方自身前後不一致（`Yang/Duong 陽→楊`、`Ng 黃→吳`、`Lam 蘭→林`、`Li 利→李`、`Yu 悠→余`僅姓氏）。鍵定位、非值取代——`黃` 家族（Huynh/Hoang/Hwang/Huang）零誤傷。
- **三方比對稽核**（官方 EN＝裁判、官方 CH＝對照、我方 CH＝受審）：21,383 筆分歧按風險分帶，core 高風險 1,695 鍵**全量**＋med/flav/lo 抽樣 660 鍵逐筆判讀，每筆 ours_wrong 經獨立對抗複核（推翻誤報 6 筆）。判讀防錨定：第一輪隱藏官方 CH，避免錨定在官方自身的錯譯上。
- **`suspicious_patterns` 支援 `skip_files` 整檔豁免**：SurvivorNames 全為人名音譯，「里」恆為正解——62 筆固定誤報歸零，避免噪音讓人習慣性忽略提示。

### Fixed

- **稽核確認錯誤 114 鍵＋姊妹鍵擴展（CH 約 259 鍵、CN 73 鍵）**：
  - 語意錯譯：`Full Top 頭頂→全上身`、`Ear Top 耳罩→上耳部`、`RESUME 返回→繼續遊戲`、`Clean Burn 清潔傷口→清理燒傷`、`Old Stove 壁爐→舊式火爐`、`Chalk Board 粉筆板→黑板`、`Wanted Notices 懸賞令→通緝令`、`invisible 無敵→隱形`（管理員會誤解指令）、引爆／啟用時間區分、喉縮 (擴散)→(改良縮口)（兩款皆縮小散布，原標註為事實錯誤）、雪松矮書櫃、緊身褲→長褲（EN=Pants）等
  - 壞文本：車名後綴重複 **15 鍵跨三車系**（`(東南油漆) (東南油漆)`）、AntiCheat 機翻碎句 20 鍵（`禁用的防作弊保護. 類型 N.`→`停用類型 N 的反作弊保護.`）、`塊石堆步→快石堆步`（同音誤植，含姊妹鍵與 CN）、逐字空格與標點空格殘留（含 StarterCondition 家族、大型伺服器警告整段）
  - Stash 藏寶圖：空值出貨 22 鍵（官方 CH 有內容我們空白）、人名劇情錯譯（`Vicky 維科→薇琪`、`June 桑德拉→茱恩`、`catfish restaurant 酒吧→鯰魚餐廳`、`barricade 架設路障→加固防禦`）
  - 名著引文：魯濱遜漂流記對仗補正、婚誓 `forsaking all others`、Amazing Grace `now I'm found 現在堅定→今被尋回`
  - 台灣用語家族：文胸→胸罩 17、曲奇→餅乾 7、創可貼→OK繃 6、西葫蘆→櫛瓜 7、半身裙→裙子 4、易拉罐→空汽水罐/易開罐 6、懸掛→懸吊 3、僵毀→殭毀 3、華夫餅→格子鬆餅、薄煎餅→美式鬆餅、彈球機→彈珠台、托盤→棧板、悉尼→雪梨、高身鏡→全身鏡
- **needs_human 15 筆全數以遊戲資料實證結案**（tile 定義／藏寶圖腳本座標／媒體 UUID 序列前後文）：修 9 鍵（`斯皮福大牆紙→大型斯皮福牆飾`（4 格寬牆面吉祥物）、`井噴銷售→清倉特賣標牌`（通用促銷招牌集）、`粗製書架→粗製木層架`（落地式）、`木製紀念樁→木製墓標`（墓園 tileset）、`None 禁用→無`、LVMap16 兒子遇害讀法等）；6 筆查證後確認我方原譯正確維持（easier way out＝逃生路線、Dog Goblin 的狗吠、Don Beverage 自報姓名等）。
- **補譯與其他**：未翻譯 16＋1 鍵（`Accept`、雜誌名 `GameZ/Merc!/Sixteen`、SCBA）、人名 `拉託亞→拉托亞` 5 鍵、`SurvivalGuide_WindowTitle` 逐字空格。

## [42.20.1-1.15.0] - 2026-08-05

### Fixed

- **修復 PZ 42.20.1 更新後主選單黑畫面（無法進入遊戲）**。42.20.1 的 `Translator` 移除無參數 `getText` overload，所有翻譯值一律經 Java `String.formatted()`，而載入期 `formatFixer` 只認 `%%` 與 `%1`–`%9`——本 MOD 沿用的舊式裸 `%`（如 `UI_BloodDecals1` 的 `10%`）拋出未被捕捉的 `UnknownFormatConversionException`，炸掉主選單建構（`MainOptions.lua:889`、sandbox tooltip 同型）。官方全語系翻譯檔已於 42.20.1 同步改為 `%%` 逸出、printf 式（`%s`/`%d`/`%i`/`%.1f`）全轉 `%1`–`%9` 編號佔位。
- **CH/CN 共 184 筆翻譯值依官方新規則遷移**（24 檔）：字面 `%` 一律 `%%`、printf 佔位依出現順序轉編號。逐鍵與官方 42.20.1 EN 佔位 token 交叉驗證一致；全語料 9.9 萬鍵以工具從舊值重推零偏差；真機啟動驗證主選單無任何格式化例外。

### Changed

- **同步管線防復發**：`sync_translations.py` 新增 `sanitize_format_tokens()`（冪等），`sync-cn` 寫出前自動整理上游 As1 仍在使用的舊式裸 %；無法等價轉換者（printf 與編號混用、超過 9 個、`%02d` 類變體）fail-closed 拒寫並以失敗狀態結束，須入 `cn_overrides.json` 人工處理。
- **fix-check 新增「% 格式 token 檢查」**：唯一 crash 級守門（發現危險 % 序列以 exit 1 失敗），涵蓋 `%N$`（Java 編號式）與 `%N` 後緊接數字（`%10` 實為 `%1$s`＋字面 0）等 formatFixer 邊角；city 檔（title/description 走 `readMapTranslation` 原樣取值、不經 formatted()）與 sync 對稱豁免。新增 `scripts/test_format_tokens.py` 回歸測試（sanitizer 16 案例＋checker 8 案例）。
- **文件同步改版**：AGENTS.md「Translator placeholder / 百分比規則」整段改寫為 42.20.1 統一規則——舊的「含 %N 不可寫 %%」兩套機制判斷已失效，照舊維護會重新引入 crash；HARDCODE_REGISTRY.md 的「42.20 % 正規化行為一致」結論標註推翻，A25 錨點補 42.20.1 對應。

### Notes

- **versionMin 提升至 42.20.1**：`%%` 逸出值在 42.20.0 的無參數 getText 路徑會原樣顯示雙百分號，新版翻譯檔不向下相容舊版遊戲。
- 經 Claude（code-reviewer agent）與 codex（review-plus）雙邊獨立審查；codex 以 JDK 實測 184 筆遷移值全數通過，並促成 fail-closed 設計與 `%10`／`%N$` 漏檢補強。
- 模組包 MinidoracatModLangFor42 存在同型問題（掃出 2,728 筆危險值），將另行發版修復；未更新前開啟含模組包的存檔仍可能觸發同類 crash，兩包需一起更新。

## [42.20.0-1.14.3] - 2026-08-04

### Fixed

- **車窗物品名去歧義：`Base.{Front,Rear}Window{1,2,3}` 由「車前窗／車後窗」改為「前側車窗／後側車窗」**（CH 六鍵；CN 維持官方「车前窗／车后窗」不動）。原譯與官方繁中的「前車窗／後車窗」都有誤讀風險：「車前窗」字面是車子前方的窗，與擋風玻璃概念重疊；「後車窗」在台灣車廠手冊（如 KIA zh_TW）常用來指後擋玻璃。

  遊戲資料實證這是**側窗**而非擋風玻璃——`media/scripts/generated/vehicles/template_window_nodoor.txt` 的 `part WindowFrontLeft { area = SeatFrontLeft, itemType = Base.FrontWindow }`，且 `media/scripts/generated/items/normal.txt` 的 `item FrontWindow1 { Icon = SideWindow }`（Windshield 用的是 `CarWindshield`）。改用「前側車窗／後側車窗」後與同畫面的「擋風玻璃／後擋風玻璃」零歧義，並符合交通部公路局隔熱紙法規「前側窗／後側窗」與「前擋／後擋」的分類。

  槽位名（`IGUI_VehiclePartWindowFrontLeft`「左前窗」等六鍵）維持不動：歧義只存在於單獨出現的物品名，槽位顯示在技工面板車輛示意圖上、位置本身即語境，且被多個載具 MOD 的複合詞（左前車窗裝甲／防護）引用，變更波及面大而收益小。

### Notes

- 模組包 MinidoracatModLangFor42 於 `42.19.0-1.8.0` 同批對齊：`CraftVanillaVehicle{Front,Rear}Window*` 12 個配方名一併改為「製作前側車窗／後側車窗 (…)」，兩包術語統一。兩包需一起更新才不會出現「配方名與產出物品名對不上」。
- 裁決經 Claude 與 codex 雙邊獨立審查；codex 以本機遊戲 script 佐證側窗判定，並指出官方「前車窗」僅解決前半歧義。

## [42.20.0-1.14.2] - 2026-08-04

### Fixed

- **物品名稱遷移（登記簿 A20）自 `276c3c5` 起從未生效，本版首次真正修復**（玩家回報多人伺服器野採物 `Lemongrass (Wild) (新鮮)` 中英混雜）：修補程式誤把 `item:getDisplayName()` 當成「當前語言譯名」，但它的 Java 實作就是 `return this.name`（`InventoryItem.java:3204-3206`）——取到的正是**要被取代的英文字串本身**。三個獨立死因疊加：(1) 早退判準恰好攔掉「中文客戶端被烘成英文」這個唯一要修的主場景；(2) 第一分支條件必被該早退覆蓋而不可達，且 `setName(getDisplayName())` 是恆等式，即使可達也是空操作；(3) 比對基準用 `getName()`，會被 新鮮／陳腐／染血 等狀態前綴包住，99 個野採物中只有無 `DaysFresh` 的 `Base.Peanuts` 能命中。建築鑰匙分支雖可達，但寫入來源同樣是英文原字串，實際在**污染**名稱（輸出 `Key - Army Surplus Store - 軍用品店`）。修正：寫入來源改用 script item 的 `getDisplayName()`（由 `Translator.getItemNameFromFullType` 以本機語言在地化，才是真譯名，與本 MOD 另五個檔案的既有寫法一致）；比對基準改用未經裝飾的原始名稱。多人伺服器上的野採物、建築鑰匙、煮食後食物名終於會顯示中文。

- **角色資訊面板「慣用武器」顯示英文武器名（新增登記簿 A24）**（簡中玩家回報 `Baseball Bat with Rake Spikes`）：非缺鍵——該武器譯文一直都在，但官方把「寫入當下語言的顯示名」當成存檔 modData 的 **key**，讀取時直接取 key 後綴繪製，全程不查翻譯表。多人下擊中結算跑在伺服器，故 key 是伺服器語言並永久烙進存檔。新增 `ISCharacterScreen_Flx.lua` 借 A20 現成反查表還原譯名，並以還原後的名稱合併次數（必要：否則切語言後同一把武器會被拆成兩筆統計，導致「慣用武器」判定失真）。

- **鑰匙圈顯示英文 `<玩家名>'s Key Ring`（新增登記簿 A25）**：與 A1 車鑰匙、A20 建築鑰匙同家族的第三條——伺服器以自身語言格式化後烙進物品名。以哨兵字元取得當前語言後綴後只替換後綴、保留人名。

- **技能面板描述 wrapper 強化**（1.14.1 修復後仍有玩家回報）：技能識別改走方法呼叫並加上譯名反查雙保險，另在開局重新掛載一次，避免被載入期整份覆寫 `updateTooltip` 的第三方 MOD 蓋掉；新增一次性 console 訊息便於回報時判斷。

### Added

- `IGUI_PlayerStats_Role`（角色資訊面板「角色:」標籤，CH/CN 各一鍵）。
- `scripts/test_item_name_fix.lua`：A20 的離線回歸測試（20 案，涵蓋修復目標、冪等性、nil 安全與玩家自訂名誤傷防護），納入版控。

### Notes

- **新增玩家自訂名保護**：本檔所有分支都是「精確比對英文建構形」，玩家若把物品改名成剛好等於某個英文原名就會被覆寫。先前只是靠上述兩個 bug **意外**擋住，死碼修復後那層意外消失，故補上明確的全域守衛。已知取捨：`Base.PastaBowl` 的官方生成名恰為 `Bowl of Pasta`（等於英文原名）且帶自訂名旗標，因而不在修復範圍——保護玩家存檔資料優先。
- **本版修復皆未經實機測試**：A20、A24、A25 三者都只在多人環境才會觸發，目前僅有離線驗證與反編譯原始碼比對。若仍有殘留請附截圖回報。
- A20 屬顯示層修復：伺服器端仍會持續以英文寫入新物品名，客戶端在開啟容器時（最慢一分鐘內）修正；需要每位玩家各自安裝本 MOD 才會生效。

## [42.20.0-1.14.1] - 2026-08-03

### Added

- **右鍵休息／睡覺子選單父項名稱 5 鍵**（玩家追蹤回報砧板英文的真根因）：可坐/可睡物件的右鍵子選單父項標籤走 `bed.getTileName()` → Moveables 表查詢，miss 原樣顯示英文。全掃 793 個 bed tile 後補齊全部 5 個缺鍵：`Chopping_Block`（砧板）、`Stump`（樹樁）、`Lean_To_Shelter`（斜頂庇護所）、`Tarp_Shelter`（油布庇護所）、`Playground_Swingset`（遊樂場鞦韆）——後三個玩家未回報、同病一次補。官方 EN 同樣缺鍵（英文玩家看到的也是內部組合名），不依賴官方修復。

### Fixed

- **技能面板 tooltip 描述顯示原始鍵**（玩家回報 `IGUI_perks_技能_Description`，官方 bug、所有非英文語言中招）：官方 `ISSkillProgressBar` 用**譯名**拼描述鍵，但官方全語系的描述鍵一律以 EN 顯示名為鍵，只有英文環境能命中——中文的描述譯文其實一直都在，只是查不到。新增 `SkillDescription_Flx.lua`（登記簿 A23）包裝 `updateTooltip`，把 miss 的原始鍵原地替換回既有譯文；零翻譯資料變更，官方日後修正拼鍵後自動失效退場。

### Notes

- **更正 1.14.0 的錯誤結論**：當時 Notes 寫「右鍵砧板非缺鍵、屬玩家環境問題」——玩家後續截圖證實其所見英文出在**休息子選單父項**（上述 Moveables 缺鍵路徑），本版已修；砧板 entity 右鍵選項本身（1.14.0 的查證範圍）確實正常。向回報玩家致意。
- 同源掃描的 `Small_Stump`（erosion 殘根 tile）僅有 CustomName、無 bed/scrap 屬性、名稱無渲染路徑，刻意不補鍵（登記於 HARDCODE_REGISTRY A22 尾註）。
- 玩家回報的「使用者面板顯示安全屋區域與關閉鈕重疊」查證為第三方「BetterSafehouse」(3634569678) 的關閉鈕偵測 bug（欄位名清單缺 `cancel`、文字比對僅認 fechar/close/ok），任何非英/葡語言皆重現、與本 MOD 無關；修法已提供供回報原作者。
- 藥品描述 `<LINE>` 追蹤更正：實際來源為**模組翻譯包**（MinidoracatModLangFor42）收錄的上游譯文用錯換行標記，已於模組包側修正（114 鍵 `<LINE>`→`<br>`），無需安裝 EHR 也可能看到、1.14.0 Notes 歸因 EHR 有誤。

## [42.20.0-1.14.0] - 2026-08-03

### Added

- **crafting entity 右鍵／建造選單名稱 5 鍵**（簡中玩家回報右鍵咖啡機英文）：官方 xuiSkin 腳本把工作站顯示名寫死英文字面、未掛翻譯鍵（硬編碼），但腳本解析期會「去空白查 Recipes 表」——CH/CN `Recipes.json` 補 `Toaster`（烤麵包機）、`CoffeeMachine`（咖啡機）、`Loom`（織布機）、`KeyDuplicator`（鑰匙複製機）、`WoodTablewithDrawer`（帶抽屜木桌）即修，零 Lua。全 238 個 entity DisplayName 掃描完畢：可達缺鍵僅此 5；`uiEnabled=false` 無渲染路徑的 5 個與未掛載 WIP／測試批次刻意不加（詳見登記簿 A22，含升版 SOP 與量化基準）。
- **配方雜誌名稱 7 鍵**（玩家回報角色面板 4 個 base 開頭英文）：官方 `literature.txt` 用 MetaRecipe 小寫 id 當 `LearnedRecipes`，官方**全語言**均無對應鍵、UI 原樣印 id。補 `base:kitchentools`／`base:assemble_shoulder_armor`／`base:makebulletprooflimbarmor`／`base:makemagazinearmor`，並由 review 挖出同路徑的**汽修雜誌 I/II/III** 三鍵（`Basic/Intermediate/Advanced Mechanics`＝基本／中階／高階汽車維修，官方 EN/CH/CN 三邊皆缺）。`LearnedRecipes` 全 395 條至此無缺鍵。
- **拆解選單名稱 8 鍵**（玩家回報拆解門窗部分英文）：Moveables 顯示名官方連 EN 都未建鍵、所有語言裸奔。CH/CN `Moveables.json` 補 `Generic_Doorframe`（木門框）、`Generic_Windowframe`（木窗框）、`Generic_Wall`（木牆）、`Generic_Fence`（木圍欄）、`Generic_Moveable_object`（木製構件）、`Log_Gate`（寬原木門，對齊既有 `WideLogGate`）、`Metal_Wall_Frame`（金屬牆框架）、`White_Window_Door`（白色玻璃門）。

### Fixed

- **CN `Assemble_*` 十鍵上游誤譯**：EN 動詞是 Assemble（組裝）非 Forge（鍛造），As1 全譯「锻造」且與 `Forge_*` 系撞名（同畫面兩配方同名）。依「上游 CN 錯誤照修」政策經 `scripts/cn_overrides.json` 修正為「组装」（含 ref hash 登記）；CH 側自始正確。

### Notes

- 玩家回報六項全數查證：右鍵**砧板**非缺鍵（我方與官方 CN 自始有鍵；xuiSkin 譯名於啟動解析期固化，切換語言需完整重啟遊戲才生效）；建造選單 **Dark Wooden Door Frame** 屬第三方「Neat Building」(3536052310) 自身 CN/CH 翻譯檔漏翻該 3 鍵；藥品描述 **`<LINE>`** 屬第三方「EHR」把僅 richText 面板支援的換行標記用在純文字物品欄 tooltip；均不代改，供回覆玩家。
- 使用者面板「顯示安全屋區域」與關閉鈕**重疊跑版**查證為第三方「BetterSafehouse」(3634569678) 的 bug：其防重疊邏輯以欄位名（無 `cancel`）與按鈕文字（僅比對 fechar/close/ok）尋找關閉鈕，任何非英／葡語言必失敗——與本 MOD 無關（官方中文亦重現），修法（candidates 補 `self.cancel`）已提供供回報原作者。
- 硬編碼登記簿新增 **A22**（xuiSkin entity 層 DisplayName 查表繞路——機制、量化基準 238/207/31、`en-diff` 盲區警示、`Translator.debugRecipeNames()` 升版 SOP）與 **C12**（component 層 40 筆英文字面現況不可達之觀察項，含預研修法與升版觸發條件）。
- 本批經三獨立 review lane（code-reviewer／critic／codex review-plus）全數 findings 修畢後 APPROVE；`sync-cn` 位元組級冪等實證兩次。

## [42.20.0-1.13.3] - 2026-08-02

### Changed

- **`MapSpawnSelect_Flx.lua` 改為包裝 `setImagePyramid()`，不再整份複製官方 `fillList()`**（112 行 → 42 行，玩家端行為不變）：原做法是把官方 `MapSpawnSelect:fillList()` 整份抄過來、只在結尾多加一段強制指定中文地圖底圖，代價是官方每次改動該函式都得人工跟版——1.10.0 就因此漏抄官方新增的 `only_for_game_mode` 過濾條件，讓 7 個沙盒限定城鎮出現在非沙盒模式的出生城鎮清單。改為包裝 `MapSpawnSelectImage:setImagePyramid()`（官方 42.20 全碼僅 `fillList` 一處呼叫），在轉交原函式前把參數換成 `getMapInfo("Riverside, KY").spawnSelectImagePyramid` 的絕對路徑，清單／過濾／排序邏輯完全交還官方，日後官方改動會自動跟進。
  - **為何仍需 Lua 介入**：官方英文底圖在 `maps/Muldraugh, KY/`，而該目錄承載全世界的 `.lotheader`／`.lotpack`；`ZomboidFileSystem.searchFolders()` 對路徑含 `media/maps/` 的**目錄本身**也會登記進 `activeFileMap`（空目錄亦然），MOD 一旦建立同名目錄就會遮蔽官方地圖資料。中文底圖因此只能放不含世界資料的 `Riverside, KY/`，再由 Lua 指定。
  - **屬條件式替換**：僅在官方決定使用 image pyramid 時換參數。固定伺服器出生點、安全屋等 synthetic region 沒有 `map.info`，官方走 `initMapData()` fallback、不會呼叫此 setter，維持原版行為。
  - 一併移除原檔死碼：`getActivatedMods()` 模組 ID 檢查的兩個分支執行的是同一件事。
  - log 訊息改為純 ASCII（PZ 的 `print()` 不支援 UTF-8 中文，會顯示為 `?`）。

### Notes

- 本次未新增或修改任何譯文，也未觸及出生座標邏輯——出生座標一律由官方 `CharacterCreationProfession.lua` 從各城鎮 `spawnpoints.lua` 取得，本 MOD 不介入（`maps/Riverside, KY/` 禁止放 `spawnpoints.lua` 的規則不變）。
- 玩家回報「啟用本 MOD 後角色出生在室外」經查證為 1.10.1 之前誤留的 `spawnpoints.lua`（B41 舊座標）所致，該檔已於 42.20.0-1.10.1（2026-07-30）移除，1.13.x 均不受影響；本次重構與該問題無關。

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
