-- 原版街名的純文字翻譯：UI_WorldMapStreet_<原名>（CH/CN）。
-- WorldMap.java:193-218 同步建立顯示副本；只在該窗口改名，結束還原 raw。
-- WorldMapStreet.java:170-176/565-622：setter 不改幾何，split 副本須重新 clip。
-- 不替換 XML、不改來源/路寬、不碰 editor setter，不清已顯示的玩家地圖。
-- scratch 清理僅解除本窗口 listener；重入與例外均須恢復原名。

local TAG = "[CatLangFor42]"
-- 官方英文街名的唯一承載目錄（小寫比對）；本檔只處理這個來源
local VANILLA_STREETS_DIR = "muldraugh, ky"
local KEY_PREFIX = "UI_WorldMapStreet_"

local origInit = MapUtils and MapUtils.initDirectoryStreetData
if type(origInit) ~= "function" then
    print(TAG .. " [Streets] DISABLED: MapUtils.initDirectoryStreetData unavailable")
    return
end
if not UIWorldMap or not getStreets then
    -- getStreets 為 42.20.0 新增；缺 API 時保留原版載入流程。
    print(TAG .. " [Streets] DISABLED: world map street API unavailable")
    return
end

local logged = {}
local function logOnce(key, message)
    if logged[key] then return end
    logged[key] = true
    print(TAG .. " [Streets] " .. message)
end

-- Java 與 Lua 空白判定不同；setter 正規化成空值的譯名不再重試。
local rejectedText = {}
-- 目前生效中的顯示窗口變更；raw 為全程序共享，重入／同檔不同地圖都指向同一份
local inFlight
local degradedReason

local function translateName(original)
    if original == "" then return original end
    local key = KEY_PREFIX .. original
    local ok, value = pcall(getTextOrNull, key)
    if not ok then
        logOnce("lookup", "name lookup failed: " .. tostring(value) .. "; keeping original names")
        return original
    end
    -- 缺鍵（nil）／空白／鍵回顯／曾被引擎拒收 → 原名
    if type(value) ~= "string" then return original end
    if value == key or value:match("^%s*$") then return original end
    if rejectedText[value] then return original end
    return value
end

local function applyChange(change)
    local street = change.street
    street:setTranslatedText(change.translated)
    if street:getTranslatedText() == "" and change.translated ~= "" then
        -- 引擎正規化後為空：保留原名，避免空標籤。
        rejectedText[change.translated] = true
        logOnce("rejected", "engine rejected a translated name; keeping original")
        street:setTranslatedText(change.original)
    end
    change.translated = street:getTranslatedText()
    -- 共享 raw 改名後會先產生 split copy，必須重新 clip 才不會留下舊標籤
    street:clipToObscuredCells()
end

local function restoreChanges(changes)
    if not changes then return end
    local failures, firstError = 0, nil
    for i = #changes, 1, -1 do
        local change = changes[i]
        local ok, err = pcall(function()
            -- 只還原「還是我們寫上去的那個名字」；原 loader 期間被外部改掉的名字保留
            if change.street:getTranslatedText() == change.translated then
                change.street:setTranslatedText(change.original)
                if change.street:getTranslatedText() ~= change.original then
                    error("native street name restore rejected")
                end
            end
            change.street:clipToObscuredCells()
        end)
        if not ok then
            failures = failures + 1
            firstError = firstError or tostring(err)
        end
    end
    if failures > 0 then return failures .. " street name restore failure(s): " .. firstError end
end

