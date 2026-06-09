-- AnimalProductName_Flx.lua
-- 修復 PZ 42.19 動物屍體與屠宰肉品在 MP / 舊存檔中保留生成端語言名稱的問題。

local TAG = "[CatLangFor42]"

local ANIMAL_CORPSE_TYPE = "Base.CorpseAnimal"

local MEAT_BASE_NAME_KEYS = {
    ["Base.Beef"] = "IGUI_AnimalMeat_Beef",
    ["Base.Steak"] = "IGUI_AnimalMeat_Steak",
    ["Base.Pork"] = "IGUI_AnimalMeat_Pork",
    ["Base.PorkChop"] = "IGUI_AnimalMeat_PorkChop",
    ["Base.MuttonChop"] = "IGUI_AnimalMeat_Mutton",
    ["Base.Rabbitmeat"] = "IGUI_AnimalMeat_Rabbit",
    ["Base.Venison"] = "IGUI_AnimalMeat_Venison",
}

local MEAT_QUALITY_KEY_BY_SOURCE_NAME = {
    ["(Prime Cut)"] = "IGUI_AnimalMeat_PrimeCut",
    ["(上等肉塊)"] = "IGUI_AnimalMeat_PrimeCut",
    ["(上等肉块)"] = "IGUI_AnimalMeat_PrimeCut",
    ["(Average Cut)"] = "IGUI_AnimalMeat_MediumCut",
    ["(中等肉塊)"] = "IGUI_AnimalMeat_MediumCut",
    ["(中等肉块)"] = "IGUI_AnimalMeat_MediumCut",
    ["(Poor Cut)"] = "IGUI_AnimalMeat_PoorCut",
    ["(劣質肉塊)"] = "IGUI_AnimalMeat_PoorCut",
    ["(劣质肉块)"] = "IGUI_AnimalMeat_PoorCut",
}

local BREED_SOURCE_NAMES = {
    leghorn = { "Leghorn", "來亨雞", "来亨鸡" },
    largeblack = { "Large Black", "大黑豬", "大黑猪" },
    suffolk = { "Suffolk", "薩福克羊", "萨福克羊" },
    friesian = { "East Friesian", "東方弗里斯蘭羊", "东方弗里斯兰羊" },
    rambouillet = { "Rambouillet", "朗布依埃羊" },
    angus = { "Angus", "安格斯牛" },
    simmental = { "Simmental", "西門塔爾牛", "西门塔尔牛" },
    holstein = { "Holstein", "荷斯坦牛" },
    landrace = { "American Landrace", "美國蘭德瑞絲豬", "美国兰德瑞丝猪" },
    rhodeisland = { "Rhode Island Red", "羅德島紅雞", "罗德岛红鸡" },
    whitetailed = { "White-Tailed", "白尾鹿" },
    meleagris = { "Meleagris", "火雞屬", "火鸡属" },
    swamp = { "Swamp", "沼澤", "沼泽" },
    golden = { "Golden", "金色" },
    deer = { "Deer", "白足" },
    appalachian = { "Appalachian", "阿巴拉契亞", "阿巴拉契亚" },
    cottontail = { "Cottontail", "棉尾" },
    grey = { "Gray", "灰色" },
    white = { "White", "白色" },
}

