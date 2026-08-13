-- AEBSWeather_Flx.lua
-- 修復 AEBS 自動廣播系統（天氣頻道）字幕在英文 server 下對中文 client 顯示英文的問題。
--
-- 根因：天氣播報由 vanilla media/lua/server/radio/ISWeatherChannel.lua 於 server 端
-- 每遊戲小時以 getText() 組成「成品字串」，再經 ZomboidRadio.SendTransmission →
-- GameServer.sendIsoWaveSignal 把最終文字送給 client。專用伺服器啟動時只跑
-- Languages.init() + Translator.loadFiles()，不載入 options.ini，Translator.getLanguage()
-- 因此退回 System.getProperty("user.language") 或預設 EN；英文 server 就會對中文
-- client 送出英文字幕。該封包的 guid 由 RadioChannel 硬帶 null，client 無從反查翻譯
-- key，只能對字串本身做反解。
--
-- 攔截點：RadioChat.showMessage() 只觸發 OnAddMessage 事件、自身不渲染，實際渲染由
-- Lua 端 ISChat.addLineInChat 負責，且 ChatMessage.setText() 為 public。本檔覆寫
-- ISChat.addLineInChat，在原函式取文字之前把英文成品字串反解回「翻譯 key + 參數」，
-- 再用 getText(key, ...) 以 client 端語言重組——因此 CH/CN 共用同一份反查表，
-- 譯文調整不需重新生成。
--
-- 覆寫時機安全：vanilla 的 Events.OnAddMessage.Add(ISChat.addLineInChat) 寫在
-- ISChat.createChat 內、由 OnGameStart 觸發，晚於 mod 檔案載入，因此註冊進事件的
-- 會是本檔覆寫後的版本，沒有 hook 順序問題。
--
-- 侷限：收音機旁的浮動文字走 ChatElement.addChatLine()，該路徑沒有任何 triggerEvent，
-- ChatElement 也沒有讀取／修改單行的公開 API（只有 addChatLine 與 clear），Lua 無法
-- 攔截，那條仍會是 server 語言。
--
-- 附帶修正一處 vanilla 缺陷：WeatherChannel.Init() 把 activity 表整個換成 key 字面
-- （"AEBS_rand_pre_0"…），而 AEBS_random_3 直接把它塞進 %1 **未經 getText**，因此
-- vanilla 在任何語言下都會顯示裸 key。本檔認出這些 key 並補譯（AEBSFlx.BARE_KEYS）。
-- 同一支 Init 也把 zones 換成 key，但 AEBS_random_0 那側有 getText(zone.name)，
-- 成品已是譯文，走一般片語表即可。
--
-- 反查表由 scripts/sync_translations.py gen-aebs-map 自動產生。

AEBSFlx = AEBSFlx or {}
AEBSFlx.PATCH_VERSION = 1

-- <AUTO-GEN:AEBS_MAP START>
-- 由 scripts/sync_translations.py gen-aebs-map 自動產生，請勿手動編輯
-- 來源：vanilla EN/DynamicRadio.json（AEBS_* 共 78 條）
-- 只含英文原文 → 翻譯 key，譯文一律由 client 端 getText 取得。
AEBSFlx = AEBSFlx or {}

-- AddForecast 的行首前綴，需先剝離才能匹配後方模板
AEBSFlx.PREFIXES = {
    { en = "Today,", key = "AEBS_Pre_today" },
    { en = "Tomorrow,", key = "AEBS_Pre_tomorrow" },
    { en = "Day after tomorrow,", key = "AEBS_Pre_dayafter" },
}

-- 帶參數模板，依固定文字長度降序（越具體越先匹配）
AEBSFlx.TEMPLATES = {
    { pat = "^All personnel%. Temporary communications failure for (.-) exclusion zone%.%.%. sectors (.-), (.-), (.-) and (.*)$", key = "AEBS_random_0", n = 5 },
    { pat = "^charlie <fzzt> india %- alpha, <bzzt> designated zone <bzzt> sector (.-) <wzzt>$", key = "AEBS_random_1", n = 1 },
    { pat = "^average temperature (.-)%. Minimum: (.-)%. Maximum: (.-)%. Humidity: (.-)%%%.%.%.$", key = "AEBS_temperature", n = 4 },
    { pat = "^All personnel <bzzt> order <fzzt> (.-) has been issued<wzzt>$", key = "AEBS_random_2", n = 1 },
    { pat = "^Severe Weather Warning%. (.-) Imminent%. ETA (.-) days%.%.%.$", key = "AEBS_weather_warning", n = 2 },
    { pat = "^(.-) wind from the (.-)%. Maximum of (.-) expected%. (.*)$", key = "AEBS_wind_0", n = 4 },
    { pat = "^%.%.%.(.-) <fzzt> activity in sector (.-) <wzzt>$", key = "AEBS_random_3", n = 2 },
}

