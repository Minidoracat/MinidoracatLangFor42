require "ISUI/AdminPanel/ISRolesList"

-- ISRolesList draws server-side role fields directly. Translate only the
-- vanilla built-in roles/default labels for display; custom roles stay intact.

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)

local ROLE_NAMES = {
    admin = "IGUI_RolesList_Role_admin",
    moderator = "IGUI_RolesList_Role_moderator",
    gm = "IGUI_RolesList_Role_gm",
    observer = "IGUI_RolesList_Role_observer",
    priority = "IGUI_RolesList_Role_priority",
    user = "IGUI_RolesList_Role_user",
    banned = "IGUI_RolesList_Role_banned",
}

local ROLE_DESCRIPTIONS = {
    admin = "IGUI_RolesList_Role_admin_description",
    moderator = "IGUI_RolesList_Role_moderator_description",
    gm = "IGUI_RolesList_Role_gm_description",
    observer = "IGUI_RolesList_Role_observer_description",
    priority = "IGUI_RolesList_Role_priority_description",
    user = "IGUI_RolesList_Role_user_description",
    banned = "IGUI_RolesList_Role_banned_description",
}

local ROLE_DEFAULTS = {
    Admin = "IGUI_RolesList_Default_Admin",
    Moderator = "IGUI_RolesList_Default_Moderator",
    GM = "IGUI_RolesList_Default_GM",
    Oversee = "IGUI_RolesList_Default_Oversee",
    Observer = "IGUI_RolesList_Default_Observer",
    PriorityUser = "IGUI_RolesList_Default_PriorityUser",
    User = "IGUI_RolesList_Default_User",
    NewUser = "IGUI_RolesList_Default_NewUser",
    Banned = "IGUI_RolesList_Default_Banned",
}

local function textOrFallback(key, fallback)
    if key then
        local text = getTextOrNull and getTextOrNull(key) or nil
        if text and text ~= "" then
            return text
        end
    end
    return fallback
end

local function getRoleName(role)
    local name = tostring(role:getName())
    return textOrFallback(ROLE_NAMES[name], name)
end

local function getRoleDescription(role)
    local name = tostring(role:getName())
    return textOrFallback(ROLE_DESCRIPTIONS[name], role:getDescription())
end

local function getDefaultsText(role)
    local labels = {}
    local defaults = role:getDefaults()
    for i = 0, defaults:size() - 1 do
        local label = tostring(defaults:get(i))
        table.insert(labels, textOrFallback(ROLE_DEFAULTS[label], label))
    end
    return table.concat(labels, " ")
end

local function getReadOnlyText(role)
    if role:isReadOnly() then
        return textOrFallback("IGUI_RolesList_ReadOnly", "[Read Only]")
    end
    return ""
end

local function getMetaText(role)
    local readOnlyText = getReadOnlyText(role)
    local defaultsText = getDefaultsText(role)
    if readOnlyText ~= "" and defaultsText ~= "" then
        return readOnlyText .. " " .. defaultsText
    end
    return readOnlyText .. defaultsText
end

function ISRolesList:drawDatas(y, item, alt)
    local a = 0.9

    self:drawRectBorder(0, y, self:getWidth(), self.itemheight - 1, a, self.borderColor.r, self.borderColor.g, self.borderColor.b)

    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15)
    end

    local role = item.item
    local color = role:getColor()
    self:drawText(getRoleName(role), 10, y + 2, color:getR(), color:getG(), color:getB(), a, UIFont.Medium)
    self:drawText(getRoleDescription(role), 10, y + 2 + (FONT_HGT_SMALL + 3), 1, 1, 1, a, self.font)
    self:drawText(getMetaText(role), 10, y + 2 + (FONT_HGT_SMALL + 3) * 2, 1, 1, 1, a, self.font)

    return y + self.itemheight
end

function ISRolesList:onMouseMove(dx, dy)
    local x = Mouse.getXA()
    local y = Mouse.getYA()
    if self.tooltipUI ~= nil
            and ((x < self.datas.x + self.x)
            or (x > self.datas.x + self.x + self.datas.width)
            or (y < self.datas.y + self.y)
            or (y > self.y + self.datas.height)) then
        self.tooltipUI:setVisible(false)
    end
    for i, item in ipairs(self.datas.items) do
        if (y < self.y + self.datas.y + self.datas.height)
                and (x > self.x + self.datas.x)
                and (x < self.x + self.datas.x + self.datas.width)
                and (y > self.y + self.datas.y + self.datas.itemheight * (i - 1) + self.datas:getYScroll())
                and (y < self.y + self.datas.y + self.datas.itemheight * i + self.datas:getYScroll()) then
            local description = getRoleDescription(item.item)
            if not self.tooltipUI then
                self.tooltipUI = ISToolTip:new()
                self.tooltipUI:setOwner(self)
                self.tooltipUI:setVisible(false)
                self.tooltipUI:setAlwaysOnTop(true)
            end
            if description == "" then
                if self.tooltipUI:getIsVisible() then
                    self.tooltipUI:setVisible(false)
                end
            else
                if not self.tooltipUI:getIsVisible() then
                    self.tooltipUI:addToUIManager()
                    self.tooltipUI:setVisible(true)
                end
            end
            self.tooltipUI.description = description
            self.tooltipUI:setX(x)
            self.tooltipUI:setY(y)
        end
    end
end

function ISRolesList:onMouseMoveOutside(dx, dy)
    if self.tooltipUI ~= nil then
        self.tooltipUI:setVisible(false)
        self.tooltipUI = nil
    end
end
