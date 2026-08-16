require "ISUI/PlayerStats/ISPlayerStatsUI"
require "ISUI/PlayerStats/ISPlayerStatsChooseTraitUI"
require "XpSystem/ISUI/ISSkillProgressBar"

local MODULE = "CatLangPlayerStats"
local COMMAND_SET_PERK_LEVEL = "setPerkLevel"
local COMMAND_SET_TRAIT = "setTrait"
local COMMAND_RESULT = "setPerkLevelResult"

local MIN_PERK_LEVEL = 0
local MAX_PERK_LEVEL = 10

local _onOptionMouseDown = ISPlayerStatsUI.onOptionMouseDown
local _loadPerks = ISPlayerStatsUI.loadPerks
local _onAddTrait = ISPlayerStatsUI.onAddTrait
local _onRemoveTrait = ISPlayerStatsUI.onRemoveTrait

local nextRequestId = 0

-- requestId -> { ui, perkKey }
--
-- 對帳一定要走這張表，不能用 ISPlayerStatsUI.instance：vanilla 在 render() 內每一幀
-- 都把 instance 設成自己（ISPlayerStatsUI.lua:37），而 ISMiniScoreboardUI 可以在不關閉
-- 舊面板的情況下再開一個，於是「發出請求的面板」與「收到回覆時的 instance」未必相同。
--
-- 也不能靠回覆裡的 perk 反查：失敗回覆（權限不足、參數不全）本來就未必有可信的 perk，
-- 舊寫法在 args.perk 缺席時提前返回，導致撤銷覆寫的分支永遠跑不到、被拒絕的變更
-- 永久留在管理員畫面上。requestId 是唯一在所有分支都存在的關聯鍵。
local pendingByRequest = {}

-- 顯示覆寫：perkKey -> { level, xp }，掛在各個 UI 實例上。
--
-- 舊版在此對 remote 的 self.char 呼叫 AddXP 做樂觀更新，有兩個問題：跨級時觸發
-- LevelPerk / LoseLevel → GameClient.sendPerks，而 remote target 的 playerIndex 預設 0、
-- server 卻以送出端連線的 slot 0 解碼，導致目標的技能摘要被掛到管理員身上；
-- 且那次 AddXP 跨級時仍會顯示英文 "+1 perk" 浮字——正是本檔案要避免的東西
-- （最後一個 false 只關掉 XP 數量浮字，關不掉升級浮字）。
--
-- 改為只覆寫顯示層，完全不碰任何 IsoPlayer。
local function overridesFor(ui)
    ui.catLangPerkOverrides = ui.catLangPerkOverrides or {}
    return ui.catLangPerkOverrides
end

-- 同一 perk／同一 trait 一次只允許一筆在途請求。
--
-- 少了這道閘，第二次點擊會把第一筆「還沒被 server 確認」的樂觀值存成自己的 previous
-- （見 pendingByRequest[].previous）；兩筆都被拒時，先處理的那筆退回真值、
-- 後處理的那筆又把顯示推回一個 server 從未確認過的中間值。
-- expirePending 的「requestId 由大到小回捲」只擋得住逾時路徑，正常回覆照抵達順序處理。
-- 在途筆數常態是 0 或 1，線性掃描比另外維護一張索引表更不容易寫錯。
-- 鎖的是「哪個目標的哪一格」而不是「哪個面板」：`ISMiniScoreboardUI:onCommand` 的 STATS
-- 直接 `ISPlayerStatsUI:new()`＋`addToUIManager()`（ISMiniScoreboardUI.lua:77-80），
-- 不經 `OnOpenPanel` 的 `instance:close()`，所以同一位目標可以同時開著兩個面板。
-- 若以 ui 為鍵，兩個面板就能對同一格併發送出、各自留下不同的顯示值。
local function hasPendingFor(onlineID, field, value)
    for _, entry in pairs(pendingByRequest) do
        if entry.onlineID == onlineID and entry[field] == value then
            return true
        end
    end
    return false
end

