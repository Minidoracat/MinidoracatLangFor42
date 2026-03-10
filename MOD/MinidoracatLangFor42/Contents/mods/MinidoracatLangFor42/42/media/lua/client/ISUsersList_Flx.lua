-- ISUsersList_Flx.lua
-- 修正 ISUsersList 中硬編碼的英文字串
-- "Online" → getText("IGUI_UsersList_Online")
-- "Offline" → getText("IGUI_UsersList_Offline")
-- "Set Role" → getText("IGUI_UsersList_SetRole")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)

-- 保存原始函式
local _orig_drawDatas = ISUsersList.drawDatas

function ISUsersList:drawDatas(y, item, alt)
    local a = 0.9;

    self:drawRectBorder(0, (y), self:getWidth(), self.itemheight - 1, a, self.borderColor.r, self.borderColor.g, self.borderColor.b);

    if self.selected == item.index then
        self:drawRect(0, (y), self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15);
    end

    local color = item.item:getRole():getColor()

    self:drawText(item.item:getUsername(), 12, y + 4, color:getR(), color:getG(), color:getB(), a, UIFont.Medium);
    if item.item:isOnline() then
        self:drawText(getText("IGUI_UsersList_Online"), 12, y + 4 + FONT_HGT_MEDIUM, 0.1, 1.0, 0.1, a, UIFont.Medium);
    else
        self:drawText(getText("IGUI_UsersList_Offline"), 12, y + 4 + FONT_HGT_MEDIUM, 0.5, 0.5, 0.5, a, UIFont.Medium);
    end

    if item.item:getWarningPoints() == 0 then
        self:drawText(getText("IGUI_UsersList_WarningPoints", item.item:getWarningPoints()), self:getWidth()- 170, y + 4, 0.3, 1.0, 0.3, a, UIFont.Small);
    elseif item.item:getWarningPoints() < 10 then
        self:drawText(getText("IGUI_UsersList_WarningPoints", item.item:getWarningPoints()), self:getWidth()- 170, y + 4, 1.0, 1.0, 0.3, a, UIFont.Small);
    else
        self:drawText(getText("IGUI_UsersList_WarningPoints", item.item:getWarningPoints()), self:getWidth()- 170, y + 4, 1.0, 0.3, 0.3, a, UIFont.Small);
    end
    if item.item:getSuspicionPoints() == 0 then
        self:drawText(getText("IGUI_UsersList_SuspicionPoints", item.item:getSuspicionPoints()), self:getWidth()- 170, y + 2 + FONT_HGT_SMALL, 0.3, 1.0, 0.3, a, UIFont.Small);
    elseif item.item:getSuspicionPoints() < 10 then
        self:drawText(getText("IGUI_UsersList_SuspicionPoints", item.item:getSuspicionPoints()), self:getWidth()- 170, y + 2 + FONT_HGT_SMALL, 1.0, 1.0, 0.3, a, UIFont.Small);
    else
        self:drawText(getText("IGUI_UsersList_SuspicionPoints", item.item:getSuspicionPoints()), self:getWidth()- 170, y + 2 + FONT_HGT_SMALL, 1.0, 0.3, 0.3, a, UIFont.Small);
    end
    if item.item:getKicks() == 0 then
        self:drawText(getText("IGUI_UsersList_Kicks", item.item:getKicks()), self:getWidth()- 170, y + 1 + 2 * FONT_HGT_SMALL, 0.3, 1.0, 0.3, a, UIFont.Small);
    else
        self:drawText(getText("IGUI_UsersList_Kicks", item.item:getKicks()), self:getWidth()- 170, y + 1 + 2 * FONT_HGT_SMALL, 1.0, 0.3, 0.3, a, UIFont.Small);
    end

    if item.item:isInWhitelist() then
        self:drawText(getText("IGUI_UsersList_DetailsRole", item.item:getRole():getName()), self:getWidth() - 480, y + 4, 1, 1, 1, a, self.font);
        self:drawText(getText("IGUI_UsersList_DetailsLastConnection", item.item:getLastConnection()), self:getWidth() - 480, y + 2 + FONT_HGT_SMALL, 1, 1, 1, a, self.font);
        self:drawText(getText("IGUI_UsersList_DetailsAuthType", item.item:getAuthTypeName()), self:getWidth() - 480, y + 1 + 2 * FONT_HGT_SMALL, 1, 1, 1, a, self.font);
    else
        self:drawText(getText("IGUI_UsersList_DetailsRole", item.item:getRole():getName()), self:getWidth() - 480, y + 4, 1, 1, 1, a, self.font);
        self:drawText(getText("IGUI_UsersList_DetailsNoWhitelist"), self:getWidth() - 480, y + 2 + FONT_HGT_SMALL, 1, 1, 1, a, self.font);
    end

    return y + self.itemheight;
