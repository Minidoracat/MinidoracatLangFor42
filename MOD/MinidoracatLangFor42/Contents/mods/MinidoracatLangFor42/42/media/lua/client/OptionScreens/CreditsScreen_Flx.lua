-- CreditsScreen_Flx.lua
-- 避免解析度變更時 CreditsScreen 尚未建立 richText 就呼叫 setWidth/setHeight 的 vanilla nil error。

require "OptionScreens/CreditsScreen"

if CreditsScreen and not CreditsScreen._CatLangFor42_onResolutionChange then
    CreditsScreen._CatLangFor42_onResolutionChange = true
    local _origOnResolutionChange = CreditsScreen.onResolutionChange
    function CreditsScreen:onResolutionChange(...)
        if not self.richText or not self.richText.setWidth or not self.richText.setHeight then
            return
        end
        return _origOnResolutionChange(self, ...)
    end
end
