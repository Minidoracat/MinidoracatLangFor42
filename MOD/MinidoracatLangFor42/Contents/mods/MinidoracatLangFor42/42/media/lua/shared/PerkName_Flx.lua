-- PerkName_Flx.lua
-- 修復 Java 層 LevelPerk halo 使用 stale / server 語言技能名的問題。
--
-- IsoGameCharacter.LevelPerk() 直接組合 "+1 " .. perk.getName()。
-- 若 PerkFactory 在本 MOD 翻譯載入前已初始化，或 MP server 使用非玩家端語言，
-- halo 可能顯示 "+1 Agriculture"。這裡在 Lua 載入後重新套用當前 runtime
-- 可見的 IGUI_perks_* 翻譯到 PerkFactory.Perk.name。
--
-- 注意：Dedicated server 會先把 HaloTextPacket 渲染成文字再送給 client；
-- 若 server 本身仍是英文語言環境，client 端無法對該 packet 做逐玩家語言修正。

local function refreshPerkNames()
    if not PerkFactory or not PerkFactory.PerkList then return end

    if PerkFactory.initTranslations then
        pcall(PerkFactory.initTranslations)
    end

    local perkList = PerkFactory.PerkList
    for i = 0, perkList:size() - 1 do
        local perk = perkList:get(i)
        if perk and perk.translation then
            local key = "IGUI_perks_" .. tostring(perk.translation)
            local translated = getTextOrNull and getTextOrNull(key) or getText(key)
            if translated and translated ~= "" and translated ~= key then
                pcall(function()
                    perk.name = translated
                end)
            end
        end
    end
end

refreshPerkNames()

if Events.OnGameStart then
    Events.OnGameStart.Add(refreshPerkNames)
end

if Events.OnServerStarted then
    Events.OnServerStarted.Add(refreshPerkNames)
end
