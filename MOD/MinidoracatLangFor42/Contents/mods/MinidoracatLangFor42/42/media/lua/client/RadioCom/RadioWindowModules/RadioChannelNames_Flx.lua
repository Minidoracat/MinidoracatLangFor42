-- RadioChannelNames_Flx.lua
-- 修正 radio/TV 裝置 UI 中的頻道預設名稱。
--
-- PZ 會把頻道名稱從 RadioData.xml 的 ChannelEntry.name 複製進 DeviceData presets；
-- 多人或舊存檔中的 presets 可能已經保存英文名稱，所以只改 ZomboidRadio channel list
-- 不一定能更新下拉選單。這裡僅覆寫 UI 顯示文字，不改玩家自訂頻道資料。

require "RadioCom/RadioWindowModules/RWMChannel"
require "RadioCom/RadioWindowModules/RWMChannelTV"
require "RadioCom/RadioWindowModules/RWMGeneral"

local function localizedChannelName(frequency, fallback)
    if RadioDataFlx and RadioDataFlx.getLocalizedChannelName then
        return RadioDataFlx.getLocalizedChannelName(frequency, fallback) or fallback
    end
    return fallback
end

local function truncateUtf8ToWidth(text, width)
    if not text or not getTextManager or not UIFont or not UIFont.Small then
        return text
    end

    local textManager = getTextManager()
    if not textManager or textManager:MeasureStringX(UIFont.Small, text) <= width then
        return text
    end

    local result = ""
    local maxWidth = width - 45
    for character in tostring(text):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        local candidate = result .. character
        if textManager:MeasureStringX(UIFont.Small, candidate) > maxWidth then
            return result .. "..."
        end
        result = candidate
    end

    return result
end

if RWMChannel and not RWMChannel._CatLangFor42_addComboOption then
    RWMChannel._CatLangFor42_addComboOption = true
    -- 原版 addComboOption 以 byte-wise s:sub(i,i) 截斷字串，中文 UTF-8 會被切成亂碼。
    -- 這裡保留 _orig 作為覆寫標記，但刻意不呼叫原函式。
    RWMChannel._CatLangFor42_origAddComboOption = RWMChannel.addComboOption
    function RWMChannel:addComboOption(_freq, _name)
        local divider = self.frequencyDivider or 1000
        local frequencyText = tostring(self:round(_freq / divider, 1)) .. " MHz "
        local name = localizedChannelName(_freq, _name)
        local option = truncateUtf8ToWidth(frequencyText .. name, self.comboBox:getWidth())
        self.comboBox:addOption(option)
    end
end

if RWMChannelTV and not RWMChannelTV._CatLangFor42_addComboOption then
    RWMChannelTV._CatLangFor42_addComboOption = true
    -- 同上：避免原版 byte-wise 截斷破壞中文頻道名稱。
    RWMChannelTV._CatLangFor42_origAddComboOption = RWMChannelTV.addComboOption
    function RWMChannelTV:addComboOption(_freq, _name)
        local option = truncateUtf8ToWidth(localizedChannelName(_freq, _name), self.comboBox:getWidth())
        self.comboBox:addOption(option)
    end
end

if RWMGeneral and not RWMGeneral._CatLangFor42_setInfoLines then
    RWMGeneral._CatLangFor42_setInfoLines = true
    local _origSetInfoLines = RWMGeneral.setInfoLines
    function RWMGeneral:setInfoLines()
        _origSetInfoLines(self)

        if not self.deviceData or not self.infoLines then
            return
        end

        local prefix = getText("IGUI_RadioChannel") .. ":   "
        local frequency = self.deviceData:getChannel()
        for _, infoLine in ipairs(self.infoLines) do
            if infoLine.prefix == prefix then
                infoLine.line = localizedChannelName(frequency, infoLine.line)
            end
        end
    end
end
