-- 測試 MapStreets_Flx.lua 的「純文字街名顯示窗口」（不再有 streets.xml 幾何副本）
-- 執行：lua scripts/test_map_streets.lua（須在 repo 根目錄，dofile 走相對路徑）
--
-- 行為契約（本測試逐條把關；刻意只驗可觀測狀態、不 pin 呼叫序列）：
--   (1) CH/CN：原 loader 複製出的顯示副本吃到譯名，raw 名稱在收工後回到英文原名，
--       幾何（點座標）全程不變
--   (2) 缺鍵／空白值／鍵回顯／查詢例外／引擎拒收 → 該條退回原名，其餘照常翻譯
--   (3) 非 CH/CN 語系（含未來新語系）完全不介入，連 scratch 都不建立
--   (4) 只翻官方街名；其他地圖保留原始資料，逐目錄隔離載入錯誤
--   (5) 重入（原 loader 期間再次載入同一份 raw）：內層自行取得譯名，內層若是
--       其他語系則拿到英文原名（不得借用外層譯名），外層窗口在內層結束後復原
--   (6) 原 loader 期間被外部改掉的街名，收工時保留外部名（不覆寫回原名）
--   (7) 翻譯／還原機制失敗明確降級並保住地圖；原始資料載入及原 loader 例外保留；
--       清理仍跑完，後續不再重複修改不確定的 raw。

local VANILLA_DIR = 'media/maps/Muldraugh, KY'
local RELATIVE = VANILLA_DIR .. '/streets.xml'
local OTHER_DIR = 'media/maps/Raven Creek'
local OTHER_RELATIVE = OTHER_DIR .. '/streets.xml'

-- ============ 可調狀態（每案例 reset） ============
local lang, translations, rejectValues, clipFails, setFails
local lookupFails, fileMissing, scratchFailNew, scratchFailAdd, origFails, origHook
local scratchCreated, scratchCleared
local shared -- raw 街道資料：引擎依檔名快取、全程序共享

-- ============ PZ global stubs ============
local function makeStreet(name, x, y)
    return {
        name = name, splitName = name, x = x, y = y,
        getTranslatedText = function(self) return self.name end,
        setTranslatedText = function(self, value)
            if setFails[value] then error("boom: restore setter") end
            -- 模擬 Java 的空值正規化。
            self.name = rejectValues[value] and "" or value
        end,
        clipToObscuredCells = function(self)
            if clipFails[self.name] then error("boom: street clipping") end
            self.splitName = self.name
        end,
    }
end

function getStreets(data)
    return {
        size = function() return #data.streets end,
        get = function(_, i) return data.streets[i + 1] end,
    }
end

function getTextOrNull(key)
    if lookupFails then error("boom: translator unavailable") end
    return translations[key]
end

function fileExists(path) return not fileMissing end

Translator = {
    getLanguage = function() return { name = function() return lang end } end,
}

UIWorldMap = {
    new = function()
        if scratchFailNew then error("boom: scratch construction") end
        scratchCreated = scratchCreated + 1
        local s = { loaded = {} }
        s.api = {
            addStreetData = function(_, rel)
                if scratchFailAdd then error("boom: XML parse error") end
                s.loaded[rel] = shared[rel]
            end,
            getStreetDataByRelativeFileName = function(_, rel) return s.loaded[rel] end,
            clearStreetData = function() scratchCleared = scratchCleared + 1; s.loaded = {} end,
        }
        s.getAPIv3 = function() return { getStreetsAPI = function() return s.api end } end
        return s
    end,
}

local function makeMapUI()
    local ui = { loaded = {} }
    ui.api = {
        getStreetDataByRelativeFileName = function(_, rel) return ui.loaded[rel] end,
        clearStreetData = function() ui.cleared = (ui.cleared or 0) + 1 end,
    }
    ui.javaObject = { getAPIv3 = function() return { getStreetsAPI = function() return ui.api end } end }
    return ui
end

-- 原版 initDirectoryStreetData stub（載入待測檔前就位，wrapper 會捕獲它）：
-- 忠實模擬引擎的同步複製——把 raw 當下的名稱與幾何複製成該地圖的顯示副本，
-- 並登記到該地圖（重複載入時 wrapper 應辨識為已載入）
MapUtils = {
    initDirectoryStreetData = function(mapUI, directory)
        if origFails == true or origFails == directory then error("boom: vanilla loader " .. directory) end
        if origHook then
            local hook = origHook
            origHook = nil -- 只觸發一次，避免無限遞迴
            hook()
        end
        local rel = directory .. "/streets.xml"
        local data = shared[rel]
        if not data then return "no-data" end
        if not mapUI.loaded[rel] then
            mapUI.displayed = {}
            for i = 1, #data.streets do
                local s = data.streets[i]
                mapUI.displayed[i] = { name = s.splitName, x = s.x, y = s.y }
            end
            mapUI.loaded[rel] = data
        end
        return "orig-result"
    end,
}

