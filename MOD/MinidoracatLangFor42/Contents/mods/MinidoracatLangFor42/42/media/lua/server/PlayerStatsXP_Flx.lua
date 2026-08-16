-- 管理員面板（ISPlayerStatsUI）技能升降級與 trait 增刪的 server 權威側。
--
-- 權威在哪（決定本檔能改什麼、不能改什麼）：
-- MP 的 XP **完全是 server 權威**。全域 `addXp`／`addXpNoMultiplier` 的 Lua 綁定是
-- `if GameServer.server then GameServer.addXp(...) elseif not GameClient.client then ...`
-- （LuaManager.java:11803-11825）——在 MP client 上兩個分支都不成立，**整個呼叫是 no-op**。
-- server 端 `XP.AddXP` 算加成時讀的是 server 自己那份 `descriptor.XPBoostMap`
-- （IsoGameCharacter.java:17359-17373），反作弊算門檻讀的也是同一張
-- （AntiCheatXPUpdate.java:23 `getPerkBoost` → :17262-17263），兩者同源、不可能分岔。
--
-- 回推方向是單向的：server 每秒對每位玩家自己的連線送 PlayerXpPacket
-- （NetworkPlayerManager.java:10 `statsUpdateLimit = 1000ms` → :36 → NetworkPlayerAI.java:697-704），
-- 內容是 XP.save()：characterTraits／totalXp／level／xpMap／perkList／multipliers
-- （IsoGameCharacter.java:17581-17609）。所以本檔寫進 server 的等級與 trait 會在一秒內
-- 出現在目標玩家自己的畫面上，而目標 client 端的 `descriptor.XPBoostMap`
-- **不在該封包內、永遠不會更新**——但它在 MP 也不參與任何計算（見上），
-- 只是一份到重連才會刷新的顯示用副本，故不需要為它補封包。
--
-- 反過來說，`modifyTraitXPBoost` **必須**在 server 端呼叫：那是 vanilla 的意圖
-- （ISPlayerStatsUI.lua:595／:670），但 vanilla 只對管理員手上的遠端副本呼叫、
-- 回推用的 XP.load() 又不含 boost map，於是 server 端那張從來沒被更新過——
-- 也就是 vanilla MP 下管理員加 trait 只有 membership 生效、XP 加成不生效。本檔補上它。

local MODULE = "CatLangPlayerStats"
local COMMAND_SET_PERK_LEVEL = "setPerkLevel"
local COMMAND_SET_TRAIT = "setTrait"
local COMMAND_RESULT = "setPerkLevelResult"

local MIN_PERK_LEVEL = 0
local MAX_PERK_LEVEL = 10

local function canModifyPlayerStats(player)
    return player
            and player:getRole()
            and player:getRole():hasCapability(Capability.CanModifyPlayerStatsInThePlayerStatsUI)
end

local function canModifyTarget(player, target)
    return target
            and target:getRole()
            and player:getRole()
            and target:getRole():getPosition() <= player:getRole():getPosition()
end

-- 與 ISPlayerStatsUI.loadPerks 的過濾條件一致（該處只列 parent ~= Perks.None 的 perk）。
-- 只擋 Perks.MAX 是不夠的：None / Melee / Passiv / Melting 與各分類標題都在 PerkById 裡查得到，
-- 卻不在 PerkFactory.PerkList 中——setPerkLevelDebug 會替它們建出永久殘留在存檔的 PerkInfo，
-- 而 AddXP 掃不到對應 perk 會在 Java 端 NPE，連帶讓反作弊基準不重設。
local function getPerkFromString(perkName)
    if not perkName then
        return nil
    end

    local ok, perk = pcall(Perks.FromString, perkName)
    if ok and perk and perk ~= Perks.MAX then
        local info = PerkFactory.getPerk(perk)
        if info and info:getParent() ~= Perks.None then
            return perk
        end
    end
    return nil
end

-- 回覆一律帶 server 的權威等級與 XP（含失敗），管理員端才有辦法對帳。
-- 管理員手上的 target 副本 XP 只在連線當下灌入一次，之後 server 不再推送
-- （NetworkPlayerAI.syncXp 只送給目標本人），所以顯示完全依賴這份回覆。
local function reply(player, requestId, ok, reason, perk, level, xp)
    sendServerCommand(player, MODULE, COMMAND_RESULT, {
        requestId = requestId,
        ok = ok,
        reason = reason,
        perk = perk and tostring(perk) or nil,
        level = level,
        xp = xp,
    })
end