end

-- 保存原始 doContextMenu
local _orig_doContextMenu = ISUsersList.doContextMenu

function ISUsersList:doContextMenu(item, x, y)
    local playerNum = self.player:getPlayerNum()
    local context = ISContextMenu.get(playerNum, x + self:getAbsoluteX(), y + self:getAbsoluteY());
    local roles = getRoles()
    if self.player:getRole():hasCapability(Capability.ChangeAccessLevel) then
        local setRoleOption = context:addOption(getText("IGUI_UsersList_SetRole"), worldobjects, nil)
        local subMenu = context:getNew(context)
        context:addSubMenu(setRoleOption, subMenu);
        for i=0,roles:size()-1 do
            local role = roles:get(i);
            subMenu:addOption(getText("IGUI_UserList_SetRole", role:getName()), ISUsersList.instance, ISUsersList.onSetRoleClickOption, item, role:getName());
        end
    end
    if item:isOnline() then
        if self.player:getRole():hasCapability(Capability.TeleportPlayerToAnotherPlayer) then
            context:addOption(getText("IGUI_UserList_Teleport"), ISUsersList.instance, ISUsersList.onClickOption, item, "Teleport");
        end
        if self.player:getRole():hasCapability(Capability.TeleportToPlayer) then
            context:addOption(getText("IGUI_UserList_TeleportToHim"), ISUsersList.instance, ISUsersList.onClickOption, item, "TeleportToHim");
        end
        if self.player:getRole():hasCapability(Capability.KickUser) then
            local kickButton = context:addOption(getText("IGUI_UserList_Kick"), ISUsersList.instance, ISUsersList.onClickOption, item, "Kick");
            if item:getUsername() == self.player:getUsername() then
                kickButton.notAvailable = true;
                local tooltip = ISWorldObjectContextMenu.addToolTip();
                tooltip.description = getText("IGUI_UserList_KickHimself");
                kickButton.toolTip = tooltip;
            end
            if item:getRole():hasCapability(Capability.CantBeKicked) then
                kickButton.notAvailable = true;
                local tooltip = ISWorldObjectContextMenu.addToolTip();
                tooltip.description = getText("IGUI_UserList_CantBeKicked");
                kickButton.toolTip = tooltip;
            end
        end
    end
    if self.player:getRole():hasCapability(Capability.BanUnbanUser) then
        local banButton;
        if item:getRole():getName() == 'banned' then
            banButton = context:addOption(getText("IGUI_UserList_UnBan"), ISUsersList.instance, ISUsersList.onClickOption, item, "UnBan");
        else
            banButton = context:addOption(getText("IGUI_UserList_Ban"), ISUsersList.instance, ISUsersList.onClickOption, item, "Ban");
            if item:getRole():hasCapability(Capability.CantBeBannedByUser) then
                banButton.notAvailable = true;
                local tooltip = ISWorldObjectContextMenu.addToolTip();
                tooltip.description = getText("IGUI_UserList_CantBeBanned");
                banButton.toolTip = tooltip;
            end
            if item:getUsername() == self.player:getUsername() then
                banButton.notAvailable = true;
                local tooltip = ISWorldObjectContextMenu.addToolTip();
                tooltip.description = getText("IGUI_UserList_BanHimself");
                banButton.toolTip = tooltip;
            end
        end
        if getSteamModeActive() then
            local banSteamIdButton;
            if item:getSteamIdBanned() ~= nil and item:getSteamIdBanned() ~= '' then
                banSteamIdButton = context:addOption(getText("IGUI_UserList_UnBanBySteamID"), ISUsersList.instance, ISUsersList.onClickOption, item, "UnBanSteamID");
            else
                banSteamIdButton = context:addOption(getText("IGUI_UserList_BanBySteamID"), ISUsersList.instance, ISUsersList.onClickOption, item, "BanSteamID");
                if item:getRole():hasCapability(Capability.CantBeBannedByUser) then
                    banSteamIdButton.notAvailable = true;
                    local tooltip = ISWorldObjectContextMenu.addToolTip();
                    tooltip.description = getText("IGUI_UserList_CantBeBanned");
                    banSteamIdButton.toolTip = tooltip;
                end
                if not item:isOnline() or item:getRole():getName() == 'banned' then
                    banSteamIdButton.notAvailable = true;
                    local tooltip = ISWorldObjectContextMenu.addToolTip();
                    tooltip.description = getText("IGUI_UserList_BanSteamIdNotOnline");
                    banSteamIdButton.toolTip = tooltip;
                end
                if item:getUsername() == self.player:getUsername() then
                    banSteamIdButton.notAvailable = true;
                    local tooltip = ISWorldObjectContextMenu.addToolTip();
                    tooltip.description = getText("IGUI_UserList_BanHimself");
                    banSteamIdButton.toolTip = tooltip;
                end
            end
        else
            local banIpButton;
            if item:getIpBanned() ~= nil and item:getIpBanned() ~= '' then
                banIpButton = context:addOption(getText("IGUI_UserList_UnBanIP"), ISUsersList.instance, ISUsersList.onClickOption, item, "UnBanIP");
            else
                banIpButton = context:addOption(getText("IGUI_UserList_BanIP"), ISUsersList.instance, ISUsersList.onClickOption, item, "BanIP");
                if item:getRole():hasCapability(Capability.CantBeBannedByUser) then
                    banIpButton.notAvailable = true;
                    local tooltip = ISWorldObjectContextMenu.addToolTip();
                    tooltip.description = getText("IGUI_UserList_CantBeBanned");
                    banIpButton.toolTip = tooltip;
                end
                if not item:isOnline() or item:getRole():getName() == 'banned' then
                    banIpButton.notAvailable = true;
                    local tooltip = ISWorldObjectContextMenu.addToolTip();
                    tooltip.description = getText("IGUI_UserList_BanIPNotOnline");
                    banIpButton.toolTip = tooltip;
                end
                if item:getUsername() == self.player:getUsername() then
                    banIpButton.notAvailable = true;
                    local tooltip = ISWorldObjectContextMenu.addToolTip();
                    tooltip.description = getText("IGUI_UserList_BanHimself");
                    banIpButton.toolTip = tooltip;
                end
            end
        end
    end
    if self.player:getRole():hasCapability(Capability.AddUserlog) then
        context:addOption(getText("IGUI_UserList_AddWarningPoint"), ISUsersList.instance, ISUsersList.onClickOption, item, "AddWarningPoint");
    end
    if self.player:getRole():hasCapability(Capability.ReadUserLog) then
        context:addOption(getText("IGUI_UserList_SeeUserLog"), ISUsersList.instance, ISUsersList.onClickOption, item, "SeeUserLog");
        if item:isOnline() then
            context:addOption(getText("IGUI_UserList_SeeSuspicionActivity"), ISUsersList.instance, ISUsersList.onClickOption, item, "SeeSuspicionActivity");
        end
    end
    if self.player:getRole():hasCapability(Capability.InspectPlayerInventory) then
        if item:isOnline() then
            context:addOption(getText("IGUI_PlayerStats_ManageInventory", item:getUsername()), ISUsersList.instance, ISUsersList.onClickOption, item, "ManageInventory");
        else
            context:addOption(getText("IGUI_PlayerStats_SeeInventory", item:getUsername()), ISUsersList.instance, ISUsersList.onClickOption, item, "ManageInventory");
        end
    end
    if self.player:getRole():hasCapability(Capability.ModifyNetworkUsers) then
        context:addOption(getText("IGUI_UserList_Delete"), ISUsersList.instance, ISUsersList.onClickOption, item, "Delete");
        context:addOption(getText("IGUI_UserList_ResetTOTPSecret"), ISUsersList.instance, ISUsersList.onClickOption, item, "ResetTOTPSecret");
        context:addOption(getText("IGUI_UserList_ResetPassword"), ISUsersList.instance, ISUsersList.onClickOption, item, "ResetPassword");
        context:addOption(getText("IGUI_UserList_SetPassword"), ISUsersList.instance, ISUsersList.onClickOption, item, "SetPassword");
    end
end