-- ============ 載入待測檔案 ============
local loaderPath = arg[1] or "MOD/MinidoracatLangFor42/Contents/mods/MinidoracatLangFor42/42/media/lua/client/ISUI/Maps/MapStreets_Flx.lua"
local originalDirectoryLoader = MapUtils.initDirectoryStreetData

-- ============ 測試骨架 ============
local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. name .. (detail and ("  [" .. tostring(detail) .. "]") or ""))
    end
end

local function reset()
    lang = "CH"
    translations = {
        ["UI_WorldMapStreet_Oak St"] = "橡樹街",
        ["UI_WorldMapStreet_Ohio Dr"] = "俄亥俄大道",
    }
    rejectValues, clipFails, setFails = {}, {}, {}
    lookupFails, fileMissing = false, false
    scratchFailNew, scratchFailAdd, origFails, origHook = false, false, false, nil
    scratchCreated, scratchCleared = 0, 0
    local vanilla = {
        streets = { makeStreet("Oak St", 1, 2), makeStreet("Ohio Dr", 3, 4), makeStreet("Nowhere Rd", 5, 6) },
    }
    shared = { [RELATIVE] = vanilla, [OTHER_RELATIVE] = { streets = { makeStreet("Oak St", 7, 8) } } }
    -- 引擎的檔案快取不分大小寫：同一份 raw，兩種寫法指向同一個物件
    shared[string.lower(RELATIVE)] = vanilla
    MapUtils.initDirectoryStreetData = originalDirectoryLoader
    dofile(loaderPath)
end

local function rawNames(rel)
    local out = {}
    for i, s in ipairs(shared[rel or RELATIVE].streets) do out[i] = s.name end
    return table.concat(out, "|")
end

local function shownNames(ui)
    if not ui.displayed then return "<none>" end
    local out = {}
    for i, s in ipairs(ui.displayed) do out[i] = s.name end
    return table.concat(out, "|")
end

-- ============ (1) CH：顯示副本得譯名、raw 還原、幾何不變 ============
reset()
local ui = makeMapUI()
local ok, res = pcall(MapUtils.initDirectoryStreetData, ui, VANILLA_DIR)
check("CH：顯示副本吃到譯名、無鍵街道維持原名",
    shownNames(ui) == "橡樹街|俄亥俄大道|Nowhere Rd", shownNames(ui))
check("CH：raw 還原英文原名", rawNames() == "Oak St|Ohio Dr|Nowhere Rd", rawNames())
check("CH：幾何不變（顯示副本）", ui.displayed[1].x == 1 and ui.displayed[1].y == 2)
check("CH：幾何不變（raw）", shared[RELATIVE].streets[2].x == 3 and shared[RELATIVE].streets[2].y == 4)
check("CH：split 副本原名還原", shared[RELATIVE].streets[1].splitName == "Oak St")
check("CH：scratch 已清理", scratchCleared == scratchCreated, scratchCleared)
check("CH：不清玩家地圖", ui.cleared == nil)
lang = "EN"
local englishAfter = makeMapUI()
MapUtils.initDirectoryStreetData(englishAfter, VANILLA_DIR)
check("後開英文地圖不借用中文 split 副本", shownNames(englishAfter) == "Oak St|Ohio Dr|Nowhere Rd", shownNames(englishAfter))

-- CN 與 CH 走同一條路徑
reset()
lang = "CN"
ui = makeMapUI()
MapUtils.initDirectoryStreetData(ui, VANILLA_DIR)
check("CN：顯示副本吃到譯名", shownNames(ui) == "橡樹街|俄亥俄大道|Nowhere Rd", shownNames(ui))
check("CN：raw 還原英文原名", rawNames() == "Oak St|Ohio Dr|Nowhere Rd", rawNames())

-- ============ (2) 譯值無效的各種形態都退回原名 ============
reset()
translations["UI_WorldMapStreet_Ohio Dr"] = "   " -- 空白值
ui = makeMapUI()
MapUtils.initDirectoryStreetData(ui, VANILLA_DIR)
check("空白譯值退回原名", shownNames(ui) == "橡樹街|Ohio Dr|Nowhere Rd", shownNames(ui))