-- 重設反作弊 XP 基準，回傳是否確定重設成功。
--
-- 42.20 起基準存於 NetworkCharacterAI.XpChecker；官方所有加 XP 路徑
-- （AddXPCommand:83、GameServer.addXp:1848、XP.load）都會呼叫 updateXpChecker() 重設。
-- 本檔案繞過官方 /addxp，必須自行重設，否則 AntiCheatXPUpdate 會把管理員的調整
-- 當成玩家自己的異常成長（門檻最低只有 1000*1.0*0.25=250 XP），
-- 累計兩次即依 AntiCheatXP 設定處置「被調整的那位玩家」。
--
-- 舊版直接呼叫 ai:updateXpChecker() 是無效的：NetworkCharacterAI 與 NetworkPlayerAI
-- 都沒有 setExposed 到 Lua，Kahlua 無法索引其上任何方法。
--
-- 唯一 Lua 可及、且內部會呼叫 updateXpChecker() 的官方入口是全域 addXpNoMultiplier
-- → GameServer.addXp（GameServer.java:1842-1851）。量必須是 0：newXP == oldXP 時
-- AddXP 的升降級迴圈條件兩邊都不成立，不會呼叫 LevelPerk，也就不會產生 server 端
-- 以英文 perk 名建構的升級 halo——那正是本檔案存在的理由。
--
-- 必須在寫入最終等級之後呼叫，基準才會對齊最終狀態。
--
-- 回傳值的語意要誠實：這條路徑上的失敗多半是**靜默**的，pcall 攔不到。
-- addXpNoMultiplier 在 isExistInTheWorld 為 false 時直接 no-op（LuaManager.java:11804），
-- GameServer.addXp 在 connection 為 nil、player 為 nil、isDead 時同樣靜默早退
-- （GameServer.java:1844-1846；:1845 的 canModifyPlayerStats 因 c 是 target 自己的連線、
-- havePlayer 恆真，實際不擋）。所以 false 只代表「Lua 層拋了錯」，
-- true 代表「已盡力且未拋錯」，不等於「確認已重設」。
-- 真正的保護來自呼叫端在 mutation 前的 in-world / alive 前置檢查；
-- 殘留的窄競態是「同一 tick 內斷線」，本函式偵測不到。
local function resetXpChecker(target, perk)
    return pcall(function()
        addXpNoMultiplier(target, perk, 0)
    end)
end

-- setXPToLevel 只在 Core.debug 下更新衍生的 CharacterStat.FITNESS，dedicated server 走不到；
-- 比照官方 /addxp 顯式同步（AddXPCommand.java:78）。
-- addXpNoMultiplier 內部在 Fitness 時也會做同一件事，但那條路徑有數個提早返回的分支，
-- 不能倚賴，故獨立補一次。
local function syncDerivedStats(target, perk)
    if perk ~= Perks.Fitness then
        return
    end

    pcall(function()
        target:getStats():set(CharacterStat.FITNESS, target:getPerkLevel(Perks.Fitness) / 5.0 - 1.0)
    end)
end

-- 補觸發 vanilla 的 LevelPerk 監聽器。
--
-- setPerkLevelDebug / setXPToLevel / 零量 AddXP 三者都不會走到 Java 的 LevelPerk，
-- 而 dedicated server 有註冊 Events.LevelPerk.Add(xpUpdate.levelPerk)（XpUpdate.lua:395），
-- 那個 handler 做的是實質遊戲邏輯而非顯示：checkAutoLearn、Strength 的
-- WEAK/FEEBLE/STOUT/STRONG 與 Fitness 的 UNFIT/OUT_OF_SHAPE/FIT/ATHLETIC 增刪、
-- 以及 Farming/Mechanics/Electricity 的門檻配方。不補的話，管理員把 Fitness 調到 10
-- 之後玩家身上仍掛著 OUT_OF_SHAPE，跑速/耐力/負重/近戰全部維持舊檔位並寫進存檔。
--
-- handler 內的 trait 區塊是「先移除該類全部 trait，再依傳入的 level 重加」，
-- 所以升級與降級都用同一個事件、傳最終等級即可（全 media/lua 無 Events.LoseLevel 監聽器）。
-- halo 是 Java 的 LevelPerk 自己產生的，走 Lua 事件不會有英文升級浮字。
-- 第四個參數 addBuffer 要與 vanilla 對齊：Java 升級側傳 true（IsoGameCharacter.java:4815），
-- LoseLevel 側傳 false（:4776）。寫死 false 會讓升級走到與原版不同的分支。
local function applyVanillaLevelSideEffects(target, perk, newLevel, direction)
    pcall(function()
        triggerEvent("LevelPerk", target, perk, newLevel, direction > 0)
    end)
end

-- 稽核字串一律剝除換行，避免使用者名稱把記錄拆成假的多筆。
local function flat(s)
    return (tostring(s):gsub("[\r\n]", " "))
end

