-- RadioLine_Flx／AEBSWeather_Flx 回歸：專用伺服器把電台／電視台詞改送 key，由各 client 用自己的語言播出。
-- 以逐字移植自 42.21 反編譯的假 Java 電台驅動（RadioLine、RadioBroadCast 含前後廣告片段與停頓 "~"、
-- RadioChannel.update），逐行對照「原版 SendTransmission 會送出的內容」：
--   已知台詞：伺服器自己的裝置收到原樣內容，client 收到本機譯文，顏色、效果碼、電視旗標不變；
--   未知台詞：原樣交回 SendTransmission。
-- AEBS 另驗：英文伺服器組、EN／CH／CN client 解，逐行等於該語言伺服器直接組出的句子；播放節奏同原版。
-- 用法：在 repo 根目錄執行 `lua scripts/test_radio_lines.lua`。需要原版檔（PZ_PATH 可覆蓋），找不到時 exit 2。
unpack = unpack or table.unpack
local PZ = os.getenv("PZ_PATH") or "D:/SteamLibrary/steamapps/common/ProjectZomboid"
local VANILLA = PZ .. "/media/lua/server/radio/ISWeatherChannel.lua"
local EN_DIR = PZ .. "/media/lua/shared/Translate/EN/"
local MOD = "MOD/MinidoracatLangFor42/Contents/mods/MinidoracatLangFor42/42/"
local SHARED = MOD .. "media/lua/shared/"
local OPEN, CLOSE = string.char(1), string.char(3)

local function loadDict(d, path)
    local f = io.open(path, "r")
    if not f then return nil end
    for line in f:lines() do
        local k, v = line:match('^%s*"([^"]+)"%s*:%s*"(.*)",?%s*$')
        if k then
            v = v:gsub('\\"', '"')
            if v:find("\\", 1, true) then error(path .. ": unsupported JSON escape (" .. k .. ")") end
            d[k] = v
        end
    end
    f:close()
    return d
end

local function dictOf(lang)
    local d = {}
    local files = { EN_DIR .. "DynamicRadio.json", EN_DIR .. "RadioData.json" } -- Translator 缺鍵退回 EN
    if lang ~= "EN" then
        files[3] = SHARED .. "Translate/" .. lang .. "/DynamicRadio.json"
        files[4] = SHARED .. "Translate/" .. lang .. "/RadioData.json"
    end
    for _, path in ipairs(files) do
        if not loadDict(d, path) then return nil end
    end
    return d
end

local DICT = { EN = dictOf("EN"), CH = dictOf("CH"), CN = dictOf("CN") }
if not DICT.EN or not io.open(VANILLA, "r") then
    print("vanilla ISWeatherChannel.lua / EN translations not found; set PZ_PATH")
    os.exit(2)
end

-- Translator.getText：%N 代入（fixupArgs：nil 印空字串、整數 double 印整數）、%% 印 %；缺鍵回傳鍵
local dict = DICT.EN
local function javaText(key, ...)
    local n, args = select("#", ...), { ... }
    for i = 1, n do
        local v = args[i]
        args[i] = v == nil and "" or (type(v) == "number" and v == math.floor(v)) and string.format("%d", v) or tostring(v)
    end
    return ((dict[key] or key):gsub("%%(.)", function(c)
        if c == "%" then return "%" end
        local i = tonumber(c)
        if i then
            if i > n then error("missing argument %" .. c .. " for " .. key) end
            return args[i]
        end
    end))
end
getText = javaText

-- ---------------------------------------------------------------- 假 Java（42.21 反編譯逐字移植）

