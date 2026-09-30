-- AEBSWeather_Flx.lua
-- 多人連線時，AEBS 自動廣播（天氣頻道）依每個 client 的語言播出（送出與播放見 RadioLine_Flx.lua）。
--
-- 原版：server 端 radio/ISWeatherChannel.lua 每遊戲小時用 getText() 組好整句，交給 Java 逐行播出。
-- 本檔在專用伺服器上照常呼叫 WeatherChannel.CreateBroadcast，期間把全域 getText 暫換成 RadioLineFlx.token，
-- 每一行只記下 key 與參數（原版的字串串接照常運作），再照原版 setAiringBroadcast 交給 Java 排程；
-- RadioLine_Flx 在每一行播出時改送 token，由各 client 翻譯。單機的 getText 本來就是本機語言，維持原版。

require "RadioLine_Flx"

local function capture(gametime)
    local realGetText = getText
    getText = RadioLineFlx.token
    local ok, bc = pcall(WeatherChannel.CreateBroadcast, gametime)
    getText = realGetText
    if ok then return bc end
    return nil, bc
end

local function install()
    local vanilla = WeatherChannel.OnEveryHour
    WeatherChannel.OnEveryHour = function(channel, gametime, radio)
        local bc, err = capture(gametime)
        if not bc then
            print("[CatLangFor42] [AEBS] per-client broadcast failed, airing the vanilla one: " .. tostring(err))
            return vanilla(channel, gametime, radio)
        end
        -- Java 依字串長度決定每行停留多久；字串現在是 token，改用自訂播放時間鎖回伺服器語言原句的節奏
        -- （RadioChannel.update：len/10*60 夾在 [90, 300] 再乘 airCounterMultiplier；自訂時間是 airTime*60、不夾不乘）
        local lines, mult = bc:getLines(), channel:getAirCounterMultiplier()
        for i = 0, lines:size() - 1 do
            local line = lines:get(i)
            line:setAirTime(math.min(math.max(#RadioLineFlx.resolve(line:getText()) / 10 * 60, 90), 300) * mult / 60)
        end
        channel:setAiringBroadcast(bc)
    end
    print("[CatLangFor42] [AEBS] weather broadcast worded by each client")
end

-- RadioLine_Flx 由上方 require 先載入，它的 OnLoadRadioScripts 先跑；沒有啟用（非專用伺服器）時維持原版
Events.OnLoadRadioScripts.Add(function()
    if isServer() and RadioLineFlx.active and WeatherChannel then install() end
end)