-- perk 與 trait 兩條指令共用的前置驗證。
-- 回傳 target，或 (nil, reason)。
local function resolveTarget(player, args)
    if not canModifyPlayerStats(player) or not args then
        return nil, "permission"
    end

    local onlineID = tonumber(args.onlineID)
    local username = args.username
    -- username 一律必填：onlineID 是連線槽位、釋出後會被遞補者重用，
    -- 只靠它可能改到另一位玩家。做成選填等於只擋得住誠實的 client。
    if not onlineID or type(username) ~= "string" or username == "" then
        return nil, "args"
    end

    local target = getPlayerByOnlineID(onlineID)
    if not canModifyTarget(player, target) then
        return nil, "target"
    end
    if target:getUsername() ~= username then
        return nil, "identity"
    end

    -- 在任何寫入之前擋掉離線與死亡目標：這兩種情況下 GameServer.addXp 會提早返回
    -- （:1844 connection ~= nil、:1846 !isDead），基準不會重設，但改動已經寫下去了。
    if not target:isExistInTheWorld() then
        return nil, "notinworld"
    end
    if target:isDead() then
        return nil, "dead"
    end

    return target
end

local function setPerkLevelWithoutHalo(player, args)
    local requestId = args and args.requestId

    local target, err = resolveTarget(player, args)
    if not target then
        return reply(player, requestId, false, err)
    end

    local direction = tonumber(args.direction)
    local perk = getPerkFromString(args.perk)
    if not perk or not direction then
        return reply(player, requestId, false, "args")
    end

    -- UI 契約就是單步升降，不讓已授權的 client 送出任意跳級。
    if direction ~= 1 and direction ~= -1 then
        return reply(player, requestId, false, "direction")
    end

    local username = args.username

    -- 等級一律由 server 依自己的權威值推算。不採信 client 送來的等級，
    -- 也不因為 client 的快照過期就拒絕——管理員手上的副本本來就停在連線當下，
    -- 拿它當前置條件只會讓「玩家連線後練過的技能」第一次點擊被靜默吞掉。
    local currentLevel = target:getPerkLevel(perk)
    local newLevel = math.max(MIN_PERK_LEVEL, math.min(MAX_PERK_LEVEL, currentLevel + direction))
    if newLevel == currentLevel then
        return reply(player, requestId, false, "clamped", perk, currentLevel, target:getXp():getXP(perk))
    end

    target:setPerkLevelDebug(perk, newLevel)
    target:getXp():setXPToLevel(perk, newLevel)
    applyVanillaLevelSideEffects(target, perk, newLevel, direction)
    syncDerivedStats(target, perk)

    local checkerOk = resetXpChecker(target, perk)
    if not checkerOk then
        print("CatLang PlayerStats: XpChecker reset FAILED for " .. tostring(username)
                .. " perk=" .. tostring(perk) .. " level=" .. tostring(newLevel))
    end

    -- 回覆必須是最後一步，而且不能被任何後續副作用打斷：管理員端的顯示層完全依賴它，
    -- 送不出去就會永遠停在樂觀值。稽核記錄排在回覆之後並各自包 pcall。
    -- 不可寫成 `checkerOk and nil or "xpchecker"`：Lua 的 `true and nil` 是 nil，
    -- 接著 `nil or "xpchecker"` 取右邊，兩種情況都會得到 "xpchecker"。
    local failReason = nil
    if not checkerOk then
        failReason = "xpchecker"
    end

    reply(player, requestId, checkerOk, failReason,
            perk, target:getPerkLevel(perk), target:getXp():getXP(perk))

    pcall(function()
        -- Lua 端的全域是 writeLog(loggerName, logs)（LuaManager.java:9171-9177）。
        -- 不是 Java 的 LoggerManager.getLogger(name):write(...) —— 那個沒有 Lua 綁定。
        writeLog("admin", flat(player:getUsername()) .. " set " .. flat(perk)
                .. " to level " .. tostring(newLevel) .. " for " .. flat(username)
                .. (checkerOk and "" or " [XPCHECKER-RESET-FAILED]"))
    end)
end