reset()
translations["UI_WorldMapStreet_Ohio Dr"] = "UI_WorldMapStreet_Ohio Dr" -- 鍵回顯
ui = makeMapUI()
MapUtils.initDirectoryStreetData(ui, VANILLA_DIR)
check("鍵回顯退回原名", shownNames(ui) == "橡樹街|Ohio Dr|Nowhere Rd", shownNames(ui))

reset()
lookupFails = true
ui = makeMapUI()
ok, res = pcall(MapUtils.initDirectoryStreetData, ui, VANILLA_DIR)
check("查詢例外：全部維持原名", shownNames(ui) == "Oak St|Ohio Dr|Nowhere Rd", shownNames(ui))
check("查詢例外：raw 乾淨", rawNames() == "Oak St|Ohio Dr|Nowhere Rd", rawNames())

reset()
translations["UI_WorldMapStreet_Nowhere Rd"] = "拒收路"
rejectValues["拒收路"] = true -- 引擎拒收（讀回空字串）
ui = makeMapUI()
MapUtils.initDirectoryStreetData(ui, VANILLA_DIR)
check("引擎拒收：該條退回原名、不留空標籤",
    shownNames(ui) == "橡樹街|俄亥俄大道|Nowhere Rd", shownNames(ui))
check("引擎拒收：raw 還原英文原名", rawNames() == "Oak St|Ohio Dr|Nowhere Rd", rawNames())

-- ============ (3) 其他語系（含未來新語系）完全不介入 ============
reset()
lang = "JP"
ui = makeMapUI()
res = MapUtils.initDirectoryStreetData(ui, VANILLA_DIR)
check("新語系：顯示副本維持原名", shownNames(ui) == "Oak St|Ohio Dr|Nowhere Rd", shownNames(ui))
check("新語系：不建立 scratch", scratchCreated == 0, scratchCreated)

-- ============ (4) 只處理官方街名承載目錄 ============
reset()
ui = makeMapUI()
res = MapUtils.initDirectoryStreetData(ui, OTHER_DIR)
check("其他地圖目錄：同名街道也不翻譯", shownNames(ui) == "Oak St", shownNames(ui))
check("其他地圖目錄：不建立 scratch", scratchCreated == 0, scratchCreated)