-- 判空不能用 `next(t) == nil`：Kahlua 沒有註冊 BaseLib，`next` 在遊戲裡是 nil，
-- 呼叫會噴「Object tried to call nil」。luac -p 與桌面 Lua 都攔不到這種問題
-- （語法合法、標準 Lua 也有這些函式），只有 scripts/verify_mod.py 的靜態掃描擋得住。
local function isEmpty(t)
    for _ in pairs(t) do
        return false
    end
    return true
end

function ISPlayerStatsUI:loadPerks()
    _loadPerks(self)

    local overrides = self.catLangPerkOverrides
    -- vanilla 在 render() 內每一幀呼叫 loadPerks（ISPlayerStatsUI.lua:36,42），
    -- 所以這個包裝也是每幀跑。沒有任何覆寫時（面板開著但還沒動過技能，也就是絕大多數時間）
    -- 直接返回，避免每幀對 42 個 perk 各做一次 tostring() 配置。
    if not overrides or isEmpty(overrides) or not self.xpListBox then
        return
    end

    -- 原版 loadPerks 逐列從 self.char 建值；此處把覆寫疊上去，
    -- 數學與原版一致（ISPlayerStatsUI.lua:725-729）。
    for i = 1, #self.xpListBox.items do
        local entry = self.xpListBox.items[i]
        local data = entry and entry.item
        local override = data and data.perk and overrides[tostring(data.perk)]
        if override then
            local perkObj = PerkFactory.getPerk(data.perk)
            data.level = override.level
            data.xpToLevel = perkObj:getXpForLevel(override.level + 1)
            data.xp = round(override.xp - ISSkillProgressBar.getPreviousXpLvl(perkObj, override.level), 2)
        end
    end
end

function ISPlayerStatsUI:onOptionMouseDown(button, x, y)
    if isClient()
            and button
            and (button.internal == "LEVELPERK" or button.internal == "LOWERPERK")
            and self.char
            and self.selectedPerk
            and self.selectedPerk.perk then
        local perk = self.selectedPerk.perk
        local perkKey = tostring(perk)

        -- 這一格已有在途請求：吞掉點擊，等回覆或逾時後再受理。
        if hasPendingFor(self.char:getOnlineID(), "perkKey", perkKey) then
            return
        end

        local overrides = overridesFor(self)
        local direction = (button.internal == "LEVELPERK") and 1 or -1

        -- 目前顯示的等級：有覆寫就以覆寫為準（那是 server 上一次回報的權威值），
        -- 否則退回 self.char——那份副本停在連線當下（ConnectedPacket.java:169-174 只灌一次，
        -- 官方每秒的 PlayerXpPacket 只送給目標本人），所以兩者都可能比 server 舊。
        --
        -- clamp 只用來讓樂觀顯示不出界，**絕不能**因為「看起來已經在邊界」就取消請求：
        -- 畫面是 0 而 server 其實已經是 1 時，按降級必須真的送出去，否則按鈕在管理員眼中
        -- 就是壞的（畫面 10、server 其實更低時同理）。上下限一律由 server 依自己的權威值
        -- 判定，真的到底了它會回 reason=clamped ＋權威等級與 XP，顯示與 halo 都由那份回覆修正。
        local shown = overrides[perkKey]
        local currentLevel = shown and shown.level or self.char:getPerkLevel(perk)
        local newLevel = math.max(MIN_PERK_LEVEL, math.min(MAX_PERK_LEVEL, currentLevel + direction))

        nextRequestId = nextRequestId + 1
        -- 保存點擊前的覆寫值：失敗回覆若沒有權威值，要還原到「上一筆 server 確認過的值」，
        -- 而不是清成 nil 退回 self.char——那份副本停在連線當下，可能比已確認值更舊。
        pendingByRequest[nextRequestId] = {
            ui = self,
            onlineID = self.char:getOnlineID(),
            perkKey = perkKey,
            sentAt = getTimestampMs(),
            previous = shown and { level = shown.level, xp = shown.xp } or nil,
        }
        overrides[perkKey] = {
            level = newLevel,
            xp = perk:getTotalXpForLevel(newLevel),
        }

        sendClientCommand(self.admin or getPlayer(), MODULE, COMMAND_SET_PERK_LEVEL, {
            requestId = nextRequestId,
            onlineID = self.char:getOnlineID(),
            username = self.char:getUsername(),
            perk = perkKey,
            direction = direction,
        })

        self:loadPerks()
        return
    end

    -- vanilla 建立選特質視窗時 target 傳 nil（ISPlayerStatsUI.lua:470），
    -- 於是 callback 收到的 self 是 nil、handler 只好退回 ISPlayerStatsUI.instance —— 而
    -- instance 每一幀被最後 render 的面板覆寫，同時開兩個面板時會加到錯的玩家身上。
    -- 舊版那只影響本機副本，本版是 server 權威寫入，代價升級了，所以在這裡把 target 補上。
    if isClient() and button and button.internal == "ADDTRAIT" then
        local modal = ISPlayerStatsChooseTraitUI:new(self.x + 200, self.y + 200, 350, 250,
                self, ISPlayerStatsUI.onAddTrait, self.char)
        modal:initialise()
        modal:addToUIManager()
        -- vanilla 這裡也是寫 ISPlayerStatsUI.instance.windows（:473），但那是每幀被
        -- 覆寫的同一個全域；modal 要掛在真正開啟它的面板上，close() 才收得乾淨。
        table.insert(self.windows, modal)
        return
    end

    _onOptionMouseDown(self, button, x, y)