-- 開放式前段：GetForecastString type 4/5 會在其後續接天氣後綴，
-- 故不錨定行尾，由 string.find 取結束位置後把剩餘內容交給 greedy。
AEBSFlx.OPEN_TEMPLATES = {
    { pat = "^WARNING: Period of weather predicted to start in the (.-)%.%.%.", key = "AEBS_weather_0_a", n = 1 },
    { pat = "^Weather period predicted to end in the (.-)%.%.%.", key = "AEBS_weather_0_c", n = 1 },
    { pat = "^Weather continues throughout the day%.%.%.", key = "AEBS_weather_0_b", n = 0 },
}

-- 整行全等查表
AEBSFlx.PHRASE_KEY = {
    ["<bzzt>... who's sending these out? <fzzt> I mean we got the orders, but ...<wzzt>"] = "AEBS_random_11",
    ["<bzzt>..elp me! <fzzt> for the love of <szzt> PLEASE NO!! <fzzt> help... <wzzt>"] = "AEBS_random_5",
    ["<bzzt>..IT'S BREACHED!... <bzzt> DAMMIT, HOLD IT! WE NEED ASSI...<wzzt>"] = "AEBS_random_7",
    ["<bzzt>... said they came from the East <fzzt> repeat: East...<wzzt>"] = "AEBS_random_13",
    ["<bzzt>... i don't trust him <fzzt> who says... can't be true<wzzt>"] = "AEBS_random_12",
    ["<bzzt> Fiver Zero Two. <wzzt> Automated Broadcast System. <bzzt>"] = "AEBS_Intro",
    ["<bzzt>..they want to pull it... <bzzt> make it so... <wzzt>"] = "AEBS_random_6",
    ["<bzzt>... Operation Artemis <fzzt> high priority ...<wzzt>"] = "AEBS_random_10",
    ["Knox Power Grid: Systems failing. Network compromised."] = "AEBS_Power_2",
    ["<bzzt>... escaped... <fzzt> moving to ...<wzzt>"] = "AEBS_random_9",
    ["Knox Power Grid: Power fluctuations detected."] = "AEBS_Power_1",
    ["<bzzt>... they need more data...<wzzt>"] = "AEBS_random_8",
    ["Knox Power Grid: Blackout."] = "AEBS_Power_3",
    ["Air Activity detected."] = "AEBS_Choppah",
    ["Very thick fog."] = "AEBS_fog_2",
    ["Light fog."] = "AEBS_fog_0",
    ["Thick fog."] = "AEBS_fog_1",
}

