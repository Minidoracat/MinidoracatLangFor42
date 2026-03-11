-- MapStreets_Flx.lua
-- 街道資料修復（確保 SP/MP 都能載入中文 streets.xml）
-- 原版 initDefaultStreetData 依賴 getLotDirectories()，在 MP client 中
-- 可能不包含 MOD 的地圖目錄，導致中文路名無法載入。
-- 此覆寫先執行原版邏輯，再明確載入 MOD 的中文 streets.xml 覆蓋。

local TAG = "[CatLangFor42]"
local MOD_STREETS = 'media/maps/Riverside, KY/streets.xml'

local _orig_initDefaultStreetData = MapUtils.initDefaultStreetData

function MapUtils.initDefaultStreetData(mapUI)
    -- 先執行原版函式（載入原版 + 其他 MOD 的街道資料）
    local ok, err = pcall(_orig_initDefaultStreetData, mapUI)
    if not ok then
        print(TAG .. " [Streets] _orig error: " .. tostring(err))
    end

    -- 清除英文街道資料，再載入中文版（addStreetData 是疊加不是覆蓋）
    if fileExists(MOD_STREETS) then
        local mapAPI = mapUI.javaObject:getAPIv3()
        local streetsAPI = mapAPI:getStreetsAPI()
        streetsAPI:clearStreetData()
        streetsAPI:addStreetData(MOD_STREETS)
        print(TAG .. " [Streets] loaded Chinese streets: " .. MOD_STREETS)
    else
        print(TAG .. " [Streets] Chinese streets not found: " .. MOD_STREETS)
    end
end