end

-- trait 增刪：本機照 vanilla 改（純顯示，不推送任何封包），實際變更交給 server。
--
-- 關鍵在**不呼叫 SyncXp**。vanilla 的這兩個 handler 改完本機副本後會 SyncXp(self.char)，
-- 而 PlayerXpPacket 送的是完整 XP.save()、server 端直接 XP.load() 清空重建
-- traits / xpMap / perkList / multipliers。管理員手上的副本只在連線當下灌入一次
-- （ConnectedPacket.java:169-174），那一推會把目標連線後累積的 XP、等級、
-- 以及本 mod 剛套用的技能變更全部打回舊值。
-- 全 media/lua 只有這兩處呼叫 SyncXp，覆寫掉它們就等於關閉整條覆寫路徑。
local function sendTraitChange(ui, traitObj, op)
    if not (ui and ui.char and traitObj) then
        return
    end

    nextRequestId = nextRequestId + 1
    pendingByRequest[nextRequestId] = {
        ui = ui,
        onlineID = ui.char:getOnlineID(),
        traitOp = op,
        trait = traitObj,
        sentAt = getTimestampMs(),
    }

    sendClientCommand(ui.admin or getPlayer(), MODULE, COMMAND_SET_TRAIT, {
        requestId = nextRequestId,
        onlineID = ui.char:getOnlineID(),
        username = ui.char:getUsername(),
        -- CharacterTrait 是註冊表物件，網路上只能傳它的 ResourceLocation 字串。
        trait = tostring(traitObj),
        op = op,
    })
end

function ISPlayerStatsUI:onAddTrait(button, trait)
    -- 單機／本機 host 沒有 server 協定可走：sendServerCommand 在非 GameServer.server
    -- 時是 no-op，回覆永遠不會來，pending 會逾時並把畫面回捲。
    -- vanilla handler 在單機下的 SyncXp 本來就是 no-op，直接交還給它最安全。
    if not isClient() or button.internal ~= "OK" then
        return _onAddTrait(self, button, trait)
    end
    -- self 為 nil 時才退回 instance：vanilla 建 modal 時 target 傳 nil
    -- （ISPlayerStatsUI.lua:470），所以 handler 的 self 可能是 nil；
    -- 下面已攔截 ADDTRAIT 改傳 self，正常路徑不會走到 instance。
    local ui = self or ISPlayerStatsUI.instance
    local traitObj = trait and trait:getType()
    if not (ui and ui.char and traitObj) then
        return
    end
    if hasPendingFor(ui.char:getOnlineID(), "trait", traitObj) then
        return
    end

    -- 已經有這個 trait 就整個不動。`CharacterTraits.set` 在值已為 true 時仍會再
    -- `knownTraits.add(trait)` 一次（CharacterTraits.java:69-79 沒有 contains 檢查），
    -- list 出現重複元素後 loadTraits 會多畫一份圖示與一顆 Remove 按鈕。
    -- pcall 包住是因為 `get()` 回的是 Java Boolean，動態註冊的 trait 不在 map 裡時會 NPE；
    -- 失效方向安全：讀不到就照舊送出，server 端對同一情況回 reason=noop。
    local alreadyHas = false
    pcall(function()
        alreadyHas = ui.char:getCharacterTraits():get(traitObj) and true or false
    end)
    if alreadyHas then
        return
    end

    ui.char:getCharacterTraits():add(traitObj)
    -- 只改 membership，**不呼叫** `modifyTraitXPBoost`：MP 的 XP 加成只認 server 端那張
    -- descriptor.XPBoostMap（server 端已代為呼叫），本機這份遠端副本不參與任何計算；
    -- 目標是管理員自己時，本機再做一次還會與 server 端重複累加
    -- （IsoGameCharacter.java:11363-11367 是累加/累減，不是設定）。
    sendTraitChange(ui, traitObj, "add")
    ui:loadTraits()