-- greedy 逐段吃掉模板參數內的片語，依長度降序
AEBSFlx.PHRASES = {
    { en = "<bzzt>... who's sending these out? <fzzt> I mean we got the orders, but ...<wzzt>", key = "AEBS_random_11" },
    { en = "<bzzt>..elp me! <fzzt> for the love of <szzt> PLEASE NO!! <fzzt> help... <wzzt>", key = "AEBS_random_5" },
    { en = "<bzzt>..IT'S BREACHED!... <bzzt> DAMMIT, HOLD IT! WE NEED ASSI...<wzzt>", key = "AEBS_random_7" },
    { en = "<bzzt>... said they came from the East <fzzt> repeat: East...<wzzt>", key = "AEBS_random_13" },
    { en = "<bzzt>... i don't trust him <fzzt> who says... can't be true<wzzt>", key = "AEBS_random_12" },
    { en = "<bzzt> Fiver Zero Two. <wzzt> Automated Broadcast System. <bzzt>", key = "AEBS_Intro" },
    { en = "<bzzt>..they want to pull it... <bzzt> make it so... <wzzt>", key = "AEBS_random_6" },
    { en = "<bzzt>... Operation Artemis <fzzt> high priority ...<wzzt>", key = "AEBS_random_10" },
    { en = "Knox Power Grid: Systems failing. Network compromised.", key = "AEBS_Power_2" },
    { en = "<bzzt>... escaped... <fzzt> moving to ...<wzzt>", key = "AEBS_random_9" },
    { en = "Knox Power Grid: Power fluctuations detected.", key = "AEBS_Power_1" },
    { en = "Weather continues throughout the day...", key = "AEBS_weather_0_b" },
    { en = "<bzzt>... they need more data...<wzzt>", key = "AEBS_random_8" },
    { en = "expecting light to moderate rain...", key = "AEBS_weather_light_moderate" },
    { en = "Knox Power Grid: Blackout.", key = "AEBS_Power_3" },
    { en = "with a chance of snowfall.", key = "AEBS_weather_snowfall" },
    { en = "Periodical cloudy spells.", key = "AEBS_clouds_3" },
    { en = "showers and or heavy rain", key = "AEBS_weather_heavy_rain" },
    { en = "Periods of heavy cloud.", key = "AEBS_clouds_4" },
    { en = "Air Activity detected.", key = "AEBS_Choppah" },
    { en = "Day after tomorrow,", key = "AEBS_Pre_dayafter" },
    { en = "Heavy cloud cover.", key = "AEBS_clouds_2" },
    { en = "Very thick fog.", key = "AEBS_fog_2" },
    { en = "tropical storm", key = "AEBS_weather_tropical" },
    { en = "Tropical storm", key = "AEBS_weather_tropical_C" },
    { en = "Storm-strength", key = "AEBS_wind_4" },
    { en = "early morning", key = "AEBS_segment_early_morning" },
    { en = "Clear skies.", key = "AEBS_clouds_0" },
    { en = "Some clouds.", key = "AEBS_clouds_1" },
    { en = "thunderstorm", key = "AEBS_weather_storm" },
    { en = "Thunderstorm", key = "AEBS_weather_storm_C" },
    { en = "Light fog.", key = "AEBS_fog_0" },
    { en = "Thick fog.", key = "AEBS_fog_1" },
    { en = "suspicious", key = "AEBS_rand_pre_1" },
    { en = "expecting ", key = "AEBS_weather_predicted" },
    { en = "North-East", key = "AEBS_zone_name_ne" },
    { en = "North-West", key = "AEBS_zone_name_nw" },
    { en = "South-East", key = "AEBS_zone_name_se" },
    { en = "South-West", key = "AEBS_zone_name_sw" },
    { en = "Tomorrow,", key = "AEBS_Pre_tomorrow" },
    { en = "anomalous", key = "AEBS_rand_pre_0" },
    { en = "afternoon", key = "AEBS_segment_afternoon" },
    { en = "friendly", key = "AEBS_rand_pre_10" },
    { en = "survivor", key = "AEBS_rand_pre_7" },
    { en = "airborne", key = "AEBS_rand_pre_9" },
    { en = "blizzard", key = "AEBS_weather_blizzard" },
    { en = "Blizzard", key = "AEBS_weather_blizzard_C" },
    { en = "Moderate", key = "AEBS_wind_2" },
    { en = "unknown", key = "AEBS_rand_pre_11" },
    { en = "neutral", key = "AEBS_rand_pre_12" },
    { en = "hostile", key = "AEBS_rand_pre_2" },
    { en = "class 5", key = "AEBS_rand_pre_4" },
    { en = "class 4", key = "AEBS_rand_pre_5" },
    { en = "class 3", key = "AEBS_rand_pre_6" },
    { en = "vehicle", key = "AEBS_rand_pre_8" },
    { en = "evening", key = "AEBS_segment_evening" },
    { en = "morning", key = "AEBS_segment_morning" },
    { en = "Central", key = "AEBS_zone_name_c" },
    { en = "Today,", key = "AEBS_Pre_today" },
    { en = "and a ", key = "AEBS_weather_and_a" },
    { en = "Strong", key = "AEBS_wind_3" },
    { en = "night", key = "AEBS_segment_night" },
    { en = "North", key = "AEBS_zone_name_n" },
    { en = "South", key = "AEBS_zone_name_s" },
    { en = "Mild", key = "AEBS_wind_1" },
    { en = "East", key = "AEBS_zone_name_e" },
    { en = "West", key = "AEBS_zone_name_w" },
    { en = "KpH", key = "AEBS_KpH" },
    { en = "MpH", key = "AEBS_MpH" },
}

-- WeatherChannel.Init() 把 activity 表換成 key 字面，AEBS_random_3 未經
-- getText 就塞進 %1，成品因此含裸 key（vanilla 各語言皆然）——認出後補譯。
AEBSFlx.BARE_KEYS = {
    ["AEBS_rand_pre_0"] = true,
    ["AEBS_rand_pre_1"] = true,
    ["AEBS_rand_pre_2"] = true,
    ["AEBS_rand_pre_4"] = true,
    ["AEBS_rand_pre_5"] = true,
    ["AEBS_rand_pre_6"] = true,
    ["AEBS_rand_pre_7"] = true,
    ["AEBS_rand_pre_8"] = true,
    ["AEBS_rand_pre_9"] = true,
    ["AEBS_rand_pre_10"] = true,
    ["AEBS_rand_pre_11"] = true,
    ["AEBS_rand_pre_12"] = true,
}
-- <AUTO-GEN:AEBS_MAP END>

