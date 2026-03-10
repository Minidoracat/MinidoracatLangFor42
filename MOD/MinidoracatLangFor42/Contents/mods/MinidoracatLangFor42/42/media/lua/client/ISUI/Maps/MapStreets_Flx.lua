-- MapStreets_Flx.lua
-- 街道資料修復（確保 SP/MP 都能載入中文 streets.xml）
-- 原始 MapUtils.initDefaultStreetData 在 MP 中可能無法正確載入 MOD 的 streets.xml
-- 此覆寫直接透過 streetsAPI 載入，確保雙語通用

local TAG = "[CatLangFor42]"

local _orig_initDefaultStreetData = MapUtils.initDefaultStreetData

function MapUtils.initDefaultStreetData(mapUI)
    print(TAG .. " [Streets] initDefaultStreetData called")
    print(TAG .. " [Streets]   isClient()=" .. tostring(isClient()) .. " isServer()=" .. tostring(isServer()))

    -- 先執行原始函式（可能是空操作）
    local ok, err = pcall(_orig_initDefaultStreetData, mapUI)
    if not ok then
        print(TAG .. " [Streets]   _orig error: " .. tostring(err))
    end

    -- 無論原始函式是否成功，我們都直接載入街道資料
    local mapAPI = mapUI.javaObject:getAPIv3()
    local streetsAPI = mapAPI:getStreetsAPI()
    streetsAPI:clearStreetData()

    local dirs = getLotDirectories()
    local loaded = 0
    for i=1,dirs:size() do
        local dir = 'media/maps/'..dirs:get(i-1)
        local file = dir..'/streets.xml'
        if fileExists(file) then
            streetsAPI:addStreetData(file)
            loaded = loaded + 1
            print(TAG .. " [Streets]   loaded: " .. file)
        else
            print(TAG .. " [Streets]   not found: " .. file)
        end
    end

    print(TAG .. " [Streets] done, loaded " .. loaded .. " streets.xml files")
end