local ANIMAL_TYPE_SOURCE_NAMES = {
    gobblers = { "Tom", "公火雞", "公火鸡" },
    turkeyhen = { "Hen", "母火雞", "母火鸡" },
    turkeypoult = { "Poult", "小火雞", "小火鸡" },
    fawndead = { "Fawn", "死小鹿" },
    deerdead = { "Deer", "死鹿" },
    mouse = { "Male Mouse (Buck)", "公家鼠" },
    mousepups = { "Mouse Pup", "小家鼠" },
    mousefemale = { "Female Mouse (Doe)", "母家鼠" },
    chick = { "Chick", "小雞", "小鸡" },
    hen = { "Hen", "母雞", "母鸡" },
    cockerel = { "Cockerel", "公雞", "公鸡" },
    boar = { "Boar", "公豬", "公猪" },
    sow = { "Sow", "母豬", "母猪" },
    piglet = { "Piglet", "小豬", "小猪" },
    buck = { "Buck", "公鹿" },
    doe = { "Doe", "母鹿" },
    fawn = { "Fawn", "小鹿" },
    raccoonboar = { "Male Raccoon (Boar)", "公浣熊" },
    raccoonsow = { "Female Raccoon (Sow)", "母浣熊" },
    raccoonkit = { "Baby Raccoon (Kit)", "小浣熊" },
    rabbuck = { "Male Rabbit (Buck)", "公兔子" },
    rabdoe = { "Female Rabbit (Doe)", "母兔子" },
    rabkitten = { "Baby Rabbit (Kitten)", "小兔子" },
    ewe = { "Ewe", "母綿羊", "母绵羊" },
    ram = { "Ram", "公綿羊", "公绵羊" },
    lamb = { "Lamb", "小綿羊", "小绵羊" },
    cow = { "Cow", "母牛" },
    bull = { "Bull", "公牛" },
    raccoon = { "Raccoon", "浣熊" },
    rat = { "Male Rat (Buck)", "公老鼠" },
    ratbaby = { "Rat Pup", "小老鼠" },
    ratfemale = { "Female Rat (Doe)", "母老鼠" },
    cowcalf = { "Calf", "小牛" },
}

local WILD_SOURCE_SUFFIXES = {
    " (Wild)",
    " (野生)",
}

local function shouldRunClientRepair()
    return not (isServer() and not isClient())
end

local function translatedText(key)
    if not key or key == "" then return nil end

    local text = getTextOrNull and getTextOrNull(key) or nil
    if text and text ~= "" then return text end

    text = getText(key)
    if text and text ~= "" and text ~= key then return text end
    return nil
end

local function setTranslatedName(item, name)
    item:setName(name)
    pcall(function()
        item:setCustomName(true)
    end)
end

local function findMeatQualityKey(currentName)
    if not currentName then return nil end

    for sourceName, qualityKey in pairs(MEAT_QUALITY_KEY_BY_SOURCE_NAME) do
        if string.find(currentName, sourceName, 1, true) then
            return qualityKey
        end
    end
    return nil
end

local function buildTranslatedMeatName(item)
    local baseNameKey = MEAT_BASE_NAME_KEYS[item:getFullType()]
    if not baseNameKey then return nil end

    local qualityKey = findMeatQualityKey(item:getName())
    if not qualityKey then return nil end

    local baseName = translatedText(baseNameKey)
    local qualityName = translatedText(qualityKey)
    if not baseName or not qualityName then return nil end

    return getText("IGUI_AnimalMeat", baseName, qualityName)
end