local function jlist(t) return { size = function() return #t end, get = function(_, i) return t[i + 1] end } end

local Line = {}
Line.__index = Line
RadioLine = { new = function(text, r, g, b, fx)
    return setmetatable({ text = text or "<!text missing!>", r = r, g = g, b = b, fx = fx or "", air = -1 }, Line)
end }
function Line:getText() return self.text end
function Line:setText(t) self.text = t end
function Line:getR() return self.r end
function Line:getG() return self.g end
function Line:getB() return self.b end
function Line:getEffectsString() return self.fx end
function Line:isCustomAirTime() return self.air > 0 end
function Line:getAirTime() return self.air end
function Line:setAirTime(v) self.air = v end

local PAUSE = RadioLine.new("~", 0.5, 0.5, 0.5) -- RadioBroadCast.pauseLine
local Bc = {}
Bc.__index = Bc
RadioBroadCast = { new = function(id) return setmetatable({ id = id, lines = {}, count = 0 }, Bc) end }
function Bc:AddRadioLine(l) if l then self.lines[#self.lines + 1] = l end end
function Bc:getLines() return jlist(self.lines) end
function Bc:getCurrentLineNumber() return self.count end
function Bc:setPreSegment(b) self.pre = b end
function Bc:setPostSegment(b) self.post = b end
function Bc:resetLineCounter() -- 只歸零行號（含前後片段），hasDonePreSegment 不重設，同 Java
    self.count = 0
    for _, seg in ipairs({ self.pre or {}, self.post or {} }) do seg.count = 0 end
end
function Bc:getNextLine()
    if not self.donePre and self.count == 0 and self.pre then
        local r = self.pre:getNextLine()
        if r then return r end
        self.donePre = true
        return PAUSE
    end
    local r = self.count < #self.lines and self.lines[self.count + 1] or nil
    if r or not self.post then
        self.count = self.count + 1
        return r
    elseif not self.donePostPause then
        self.donePostPause = true
        return PAUSE
    end
    return self.post:getNextLine()
end

local RADIO = { disabled = false }
local GT
local Ch = {}
Ch.__index = Ch
local function channel(freq, tv, scripted)
    return setmetatable({ freq = freq, tv = tv, scripted = scripted, counter = 0, last = "", mult = 1 }, Ch)
end
function Ch:GetFrequency() return self.freq end
function Ch:IsTv() return self.tv end
function Ch:getRadioData() return self.scripted and {} or nil end
function Ch:getAiringBroadcast() return self.airing end
function Ch:setAiringBroadcast(bc) self.airing = bc end
function Ch:getLastAiredLine() return self.last end
function Ch:getAirCounterMultiplier() return self.mult end
function Ch:update() -- RadioChannel.update()
    if not self.airing then return end
    self.counter = self.counter - 1.25 * GT:getMultiplier()
    if self.counter >= 0 then return end
    local line = self.airing:getNextLine()
    if not line then
        self.airing = nil
        return
    end
    self.last = line:getText()
    if not RADIO.disabled then
        RADIO:SendTransmission(0, 0, self.freq, line:getText(), nil, line:getEffectsString(), line:getR(), line:getG(), line:getB(), -1, self.tv)
    end
    if line:isCustomAirTime() then
        self.counter = line:getAirTime() * 60
    else
        self.counter = math.min(math.max(#line:getText() / 10 * 60, 90), 300) * self.mult
    end
end

local CHANNELS = {}
local SM = { getChannelsList = function() return jlist(CHANNELS) end }
local out, heard, side, now = {}, {}, "server", 0
local function rec(kind, freq, text, guid, codes, r, g, b, strength, tv, x, y)
    return { kind = kind, tick = now, freq = freq, text = text, guid = guid, codes = codes, r = r, g = g, b = b, strength = strength, tv = tv, x = x, y = y }
end
function RADIO:setDisableBroadcasting(b) self.disabled = b end
function RADIO:scrambleString(text, n, ignoreBB) return "~" .. n .. (ignoreBB and "b~" or "~") .. text end
function RADIO:SendTransmission(x, y, freq, text, guid, codes, r, g, b, strength, tv)
    out[#out + 1] = rec("send", freq, text, guid, codes, r, g, b, strength, tv, x, y)
end
function RADIO:DistributeTransmission(x, y, freq, text, guid, codes, r, g, b, strength, tv)
    local list = side == "server" and out or heard
    list[#list + 1] = rec(side == "server" and "local" or "heard", freq, text, guid, codes, r, g, b, strength, tv, x, y)
end
function getZomboidRadio() return RADIO end
function sendServerCommand(module, command, args) out[#out + 1] = { kind = "cmd", tick = now, module = module, command = command, args = args } end
function getModFileReader(_, path)
    local f = io.open(MOD .. path, "r")
    if not f then return nil end
    return { readLine = function() return f:read("l") end, close = function() f:close() end }
end

-- ---------------------------------------------------------------- 原版天氣播報需要的世界

local seed = 1
function ZombRand(a, b)
    if not b then a, b = 0, a end
    seed = (seed * 1103515245 + 12345) % 2147483648
    return b <= a and a or a + seed % (b - a)
end
local function values(mean, min, max)
    return { getTotalMean = function() return mean end, getTotalMin = function() return min end, getTotalMax = function() return max end }
end
local function forecast(s)
    local f = {
        getTemperature = function() return values(s.t, s.t - 6.26, s.t + 6.6) end,
        getHumidity = function() return values(s.h) end,
        getWindPower = function() return values(s.w, 0, s.w + 0.13) end,
        getMeanWindAngleString = function() return s.dir end,
        getCloudiness = function() return values(s.c1, 0, s.c2) end,
        isHasFog = function() return s.fog ~= nil end,
        getFogStrength = function() return s.fog end,
        getWeatherStartTime = function() return s.start end,
        getWeatherEndTime = function() return s.stop end,
    }
    for name, field in pairs({ isWeatherStarts = "start", getWeatherOverlap = "stop", isHasHeavyRain = "rain", isHasStorm = "storm",
        isHasTropicalStorm = "tropical", isHasBlizzard = "blizzard", isChanceOnSnow = "snow" }) do
        f[name] = function() return s[field] ~= nil end
    end
    return f
end
local calm = forecast({ t = 18, h = 0.4, w = 0.1, dir = "S", c1 = 0.1, c2 = 0.2 })
local FORECASTS = {
    [0] = forecast({ t = 21.3, h = 0.634, w = 0.3, dir = "NE", c1 = 0.5, c2 = 0.8, fog = 1, start = 6, rain = 1, storm = 1, snow = 1 }),
    [1] = forecast({ t = -3.25, h = 0.9, w = 0.8, dir = "SW", c1 = 0.2, c2 = 0.5, fog = 0.8, stop = 23 }),
    [2] = forecast({ t = 10, h = 0.5, w = 0.6, dir = "N", c1 = 0.9, c2 = 0.95, fog = 0.3, stop = 15, rain = 1, tropical = 1, blizzard = 1 }),
    [7] = forecast({ t = 1, h = 0.7, w = 0.9, dir = "W", c1 = 0.8, c2 = 0.9, blizzard = 1 }),
}
local forecaster = { getForecast = function(_, i) return FORECASTS[i or 0] or calm end }
local interference = 0
function getClimateManager()
    return { getClimateForecaster = function() return forecaster end, getWeatherInterference = function() return interference end }
end
Temperature = { getTemperatureString = function(v) return string.format("%.1f C", v) end }
ClimateManager = { ToKph = function(v) return v * 100 end, ToMph = function(v) return v * 62 end }
local celsius = true
function getCore() return { getOptionDisplayAsCelsius = function() return celsius end } end
GT = {
    getHour = function() return 9 end, getNightsSurvived = function() return 3 end, getHelicopterDay1 = function() return 3 end,
    getWorldAgeHours = function() return 324 end, getMultiplier = function() return 1 end,
}
function getGameTime() return GT end
function getSandboxOptions() return { getTimeSinceApo = function() return 1 end, getElecShutModifier = function() return 14 end } end
local handlers = {}
Events = setmetatable({}, { __index = function(t, name)
    local list = {}
    handlers[name] = list
    rawset(t, name, { Add = function(fn) list[#list + 1] = fn end })
    return t[name]
end })
DynamicRadio = { scripts = {} }
function isServer() return true end
local printed = {}
print = function(s) printed[#printed + 1] = tostring(s) end
local loaded = {}
function require(name)
    if not loaded[name] then
        loaded[name] = true
        dofile(SHARED .. name .. ".lua")
    end
end

-- ---------------------------------------------------------------- 載入（同遊戲：shared 早於 server 檔的事件順序不影響結果）

dofile(VANILLA)
require("AEBSWeather_Flx") -- 內含 require "RadioLine_Flx"
require("RadioData_Flx")

local fails = 0
local function check(name, cond, detail)
    if cond then return end
    fails = fails + 1
    io.stdout:write("FAIL " .. name .. (detail and ("\n  " .. detail) or "") .. "\n")
end

-- 跑到所有頻道播完；每個 tick 先 Java update 再 OnTick，同 IngameState
local function run(maxTicks)
    for _ = 1, maxTicks or 20000 do
        now = now + 1
        dict, side = DICT.EN, "server"
        local busy = false
        for _, ch in ipairs(CHANNELS) do
            ch:update()
            busy = busy or ch.airing ~= nil
        end
        for _, fn in ipairs(handlers.OnTick or {}) do fn() end
        if not busy then return end
    end
end
local function deliver(lang, from)
    dict, side, heard = DICT[lang], "client", {}
    for i = from or 1, #out do
        local r = out[i]
        if r.kind == "cmd" then handlers.OnServerCommand[1](r.module, r.command, r.args) end
    end
    dict, side = DICT.EN, "server"
    return heard
end

-- ---------------------------------------------------------------- 節目內容

-- 挑英文原文獨一無二、各語言都有譯文的台詞，期望值才不受重複原文影響
local enCount = {}
for k, v in pairs(DICT.EN) do
    if k:sub(1, 3) == "RD_" then enCount[v] = (enCount[v] or 0) + 1 end
end
local function pick(keys, n, from)
    local list = {}
    for _, k in ipairs(keys) do
        local v = DICT.EN[k]
        if v and enCount[v] == 1 and #v > 12 and DICT.CH[k] ~= v and DICT.CN[k] ~= v then list[#list + 1] = k end
        if #list == n then break end
    end
    return list
end
local rdKeys = {}
for k in pairs(DICT.EN) do
    if k:sub(1, 3) == "RD_" and not RadioDataFlx.ADVERT_LINES[k] then rdKeys[#rdKeys + 1] = k end
end
table.sort(rdKeys)
local advertKeys = {}
for k in pairs(RadioDataFlx.ADVERT_LINES) do advertKeys[#advertKeys + 1] = k end
table.sort(advertKeys)
local K, A = pick(rdKeys, 7), pick(advertKeys, 4)
check("picked distinct translated lines", #K == 7 and #A == 4)
local RAW = "RD_mod-line-1" -- 伺服器缺 MOD 翻譯時的裸 key；只有 client 有譯文
DICT.CH[RAW], DICT.CN[RAW], DICT.EN[RAW] = "MOD CH", "MOD CN", nil

local expectKey = { [RAW] = RAW }
for _, k in ipairs(K) do expectKey[DICT.EN[k]] = k end
for _, k in ipairs(A) do expectKey[DICT.EN[k]] = k end

local function advert(keys)
    local seg = RadioBroadCast.new("AD")
    for _, k in ipairs(keys) do
        local s = RadioDataFlx.ADVERT_LINES[k]
        seg:AddRadioLine(RadioLine.new(DICT.EN[k], s.r / 255, s.g / 255, s.b / 255, s.codes))
    end
    return seg
end
local function stationShow()
    local bc = RadioBroadCast.new("BC-station")
    bc:AddRadioLine(RadioLine.new(DICT.EN[K[1]], 1, 1, 1))
    bc:AddRadioLine(RadioLine.new(DICT.EN[K[2]], 0.2, 0.6, 1, "BOR-1"))
    bc:AddRadioLine(RadioLine.new(DICT.EN[K[3]], 1, 0.8, 0))
    bc:AddRadioLine(RadioLine.new(DICT.EN[K[3]], 1, 0.8, 0)) -- 同一句連播兩次
    bc:AddRadioLine(RadioLine.new("An unknown mod line.", 0.3, 0.3, 0.3, "UNH-1"))
    bc:AddRadioLine(RadioLine.new(RAW, 1, 1, 1))
    bc:AddRadioLine(RadioLine.new(DICT.EN[K[4]], 1, 1, 1))
    bc:setPreSegment(advert({ A[1], A[2] }))
    bc:setPostSegment(advert({ A[3], A[4] }))
    return bc
end
local function tvShow()
    local bc = RadioBroadCast.new("BC-tv")
    bc:AddRadioLine(RadioLine.new(DICT.EN[K[5]], 1, 1, 1, "BOR-1,UNH-1"))
    bc:AddRadioLine(RadioLine.new(DICT.EN[K[6]], 0.5, 1, 0.5, "RCP=Make Butter Knife"))
    bc:AddRadioLine(RadioLine.new(DICT.EN[K[7]], 1, 1, 1))
    return bc
end

-- ---------------------------------------------------------------- 1. 原版送出序列（安裝前、未停用廣播）

local station, tv = channel(93200, false, true), channel(200, true, true)
CHANNELS = { station, tv }
station:setAiringBroadcast(stationShow())
tv:setAiringBroadcast(tvShow())
run()
local reference = {}
for _, r in ipairs(out) do
    reference[r.freq] = reference[r.freq] or {}
    table.insert(reference[r.freq], r)
end
check("reference aired pre/post adverts, pauses and every main line", #reference[93200] == 4 + 2 + 7 and #reference[200] == 3)

-- ---------------------------------------------------------------- 安裝（OnLoadRadioScripts）

local aebs = channel(91200, false, false) -- DynamicRadioChannel：沒有 RadioData
for _, fn in ipairs(handlers.OnLoadRadioScripts) do fn(SM, false) end
check("Java broadcasting disabled on the server", RADIO.disabled == true)
local keyed = 0
for _, s in ipairs(printed) do keyed = math.max(keyed, tonumber(s:match("%((%d+) RadioData lines keyed%)") or "0")) end
check("server keyed every RadioData line of its own language", keyed > 13000, "keyed " .. keyed)

-- 第一次看到的頻道只記狀態：開機時殘留的 lastAiredLine 不補送
local stale = channel(107600, false, true)
stale.last = DICT.EN[K[1]]
out = {}
station, tv = channel(93200, false, true), channel(200, true, true)
CHANNELS = { station, tv, aebs, stale }
run(1)
check("first sight of a channel sends nothing", #out == 0)

-- ---------------------------------------------------------------- 2. RadioData：逐行對照原版

local function same(a, b)
    return a.text == b.text and a.codes == b.codes and a.r == b.r and a.g == b.g and a.b == b.b and a.tv == b.tv
        and a.guid == nil and a.strength == -1 and a.x == 0 and a.y == 0
end
local function perLine(freq)
    local lines, i = {}, 1
    while i <= #out do
        local r = out[i]
        if r.kind == "send" and r.freq == freq then
            lines[#lines + 1] = { send = r }
        elseif r.kind == "local" and r.freq == freq then
            lines[#lines + 1] = { loc = r, cmd = out[i + 1] }
            i = i + 1
        end
        i = i + 1
    end
    return lines
end

station:setAiringBroadcast(stationShow())
tv:setAiringBroadcast(tvShow())
run()
for _, freq in ipairs({ 93200, 200 }) do
    local ours, ref = perLine(freq), reference[freq]
    check(freq .. ": one output per aired line", #ours == #ref, #ours .. " vs " .. #ref)
    for _, lang in ipairs({ "EN", "CH", "CN" }) do
        local got = {}
        for _, h in ipairs(deliver(lang)) do
            if h.freq == freq then got[#got + 1] = h end
        end
        local n = 0
        for i, r in ipairs(ref) do
            local o, key = ours[i] or {}, expectKey[r.text]
            local tag = freq .. " " .. lang .. " line " .. i
            if key then
                n = n + 1
                check(tag .. " server devices get the vanilla line", o.loc and same(o.loc, r))
                check(tag .. " clients get the key", o.cmd and o.cmd.kind == "cmd" and o.cmd.args.t == OPEN .. key .. CLOSE)
                local h = got[n] or {}
                local want = DICT[lang][key] or key
                check(tag .. " worded by the client", h.text == want, tostring(h.text) .. "\n  want " .. want)
                check(tag .. " keeps color, codes and TV flag", h.codes == r.codes and h.r == r.r and h.g == r.g and h.b == r.b
                    and h.tv == r.tv and h.guid == nil and h.strength == -1)
            else
                check(tag .. " unknown line goes back to SendTransmission unchanged", o.send and same(o.send, r))
            end
        end
        check(freq .. " " .. lang .. " clients heard every keyed line once", #got == n, #got .. " vs " .. n)
    end
end

-- ---------------------------------------------------------------- 3. 天氣干擾：強度由伺服器決定，電視不受影響

for _, case in ipairs({ { 0.5, 50, true }, { 1.0, 100, false } }) do
    interference = case[1]
    out = {}
    station:setAiringBroadcast((function()
        local bc = RadioBroadCast.new("noise")
        bc:AddRadioLine(RadioLine.new(DICT.EN[K[2]], 0.2, 0.6, 1, "BOR-1"))
        return bc
    end)())
    tv:setAiringBroadcast((function()
        local bc = RadioBroadCast.new("noise-tv")
        bc:AddRadioLine(RadioLine.new(DICT.EN[K[5]], 1, 1, 1, "BOR-1"))
        return bc
    end)())
    run()
    local s, t = perLine(93200)[1] or {}, perLine(200)[1] or {}
    local grey = case[3]
    local tag = "interference " .. case[2]
    check(tag .. " scrambles the server's copy", s.loc and s.loc.text == "~" .. case[2] .. "b~" .. DICT.EN[K[2]])
    check(tag .. " server copy color/codes", s.loc and (grey and (s.loc.r == 0.5 and s.loc.codes == "") or (s.loc.r == 0.2 and s.loc.codes == "BOR-1")))
    check(tag .. " sent to clients", s.cmd and s.cmd.args.n == case[2])
    local h = deliver("CH")
    local hs, ht
    for _, x in ipairs(h) do
        if x.freq == 93200 then hs = x else ht = x end
    end
    check(tag .. " client scrambles its own wording", hs and hs.text == "~" .. case[2] .. "b~" .. DICT.CH[K[2]])
    check(tag .. " client color/codes", hs and (grey and (hs.r == 0.5 and hs.codes == "") or (hs.r == 0.2 and hs.codes == "BOR-1")))
    check(tag .. " TV untouched", t.cmd and t.cmd.args.n == nil and ht and ht.text == DICT.CH[K[5]] and ht.codes == "BOR-1")
end
interference = 0

-- ---------------------------------------------------------------- 4. 同一個節目播完後重播（腳本循環）：從第一句重送，頭尾同一句也不漏

do
    out = {}
    local bc = RadioBroadCast.new("replay")
    for _, i in ipairs({ 1, 2, 1 }) do bc:AddRadioLine(RadioLine.new(DICT.EN[K[i]], 0.7, 0.7, 0.7, "BOR-1")) end
    station:setAiringBroadcast(bc)
    run()
    bc:resetLineCounter()
    station:setAiringBroadcast(bc)
    run()
    local lines = perLine(93200)
    check("replayed show is sent again from its first line", #lines == 6 and lines[4].cmd
        and lines[4].cmd.args.t == OPEN .. K[1] .. CLOSE and lines[4].cmd.args.c == "BOR-1")
end

-- ---------------------------------------------------------------- 5. AEBS：逐行等於該語言伺服器直接組出的句子

local function linesOf(bc)
    local list, res = bc:getLines(), {}
    for i = 0, list:size() - 1 do
        local l = list:get(i)
        res[#res + 1] = { text = l:getText(), r = l:getR(), g = l:getG(), b = l:getB() }
    end
    return res
end
local bareHits = 0
for _, lang in ipairs({ "EN", "CH", "CN" }) do
    for _, all in ipairs({ false, true }) do
        WeatherChannel.debugTestAll = all
        for s = 1, 40 do
            celsius = s % 2 == 0
            dict, seed = DICT[lang], s
            local want = linesOf(WeatherChannel.CreateBroadcast(GT))
            out, dict, seed = {}, DICT.EN, s
            WeatherChannel.OnEveryHour(aebs, GT, RADIO)
            run()
            -- client 看到的順序：原樣重送的行（"<bzzt>" 這類 Lua 字面）與改送 key 的行交錯
            local mine, got, ticks, j = {}, {}, {}, 0
            for _, h in ipairs(deliver(lang)) do
                if h.freq == 91200 then mine[#mine + 1] = h end
            end
            for _, r in ipairs(out) do
                if r.kind == "send" and r.freq == 91200 then
                    got[#got + 1], ticks[#ticks + 1] = r, r.tick
                elseif r.kind == "cmd" and r.args.f == 91200 then
                    j = j + 1
                    got[#got + 1], ticks[#ticks + 1] = mine[j] or {}, r.tick
                end
            end
            local tag = lang .. (all and " TestAll" or " Fill") .. " seed " .. s
            check(tag .. " line count", #got == #want, #got .. " vs " .. #want)
            for i, w in ipairs(want) do
                -- 唯一刻意的差異：AEBS_random_3 的 activity 原版印裸 key，這裡要翻好
                local text, hits = w.text:gsub("AEBS_rand_pre_%d+", function(k) return DICT[lang][k] end)
                bareHits = bareHits + hits
                local h = got[i] or {}
                check(tag .. " line " .. i, h.text == text, tostring(h.text) .. "\n  want " .. text)
                check(tag .. " color " .. i, h.r == w.r and h.g == w.g and h.b == w.b and h.codes == "" and h.tv == false)
                -- 節奏同原版：依英文原句長度 len/10*60 夾 [90, 300]；第一行在播出後的下一個 tick
                if lang == "EN" and i > 1 and ticks[i] then
                    local wait = math.floor(math.min(math.max(#got[i - 1].text / 10 * 60, 90), 300) / 1.25) + 1
                    check(tag .. " pace " .. i, ticks[i] - ticks[i - 1] == wait, (ticks[i] - ticks[i - 1]) .. " vs " .. wait)
                end
            end
        end
    end
end
WeatherChannel.debugTestAll = false
check("activity keys were exercised", bareHits > 0)

-- ---------------------------------------------------------------- 6. token 化失敗：還原 getText、改播原版播報

do
    local create = WeatherChannel.CreateBroadcast
    WeatherChannel.CreateBroadcast = function(gt)
        if getText ~= javaText then error("mod code that breaks on tokens") end
        return create(gt)
    end
    out, seed = {}, 7
    WeatherChannel.OnEveryHour(aebs, GT, RADIO)
    run()
    WeatherChannel.CreateBroadcast = create
    local sends, cmds = 0, 0
    for _, r in ipairs(out) do
        if r.freq == 91200 and r.kind == "send" then sends = sends + 1 end
        if r.kind == "cmd" then cmds = cmds + 1 end
    end
    check("getText restored after a failed capture", getText == javaText)
    check("vanilla broadcast replayed through SendTransmission", sends > 0 and out[1].text == DICT.EN.AEBS_Intro)
    check("nothing worded per client", cmds == 0)
end

io.stdout:write(fails == 0 and "PASS test_radio_lines\n" or (fails .. " failure(s)\n"))
os.exit(fails == 0 and 0 or 1)
