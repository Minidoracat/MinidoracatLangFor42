-- RadioLine_Flx.lua
-- 多人連線時，電台與電視的每一行依每個 client 自己的語言播出：收音機／電視上方字幕與聊天列都是。
--
-- 原版：專用伺服器用自己的語言組好每一行（RadioData.xml 的 RD_* 台詞在載入時就固化；AEBS 天氣播報每小時組句），
-- RadioChannel.update() 播出時 SendTransmission 把成品字串送給所有 client。混合語言的伺服器只能有一種語言，
-- 伺服器的 Translator 也不含 MOD 翻譯。
--
-- 本檔只改專用伺服器的流程（單機的 getText 本來就是本機語言，維持原版）：
-- 1. OnLoadRadioScripts 時 setDisableBroadcasting(true)：Java 照常排程、逐行推進，只是不送出
--    （全反編譯樹唯一的檢查點在 RadioChannel.update()）。
-- 2. OnTick（與 ZomboidRadio.update() 同在 IngameState 的 !paused 區塊、緊接在後）偵測每個頻道剛播出的那一行。
-- 3. 能翻譯的行改送 key：AEBS 本身就是 token；RadioData 台詞以伺服器語言原文反查 RD key。伺服器照
--    SendTransmission 先套天氣干擾，再對自己的裝置 DistributeTransmission（OnDeviceText 的無聊、配方等效果）。
--    其餘的行（其他 MOD 的頻道、未知廣告、停頓 "~"）原樣交回 SendTransmission，行為同原版。
-- client 用本機 getText 解開 key，套伺服器給的干擾強度，再呼叫原生 DistributeTransmission
-- （與 WaveSignalPacket.processClient 同一個呼叫）。收件人同原版：每一行送給所有連線（sendIsoWaveSignal 亦然）。

RadioLineFlx = RadioLineFlx or {}

local MODULE, COMMAND = "CatLangRadio", "line"
local OPEN, SEP, CLOSE = string.char(1), string.char(2), string.char(3)
local KEY_END = "[" .. SEP .. CLOSE .. "]"
local ANY_MARK = "[" .. OPEN .. SEP .. CLOSE .. "]"