-- trait 增刪也走 server 權威。
--
-- 原因不是權限（vanilla 的按鈕本來就要管理員才點得到），而是資料完整性：
-- vanilla 的 onAddTrait / onRemoveTrait 在改完管理員手上的 remote 副本之後會呼叫
-- SyncXp(self.char)，把那份副本整包推回 server；而 PlayerXpPacket 送的是完整
-- XP.save()、server 端直接 XP.load() 清空重建 traits / xpMap / perkList / multipliers
-- （IsoGameCharacter.java:17531 一帶）。管理員手上的副本只在連線當下灌入一次
-- （ConnectedPacket.java:169-174），所以那一推會把目標連線後累積的 XP、等級、
-- 以及本 mod 剛套用的變更全部打回舊值。
--
-- client 端已覆寫掉那兩個 handler 並且不再呼叫 SyncXp（全 media/lua 只有那兩處呼叫），
-- 因此那條覆寫路徑整個消失；trait 的實際變更改由這裡以 server 權威值套用。
local function setTraitAuthoritative(player, args)
    local requestId = args and args.requestId

    local target, err = resolveTarget(player, args)
    if not target then
        return reply(player, requestId, false, err)
    end

    local traitId = args.trait
    local op = args.op
    if type(traitId) ~= "string" or traitId == ""
            or (op ~= "add" and op ~= "remove") then
        return reply(player, requestId, false, "args")
    end

    -- CharacterTrait 是註冊表物件、不是字串，網路上只能傳它的 ResourceLocation
    -- （CharacterTrait.toString() 就是完整 location）。這裡照 vanilla Lua 既有慣例
    -- 反查（同 ItemTag.get(ResourceLocation.of(...))），查不到即視為非法輸入——
    -- 這同時就是白名單，擋掉把垃圾字串寫進角色並隨存檔殘留。
    local trait = nil
    pcall(function()
        trait = CharacterTrait.get(ResourceLocation.of(traitId))
    end)
    -- 再要求有對應的 CharacterTraitDefinition，才與 UI 能產生的集合完全對齊：
    -- 第三方 mod 可能只 register 而未提供定義，那種 trait 寫進角色後
    -- loadTraits 因為拿不到 texture 而不畫 Remove 按鈕，會變成拔不掉的黏著狀態。
    if not trait or not CharacterTraitDefinition.getCharacterTraitDefinition(trait) then
        return reply(player, requestId, false, "args")
    end

    local isRemoving = (op == "remove")
    local traits = target:getCharacterTraits()
    local has = traits:get(trait)
    if (isRemoving and not has) or (not isRemoving and has) then
        -- 已是目標狀態：一定要擋。`CharacterTraits.set` 在值已為 true 時仍會無條件再
        -- `knownTraits.add(trait)` 一次（CharacterTraits.java:69-79 沒有 contains 檢查），
        -- 重複元素會讓 loadTraits 畫出兩份圖示與兩顆 Remove 按鈕。
        -- 回覆 reason=noop 同時告訴 client「server 早就是這個狀態」，不必回捲本機顯示。
        return reply(player, requestId, false, "noop")
    end

    if isRemoving then
        traits:remove(trait)
    else
        traits:add(trait)
    end
    -- 與 vanilla 同一組副作用（ISPlayerStatsUI.lua:595／:670），但改在 server 端做：
    -- MP 的 XP 加成只認 server 這張 descriptor.XPBoostMap（見檔頭「權威在哪」），
    -- vanilla 對遠端副本呼叫等於沒生效。client 端**不**跟著做——那份副本不參與計算，
    -- 且目標是管理員自己時會與這裡重複累加（IsoGameCharacter.java:11363-11367 是累加/累減）。
    target:modifyTraitXPBoost(trait, isRemoving)

    -- 必須重設 XpChecker。
    -- boost 數值層本身有 Math.max(newXpBoost, oldXpBoost) 保護
    -- （AntiCheatXPUpdate.java:22-25），但 FAST_LEARNER／CRAFTY 的 1.3 倍是直接讀
    -- **當前** characterTraits（:33-40），沒有 old-trait 保護：移除其中任一個之後門檻
    -- 立刻少 23%，baseline 卻仍停在移除前，delta 會把移除前（還享有 1.3 倍加成時）
    -- 累積的 XP 一併算進來，於是玩家可能因管理員的操作被記 strike
    -- （累計兩次即依 AntiCheatXP 設定處置）。把 baseline 對齊到變更當下即可斷開這段跨界 delta。
    -- 代價是全量 putAll 會順帶清掉這一輪 XP 觀察窗（NetworkCharacterAI.java:308-313），
    -- 但「管理員操作觸發一次觀察窗重置」遠優於「誤判並處置玩家」。
    --
    -- 量給 0、perk 給任一個都可以：updateXpChecker() 是三張 baseline map 全量 putAll，
    -- 與傳入的 perk 無關；Strength 只會被 nutrition 乘算 amount，0 乘任何倍率仍是 0。
    local checkerOk = resetXpChecker(target, Perks.Strength)
    local failReason = nil
    if not checkerOk then
        failReason = "xpchecker"
    end
    reply(player, requestId, checkerOk, failReason)

    pcall(function()
        writeLog("admin", flat(player:getUsername()) .. " " .. op .. " trait "
                .. flat(traitId) .. " for " .. flat(args.username))
    end)
end

local function onClientCommand(module, command, player, args)
    if module ~= MODULE then
        return
    end

    if command == COMMAND_SET_PERK_LEVEL then
        setPerkLevelWithoutHalo(player, args)
    elseif command == COMMAND_SET_TRAIT then
        setTraitAuthoritative(player, args)
    end
end

Events.OnClientCommand.Add(onClientCommand)
