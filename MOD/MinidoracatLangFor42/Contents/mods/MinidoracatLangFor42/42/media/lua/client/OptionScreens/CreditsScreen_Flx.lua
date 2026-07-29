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

-- 補回漢化組署名。
-- PZ 42.20 移除了 LuaManager 對 Translate/<lang>/credits.txt 的讀取，改為只認
-- Credits_Translator.json；而 CreditsRole.getTranslatorCreditsList 是用相對於遊戲
-- 執行目錄的 Path.of("media/lua/shared/Translate") + 原生 Files API 讀檔，完全不走
-- ZomboidFileSystem 的 mod 疊加，MOD 目錄下放同名檔讀不到。
-- 因此改用 credits_ 前綴的自有鍵（走 Credits.json 既有翻譯路由）在名單尾端補一段。
if CreditsScreen and not CreditsScreen._CatLangFor42_doCreditsText then
    CreditsScreen._CatLangFor42_doCreditsText = true
    local _origDoCreditsText = CreditsScreen.doCreditsText
    function CreditsScreen:doCreditsText(...)
        local text = _origDoCreditsText(self, ...)
        local title = getTextOrNull("credits_CatLangFor42_group")
        local names = getTextOrNull("credits_CatLangFor42_names")
        if type(text) == "string" and title and names then
            -- 排版沿用 vanilla doCreditsText 的 roleGroupHeader / nameHeader 慣例
            text = text
                .. " <LINE> <LINE> <LINE> <SIZE:credits2> " .. title
                .. " <SIZE:medium> <LINE> " .. names
                .. " <LINE> <LINE> "
        end
        return text
    end
end
