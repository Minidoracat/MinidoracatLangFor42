-- MapStreets_Flx.lua
-- 街道資料修復（確保 SP/MP 都能載入中文 streets.xml）
--
-- 取代原版 initDefaultStreetData 的載入策略：
--   1. 原版依 getLotDirectories() 載入各目錄 streets.xml；官方英文街道
--      只存在 'Muldraugh, KY/streets.xml'（全地圖唯一承載檔）。本檔改為
--      跳過該目錄、改載我方中文版（media/maps/Riverside, KY/streets.xml），
--      其他地圖 MOD 的街道目錄照舊載入。
--   2. 絕對不可走「先載官方英文再 clearStreetData() 再載中文」的舊流程：
--      官方 WorldMapStreets.clear() 只清 street list 並把物件 release 回
--      物件池，「不清 StreetLookup 空間索引」，而渲染 getStreetsOverlapping
--      走的正是該索引——被清掉的英文街道物件會以幽靈引用殘留。
--      42.20.2 以前 ObjectPool 無上限，幽靈物件會被後續 alloc 重用改寫、
--      視覺無感；42.20.3 起 ObjectPool 有容量上限（1024，超限 release 直接
--      丟棄），官方 1098 條街道 clear 後尾端物件永不被重用，英文街名就
--      永遠殘留在大地圖上（42.20.3 玩家回報「Spring Dr凱利大道」中英混雜
--      的根因）。因此本檔全程只 add、永不 clear。
--   3. WorldMap.addStreetData 以檔案為單位冪等（streetData contains 去重、
--      s_fileNameToData 全程序快取），小地圖 InitPlayer 等處重入安全。
--
-- MP client 的 getLotDirectories() 只回當前遊戲地塊目錄（如 Muldraugh, KY），
-- 不含 Riverside, KY，故中文檔必須顯式指定路徑載入，不能依賴目錄迴圈。

local TAG = "[CatLangFor42]"
local MOD_STREETS = 'media/maps/Riverside, KY/streets.xml'
-- 官方英文 streets.xml 的唯一承載目錄（小寫比對）；由我方中文檔整份取代
local VANILLA_STREETS_DIR = 'muldraugh, ky'

local _orig_initDefaultStreetData = MapUtils.initDefaultStreetData

-- fallback 共用：委派原版流程，並以 pcall 防護——若失敗根因在 getAPIv3/
-- getStreetsAPI（javaObject 異常），_orig 第一行會原樣重拋，必須攔下，
-- 否則例外炸穿 ISWorldMap:initDataAndStyle，其後的 initDefaultStyleV3/
-- overlayPaper/initDefaultAnnotations 全部不執行（整張大地圖壞掉）。
-- 攔下後放棄街道資料（大地圖只是沒有街名，其餘功能照常）。
local function runVanillaStreetData(mapUI)
    local ok, err = pcall(_orig_initDefaultStreetData, mapUI)
    if not ok then
        print(TAG .. " [Streets] vanilla street data also failed: " .. tostring(err))
    end
end

function MapUtils.initDefaultStreetData(mapUI)
    if not fileExists(MOD_STREETS) then
        -- 中文街道檔缺失（異常情況）→ 維持原版行為
        print(TAG .. " [Streets] Chinese streets not found, fallback to vanilla: " .. MOD_STREETS)
        return runVanillaStreetData(mapUI)
    end

    -- 先載中文街道（核心目標優先：任何第三方目錄出錯都不得影響中文載入）。
    -- 主路徑 pcall＝fail-loud＋graceful degrade：中文檔存在但載入失敗（XML 損毀等）
    -- 時印醒目錯誤並退回原版流程（英文街名），絕不讓例外炸穿呼叫端
    local okZh, errZh = pcall(function()
        local mapAPI = mapUI.javaObject:getAPIv3()
        local streetsAPI = mapAPI:getStreetsAPI()
        streetsAPI:addStreetData(MOD_STREETS)
    end)
    if not okZh then
        print(TAG .. " [Streets] ERROR loading Chinese streets (" .. MOD_STREETS .. "): " .. tostring(errZh))
        print(TAG .. " [Streets] falling back to vanilla street data")
        return runVanillaStreetData(mapUI)
    end
    print(TAG .. " [Streets] loaded Chinese streets: " .. MOD_STREETS)

    -- 照原版順序載入其他地圖 MOD 的街道，只跳過官方英文承載目錄；
    -- 逐目錄 pcall 隔離：單一 MOD 的 streets.xml 損壞不拖垮其他目錄
    -- （SP 下 Riverside 目錄會再遇到中文檔，addStreetData 冪等無妨）
    local dirs = getLotDirectories()
    for i = 1, dirs:size() do
        local dir = tostring(dirs:get(i - 1)) -- Java String → Lua string，確保 string.lower 安全
        if string.lower(dir) ~= VANILLA_STREETS_DIR then
            local ok, err = pcall(MapUtils.initDirectoryStreetData, mapUI, 'media/maps/' .. dir)
            if not ok then
                print(TAG .. " [Streets] initDirectoryStreetData error (" .. dir .. "): " .. tostring(err))
            end
        end
    end
end
