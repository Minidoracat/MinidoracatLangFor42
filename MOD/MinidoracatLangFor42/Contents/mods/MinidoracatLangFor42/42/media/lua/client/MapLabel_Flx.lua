local MapLabelEdit = {}

function MapLabelEdit.isAppropriateKey(text)
    if not text or text == "" then
        return false
    end
    return text:find("^MapLabel_[^%s<>]+$") ~= nil
end

function MapLabelEdit.applyChanges()
    if not ISWorldMap_instance then
        ISWorldMap.ShowWorldMap(0)
        ISWorldMap_instance:close()
    end

    local mapAPI = ISWorldMap_instance.javaObject:getAPIv3()
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
        table.sort(indicesToRemove, function(a, b) return a > b end)
        for _, index in ipairs(indicesToRemove) do
            symAPI:removeSymbolByIndex(index)
        end
    end
end

Events.OnGameStart.Add(MapLabelEdit.applyChanges)