local function stripKnownWildSuffix(name)
    if not name then return nil, false end

    for _, suffix in ipairs(WILD_SOURCE_SUFFIXES) do
        if string.sub(name, -#suffix) == suffix then
            return string.sub(name, 1, #name - #suffix), true
        end
    end
    return name, false
end

local function sourceAnimalNameMatches(name, animalType, breed)
    local baseName = stripKnownWildSuffix(name)
    local typeNames = ANIMAL_TYPE_SOURCE_NAMES[animalType]
    if not baseName or not typeNames then return false end

    local breedNames = breed and BREED_SOURCE_NAMES[breed] or nil
    if breedNames then
        for _, breedName in ipairs(breedNames) do
            for _, typeName in ipairs(typeNames) do
                if baseName == breedName .. " " .. typeName then
                    return true
                end
            end
        end
    end

    for _, typeName in ipairs(typeNames) do
        if baseName == typeName then
            return true
        end
    end
    return false
end

local function buildTranslatedAutoAnimalName(corpse)
    local animalType = corpse and corpse:getAnimalType()
    if not animalType or animalType == "" then return nil end

    local typeName = translatedText("IGUI_AnimalType_" .. animalType)
    if not typeName then return nil end

    local breed = corpse:getBreed()
    local breedName = breed and translatedText("IGUI_Breed_" .. breed) or nil
    local name = breedName and (breedName .. " " .. typeName) or typeName

    local _baseName, isWild = stripKnownWildSuffix(corpse:getCustomName())
    if isWild then
        local wild = translatedText("IGUI_Animal_Wild")
        if wild then
            name = name .. " (" .. wild .. ")"
        end
    end

    return name
end

local function getCorpseFromItem(item)
    if not item then return nil end

    local corpse = item:getDeadBodyObject()
    if corpse then return corpse end

    local ok, loadedCorpse = pcall(function()
        return item:loadCorpseFromByteData(nil)
    end)
    if ok then return loadedCorpse end
    return nil
end

local function buildTranslatedAnimalCorpseName(item)
    if item:getFullType() ~= ANIMAL_CORPSE_TYPE then return nil end

    local corpse = getCorpseFromItem(item)
    if not corpse or not corpse:isAnimal() then return nil end

    local corpseName = corpse:getCustomName()
    local animalName = corpseName
    if not animalName or animalName == "" or sourceAnimalNameMatches(corpseName, corpse:getAnimalType(), corpse:getBreed()) then
        animalName = buildTranslatedAutoAnimalName(corpse)
    end
    if not animalName or animalName == "" then return nil end

    local key = corpse:isAnimalSkeleton() and "IGUI_Item_AnimalSkeleton" or "IGUI_Item_AnimalCorpse"
    return getText(key, animalName)
end

local function fixAnimalProductName(item)
    if not item then return 0 end

    local newName = buildTranslatedAnimalCorpseName(item) or buildTranslatedMeatName(item)
    local currentName = item:getName()
    if not newName or not currentName or newName == currentName then return 0 end

    setTranslatedName(item, newName)
    return 1
end

local function fixContainer(container)
    if not container then return 0 end
    if instanceof and not instanceof(container, "ItemContainer") then return 0 end

    local stack = { container }
    local fixed = 0
    while #stack > 0 do
        local currentContainer = table.remove(stack)
        local items = currentContainer and currentContainer:getItems()
        if items then
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                fixed = fixed + fixAnimalProductName(item)

                if item and item.IsInventoryContainer and item:IsInventoryContainer() then
                    local childContainer = item:getInventory()
                    if childContainer then
                        table.insert(stack, childContainer)
                    end
                end
            end
        end
    end
    return fixed
end

local function getPlayerByIndex(playerIndex)
    if getSpecificPlayer then
        return getSpecificPlayer(playerIndex)
    end
    if playerIndex == 0 and getPlayer then
        return getPlayer()
    end
    return nil
end

local function fixPlayerItems(playerObj)
    if not playerObj then return 0 end
    return fixContainer(playerObj:getInventory())
end

local function fixInventoryPage(page)
    local pane = page and page.inventoryPane
    return fixContainer(pane and pane.inventory)
end

local function fixOpenInventoryPages()
    if not getPlayerInventory or not getPlayerLoot then return 0 end

    local fixed = 0
    for playerIndex = 0, 3 do
        if getPlayerByIndex(playerIndex) then
            fixed = fixed + fixInventoryPage(getPlayerInventory(playerIndex))
            fixed = fixed + fixInventoryPage(getPlayerLoot(playerIndex))
        end
    end
    return fixed
end

local function getPrimaryPlayer()
    return getPlayerByIndex(0)
end

local function onCreatePlayer(_playerIndex, playerObj)
    if not shouldRunClientRepair() then return end
    fixPlayerItems(playerObj)
end
Events.OnCreatePlayer.Add(onCreatePlayer)

local function onGameStart()
    if not shouldRunClientRepair() then return end

    local fixed = fixPlayerItems(getPrimaryPlayer())
    if fixed > 0 then
        print(TAG .. " [AnimalProductName] Fixed persisted animal product names: " .. tostring(fixed))
    end
end
Events.OnGameStart.Add(onGameStart)

local function onFillContainer(_roomName, _containerType, container)
    if not shouldRunClientRepair() then return end
    fixContainer(container)
end
Events.OnFillContainer.Add(onFillContainer)

local function onContainerUpdate()
    if not shouldRunClientRepair() then return end
    fixOpenInventoryPages()
end
Events.OnContainerUpdate.Add(onContainerUpdate)

local function onRefreshInventoryWindowContainers(_page, state)
    if state ~= "end" or not shouldRunClientRepair() then return end
    fixOpenInventoryPages()
end
Events.OnRefreshInventoryWindowContainers.Add(onRefreshInventoryWindowContainers)

local function onEveryOneMinute()
    if not shouldRunClientRepair() then return end
    fixPlayerItems(getPrimaryPlayer())
    fixOpenInventoryPages()
end
Events.EveryOneMinute.Add(onEveryOneMinute)
