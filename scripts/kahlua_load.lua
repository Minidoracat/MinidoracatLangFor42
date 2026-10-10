-- 以 Kahlua 編譯器的字串字面值行為載入 Lua 檔；harness 用 dofile("scripts/kahlua_load.lua")(path) 取代 dofile(path)。
-- Kahlua 的 LexState 逐 char 讀原始碼，save() 以 (byte)c 存進 token 緩衝（LexState.java:194-199），字串結束才用
-- UTF-8 解回（newstring，:245-247）：直接寫的非 ASCII 字只剩低位 byte，拿來比對永遠失敗；\ddd 跳脫本身是 ASCII，
-- 不受影響。標準 Lua 正確處理 UTF-8，直接 dofile 看不出這類失效（2026-10-11 以 projectzomboid.jar 的編譯器實測）。
-- 註解不經 save()，原樣保留；長字串（[[ ]]）也原樣保留，verify_mod 4b 已擋含非 ASCII 的長字串。

-- 一個 UTF-8 字 → Kahlua 存進緩衝的 byte（UTF-16 每個 char 取低位），寫成 \ddd 跳脫
local function truncate(ch)
    local cp = utf8.codepoint(ch)
    if cp < 0x80 then return ch end
    local units = cp < 0x10000 and { cp }
        or { 0xD800 + ((cp - 0x10000) >> 10), 0xDC00 + ((cp - 0x10000) & 0x3FF) }
    local out = {}
    for _, u in ipairs(units) do out[#out + 1] = string.format("\\%03d", u & 0xFF) end
    return table.concat(out)
end

local function kahluaSource(src)
    local out, i, n = {}, 1, #src
    while i <= n do
        local c = src:sub(i, i)
        local longEq = src:match("^%[(=*)%[", i)
        if c == "-" and src:sub(i + 1, i + 1) == "-" then
            local eq = src:match("^%[(=*)%[", i + 2)
            local stop = eq and select(2, src:find("]" .. eq .. "]", i + 2, true))
                or (src:find("\n", i, true) or n + 1) - 1
            out[#out + 1] = src:sub(i, stop)
            i = stop + 1
        elseif longEq then
            local stop = select(2, src:find("]" .. longEq .. "]", i, true))
            out[#out + 1] = src:sub(i, stop)
            i = stop + 1
        elseif c == '"' or c == "'" then
            local j = i + 1
            while src:sub(j, j) ~= c do
                assert(j <= n, "unfinished string")
                j = j + (src:sub(j, j) == "\\" and 2 or 1)
            end
            out[#out + 1] = c .. (src:sub(i + 1, j - 1):gsub(utf8.charpattern, truncate)) .. c
            i = j + 1
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
    return table.concat(out)
end

return function(path)
    local fh = assert(io.open(path, "rb"))
    local src = fh:read("a")
    fh:close()
    return assert(load(kahluaSource(src), "@" .. path))()
end
