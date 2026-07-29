-- DialogText_Flx.lua
-- 修復官方以字面英文直接建構 ISTextBox / ISModalDialog 的對話框提示文字
-- （HARDCODE_REGISTRY.md B9 殘餘、B17、B20、B21）。
--
-- 這些字串不在選單樹上，A16 的 walker 涵蓋不到；官方也沒掛任何翻譯鍵，
-- 翻譯 JSON 無從介入，只能在建構層攔截。
--
-- 修補策略與 A16 相同：
--   1. 先以「官方英文原句」精確查表；查不到再套 PATTERNS（動態組字）
--   2. 兩者皆 miss 一律原樣保留 —— 第三方 MOD 的對話框只有在字串與已登記
--      官方原句逐字相同時才會被同一譯文命中（語義相同，可接受）
--   3. getTextOrNull：鍵未載入（非 CH/CN 語系）時回 nil 保留原文
--
-- 注意 B20（ModListPresets 的分享/匯入對話框）**沒有任何 debug/admin gate**，
-- 是一般玩家在主選單 MOD 管理就會看到的英文，故本檔不做權限 gate。

require "ISUI/ISTextBox"
require "ISUI/ISModalDialog"

-- 官方英文原句 → 我方翻譯鍵
local EXACT = {
    -- B20 主選單 MOD 預設集（一般玩家可見）
    ["Mods preset text copied to clipboard"] = "IGUI_CatLangDialog_ModPresetCopied",
    ["Paste here mods preset text:"]         = "IGUI_CatLangDialog_ModPresetPaste",
    -- B21 採集除錯
    ["Enter Item Type:"]                     = "IGUI_CatLangDialog_EnterItemType",
    -- B9 除錯選單殘餘對話框標題
    ["Key ID:"]                              = "IGUI_CatLangDialog_KeyID",
    ["Fuel (Minutes):"]                      = "IGUI_CatLangDialog_FuelMinutes",
    ["Compost (0-100):"]                     = "IGUI_CatLangDialog_Compost0100",
    -- B17 動物基因編輯視窗
    ["Dominant?"]                            = "IGUI_CatLangDialog_Dominant",
}

-- 動態組字。n = 擷取數；順序即優先序
local PATTERNS = {
    -- DebugContextMenu.lua "Fuel (0-".. max .. "):"
    { match = "^Fuel %(0%-(%d+)%):$", key = "IGUI_CatLangDialog_Pat_FuelRange", n = 1 },
    -- ISAnimalGenomeUI.lua "Change " .. allele:getName()
    { match = "^Change (.+)$", key = "IGUI_CatLangDialog_Pat_Change", n = 1 },
}

local function translateDialogText(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end
    local key = EXACT[text]
    if key then
        return getTextOrNull(key)
    end
    for _, p in ipairs(PATTERNS) do
        local c1 = text:match(p.match)
        if c1 ~= nil then
            return getTextOrNull(p.key, c1)
        end
    end
    return nil
end

-- ISTextBox:new(x, y, width, height, text, defaultEntryText, target, onclick, player, ...)
local _origTextBoxNew = ISTextBox.new
function ISTextBox:new(x, y, width, height, text, ...)
    local ok, translated = pcall(translateDialogText, text)
    if ok and translated then
        text = translated
    end
    return _origTextBoxNew(self, x, y, width, height, text, ...)
end

-- ISModalDialog:new(x, y, width, height, text, yesno, target, onclick, player, ...)
local _origModalDialogNew = ISModalDialog.new
function ISModalDialog:new(x, y, width, height, text, ...)
    local ok, translated = pcall(translateDialogText, text)
    if ok and translated then
        text = translated
    end
    return _origModalDialogNew(self, x, y, width, height, text, ...)
end
