-- 原版街名的純文字翻譯：UI_WorldMapStreet_<原名>（CH/CN）。
-- 42.21 起 raw 只存未翻譯文字，getTranslatedText() = Translator.getText(untranslated)
-- （WorldMapStreet.java:178-188）。WorldMap.java:193-220 同步建立顯示副本時複製 split 副本，
-- 而 split 副本在 clipToObscuredCells（:577-634）以 getTranslatedText() 固化文字。
-- 所以只在該窗口把 raw 原名換成翻譯鍵再 clip，結束還原原名並再 clip。
-- 鍵內含英文原名：萬一還原失敗，registerNavZones 以原名辨識鐵路的判斷仍有效。
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

-- 目前生效中的顯示窗口變更；raw 為全程序共享，重入／同檔不同地圖都指向同一份
local inFlight
local degradedReason

-- 有可用譯文才回傳翻譯鍵；缺鍵（nil）／空白／鍵回顯／查詢失敗 → nil（維持原名）
local function translationKey(original)
    if original == "" then return nil end
    local key = KEY_PREFIX .. original
    local ok, value = pcall(getTextOrNull, key)
    if not ok then
        logOnce("lookup", "name lookup failed: " .. tostring(value) .. "; keeping original names")
        return nil
    end
    if type(value) ~= "string" or value == key or value:match("^%s*$") then return nil end
    return key
end

-- raw 由 change.from 換成 change.to；split 副本以當下譯文固化，換名後必須重新 clip
local function applyChange(change)
    local street = change.street
    street:setUntranslatedText(change.to)
    if street:getUntranslatedText() ~= change.to then
        error("native street name write rejected")
    end
    street:clipToObscuredCells()
end

local function restoreChanges(changes)
    if not changes then return end
    local failures, firstError = 0, nil
    for i = #changes, 1, -1 do
        local change = changes[i]
        local ok, err = pcall(function()
            -- 只還原「還是我們寫上去的那個值」；原 loader 期間被外部改掉的名字保留
            if change.street:getUntranslatedText() == change.to then
                change.street:setUntranslatedText(change.from)
                if change.street:getUntranslatedText() ~= change.from then
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
        if old.street:getUntranslatedText() == old.to then
            local change = { street = old.street, from = old.to, to = old.from }
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
            local original = street:getUntranslatedText() or ""
            local key = translationKey(original)
            if key then
                local change = { street = street, from = original, to = key }
                changes[#changes + 1] = change
                applyChange(change)
                translatedCount = translatedCount + 1
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