-- 重入／同檔不同地圖：內層開工前先把外層窗口還原成 raw 原名，
-- 內層（可能是別的語系）不得借用外層譯名；內層結束後由 restoreChanges 復原外層
local function suspendWindow(parent, suspended)
    for i = #parent, 1, -1 do
        local old = parent[i]
        if old.street:getTranslatedText() == old.translated then
            local change = { street = old.street, original = old.translated, translated = old.original }
            suspended[#suspended + 1] = change
            applyChange(change)
        end
    end
end

function MapUtils.initDirectoryStreetData(mapUI, directory)
    local dir = type(directory) == "string" and directory:match("^media/maps/(.+)$") or nil
    if dir and string.lower(dir) ~= VANILLA_STREETS_DIR then
        -- 原版目錄迴圈沒有 pcall；保留其他 MOD 的隔離，不改順序或重試壞來源。
        local ok, result = pcall(origInit, mapUI, directory)
        if not ok then
            logOnce("directory:" .. dir, "street data load failed (" .. dir .. "): "
                .. tostring(result) .. "; continuing other map directories")
            return
        end
        return result
    end
    if not dir or degradedReason then
        return origInit(mapUI, directory)
    end

    local relative = directory .. "/streets.xml"
    local changes, scratchAPI, suspended, parent, windowed = {}, nil, nil, nil, false
    local suspensionReady, acquiring = true, false
    local lang, streetCount
    local translatedCount = 0
    local prepared, prepareErr = pcall(function()
        parent = inFlight
        if parent then
            suspensionReady = false
            suspended = {}
            suspendWindow(parent, suspended)
            suspensionReady = true
        end
        lang = Translator.getLanguage():name()
        if lang ~= "CH" and lang ~= "CN" then return end
        if not fileExists(relative) then return end
        local targetAPI = mapUI.javaObject:getAPIv3():getStreetsAPI()
        if targetAPI:getStreetDataByRelativeFileName(relative) then return end
        local scratch = UIWorldMap.new({})
        scratchAPI = scratch:getAPIv3():getStreetsAPI()
        acquiring = true
        scratchAPI:addStreetData(relative)
        acquiring = false
        local data = scratchAPI:getStreetDataByRelativeFileName(relative)
        if not data then error("native street data unavailable") end
        inFlight, windowed = changes, true
        local streets = getStreets(data)
        streetCount = streets:size()
        for i = 0, streetCount - 1 do
            local street = streets:get(i)
            local original = street:getTranslatedText() or ""
            local translated = translateName(original)
            if translated ~= original then
                local change = { street = street, original = original, translated = translated }
                changes[#changes + 1] = change
                applyChange(change)
                if change.translated ~= original then translatedCount = translatedCount + 1 end
            end
        end
    end)

    local restoreErr, parentErr
    if not prepared then
        restoreErr = restoreChanges(changes)
        if not suspensionReady then
            -- 暫停不完整時先回到父窗口，不能把半套狀態當成新語系的原名。
            parentErr = restoreChanges(suspended)
            suspended = nil
        end
        degradedReason = tostring(prepareErr)
    end
    local loaded, result
    if acquiring then
        -- native 先快取再解析；同次重試可能吃到半份來源。原始載入錯誤必須保留。
        loaded, result = false, prepareErr
    else
        loaded, result = pcall(origInit, mapUI, directory)
    end
    -- 內層降級不能跳過外層正在進行的還原與 listener 清理。
    if prepared then restoreErr = restoreChanges(changes) end
    if suspended then parentErr = restoreChanges(suspended) end
    if windowed then inFlight = parent end
    local cleanupErr
    if scratchAPI then
        local ok, err = pcall(function() scratchAPI:clearStreetData() end)
        if not ok then cleanupErr = "scratch cleanup failed: " .. tostring(err) end
    end
    degradedReason = restoreErr or parentErr or cleanupErr or degradedReason
    if degradedReason then
        logOnce("degraded", degradedReason .. "; street translation disabled for this session; restart to reload original names")
    elseif loaded and windowed then
        logOnce("loaded:" .. lang,
            "street names applied (" .. lang .. ", " .. translatedCount .. " of " .. streetCount .. ")")
    end
    if not loaded then error(result) end
    return result
end

print(TAG .. " [Streets] armed (names only, official directory)")
