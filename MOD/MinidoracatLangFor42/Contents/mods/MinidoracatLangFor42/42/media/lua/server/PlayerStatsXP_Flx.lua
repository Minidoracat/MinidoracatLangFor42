local MODULE = "CatLangPlayerStats"
local COMMAND_SET_PERK_LEVEL = "setPerkLevel"

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

local function getPerkFromString(perkName)
    if not perkName then
        return nil
    end

    local ok, perk = pcall(Perks.FromString, perkName)
    if ok and perk and perk ~= Perks.MAX then
        return perk
    end
    return nil
end

local function syncXp(target)
    if not target then
        return
    end

    pcall(function()
        local ai = target:getNetworkCharacterAI()
        if ai then
            ai:syncXp()
        end
    end)
end

local function setPerkLevelWithoutHalo(player, args)
    if not canModifyPlayerStats(player) or not args then
        return
    end

    local onlineID = tonumber(args.onlineID)
    local level = tonumber(args.level)
    local perk = getPerkFromString(args.perk)
    if not onlineID or not level or not perk then
        return
    end

    local target = getPlayerByOnlineID(onlineID)
    if not canModifyTarget(player, target) then
        return
    end

    level = math.max(0, math.min(10, level))
    target:setPerkLevelDebug(perk, level)
    target:getXp():setXPToLevel(perk, level)
    syncXp(target)
end

local function onClientCommand(module, command, player, args)
    if module ~= MODULE then
        return
    end

    if command == COMMAND_SET_PERK_LEVEL then
        setPerkLevelWithoutHalo(player, args)
    end
end

Events.OnClientCommand.Add(onClientCommand)
