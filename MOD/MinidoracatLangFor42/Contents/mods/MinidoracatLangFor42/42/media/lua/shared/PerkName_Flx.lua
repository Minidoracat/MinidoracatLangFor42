-- PerkName_Flx.lua
-- 修復 Java 層 LevelPerk halo 使用 stale 技能名的問題。
--
-- IsoGameCharacter.LevelPerk() 直接組合 "+1 " .. perk.getName()。
-- PerkFactory.initTranslations()（Java）會以目前 Translator（含本 MOD 翻譯）重設每個
-- Perk.name；Translator 載入完也會呼叫它，這裡在 Lua 載入與開局時再保險呼叫一次。
-- （Lua 端讀不到 Java public 欄位 perk.translation，不能自己逐項改 perk.name。）
--
-- 注意：Dedicated server 會先把 HaloTextPacket 渲染成文字再送給 client；
-- 若 server 本身仍是英文語言環境，client 端無法對該 packet 做逐玩家語言修正。

local function refreshPerkNames()
    if PerkFactory and PerkFactory.initTranslations then
        pcall(PerkFactory.initTranslations)
    end
end

refreshPerkNames()

if Events.OnGameStart then
    Events.OnGameStart.Add(refreshPerkNames)
end

if Events.OnServerStarted then
    Events.OnServerStarted.Add(refreshPerkNames)
end
