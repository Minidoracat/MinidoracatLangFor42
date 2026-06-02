-- ISUsersList_Flx.lua
-- Narrow B42.19.0 wrappers for hardcoded admin users-list labels.

require "ISUI/AdminPanel/ISUsersList"

local function translateStatusText(text)
    if text == "Online" then
        return getText("IGUI_UsersList_Online")
    end
    if text == "Offline" then
        return getText("IGUI_UsersList_Offline")
    end
    return text
end

local _orig_drawDatas = ISUsersList.drawDatas
function ISUsersList:drawDatas(y, item, alt)
    local originalDrawText = self.drawText

    self.drawText = function(drawSelf, text, ...)
        return originalDrawText(drawSelf, translateStatusText(text), ...)
    end

    local ok, result = pcall(_orig_drawDatas, self, y, item, alt)
    self.drawText = originalDrawText

    if not ok then
        error(result)
    end
    return result
end

local _orig_doContextMenu = ISUsersList.doContextMenu
function ISUsersList:doContextMenu(item, x, y)
    local originalGetContext = ISContextMenu.get
    local patchedContexts = {}
    local patchedContextOrder = {}

    ISContextMenu.get = function(...)
        local context = originalGetContext(...)
        if context and context.addOption and not patchedContexts[context] then
            patchedContexts[context] = context.addOption
            patchedContextOrder[#patchedContextOrder + 1] = context

            context.addOption = function(menu, label, ...)
                if label == "Set Role" then
                    label = getText("IGUI_UsersList_SetRole")
                end
                return patchedContexts[context](menu, label, ...)
            end
        end
        return context
    end

    local ok, result = pcall(_orig_doContextMenu, self, item, x, y)
    ISContextMenu.get = originalGetContext

    for _, context in ipairs(patchedContextOrder) do
        context.addOption = patchedContexts[context]
    end

    if not ok then
        error(result)
    end
    return result
end
