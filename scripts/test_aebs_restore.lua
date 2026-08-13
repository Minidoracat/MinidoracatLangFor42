-- 測試 AEBSWeather_Flx.lua 的 AEBS 天氣播報反解
-- 執行：lua scripts/test_aebs_restore.lua（須在 repo 根目錄，dofile 走相對路徑）
--
-- 修復目標：AEBS 天氣播報由 server 端 ISWeatherChannel.lua 以 getText() 組成成品
--   字串後直接送給 client（guid 為 null，無法反查 key），英文 server 對中文 client
--   必然送英文字幕。本檔驗證 client 端能把成品字串反解回 key 並以當前語言重組。
--
-- 重點驗證：
--   (a) 截圖回報的三行（fog / 前綴+溫度 / 風向+雲量）能正確還原
--   (b) getText 參數個數必須與模板佔位符完全相符——參數不符會讓 Translator 每次
--       呼叫都噴 "Missing arguments"，正是 DynamicItemName 踩過的警告洪水坑
--   (c) 非 AEBS 文字一律回傳 nil，不得誤改其他電台台詞
--   (d) vanilla 以裸字串呼叫 getText 的兩處缺陷（zone 小寫、activity）有被補上

unpack = unpack or table.unpack

-- ============ PZ global stubs（模擬 CH client） ============
-- 譯文取自 MOD CH/DynamicRadio.json；佔位符維持 JSON 原形，由 stub 自行格式化
local FAKE = {
    AEBS_Pre_today = "今天, ",
    AEBS_Pre_tomorrow = "明天, ",
    AEBS_temperature = "平均氣溫 %1. 最低: %2. 最高: %3. 溼度: %4%%…",
    AEBS_wind_0 = "預計有 %1, 風向為 %2. 最大風力 %3. %4",
    AEBS_wind_1 = "輕風",
    AEBS_wind_3 = "強風",
    AEBS_zone_name_ne = "東北方",
    AEBS_zone_name_sw = "西南方",
    AEBS_MpH = "英里/小時",
    AEBS_clouds_0 = "晴天.",
    AEBS_clouds_3 = "晴時多雲.",
    AEBS_clouds_4 = "陰時多雲.",
    AEBS_fog_0 = "輕霧.",
    AEBS_fog_2 = "濃霧.",
    AEBS_Intro = "<噗滋> 五零二. <嗚滋>自動廣播系統. <噗滋>",
    AEBS_Power_3 = "諾克斯電網: 供電中斷.",
    AEBS_random_0 = "全體人員. %1 隔離區的臨時通訊發生故障…扇區 %2, %3, %4 和 %5",
    AEBS_random_1 = "C<滋>I - A小隊, <噗滋>指定區域<噗滋>扇區 %1<嗚滋>",
    AEBS_random_2 = "全體人員<噗滋>命令<滋> %1 已下達<嗚滋>",
    AEBS_random_3 = "…%1 <滋>扇區 %2 發生活動<嗚滋>",
    AEBS_rand_pre_0 = "異常的",
    AEBS_weather_warning = "惡劣天氣警報. %1即將到來. 預計 %2 天後抵達…",
    AEBS_weather_storm_C = "雷暴",
    AEBS_segment_morning = "上午",
    AEBS_segment_evening = "傍晚",
    AEBS_segment_night = "夜間",
    AEBS_weather_0_a = "警報: 預測的天氣將於 %1 開始…",
    AEBS_weather_0_b = "天氣將會持續一整天…",
    AEBS_weather_0_c = "預測的天氣將在 %1 結束…",
    AEBS_weather_predicted = "預期出現",
    AEBS_weather_and_a = "同時伴有",
    AEBS_weather_light_moderate = "預計有小到中雨…",
    AEBS_weather_heavy_rain = "陣雨或大雨",
    AEBS_weather_storm = "雷暴",
    AEBS_weather_snowfall = "有機率降雪.",
}

local warnings = {}

