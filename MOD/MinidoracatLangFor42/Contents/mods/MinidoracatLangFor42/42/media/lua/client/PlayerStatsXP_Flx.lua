require "ISUI/PlayerStats/ISPlayerStatsUI"

local MODULE = "CatLangPlayerStats"
local COMMAND_SET_PERK_LEVEL = "setPerkLevel"

local _onOptionMouseDown = ISPlayerStatsUI.onOptionMouseDown

local function clampPerkLevel(level)
    if level < 0 then
        return 0
    end
    if level > 10 then
        return 10
    end
    return level
end

local function sendServerPerkLevelSync(actor, target, perk, level)
    sendClientCommand(actor, MODULE, COMMAND_SET_PERK_LEVEL, {
        onlineID = target:getOnlineID(),
        perk = tostring(perk),
        level = level,
    })
end

function ISPlayerStatsUI:onOptionMouseDown(button, x, y)
    if isClient()
            and button
            and (button.internal == "LEVELPERK" or button.internal == "LOWERPERK")
            and self.char
            and self.selectedPerk
            and self.selectedPerk.perk then
        local perk = self.selectedPerk.perk
        local playerXP = self.char:getXp():getXP(perk)
        local levelChange = button.internal == "LEVELPERK" and 1 or -1
        local perkLevel = clampPerkLevel(self.char:getPerkLevel(perk) + levelChange)
        local totalXP = perk:getTotalXpForLevel(perkLevel)
        local amount = totalXP - playerXP

        sendServerPerkLevelSync(getPlayer(), self.char, perk, perkLevel)
        self.char:getXp():AddXP(perk, amount, false, false, false, false)
        self:loadPerks()

        if perk == Perks.Strength or perk == Perks.Fitness then
            self:loadTraits()
        end
        return
    end

    _onOptionMouseDown(self, button, x, y)
end
