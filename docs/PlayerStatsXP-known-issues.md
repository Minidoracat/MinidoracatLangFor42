# 管理員 Player Stats 面板（PlayerStatsXP_Flx）— 已知問題與測試清單

適用檔案：

- `42/media/lua/server/PlayerStatsXP_Flx.lua`
- `42/media/lua/client/PlayerStatsXP_Flx.lua`
- `42/media/lua/shared/Translate/{CH,CN}/IG_UI.json`（`IGUI_CatLangStats_*`）

適用版本：B42.20.x dedicated server。

---

## 這次改了什麼

原本的問題：管理員用 Player Stats 面板替玩家調技能，**反而會害那位玩家被反作弊封鎖**。

原因是 42.20 起反作弊基準存在 `NetworkCharacterAI.XpChecker`，官方所有加 XP 路徑（`AddXPCommand:83`、`GameServer.addXp:1848`、`XP.load`）都會呼叫 `updateXpChecker()` 重設它，本 mod 繞過官方 `/addxp` 卻沒有重設。舊版試著呼叫 `ai:updateXpChecker()`，但 `NetworkCharacterAI` / `NetworkPlayerAI` **都沒有 `setExposed` 到 Lua**，Kahlua 索引不到其上任何方法——那行是死的，每次操作還會丟一個 Lua 例外（正式服 log 中約每天 24 次）。

修法是把整條路徑改成 server 權威：

| 面向 | 舊 | 新 |
|---|---|---|
| 反作弊基準 | 呼叫不存在的方法，靜默失效 | 走唯一 Lua 可及的入口 `addXpNoMultiplier(target, perk, 0)` → `GameServer.addXp` 內部重設 |
| 等級變更 | client 本機 `AddXP`，再靠封包同步 | client 只改顯示層，server 依自己的權威值推算 |
| vanilla 升降級副作用 | 完全沒觸發 | 補 `triggerEvent("LevelPerk", ...)`，`addBuffer` 依方向對齊 vanilla |
| trait 增刪 | `SyncXp()` 把管理員手上的舊副本整包推回 server | server 權威套用，client 不再呼叫 `SyncXp`；`modifyTraitXPBoost` 改在 server 端做（見「2026-08-16 修正」第 2 項）|
| 併發點擊 | 無節流，第二筆會把第一筆未確認值當成回捲目標 | single-flight，鎖 **(目標 onlineID, perk／trait)** |
| 失敗回饋 | 無聲 | halo 提示，CH / CN 皆有翻譯 |

順帶修掉的：

- **調完 Fitness 到 10，角色身上仍掛著 `OUT_OF_SHAPE`**。`setPerkLevelDebug` / `setXPToLevel` / 零量 `AddXP` 三者都走不到 Java 的 `LevelPerk`，而 dedicated server 有註冊 `Events.LevelPerk.Add(xpUpdate.levelPerk)`（`XpUpdate.lua:395`），那個 handler 做的是實質遊戲邏輯：`checkAutoLearn`、Strength 的 `WEAK/FEEBLE/STOUT/STRONG`、Fitness 的 `UNFIT/OUT_OF_SHAPE/FIT/ATHLETIC`、以及 Farming / Mechanics / Electricity 的門檻配方。不補的話跑速、耐力、負重、近戰全部維持舊檔位**並寫進存檔**。
- **技能摘要被掛到管理員身上**。舊版對 remote 的 `self.char` 做樂觀 `AddXP`，跨級時觸發 `GameClient.sendPerks`，而 remote target 的 `playerIndex` 預設 0、server 卻以送出端連線的 slot 0 解碼。
- **trait 編輯回滾玩家 XP**。`SyncXp` 送的是完整 `XP.save()`、server 端直接 `XP.load()` 清空重建 traits / xpMap / perkList / multipliers；管理員手上的副本只在連線當下灌入一次（`ConnectedPacket.java:169-174`），那一推會把目標連線後累積的一切打回舊值。
- **殘留英文升級浮字**。

---

## 2026-08-16 修正（第二輪雙邊審查後）

第一版交付前又跑了一輪 Claude 獨立驗證 ＋ codex `review-plus`／對抗審查，抓到 7 項並全部修掉。
其中第 1、2 項是**會讓玩家被誤判處置**的實質風險，不是顯示瑕疵。