end

function ISPlayerStatsUI:onRemoveTrait(button, x, y)
    local traitObj = button and button.internal
    if not isClient() or not (self.char and traitObj) then
        return _onRemoveTrait(self, button, x, y)
    end

    if hasPendingFor(self.char:getOnlineID(), "trait", traitObj) then
        return
    end

    self.char:getCharacterTraits():remove(traitObj)
    -- 同 onAddTrait：只改 membership，boost 交給 server 端。
    sendTraitChange(self, traitObj, "remove")
    self:loadTraits()
end

-- 失敗一定要讓管理員看見：identity（改到了別人）與 xpchecker（等級或 trait 改了但反作弊
-- 基準沒重設，該玩家有被 AntiCheatXPUpdate 誤判的風險）尤其不能無聲。
-- 用管理員本機的 halo，不經 server，因此不會有語言問題。
--
-- reason -> { 翻譯 key, 無翻譯時的備援文字 }。
-- 本 mod 只提供 CH / CN 兩份翻譯（shared/Translate/{CH,CN}/IG_UI.json）；其他語言下
-- getText 找不到 key 時會原樣把 key 當結果回傳（Translator.java:495），
-- 直接顯示就會在管理員畫面上跳出 "IGUI_CatLangStats_Permission" 這種原始鍵。
-- 用 getTextOrNull 而非比較 getText(k) == k：後者在 Core.debug 且開啟 Translation.Prefix 時
-- 會拿到 "!key"、比較失效（Translator.java:496）。getTextOrNull 直接回 nil，
-- 也是 vanilla 既有慣用寫法（ISHotbar.lua:43、ISZoneDisplay.lua:459）。
local REASON_TEXT = {
    permission = { "IGUI_CatLangStats_Permission", "權限不足" },
    args = { "IGUI_CatLangStats_Args", "參數不完整" },
    direction = { "IGUI_CatLangStats_Direction", "無效的升降方向" },
    target = { "IGUI_CatLangStats_Target", "找不到目標或權限不足" },
    identity = { "IGUI_CatLangStats_Identity", "目標身分不符，已取消（onlineID 可能已被其他玩家佔用）" },
    notinworld = { "IGUI_CatLangStats_NotInWorld", "目標不在世界中" },
    dead = { "IGUI_CatLangStats_Dead", "目標已死亡" },
    clamped = { "IGUI_CatLangStats_Clamped", "已達上下限" },
    xpchecker = { "IGUI_CatLangStats_XpChecker", "等級已變更，但反作弊基準未能重設——請留意該玩家是否被誤判" },
    timeout = { "IGUI_CatLangStats_Timeout", "伺服器未回應：已還原顯示，實際結果未知" },
}

-- server 的失敗回覆分兩類，只有「未提交」才該把本機那次樂觀增／刪反向做回去：
--   已提交：noop（server 早就是該狀態）、xpchecker（trait 已寫入，只是反作弊基準沒重設）
--   未提交：permission／args／target／identity／notinworld／dead
local TRAIT_COMMITTED_REASON = {
    noop = true,
    xpchecker = true,
}