-- 原版按 MOD 優先順序逐目錄載入；一個 MOD 出錯不得阻止其餘正常路網。
for _, mode in ipairs({ "CH", "EN" }) do
    reset()
    lang = mode
    local brokenDir = "media/maps/Broken Map"
    origFails = brokenDir
    local messages, originalPrint = {}, print
    print = function(message) messages[#messages + 1] = message end
    ui = makeMapUI()
    local loadedAll, loadError = pcall(function()
        for _, directory in ipairs({ OTHER_DIR, brokenDir, VANILLA_DIR }) do
            MapUtils.initDirectoryStreetData(ui, directory)
        end
    end)
    print = originalPrint
    check(mode .. "：單一 MOD 錯誤不打斷目錄迴圈", loadedAll, loadError)
    check(mode .. "：失敗前後的有效來源均保留", ui.loaded[OTHER_RELATIVE] == shared[OTHER_RELATIVE]
        and ui.loaded[RELATIVE] == shared[RELATIVE])
    check(mode .. "：錯誤包含故障目錄與原始原因",
        table.concat(messages, "\n"):find("boom: vanilla loader " .. brokenDir, 1, true) ~= nil)
    check(mode .. "：保留其他地圖原名與座標", shared[OTHER_RELATIVE].streets[1].name == "Oak St"
        and shared[OTHER_RELATIVE].streets[1].x == 7 and shared[OTHER_RELATIVE].streets[1].y == 8)
end

reset()
ui = makeMapUI()
res = MapUtils.initDirectoryStreetData(ui, 'media/maps/muldraugh, ky')
check("承載目錄大小寫不敏感", shownNames(ui) == "橡樹街|俄亥俄大道|Nowhere Rd", shownNames(ui))

-- ============ (5) 重入 ============
reset()
local inner, innerOk, innerRes
origHook = function()
    inner = makeMapUI()
    innerOk, innerRes = pcall(MapUtils.initDirectoryStreetData, inner, VANILLA_DIR)
end
ui = makeMapUI()
MapUtils.initDirectoryStreetData(ui, VANILLA_DIR)
check("重入：內層不拋例外", innerOk, innerRes)
check("重入：內層自行取得譯名", shownNames(inner) == "橡樹街|俄亥俄大道|Nowhere Rd", shownNames(inner))
check("重入：外層窗口在內層結束後復原", shownNames(ui) == "橡樹街|俄亥俄大道|Nowhere Rd", shownNames(ui))
check("重入：raw 最終還原", rawNames() == "Oak St|Ohio Dr|Nowhere Rd", rawNames())
check("重入：所有 scratch 都清理", scratchCleared == scratchCreated, scratchCleared)

reset()
inner = nil
origHook = function()
    lang = "EN" -- 內層是其他語系
    inner = makeMapUI()
    MapUtils.initDirectoryStreetData(inner, VANILLA_DIR)
    lang = "CH"
end
ui = makeMapUI()
MapUtils.initDirectoryStreetData(ui, VANILLA_DIR)
check("重入：內層 EN 不得借用外層譯名", shownNames(inner) == "Oak St|Ohio Dr|Nowhere Rd", shownNames(inner))
check("重入：內層 EN 後外層仍拿到譯名", shownNames(ui) == "橡樹街|俄亥俄大道|Nowhere Rd", shownNames(ui))
check("重入：內層 EN 後 raw 還原", rawNames() == "Oak St|Ohio Dr|Nowhere Rd", rawNames())

-- 內層 EN 失敗仍須復原外層 CH 窗口，不能只守各自單獨成功的路徑。
reset()
origHook = function()
    lang, origFails = "EN", true
    inner = makeMapUI()
    innerOk, innerRes = pcall(MapUtils.initDirectoryStreetData, inner, VANILLA_DIR)
    lang, origFails = "CH", false
end
ui = makeMapUI()
MapUtils.initDirectoryStreetData(ui, VANILLA_DIR)
check("內層失敗仍傳回真正例外", not innerOk and tostring(innerRes):find("boom: vanilla loader", 1, true), innerRes)
check("內層失敗後外層仍顯示中文", shownNames(ui) == "橡樹街|俄亥俄大道|Nowhere Rd", shownNames(ui))
check("內層失敗後 raw 與 split 還原", rawNames() == "Oak St|Ohio Dr|Nowhere Rd"
    and shared[RELATIVE].streets[1].splitName == "Oak St")
check("內層失敗後 scratch 全部清理且不清玩家地圖", scratchCleared == scratchCreated and not ui.cleared and not inner.cleared)

-- 已載入同一份資料的地圖不重複開窗（連續呼叫）
reset()
ui = makeMapUI()
MapUtils.initDirectoryStreetData(ui, VANILLA_DIR)
MapUtils.initDirectoryStreetData(ui, VANILLA_DIR)
check("同一地圖再次載入：不重開窗", scratchCreated == 1, scratchCreated)
check("同一地圖再次載入：顯示副本保留譯名", shownNames(ui) == "橡樹街|俄亥俄大道|Nowhere Rd", shownNames(ui))
check("同一地圖再次載入：raw 仍是原名", rawNames() == "Oak St|Ohio Dr|Nowhere Rd", rawNames())

-- ============ (6) 外部改名保留 ============
reset()
origHook = function() shared[RELATIVE].streets[1].name = "第三方改的名" end
ui = makeMapUI()
MapUtils.initDirectoryStreetData(ui, VANILLA_DIR)
check("外部改名：不被還原覆寫", shared[RELATIVE].streets[1].name == "第三方改的名",
    shared[RELATIVE].streets[1].name)
check("外部改名：其他條目照常還原", rawNames() == "第三方改的名|Ohio Dr|Nowhere Rd", rawNames())

-- ============ (7) 例外與清理邊界 ============
reset()
scratchFailNew = true
ui = makeMapUI()
ok, res = pcall(MapUtils.initDirectoryStreetData, ui, VANILLA_DIR)
check("scratch 建立失敗：顯示原名", shownNames(ui) == "Oak St|Ohio Dr|Nowhere Rd", shownNames(ui))
check("scratch 建立失敗：raw 乾淨", rawNames() == "Oak St|Ohio Dr|Nowhere Rd", rawNames())

reset()
scratchFailAdd = true
ui = makeMapUI()
ok, res = pcall(MapUtils.initDirectoryStreetData, ui, VANILLA_DIR)
check("原始 XML 載入錯誤保留，不在同次重用不確定快取",
    not ok and tostring(res):find("boom: XML parse error", 1, true) and ui.displayed == nil, res)
check("XML 載入失敗：scratch 仍清理", scratchCleared == scratchCreated, scratchCleared)

reset()
fileMissing = true
ui = makeMapUI()
ok, res = pcall(MapUtils.initDirectoryStreetData, ui, VANILLA_DIR)
check("檔案不存在：不拋例外且不開窗", ok and scratchCreated == 0, res)

reset()
origFails = true
ui = makeMapUI()
ok, res = pcall(MapUtils.initDirectoryStreetData, ui, VANILLA_DIR)
check("原 loader 失敗：例外不被吞", not ok and tostring(res):find("boom: vanilla loader", 1, true), res)
check("原 loader 失敗：raw 已還原", rawNames() == "Oak St|Ohio Dr|Nowhere Rd", rawNames())
check("原 loader 失敗：scratch 已清理", scratchCleared == scratchCreated, scratchCleared)
check("原 loader 失敗：不清玩家地圖", ui.cleared == nil)

-- 失敗後仍可正常服務下一次呼叫（inFlight 未殘留）
ui = makeMapUI()
origFails = false
MapUtils.initDirectoryStreetData(ui, VANILLA_DIR)
check("失敗後回復：下一次照常翻譯", shownNames(ui) == "橡樹街|俄亥俄大道|Nowhere Rd", shownNames(ui))
check("失敗後回復：raw 還原", rawNames() == "Oak St|Ohio Dr|Nowhere Rd", rawNames())


reset()
clipFails["俄亥俄大道"] = true
ui = makeMapUI()
MapUtils.initDirectoryStreetData(ui, VANILLA_DIR)
check("中途裁切失敗：已翻譯條目與 split 一起還原", shownNames(ui) == "Oak St|Ohio Dr|Nowhere Rd", shownNames(ui))
check("中途裁切失敗：raw 原名保留", rawNames() == "Oak St|Ohio Dr|Nowhere Rd", rawNames())
check("中途裁切失敗：scratch 全部釋放", scratchCleared == scratchCreated, scratchCleared)

-- 父窗口暫停一半失敗：先回復父狀態，再降級委派，不能假稱內層翻譯成功。
reset()
origHook = function()
    clipFails["Oak St"] = true
    inner = makeMapUI()
    innerOk, innerRes = pcall(MapUtils.initDirectoryStreetData, inner, VANILLA_DIR)
    clipFails["Oak St"] = nil
end
ui = makeMapUI()
MapUtils.initDirectoryStreetData(ui, VANILLA_DIR)
check("暫停失敗仍保留可用內層地圖", innerOk and shownNames(inner) == "橡樹街|俄亥俄大道|Nowhere Rd", innerRes)
check("暫停失敗不以混合 raw 建外層", shownNames(ui) == "橡樹街|俄亥俄大道|Nowhere Rd", shownNames(ui))
check("內層降級不跳過外層還原", rawNames() == "Oak St|Ohio Dr|Nowhere Rd"
    and shared[RELATIVE].streets[1].splitName == "Oak St")
check("暫停失敗仍清理 scratch", scratchCleared == scratchCreated and not ui.cleared and not inner.cleared)

-- 還原 setter 故障：地圖已建立則保持可用，但必須報錯並停止後續文字交易。
reset()
local reported, savedPrint = {}, print
print = function(message) reported[#reported + 1] = tostring(message); savedPrint(message) end
origHook = function() setFails["Oak St"] = true end
ui = makeMapUI()
ok, res = pcall(MapUtils.initDirectoryStreetData, ui, VANILLA_DIR)
print = savedPrint
check("還原故障不破壞已建立的地圖", ok and shownNames(ui) == "橡樹街|俄亥俄大道|Nowhere Rd", res)
check("還原故障仍嘗試其他條目", shared[RELATIVE].streets[2].name == "Ohio Dr")
check("還原故障仍清理 listener", scratchCleared == scratchCreated and not ui.cleared)
check("還原故障保留原始錯誤診斷", table.concat(reported, "\n"):find("boom: restore setter", 1, true) ~= nil)
local priorScratch = scratchCreated
setFails = {}
local later = makeMapUI()
MapUtils.initDirectoryStreetData(later, VANILLA_DIR)
check("已降級的窗口不反覆修改 raw", scratchCreated == priorScratch and shownNames(later) == "橡樹街|Ohio Dr|Nowhere Rd")
print(string.format("passed=%d failed=%d", passed, failed))
os.exit(failed == 0 and 0 or 1)