| # | 問題 | 修法 |
|---|---|---|
| 1 | trait 變更後未重設 `XpChecker`。原先的理由「反作弊取 `Math.max(newXpBoost, oldXpBoost)`，基準過期只可能讓門檻更寬鬆」**是錯的**：`AntiCheatXPUpdate.java:33-40` 的 `FAST_LEARNER`／`CRAFTY` 1.3 倍直接讀**當前** `characterTraits`，沒有 boost 數值層那道 `Math.max` 保護（:22-25）。移除其中任一個之後門檻立刻少 23%，baseline 卻仍停在移除前，delta 會把移除前（還享有加成時）累積的 XP 一併算進來 | trait 寫入後同樣呼叫 `resetXpChecker(target, Perks.Strength)`，失敗回 `reason=xpchecker` |
| 2 | `modifyTraitXPBoost` 呼叫在錯誤的一側。**先前一版曾誤判為「server 不該寫 boost，否則會與目標 client 分岔並害玩家被誤判」而整個移除——那是錯的**：MP 的 XP 是 server 權威，`addXp`／`addXpNoMultiplier` 的 Lua 綁定在 MP client 上兩個分支都不成立、整個呼叫是 no-op（`LuaManager.java:11803-11825`），server 端 `AddXP` 算加成（`IsoGameCharacter.java:17359-17373`）與反作弊算門檻（`AntiCheatXPUpdate.java:23` → :17262-17263）讀的是同一張 server map，同源不可能分岔 | **server 端呼叫**（vanilla 只對管理員手上的遠端副本呼叫，等於沒生效——vanilla MP 下加 trait 只有 membership 生效、XP 加成不生效，本 mod 補上）；**client 端與 `revertTrait()` 不做**（遠端副本不參與計算，且目標是管理員自己時會與 server 重複累加；只移除正向會讓被拒的 add 憑空扣 boost）|
| 3 | 同一 perk／trait 連點時，第二筆會把第一筆「尚未被 server 確認」的樂觀值存成自己的 `previous`；兩筆都被拒時，先處理的退回真值、後處理的又把顯示推回一個從未被確認過的中間值 | 新增 `hasPendingFor()`，鎖 **(目標 onlineID, perk／trait)**，第二次點擊在送出前就被吞掉。**鎖目標而非鎖面板**：`ISMiniScoreboardUI:onCommand` 的 STATS 直接 `ISPlayerStatsUI:new()`＋`addToUIManager()`（`ISMiniScoreboardUI.lua:77-80`）、不經 `OnOpenPanel` 的 `instance:close()`，所以同一位目標可以同時開著兩個面板，以 ui 為鍵會讓兩個面板對同一格併發 |
| 4 | trait 的 `xpchecker` 失敗（trait 其實已經寫進 server）被當成「未提交」而回捲本機顯示 | 新增 `TRAIT_COMMITTED_REASON = {noop, xpchecker}`，只有未提交類 reason 才 `revertTrait` |
| 5 | client 以可能過期的顯示值判斷上下限並提前 return——畫面 0 而 server 其實已是 1 時，按降級根本不送封包（畫面 10、server 更低時同理），`clamped` 路徑也因此永遠不可達 | 移除該 early return；clamp 只作用於樂觀顯示，上下限一律交給 server 判定 |
| 6 | 重複新增已存在的 trait 會讓 `knownTraits` 出現重複元素——`CharacterTraits.java:69-79` 的 `set()` 在值已為 true 時仍無條件 `knownTraits.add()`，面板會多畫一份圖示與一顆 Remove 按鈕 | client 送出前先查 `getCharacterTraits():get()`（`pcall` 包住，Java `Boolean` 對動態註冊的 trait 會 NPE），server 端維持 `reason=noop` |
| 7 | timeout halo 聲稱「已還原顯示」，但 server 可能只是回覆延遲、實際已經提交 | 文案改為「已還原顯示，實際結果未知」（CH／CN 同步）|

---

## 已知未修問題

以下經多輪雙邊審查確認為真，**刻意未修**，原因見各項說明。

### 1. MEDIUM — `resetXpChecker` 在 mutation 之後失敗時，server 不回滾

**現象**：等級／trait 已經寫進 server，但反作弊基準沒重設，此時管理員畫面顯示 server 回報的權威值並跳 `xpchecker` 警告——顯示是對的，但那位玩家確實處在可能被誤判的狀態。

**現有緩解**：halo 明講「等級或 trait 已變更，但反作弊基準未能重設」，`admin` log 同時寫入 `[XPCHECKER-RESET-FAILED]` 標記；client 端不回捲（`xpchecker` 已列入「已提交」類）。