-- getText 的替身：key 與參數原樣帶走，由各 client 翻譯。
-- AEBS_random_3 的 activity 在原版是裸 key（WeatherChannel.Init 換成 key 字面卻沒 getText），包成巢狀 token 一起翻譯。
function RadioLineFlx.token(key, ...)
    local out = { OPEN, tostring(key) }
    for i = 1, select("#", ...) do
        -- Kahlua 的 tostring 對整數 double 印整數，與 Translator.fixupArgs 相同
        local v = tostring((select(i, ...)))
        if v:match("^AEBS_rand_pre_%d+$") then
            v = OPEN .. v .. CLOSE
        end
        out[#out + 1] = SEP
        out[#out + 1] = v
    end
    out[#out + 1] = CLOSE
    return table.concat(out)
end

-- 用本機 getText 解開 token；參數先翻好再代入，與原版先 getText 內層再傳入相同。
function RadioLineFlx.resolve(s)
    local pos, len = 1, #s
    local function read(inArg)
        local out = {}
        while pos <= len do
            local c = s:sub(pos, pos)
            if c == OPEN then
                local stop = s:find(KEY_END, pos + 1) or (len + 1)
                local key, args = s:sub(pos + 1, stop - 1), {}
                pos = stop
                while s:sub(pos, pos) == SEP do
                    pos = pos + 1
                    args[#args + 1] = read(true)
                end
                pos = pos + 1
                out[#out + 1] = getText(key, unpack(args))
            elseif inArg and (c == SEP or c == CLOSE) then
                break
            else
                local stop = s:find(ANY_MARK, pos + 1) or (len + 1)
                out[#out + 1] = s:sub(pos, stop - 1)
                pos = stop
            end
        end
        return table.concat(out)
    end
    return read(false)
end

local resolve = RadioLineFlx.resolve

-- ---------------------------------------------------------------- server

local keyOf, styles, states = {}, {}, {}

-- 伺服器語言原文 -> RD key。RadioData.java 載入時以 Translator.getText("RD_" .. id) 固化台詞，這裡在同一個時點
-- 對每個 RD key 呼叫同一個 getText，所以不論伺服器是什麼語言都對得上。key 清單取自本包 CH/RadioData.json（與官方 EN 同一組）。
local function loadKeys()
    local reader = getModFileReader("CatLangFor42", "media/lua/shared/Translate/CH/RadioData.json", false)
    if not reader then return 0 end
    local n = 0
    local line = reader:readLine()
    while line do
        local key = line:match('^%s*"(RD_[^"]+)"')
        if key then
            local text = getText(key)
            if text ~= key and text ~= "" and text ~= "~" then
                keyOf[text] = key
                n = n + 1
            end
        end
        line = reader:readLine()
    end
    reader:close()
    return n
end

-- 送出一行。line 是 Java 那一行的 RadioLine（主線台詞才拿得到）；廣告片段在 private 欄位，改查產生的樣式表。
local function air(radio, ch, text, line)
    local token
    if text:find(OPEN, 1, true) then
        token = text
    elseif ch:getRadioData() then
        -- 只查 RadioData 頻道：AEBS 的 "<bzzt>" 是 Lua 字面，查到同字的 RD 台詞會被翻成 "<噗滋>"、不再算靜電聲。
        -- 伺服器缺 MOD 翻譯時 RadioData 台詞會是裸 RD key，client 有翻譯就能顯示
        local key = keyOf[text] or (text:match("^RD_[%w%-]+$") and text)
        if key then token = OPEN .. key .. CLOSE end
    end

    local r, g, b, codes
    if line then
        r, g, b, codes = line:getR(), line:getG(), line:getB(), line:getEffectsString()
    else
        local s = token and styles[token:sub(2, -2)]
        if s then
            r, g, b, codes = s.r / 255, s.g / 255, s.b / 255, s.codes or ""
        elseif text == "~" then
            r, g, b, codes = 0.5, 0.5, 0.5, "" -- RadioBroadCast.pauseLine
        else
            r, g, b, codes = 1, 1, 1, ""
        end
    end

    local freq, tv = ch:GetFrequency(), ch:IsTv()
    if not token then
        radio:SendTransmission(0, 0, freq, text, nil, codes, r, g, b, -1, tv)
        return
    end

    -- SendTransmission 的伺服器半邊：非電視先套天氣干擾（0 < 強度 < 100 才轉灰並清掉 codes），再對伺服器自己的裝置分發
    local noise = tv and 0 or math.floor(getClimateManager():getWeatherInterference() * 100)
    local localText, lr, lg, lb, lcodes = token == text and resolve(text) or text, r, g, b, codes
    if noise > 0 then
        localText = radio:scrambleString(localText, noise, true, nil)
        if noise < 100 then lr, lg, lb, lcodes = 0.5, 0.5, 0.5, "" end
    end
    radio:DistributeTransmission(0, 0, freq, localText, nil, lcodes, lr, lg, lb, -1, tv)

    sendServerCommand(MODULE, COMMAND, {
        f = freq, t = token, r = r, g = g, b = b,
        c = codes ~= "" and codes or nil, v = tv or nil, n = noise > 0 and noise or nil,
    })
end

-- 每個頻道每次 update 至多播一行。主線台詞看行號前進（同一句連播兩次也抓得到）；廣告片段與停頓只看
-- getLastAiredLine() 變了沒（行號不動）。第一次看到的頻道只記狀態，不補送。
local function detect(radio, ch)
    local bc = ch:getAiringBroadcast()
    local num = bc and bc:getCurrentLineNumber() or 0
    local last = ch:getLastAiredLine()
    local st = states[ch]
    if not st then
        states[ch] = { bc = bc, num = num, last = last }
        return
    end
    local line
    if bc and num > 0 and (bc ~= st.bc or num > st.num) then
        local lines = bc:getLines()
        if num <= lines:size() and lines:get(num - 1):getText() == last then
            line = lines:get(num - 1)
        end
    end
    if line or last ~= st.last then air(radio, ch, last, line) end
    st.bc, st.num, st.last = bc, num, last
end

local function install(scriptManager)
    local radio = getZomboidRadio()
    radio:setDisableBroadcasting(true)
    Events.OnTick.Add(function()
        local list = scriptManager:getChannelsList()
        for i = 0, list:size() - 1 do
            detect(radio, list:get(i))
        end
    end)
    RadioLineFlx.active = true
    styles = RadioDataFlx and RadioDataFlx.ADVERT_LINES or {}
    print(string.format("[CatLangFor42] [Radio] radio/TV lines worded by each client (%d RadioData lines keyed)", loadKeys()))
end

Events.OnLoadRadioScripts.Add(function(scriptManager)
    if isServer() then install(scriptManager) end
end)

-- ---------------------------------------------------------------- client

-- 原版在聊天還沒就緒時丟棄 WaveSignal（ChatManager.isWorking，Lua 看不到）；那段期間 radioChat 為 null、
-- 這裡會拋例外，同樣丟棄該行。
Events.OnServerCommand.Add(function(module, command, args)
    if module ~= MODULE or command ~= COMMAND then return end
    local radio = getZomboidRadio()
    local text, r, g, b, codes = resolve(args.t), args.r, args.g, args.b, args.c or ""
    if args.n then
        text = radio:scrambleString(text, args.n, true, nil)
        if args.n < 100 then r, g, b, codes = 0.5, 0.5, 0.5, "" end
    end
    local ok, err = pcall(function()
        radio:DistributeTransmission(0, 0, args.f, text, nil, codes, r, g, b, -1, args.v == true)
    end)
    if not ok then print("[CatLangFor42] [Radio] line dropped: " .. tostring(err)) end
end)
