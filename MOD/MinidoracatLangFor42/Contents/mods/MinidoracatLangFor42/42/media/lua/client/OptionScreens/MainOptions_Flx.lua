-- MainOptions_Flx.lua
-- 在「遊戲設定 → 使用者介面 → 語言」的譯者清單補上漢化組署名。
--
-- 該區塊走 MainOptions.getGeneralTranslators() → CreditsRole.getTranslatorCreditsList(Language)，
-- 而後者是 Java 端以 Path.of("media/lua/shared/Translate") 這個「相對於遊戲執行目錄」的
-- 原生 Files API 讀 Credits_Translator.json，完全不經 ZomboidFileSystem 的 mod 疊加
-- （見 HARDCODE_REGISTRY.md 第 0 節），所以 MOD 目錄放同名檔永遠讀不到。
-- 唯一介入點是包裝這個 Lua 函式，把我方名單接在官方清單後面。
--
-- 名單真相來源與 CreditsScreen_Flx.lua 共用同一組鍵（credits_ 前綴有正規路由），
-- 但這裡的消費端是「一行一個字串」的清單，不吃 richText，所以要把 <LINE> 拆成多行。

require "OptionScreens/MainOptions"

local function safeName(language)
    if not language then return nil end
    local ok, name = pcall(function() return language:name() end)
    if ok and type(name) == "string" then return name end
    return nil
end

if MainOptions and type(MainOptions.getGeneralTranslators) == "function"
        and not MainOptions._CatLangFor42_translators then
    MainOptions._CatLangFor42_translators = true
    local _origGetGeneralTranslators = MainOptions.getGeneralTranslators

    function MainOptions.getGeneralTranslators(_language)
        local result = _origGetGeneralTranslators(_language)

        -- 只在「被詢問的語言 == 目前載入的語言」時附加。
        -- getTextOrNull 取的一律是目前語言的值，若使用者在下拉選單預覽別的語言，
        -- 把我方名單貼到那個語言底下就錯了。
        local asked = safeName(_language)
        local current = safeName(Translator.getLanguage())
        if asked and current and asked == current then
            local names = getTextOrNull("credits_CatLangFor42_names")
            if names then
                if type(result) ~= "table" then
                    result = {}
                end
                -- richText 的 <LINE> 在這個清單裡不會被解釋，必須自行拆行
                local flat = names:gsub("%s*<LINE>%s*", "\n")
                for line in flat:gmatch("[^\n]+") do
                    line = line:match("^%s*(.-)%s*$")
                    if line ~= "" then
                        table.insert(result, line)
                    end
                end
            end
        end

        return result
    end
end