local function notifyAdmin(reason)
    local entry = REASON_TEXT[reason]
    if not entry then
        return
    end
    local text = getTextOrNull(entry[1]) or entry[2]
    pcall(function()
        HaloTextHelper.addBadText(getPlayer(), text)
    end)
end

-- 逾時清理：server 端若因任何理由沒回覆（未載入本 mod、Lua 例外、封包遺失），
-- 樂觀覆寫會永遠停在假值並強參考住 UI 實例。失效方向是「對管理員說謊」，
-- 所以寧可過期撤回。EveryOneMinute 綁遊戲內時間，預設約每 1.25 真實秒觸發一次。
local PENDING_TIMEOUT_MS = 8000

-- server 拒絕 trait 變更時，把本機那次樂觀增/刪反向做回去。
local function revertTrait(entry)
    local ui, trait, op = entry.ui, entry.trait, entry.traitOp
    if not (ui and ui.char and trait) then
        return
    end
    -- 只反向 membership。boost 從頭就沒在 client 動過（見 onAddTrait／onRemoveTrait），
    -- 這裡若反向做一次就會單向漂移：被拒的 add 憑空扣 boost、被拒的 remove 憑空加 boost。
    pcall(function()
        if op == "add" then
            ui.char:getCharacterTraits():remove(trait)
        else
            ui.char:getCharacterTraits():add(trait)
        end
        ui:loadTraits()
    end)
end

local function revertPerk(entry)
    local overrides = entry.ui and entry.ui.catLangPerkOverrides
    if not (overrides and entry.perkKey) then
        return
    end
    overrides[entry.perkKey] = entry.previous
    pcall(function() entry.ui:loadPerks() end)
end

local function expirePending()
    local now = getTimestampMs()

    -- 不需要排序，也不能用 table.sort（Kahlua 的 sort 是遞迴 quicksort，受 coroutine
    -- 堆疊上限 3000 限制，見 scripts/verify_mod.py 檢查 6）。
    -- 原本排序是為了「同一 perk 連點兩次且都逾時」時由新到舊回捲，但 single-flight
    -- 已保證同一 (目標 onlineID, perk／trait) 最多只有一筆在途，那種情況不可能發生；
    -- 剩下的多筆逾時必然來自不同的目標或不同的格子，各自的覆寫互不干擾，順序無關。
    local expired = {}
    for requestId, entry in pairs(pendingByRequest) do
        if now - (entry.sentAt or 0) > PENDING_TIMEOUT_MS then
            table.insert(expired, { id = requestId, entry = entry })
        end
    end

    for _, item in ipairs(expired) do
        pendingByRequest[item.id] = nil
        notifyAdmin("timeout")
        if item.entry.traitOp then
            revertTrait(item.entry)
        else
            revertPerk(item.entry)
        end
    end
end

Events.EveryOneMinute.Add(expirePending)

-- server 一律回覆，成功與失敗都帶 requestId；perk 指令另帶權威等級與 XP。
local function onServerCommand(module, command, args)
    if module ~= MODULE or command ~= COMMAND_RESULT or not args then
        return
    end

    local requestId = args.requestId
    local entry = requestId and pendingByRequest[requestId]
    if not entry then
        return
    end
    pendingByRequest[requestId] = nil

    if not args.ok then
        notifyAdmin(args.reason)
    end

    if entry.traitOp then
        -- trait：本機已樂觀套用，只有「server 端根本沒寫入」才需要回捲。
        if not args.ok and not TRAIT_COMMITTED_REASON[args.reason] then
            revertTrait(entry)
        end
        return
    end

    local overrides = entry.ui and entry.ui.catLangPerkOverrides
    if not overrides then
        return
    end

    if args.level then
        -- 成功或「server 有權威值可回報」的失敗（clamped / xpchecker）：顯示 server 的值。
        overrides[entry.perkKey] = { level = args.level, xp = args.xp }
    else
        -- 連權威值都沒有的失敗（權限、參數、身分、離線、死亡）：還原到點擊前的狀態。
        -- 若先前有 server 確認過的覆寫就回到它，否則才清成 nil 退回 self.char。
        overrides[entry.perkKey] = entry.previous
    end

    pcall(function() entry.ui:loadPerks() end)
end

Events.OnServerCommand.Add(onServerCommand)