**為什麼不修**：真正的補救是回滾，但回滾本身也可能失敗，會把一次失敗變成兩次不一致。誠實回報 ＋ 留稽核痕跡比自作聰明安全。

### 2. LOW — 管理員面板的 trait 圖示不反映 server 端的衍生 trait 變化

**現象**：把 Strength／Fitness 調到 10 之後，server 端的 `LevelPerk` 事件會增刪 `WEAK`／`FEEBLE`／`STOUT`／`STRONG`（Fitness 則是 `UNFIT`⋯`ATHLETIC`），但管理員面板的 trait 區塊停在舊值，要重開面板或重連才會更新。

**成因**：官方每秒的 `PlayerXpPacket` 只送給目標玩家自己（`NetworkPlayerManager.java:36` → `NetworkPlayerAI.java:697-700`），管理員手上的那份 target 副本只在連線當下灌入一次。**目標玩家自己看到的是正確的。**

**為什麼不修**：純顯示落差，且要修就得再開一條「server → 管理員」的推送協定，換不到對等價值。

### 3. LOW — 目標 client 的 `descriptor.XPBoostMap` 要重連才刷新

**現象**：管理員增刪 trait 後，目標玩家 client 端那份 `xpBoostMap` 直到重連都是舊值。

**為什麼不修**：它在 MP **不參與任何計算**。XP 授予與反作弊都在 server 端、讀 server 那張 map（`LuaManager.java:11803-11825` 的 client 分支是 no-op），client 這份純顯示。要修得新增一條 server → 目標 client 的封包，傳**權威絕對值**由 client 覆寫（不能傳 op 讓 client 重播 delta——`modifyTraitXPBoost` 是累加/累減，會加倍）。換不到對等價值。

### 4. LOW — 「學會配方」浮字在英文 server 顯示英文

把 Farming 調到 10（或 Mechanics >7/8/9、Electricity >2）時，`xpUpdate.levelPerk` 會呼叫 `checkForLearningRecipe` → `HaloTextHelper.addGoodText(...)`，而 Java 端在 `GameServer.server` 時是把**已組好的 server 語言字串**用 `PacketType.HaloText` 送給 client（`HaloTextHelper.java:166-167`）。**vanilla 正常升級同樣中招**（MP 的 XP 授予本來就在 server），不是本次改動引入的問題類型，只是多一個觸發時機。已登記 `HARDCODE_REGISTRY.md` C14。

> 註：`resetXpChecker` 的回傳值語意是「Lua 層沒拋錯」，**不等於**「確認已重設」。`addXpNoMultiplier` 在 `isExistInTheWorld` 為 false 時直接 no-op（`LuaManager.java:11804`），`GameServer.addXp` 在 connection 為 nil、player 為 nil、isDead 時同樣**靜默**早退（`GameServer.java:1844-1846`），這些 `pcall` 都攔不到。真正的保護來自 `resolveTarget()` 在任何寫入之前做的 in-world / alive 前置檢查；殘留的窄競態是「同一 tick 內斷線」。

---

## 測試清單

**沒有任何一輪審查能實際執行這些程式碼**——兩條 review 線都只能讀原始碼。上正式服前請在測試機逐項確認。

### 前置

- 測試機需 dedicated server（`isClient()` 分支才會生效；單機/本機 host 會直接退回 vanilla handler）。
- 至少兩個帳號：一個管理員、一個目標玩家。
- 開著 `server-console.txt` 與 `admin.txt` log。

### 核心路徑

| # | 操作 | 預期 |
|---|---|---|
| 1 | 管理員對目標玩家 +1 某技能 | 面板等級 +1；**目標玩家不應出現英文升級浮字**；`admin.txt` 有一筆 `set ... to level N for ...` |
| 2 | 同上，-1 | 等級 -1，log 同樣有記錄 |
| 3 | 把 Fitness 調到 10 | 目標玩家身上的 `OUT_OF_SHAPE` / `UNFIT` 應被移除、`ATHLETIC` 加上；跑速與耐力應實際改變 |
| 4 | 把 Strength 調到 10 | 同理檢查 `WEAK` / `FEEBLE` → `STRONG` |
| 5 | 把某技能調到 0 再往下點 | halo 顯示「已達上下限」，等級不變 |
| 6 | 替目標玩家新增一個 trait | 面板 trait 列表更新；**目標玩家連線中累積的 XP / 等級不應被打回舊值**（這是最重要的一項） |
| 7 | 移除該 trait | 同上 |
| 8 | 重複新增已存在的 trait | 無變化；面板**不應**多出一份重複的 trait 圖示或 Remove 按鈕 |

