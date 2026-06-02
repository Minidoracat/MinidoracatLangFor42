-- GameOptionControllerTab_Flx.lua
-- Narrow B42.19.0 wrapper for translated controller preset labels.

require "ISUI/Gamepad/GameOptionControllerTab"
require "gamepadBinding"

local function getPresetLabelText(presetKey, preset)
    if preset.loadedSet ~= nil then
        local customSuffix = presetKey:match("^Custom(_%d+)$")
        if presetKey == "Custom" or customSuffix ~= nil then
            return getText("UI_optionscreen_gamepad_preset_Custom_Label") .. (customSuffix or "")
        end
    end

    return getText(preset.labelText)
end

local function translatePresetOptions(comboBox)
    local style = comboBox:getStyle()
    local font = style:getFont("Medium")
    local width = style.buttonHeight

    for _, option in ipairs(comboBox.options) do
        local optionText = option
        if type(option) == "table" then
            if option.data == "CreateNew" then
                option.text = getText("UI_optionscreen_gamepad_createNew_Label")
                option.tooltip = getText("UI_optionscreen_gamepad_createNew_Description")
            else
                local preset = gamepadBinding.presets[option.data]
                if preset then
                    option.text = getPresetLabelText(option.data, preset)
                end
            end
            optionText = option.text
        end

        width = math.max(width, getTextManager():MeasureStringX(font, optionText or ""))
    end

    comboBox:setWidth(width + style.borderSpacing * 2 + style.buttonHeight)
end

local _orig_createGamepadBindingPresetsCBox = GameOptionControllerTab.createGamepadBindingPresetsCBox
function GameOptionControllerTab:createGamepadBindingPresetsCBox(x, y)
    local comboBox = _orig_createGamepadBindingPresetsCBox(self, x, y)
    local _orig_populate = comboBox.populate

    function comboBox:populate()
        _orig_populate(self)
        translatePresetOptions(self)
    end

    return comboBox
end
