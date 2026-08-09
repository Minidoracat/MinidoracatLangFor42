local MapLabelEdit = {}

function MapLabelEdit.isAppropriateKey(text)
    if not text or text == "" then
        return false
    end
    return text:find("^MapLabel_[^%s<>]+$") ~= nil
end

function MapLabelEdit.applyChanges(mapInstance)
    local worldMap = mapInstance or ISWorldMap_instance
    if not worldMap or not worldMap.javaObject then return end

    local mapAPI = worldMap.javaObject:getAPIv3()
    if not mapAPI then return end
    local symAPI = mapAPI:getSymbolsAPIv2()
    if not symAPI then return end
    
    local indicesToRemove = {}
    for i = 0, symAPI:getSymbolCount() - 1 do
        local sym = symAPI:getSymbolByIndex(i)

        if sym and sym:isText() then
            if sym:isUserDefined() then
            else
                local untranslatedKey = sym:getUntranslatedText()

                if not MapLabelEdit.isAppropriateKey(untranslatedKey) then
                    table.insert(indicesToRemove, i)
                end
            end
        end
    end

    if #indicesToRemove > 0 then
        -- indicesToRemove 由升冪迴圈收集、本身已是排序狀態；再對它排序（降冪）正是 Kahlua
        -- 遞迴 quicksort 的最壞輸入——已排序＋數百筆即 coroutine 堆疊溢位（MAX_STACK_SIZE
        -- 3000，Coroutine.java:16；Cleaner 0.1.1 正式服實際炸過）。要「由大到小刪除」
        -- 反向走訪即可，完全不需要排序。
        for j = #indicesToRemove, 1, -1 do
            symAPI:removeSymbolByIndex(indicesToRemove[j])
        end
    end
end

local function applyChangesIfMapExists()
    MapLabelEdit.applyChanges(ISWorldMap_instance)
end
Events.OnGameStart.Add(applyChangesIfMapExists)

if ISWorldMap and ISWorldMap.ShowWorldMap then
    local _showWorldMap = ISWorldMap.ShowWorldMap
    function ISWorldMap.ShowWorldMap(playerNum, centerX, centerY, zoom)
        local result = _showWorldMap(playerNum, centerX, centerY, zoom)
        MapLabelEdit.applyChanges(ISWorldMap_instance)
        return result
    end
end