-- 反解模板參數：greedy 由左至右吃掉最長的已知片語，其餘（數值等）原樣保留。
-- 只作用於模板捕獲到的參數，不掃整行，避免誤傷其他電台台詞。
function AEBSFlx.translateSegment(s)
    if not s or s == "" then
        return s
    end

    if AEBSFlx.BARE_KEYS[s] then
        return getText(s)
    end

    local out = ""
    local rest = s
    while #rest > 0 do
        local hit = nil
        for _, phrase in ipairs(AEBSFlx.PHRASES) do
            if rest:sub(1, #phrase.en) == phrase.en then
                hit = phrase
                break
            end
        end
        if hit then
            out = out .. getText(hit.key)
            rest = rest:sub(#hit.en + 1)
        else
            out = out .. rest:sub(1, 1)
            rest = rest:sub(2)
        end
    end
    return out
end

-- 反解單行本體（不含行首前綴）。先求整行精確匹配，失敗才退到開放式前段。
local function restoreBody(text)
    -- 1) 整行即單一 key：模板（含參數）或固定片語
    for _, template in ipairs(AEBSFlx.TEMPLATES) do
        local captures = { text:match(template.pat) }
        if captures[1] ~= nil then
            for i = 1, template.n do
                captures[i] = AEBSFlx.translateSegment(captures[i])
            end
            -- 參數個數必須與 key 完全相符，否則 Translator 會逐次刷 Missing arguments 警告
            return getText(template.key, unpack(captures, 1, template.n))
        end
    end

    local phraseKey = AEBSFlx.PHRASE_KEY[text]
    if phraseKey then
        return getText(phraseKey)
    end

    -- 2) GetForecastString 的 type 4/5：weather_0_a/b/c 之後直接串接天氣後綴
    --    （weather_predicted＋災害名／light_moderate／and_a／snowfall，vanilla 不加分隔），
    --    整行不等於任何單一 key，故以不錨定行尾的 pattern 取前段、剩餘交給 greedy。
    for _, template in ipairs(AEBSFlx.OPEN_TEMPLATES) do
        local found = { text:find(template.pat) }
        if found[1] == 1 then
            local head
            if template.n > 0 then
                local captures = {}
                for i = 1, template.n do
                    captures[i] = AEBSFlx.translateSegment(found[2 + i])
                end
                head = getText(template.key, unpack(captures, 1, template.n))
            else
                head = getText(template.key)
            end
            return head .. AEBSFlx.translateSegment(text:sub(found[2] + 1))
        end
    end

    return nil
end

-- 回傳反解後的譯文；非 AEBS 文字回傳 nil（呼叫端據此決定是否覆寫）。
function AEBSFlx.restore(line)
    if not line or line == "" then
        return nil
    end

    -- AddForecast 是 prefix .. GetForecastString(1)，而後者開頭固定帶一個空格，
    -- 故先剝離前綴與其後的空白，重組時原樣接回，保持與中文 server 相同的輸出。
    local prefixKey = nil
    local body = line
    for _, prefix in ipairs(AEBSFlx.PREFIXES) do
        if body:sub(1, #prefix.en) == prefix.en then
            prefixKey = prefix.key
            body = body:sub(#prefix.en + 1)
            break
        end
    end

    local lead = body:match("^ *") or ""
    local out = restoreBody(body:sub(#lead + 1))
    if not out then
        return nil
    end

    if prefixKey then
        return getText(prefixKey) .. lead .. out
    end
    return lead .. out
end

-- 只處理電台訊息：ChatMessage.radioChannel 預設 -1，僅 ChatManager.showRadioMessage
-- 與 RadioChat 會設值，故此閘門可擋掉一般聊天／喊話，避免整行全等表誤改玩家發言。
local function isRadioMessage(message)
    local ok, channel = pcall(function() return message:getRadioChannel() end)
    return ok and type(channel) == "number" and channel > 0
end

if AEBSFlx._patchedVersion ~= AEBSFlx.PATCH_VERSION then
    AEBSFlx._patchedVersion = AEBSFlx.PATCH_VERSION
    local original = ISChat.addLineInChat
    ISChat.addLineInChat = function(message, tabID)
        if message and isRadioMessage(message) then
            local ok, text = pcall(function() return message:getText() end)
            if ok and text then
                local fixed = AEBSFlx.restore(text)
                if fixed and fixed ~= text then
                    message:setText(fixed)
                end
            end
        end
        return original(message, tabID)
    end
end