### 反作弊

> **前置**：`servertest.ini` 的 `AntiCheatXP=4` ＝**完全停用**（`AntiCheat.java:73` 的 `getValue() != 4`），這一段整段測不到。要測先改成 `3`，測完改回（Policy：`1`=Ban／`2`=Kick／`3`=Log／`4`=停用）。門檻為 `1000 × 技能倍率 × boost 倍率`，無 boost 時落到 default `0.25F` ＝ 250 XP／60 秒（檢查週期見 `NetworkCharacterAI.java:422` 的 `UpdateLimit(60000L)`）。

| # | 操作 | 預期 |
|---|---|---|
| 9 | 調完技能後讓目標玩家正常遊玩 30 分鐘 | **不應**出現 AntiCheatXP 警告或踢出。這是本次修改的主要目的 |
| 10 | `server-console.txt` 搜尋 `updateXpChecker` | 不應再出現舊版那個 Lua 例外堆疊 |
| 11 | `server-console.txt` 搜尋 `XpChecker reset FAILED` | 正常情況不應出現；出現代表命中第 3 項已知問題 |

### 邊界

| # | 操作 | 預期 |
|---|---|---|
| 12 | 目標玩家在操作瞬間斷線 | halo 顯示「目標不在世界中」或「伺服器未回應，已還原顯示」；面板回捲 |
| 13 | 同時開兩個玩家的 Player Stats 面板，各改各的 | 變更應各自套用到正確的玩家，不應串到另一位身上 |
| 14 | 非管理員身分嘗試（若能觸發） | halo 顯示「權限不足」，server 端無任何寫入 |
| 15 | 把 client 語言切成簡中 | halo 應顯示簡中；切成英文應顯示繁中備援（不應顯示 `IGUI_CatLangStats_*` 原始鍵） |
| 16 | 讓目標玩家自己把某技能練到 10（管理員面板仍顯示舊的低值），管理員按 +1 | halo 顯示「已達上下限」，面板等級跳為 server 的 10（驗證 client 不再用過期值取消請求）|
| 17 | 同上狀態改按 -1 | 應成功降為 9（舊版在畫面顯示 0／10 的邊界會整個不送封包）|
| 18 | 同一技能快速連點 5 次 | 只有第一筆送出（`admin.txt` 只有一筆），其餘被 single-flight 吞掉；畫面不應停在未經 server 確認的中間值 |
| 19 | **順序決定測不測得到**：先讓 B 在**同一個 60 秒檢查窗內**密集練同一技能，**期間**（不是之後）由管理員移除 `FAST_LEARNER`／`CRAFTY`，再觀察接下來那一次檢查 | **不應**出現 `Anti-cheat="XPUpdate" is triggered`。這才是修正第 1 項針對的邊界：基準停在移除前、delta 含移除前還享 1.3 倍時累積的 XP、門檻卻已按移除後計算。<br>**「移除之後才開始練」測不到**——那時成長與門檻都用移除後的狀態、本來就自洽，不管修沒修都會通過。<br>而且即使順序正確，這仍是**弱驗證**：要越過門檻需在 60 秒內對單一技能拿到接近 `1000 × 倍率 × boost` 的 XP，而全域倍率會同時放大成長與門檻（`getMaxPerkXpMultiplier` 與 `AddXP` 讀同一組 sandbox 值），調高倍率不會更容易觸發。沒觸發不等於證明修對了，真正的依據是程式碼層論證 |
| 20 | 用 `ISMiniScoreboardUI` 的 Check Stats 對**同一位**玩家開兩個 stats 面板，交替點同一技能的 +1／-1 | 兩個面板不應對同一格併發送出（`admin.txt` 不應出現同一 tick 的兩筆）；兩邊顯示最終應收斂到 server 權威值（其中一個面板可能暫時落後，下次互動即修正）|

### 若第 6 項失敗

那代表 `SyncXp` 覆寫沒生效——檢查 client 檔是否真的載入（`ISPlayerStatsUI.onAddTrait` 是否被覆寫）。全 `media/lua` 只有那兩處呼叫 `SyncXp`，覆寫掉它們就等於關閉整條覆寫路徑；若還在回滾，就是覆寫時機被別的 mod 蓋掉了。