-- 模擬 Translator.getText：查無 key 回傳 key 本身；參數個數不符時記錄警告
function getText(key, ...)
    local args = { ... }
    local value = FAKE[key]
    if not value then
        return key
    end

    local maxSlot = 0
    for digit in value:gmatch("%%(%d)") do
        local n = tonumber(digit)
        if n > maxSlot then
            maxSlot = n
        end
    end
    if #args ~= maxSlot then
        table.insert(warnings, string.format("%s 期望 %d 個參數，實得 %d 個", key, maxSlot, #args))
    end

    local out = value
    for i = 1, maxSlot do
        out = out:gsub("%%" .. i, (tostring(args[i] or ""):gsub("%%", "%%%%")))
    end
    return (out:gsub("%%%%", "%%"))
end

-- ISChat stub：記錄原函式是否收到（可能已被改寫的）message
ISChat = {}
local received = nil
ISChat.addLineInChat = function(message, tabID)
    received = { text = message:getText(), tab = tabID }
end
local vanillaAddLine = ISChat.addLineInChat

-- radioChannel 預設 -1（ChatMessage.java:23），僅電台訊息會被設值
local function newMessage(text, channel)
    local self = { _text = text, _channel = channel or -1 }
    function self:getText() return self._text end
    function self:setText(v) self._text = v end
    function self:getRadioChannel() return self._channel end
    return self
end

dofile("MOD/MinidoracatLangFor42/Contents/mods/MinidoracatLangFor42/42/media/lua/client/Chat/AEBSWeather_Flx.lua")

-- ============ 測試框架 ============
local failed = 0
local passed = 0

local function check(label, actual, expected)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("FAIL %s\n  期望: %s\n  實得: %s", label, tostring(expected), tostring(actual)))
    end
end

-- ============ (a) 玩家回報的三行 ============
check(
    "fog 單句",
    AEBSFlx.restore("Light fog."),
    "輕霧."
)
check(
    "前綴＋溫度（%% 還原成單一 %）",
    AEBSFlx.restore("Tomorrow, average temperature 58.3 °F. Minimum: 49.5 °F. Maximum: 67.7 °F. Humidity: 27%..."),
    "明天,  平均氣溫 58.3 °F. 最低: 49.5 °F. 最高: 67.7 °F. 溼度: 27%…"
)
check(
    "風向＋風速單位＋雲量兩句串接",
    AEBSFlx.restore("Mild wind from the North-East. Maximum of 25.09MpH expected. Clear skies. Periodical cloudy spells."),
    "預計有 輕風, 風向為 東北方. 最大風力 25.09英里/小時. 晴天. 晴時多雲."
)

-- ============ 其他組合 ============
check(
    "今天前綴",
    AEBSFlx.restore("Today, average temperature 10 °C. Minimum: 5 °C. Maximum: 15 °C. Humidity: 80%..."),
    "今天,  平均氣溫 10 °C. 最低: 5 °C. 最高: 15 °C. 溼度: 80%…"
)
check(
    "無前綴的風向行＋雲量單句",
    AEBSFlx.restore("Strong wind from the South-West. Maximum of 40.5MpH expected. Periods of heavy cloud."),
    "預計有 強風, 風向為 西南方. 最大風力 40.5英里/小時. 陰時多雲."
)
check(
    "整行全等片語（Intro）",
    AEBSFlx.restore("<bzzt> Fiver Zero Two. <wzzt> Automated Broadcast System. <bzzt>"),
    "<噗滋> 五零二. <嗚滋>自動廣播系統. <噗滋>"
)
check(
    "極端天氣警告（2 參數，數值原樣保留）",
    AEBSFlx.restore("Severe Weather Warning. Thunderstorm Imminent. ETA 3 days..."),
    "惡劣天氣警報. 雷暴即將到來. 預計 3 天後抵達…"
)
check(
    "天氣期間起始（參數為時段詞）",
    AEBSFlx.restore("WARNING: Period of weather predicted to start in the morning..."),
    "警報: 預測的天氣將於 上午 開始…"
)

-- GetForecastString type 4/5 會在 weather_0_a/b/c 之後直接串接後綴，
-- 整行不等於任何單一 key——$ 錨定的模板永遠匹配不到，須走開放式前段 + 剩餘 greedy
check(
    "天氣期間＋單一災害後綴（開放式續接）",
    AEBSFlx.restore("WARNING: Period of weather predicted to start in the morning...expecting thunderstorm"),
    "警報: 預測的天氣將於 上午 開始…預期出現雷暴"
)
check(
    "天氣期間＋無災害時的小到中雨後綴",
    AEBSFlx.restore("WARNING: Period of weather predicted to start in the evening...expecting light to moderate rain..."),
    "警報: 預測的天氣將於 傍晚 開始…預計有小到中雨…"
)
check(
    "天氣持續整天（無參數前段）＋降雪後綴",
    AEBSFlx.restore("Weather continues throughout the day...expecting light to moderate rain...with a chance of snowfall."),
    "天氣將會持續一整天…預計有小到中雨…有機率降雪."
)
-- 多災害串接的收尾 "..." 是 vanilla 直接寫死的半形三點（非翻譯鍵），原樣保留才正確
check(
    "天氣期間結束（帶參數前段）＋多災害後綴",
    AEBSFlx.restore("Weather period predicted to end in the night...expecting showers and or heavy rain, and a thunderstorm..."),
    "預測的天氣將在 夜間 結束…預期出現陣雨或大雨, 同時伴有雷暴..."
)

-- ============ (d) vanilla 裸字串缺陷補正 ============
-- Init() 之後 zones[i].name 是 key，但 random_0 那側有 getText(zone.name)，
-- 故成品帶的是 server 語言的譯文（"South-West"），走一般片語表
check(
    "random_0 的方位參數（server 已 getText，成品為英文譯文）",
    AEBSFlx.restore("All personnel. Temporary communications failure for South-West exclusion zone... sectors 1, 3, 6 and 7"),
    "全體人員. 西南方 隔離區的臨時通訊發生故障…扇區 1, 3, 6 和 7"
)
-- 對照組：Init() 之後 activity[i] 是 key 字面，且 random_3 未經 getText 直接塞進 %1，
-- 成品因此含裸 key（vanilla 各語言皆然）——反解須認出 key 本身並補譯
check(
    "random_3 的 activity 裸 key 補譯",
    AEBSFlx.restore("...AEBS_rand_pre_0 <fzzt> activity in sector 12 <wzzt>"),
    "…異常的 <滋>扇區 12 發生活動<嗚滋>"
)

-- ============ (c) 不得誤傷 ============
check("非 AEBS：一般台詞", AEBSFlx.restore("This is Triple-N news."), nil)
check("非 AEBS：空字串", AEBSFlx.restore(""), nil)
check("非 AEBS：nil", AEBSFlx.restore(nil), nil)
check("非 AEBS：雜訊", AEBSFlx.restore("~"), nil)
check("已是中文不再處理", AEBSFlx.restore("輕霧."), nil)

-- 其餘兩個帶參數的 random 模板（湊齊 10 個模板全覆蓋）
check(
    "random_1（單一數字參數）",
    AEBSFlx.restore("charlie <fzzt> india - alpha, <bzzt> designated zone <bzzt> sector 24 <wzzt>"),
    "C<滋>I - A小隊, <噗滋>指定區域<噗滋>扇區 24<嗚滋>"
)
check(
    "random_2（單一數字參數）",
    AEBSFlx.restore("All personnel <bzzt> order <fzzt> 617 has been issued<wzzt>"),
    "全體人員<噗滋>命令<滋> 617 已下達<嗚滋>"
)

-- ============ 短詞不得整行匹配（否則玩家聊天會被改） ============
-- "North"／"Mild"／"unknown"／"morning" 等只出現在模板參數或天氣後綴，
-- 絕不會由 AddRadioLine 單獨送出一行，故整行全等表不得收錄
for _, word in ipairs({ "North", "East", "West", "South", "Mild", "Strong", "Moderate",
                        "unknown", "neutral", "hostile", "vehicle", "morning", "evening",
                        "night", "blizzard", "thunderstorm", "class 5", "expecting ",
                        "and a ", "MpH", "KpH", "Central", "North-East" }) do
    check("短詞不整行匹配：" .. word, AEBSFlx.restore(word), nil)
end

-- ============ wrapper 行為 ============
local msg = newMessage("Light fog.", 97600)
ISChat.addLineInChat(msg, 1)
check("wrapper 改寫電台訊息", msg:getText(), "輕霧.")
check("wrapper 有轉呼原函式", received and received.text, "輕霧.")
check("wrapper 有傳遞 tabID", received and received.tab, 1)

local untouched = newMessage("Hello survivors.", 97600)
ISChat.addLineInChat(untouched, 2)
check("wrapper 不動非 AEBS 電台訊息", untouched:getText(), "Hello survivors.")

-- 一般聊天 radioChannel 為 -1，即使內容剛好命中整行表也不得改寫
local playerChat = newMessage("Light fog.")
ISChat.addLineInChat(playerChat, 3)
check("wrapper 不碰一般聊天（radioChannel = -1）", playerChat:getText(), "Light fog.")

if ISChat.addLineInChat == vanillaAddLine then
    failed = failed + 1
    print("FAIL 未覆寫 ISChat.addLineInChat")
else
    passed = passed + 1
end

-- ============ (b) 參數個數 ============
if #warnings > 0 then
    failed = failed + #warnings
    print("FAIL Translator 參數個數不符（會造成 Missing arguments 警告洪水）：")
    for _, warning in ipairs(warnings) do
        print("  - " .. warning)
    end
else
    passed = passed + 1
end

print(string.format("\n通過 %d 項，失敗 %d 項", passed, failed))
os.exit(failed == 0 and 0 or 1)
