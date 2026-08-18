-- 測試 MapStreets_Flx.lua 的 add-only 街道載入策略（42.20.3 幽靈街道回歸驗證）
-- 執行：lua scripts/test_map_streets.lua（須在 repo 根目錄，dofile 走相對路徑）
--
-- 事件背景（HARDCODE_REGISTRY.md §0 42.20.3）：官方 WorldMapStreets.clear() 只清
-- street list、不清 StreetLookup 空間索引；42.20.3 起 ObjectPool 有容量上限，
-- 清除後的官方英文街道物件不再保證被重用覆寫，幽靈殘留大地圖。
-- 因此本修補的行為契約（本測試逐條把關）：
--   (1) 絕不呼叫 clearStreetData（任何路徑）
--   (2) 中文檔存在：先 add 中文，再依 getLotDirectories 載其他目錄
--   (3) 跳過官方英文承載目錄 'Muldraugh, KY'（大小寫不敏感）
--   (4) 單一第三方目錄拋錯不中斷其他目錄載入（pcall 隔離）
--   (5) 中文檔缺失：僅委派原版 _orig（不 add、不 clear）
--   (6) 中文載入本身拋錯：fail-loud 後 fallback 原版 _orig（地圖初始化不可炸穿）

-- ============ PZ global stubs ============
local MOD_STREETS = 'media/maps/Riverside, KY/streets.xml'

local calls          -- 每案例重置的呼叫紀錄
local fileExistsValue = true
local dirsValue = {}
local failDirs = {}   -- initDirectoryStreetData 要拋錯的目錄集合
local apiShouldFail = false

function fileExists(path) return fileExistsValue end

function getLotDirectories()
    return {
        size = function() return #dirsValue end,
        get = function(_, i) return dirsValue[i + 1] end,
    }
end

local addShouldFail = false
local streetsAPI = {
    addStreetData = function(_, path)
        if addShouldFail then error("boom: XML parse error") end
        table.insert(calls, "add:" .. path)
    end,
    clearStreetData = function() table.insert(calls, "clear") end,
}

local function makeMapUI()
    return {
        javaObject = {
            getAPIv3 = function()
                if apiShouldFail then error("boom: broken API") end
                return { getStreetsAPI = function() return streetsAPI end }
            end,
        },
    }
end

-- 原版 initDefaultStreetData stub（載入待測檔前就位，_orig 會捕獲它）。
-- 忠實模擬 vanilla ISMapDefinitions.lua:41-50 的真實序列：getAPIv3 →
-- getStreetsAPI → clearStreetData → 依 getLotDirectories 逐目錄載入——
-- 這樣 fallback 案例才真的打得到「_orig 內同一失敗點重拋」的路徑
-- （42.20.3 review lane 抓到的 stub 不保真問題）
MapUtils = {
    initDefaultStreetData = function(mapUI)
        local mapAPI = mapUI.javaObject:getAPIv3()
        local streetsAPI = mapAPI:getStreetsAPI()
        streetsAPI:clearStreetData()
        local dirs = getLotDirectories()
        for i = 1, dirs:size() do
            MapUtils.initDirectoryStreetData(mapUI, 'media/maps/' .. dirs:get(i - 1))
        end
        table.insert(calls, "orig-done")
    end,
    initDirectoryStreetData = function(mapUI, dir)
        if failDirs[dir] then error("boom: " .. dir) end
        table.insert(calls, "dir:" .. dir)
    end,
}

-- ============ 載入待測檔案 ============
dofile("MOD/MinidoracatLangFor42/Contents/mods/MinidoracatLangFor42/42/media/lua/client/ISUI/Maps/MapStreets_Flx.lua")

-- ============ 測試 ============
local passed, failed = 0, 0
local function case(name, setup, expect)
    calls, fileExistsValue, dirsValue, failDirs, apiShouldFail, addShouldFail = {}, true, {}, {}, false, false
    setup()
    MapUtils.initDefaultStreetData(makeMapUI())
    local got = table.concat(calls, " | ")
    local want = table.concat(expect, " | ")
    if got == want then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. name)
        print("  want: " .. want)
        print("  got : " .. got)
    end
end

-- (1)(2)(3) 中文優先、跳過 Muldraugh（精確名）、其他目錄照序、全程無 clear
case("中文優先＋跳過 Muldraugh＋其他目錄照序", function()
    dirsValue = { "Muldraugh, KY", "Raven Creek", "Riverside, KY" }
end, {
    "add:" .. MOD_STREETS,
    "dir:media/maps/Raven Creek",
    "dir:media/maps/Riverside, KY",
})

-- (3) 大小寫不敏感跳過
case("跳過 Muldraugh 大小寫變體", function()
    dirsValue = { "muldraugh, ky", "MULDRAUGH, KY", "Fort Knox" }
end, {
    "add:" .. MOD_STREETS,
    "dir:media/maps/Fort Knox",
})

-- (4) 單一目錄拋錯不中斷
case("第三方目錄拋錯隔離", function()
    dirsValue = { "BadMap", "GoodMap" }
    failDirs["media/maps/BadMap"] = true
end, {
    "add:" .. MOD_STREETS,
    "dir:media/maps/GoodMap",
})

-- (5) 中文檔缺失 → 委派原版（vanilla 真序列：clear + 全目錄載入，屬刻意降級）
case("中文檔缺失 fallback 原版", function()
    fileExistsValue = false
    dirsValue = { "Muldraugh, KY" }
end, { "clear", "dir:media/maps/Muldraugh, KY", "orig-done" })

-- (6) 中文載入拋錯（getAPIv3 炸）→ fallback 原版在同一點重拋 → 必須被攔下，
-- 例外不得逸出（否則炸穿 initDataAndStyle，整張地圖不初始化）——F12 防護的可觀測證據
case("getAPIv3 拋錯 fallback 亦攔下例外", function()
    apiShouldFail = true
    dirsValue = { "Muldraugh, KY" }
end, {})

-- (7) addStreetData 本身拋錯（如 XML 損毀的 RuntimeException）→ fallback 原版走完
-- 引擎事實：getOrCreateData 的 read 拋錯發生在 streetData.add/combine 之前，
-- WorldMap 狀態乾淨，fallback 的 clear 面對空集合零副作用、無幽靈
case("addStreetData 拋錯 fallback 原版", function()
    addShouldFail = true
    dirsValue = { "Muldraugh, KY" }
end, { "clear", "dir:media/maps/Muldraugh, KY", "orig-done" })

-- (1) 重入不 clear（呼叫兩次，兩輪皆無 clear）
case("重入無 clear（第二次呼叫）", function()
    dirsValue = { "Muldraugh, KY", "Raven Creek" }
    MapUtils.initDefaultStreetData(makeMapUI()) -- 第一次；calls 會累積
end, {
    "add:" .. MOD_STREETS,
    "dir:media/maps/Raven Creek",
    "add:" .. MOD_STREETS,
    "dir:media/maps/Raven Creek",
})

print(string.format("passed=%d failed=%d", passed, failed))
os.exit(failed == 0 and 0 or 1)
