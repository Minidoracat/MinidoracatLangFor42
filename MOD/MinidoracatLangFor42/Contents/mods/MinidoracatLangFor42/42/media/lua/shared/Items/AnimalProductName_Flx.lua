-- AnimalProductName_Flx.lua
-- 修復 PZ 42.19 動物屍體與屠宰肉品在 MP / 舊存檔中保留生成端語言名稱的問題。
-- 另含活體動物顯示名修復：見檔尾「活體動物顯示名修復」段落。

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

-- 中文名寫成 UTF-8 位元組的十進位跳脫，行尾註解是原文：直接寫的非 ASCII 字面值會被 Kahlua 截壞、
-- 實機永遠比不中（verify_mod 4b；scripts/test_source_language_names.lua）。
local MEAT_QUALITY_KEY_BY_SOURCE_NAME = {
    ["(Prime Cut)"] = "IGUI_AnimalMeat_PrimeCut",
    ["(\228\184\138\231\173\137\232\130\137\229\161\138)"] = "IGUI_AnimalMeat_PrimeCut", -- (上等肉塊)
    ["(\228\184\138\231\173\137\232\130\137\229\157\151)"] = "IGUI_AnimalMeat_PrimeCut", -- (上等肉块)
    ["(Average Cut)"] = "IGUI_AnimalMeat_MediumCut",
    ["(\228\184\173\231\173\137\232\130\137\229\161\138)"] = "IGUI_AnimalMeat_MediumCut", -- (中等肉塊)
    ["(\228\184\173\231\173\137\232\130\137\229\157\151)"] = "IGUI_AnimalMeat_MediumCut", -- (中等肉块)
    ["(Poor Cut)"] = "IGUI_AnimalMeat_PoorCut",
    ["(\229\138\163\232\179\170\232\130\137\229\161\138)"] = "IGUI_AnimalMeat_PoorCut", -- (劣質肉塊)
    ["(\229\138\163\232\180\168\232\130\137\229\157\151)"] = "IGUI_AnimalMeat_PoorCut", -- (劣质肉块)
}

local BREED_SOURCE_NAMES = {
    leghorn = { "Leghorn", "\228\190\134\228\186\168\233\155\158", "\230\157\165\228\186\168\233\184\161" }, -- 來亨雞 / 来亨鸡
    largeblack = { "Large Black", "\229\164\167\233\187\145\232\177\172", "\229\164\167\233\187\145\231\140\170" }, -- 大黑豬 / 大黑猪
    suffolk = { "Suffolk", "\232\150\169\231\166\143\229\133\139\231\190\138", "\232\144\168\231\166\143\229\133\139\231\190\138" }, -- 薩福克羊 / 萨福克羊
    friesian = { "East Friesian", "\230\157\177\230\150\185\229\188\151\233\135\140\230\150\175\232\152\173\231\190\138", "\228\184\156\230\150\185\229\188\151\233\135\140\230\150\175\229\133\176\231\190\138", "\230\157\177\229\188\151\233\135\140\230\150\175\232\152\173\231\190\138" }, -- 東方弗里斯蘭羊 / 东方弗里斯兰羊 / 東弗里斯蘭羊
    rambouillet = { "Rambouillet", "\230\156\151\229\184\131\228\190\157\229\159\131\231\190\138" }, -- 朗布依埃羊
    angus = { "Angus", "\229\174\137\230\160\188\230\150\175\231\137\155" }, -- 安格斯牛
    simmental = { "Simmental", "\232\165\191\233\150\128\229\161\148\231\136\190\231\137\155", "\232\165\191\233\151\168\229\161\148\229\176\148\231\137\155" }, -- 西門塔爾牛 / 西门塔尔牛
    holstein = { "Holstein", "\232\141\183\230\150\175\229\157\166\231\137\155" }, -- 荷斯坦牛
    landrace = { "American Landrace", "\231\190\142\229\156\139\232\152\173\229\190\183\231\145\158\231\181\178\232\177\172", "\231\190\142\229\155\189\229\133\176\229\190\183\231\145\158\228\184\157\231\140\170", "\231\190\142\229\156\139\232\151\141\231\145\158\230\150\175\232\177\172" }, -- 美國蘭德瑞絲豬 / 美国兰德瑞丝猪 / 美國藍瑞斯豬
    rhodeisland = { "Rhode Island Red", "\231\190\133\229\190\183\229\179\182\231\180\133\233\155\158", "\231\189\151\229\190\183\229\178\155\231\186\162\233\184\161" }, -- 羅德島紅雞 / 罗德岛红鸡
    whitetailed = { "White-Tailed", "\231\153\189\229\176\190\233\185\191" }, -- 白尾鹿
    meleagris = { "Meleagris", "\231\129\171\233\155\158\229\177\172", "\231\129\171\233\184\161\229\177\158" }, -- 火雞屬 / 火鸡属
    swamp = { "Swamp", "\230\178\188\230\190\164", "\230\178\188\230\179\189" }, -- 沼澤 / 沼泽
    golden = { "Golden", "\233\135\145\232\137\178" }, -- 金色
    deer = { "Deer", "\231\153\189\232\182\179" }, -- 白足
    appalachian = { "Appalachian", "\233\152\191\229\183\180\230\139\137\229\165\145\228\186\158", "\233\152\191\229\183\180\230\139\137\229\165\145\228\186\154" }, -- 阿巴拉契亞 / 阿巴拉契亚
    cottontail = { "Cottontail", "\230\163\137\229\176\190" }, -- 棉尾
    grey = { "Gray", "\231\129\176\232\137\178" }, -- 灰色
    white = { "White", "\231\153\189\232\137\178" }, -- 白色
}

local ANIMAL_TYPE_SOURCE_NAMES = {
    gobblers = { "Tom", "\229\133\172\231\129\171\233\155\158", "\229\133\172\231\129\171\233\184\161" }, -- 公火雞 / 公火鸡
    turkeyhen = { "Hen", "\230\175\141\231\129\171\233\155\158", "\230\175\141\231\129\171\233\184\161" }, -- 母火雞 / 母火鸡
    turkeypoult = { "Poult", "\229\176\143\231\129\171\233\155\158", "\229\176\143\231\129\171\233\184\161" }, -- 小火雞 / 小火鸡
    fawndead = { "Fawn", "\230\173\187\229\176\143\233\185\191" }, -- 死小鹿
    deerdead = { "Deer", "\230\173\187\233\185\191" }, -- 死鹿
    mouse = { "Male Mouse (Buck)", "\229\133\172\229\174\182\233\188\160" }, -- 公家鼠
    mousepups = { "Mouse Pup", "\229\176\143\229\174\182\233\188\160" }, -- 小家鼠
    mousefemale = { "Female Mouse (Doe)", "\230\175\141\229\174\182\233\188\160" }, -- 母家鼠
    chick = { "Chick", "\229\176\143\233\155\158", "\229\176\143\233\184\161" }, -- 小雞 / 小鸡
    hen = { "Hen", "\230\175\141\233\155\158", "\230\175\141\233\184\161" }, -- 母雞 / 母鸡
    cockerel = { "Cockerel", "\229\133\172\233\155\158", "\229\133\172\233\184\161" }, -- 公雞 / 公鸡
    boar = { "Boar", "\229\133\172\232\177\172", "\229\133\172\231\140\170" }, -- 公豬 / 公猪
    sow = { "Sow", "\230\175\141\232\177\172", "\230\175\141\231\140\170" }, -- 母豬 / 母猪
    piglet = { "Piglet", "\229\176\143\232\177\172", "\229\176\143\231\140\170" }, -- 小豬 / 小猪
    buck = { "Buck", "\229\133\172\233\185\191" }, -- 公鹿
    doe = { "Doe", "\230\175\141\233\185\191" }, -- 母鹿
    fawn = { "Fawn", "\229\176\143\233\185\191" }, -- 小鹿
    raccoonboar = { "Male Raccoon (Boar)", "\229\133\172\230\181\163\231\134\138" }, -- 公浣熊
    raccoonsow = { "Female Raccoon (Sow)", "\230\175\141\230\181\163\231\134\138" }, -- 母浣熊
    raccoonkit = { "Baby Raccoon (Kit)", "\229\176\143\230\181\163\231\134\138" }, -- 小浣熊
    rabbuck = { "Male Rabbit (Buck)", "\229\133\172\229\133\148\229\173\144" }, -- 公兔子
    rabdoe = { "Female Rabbit (Doe)", "\230\175\141\229\133\148\229\173\144" }, -- 母兔子
    rabkitten = { "Baby Rabbit (Kitten)", "\229\176\143\229\133\148\229\173\144" }, -- 小兔子
    ewe = { "Ewe", "\230\175\141\231\182\191\231\190\138", "\230\175\141\231\187\181\231\190\138" }, -- 母綿羊 / 母绵羊
    ram = { "Ram", "\229\133\172\231\182\191\231\190\138", "\229\133\172\231\187\181\231\190\138" }, -- 公綿羊 / 公绵羊
    lamb = { "Lamb", "\229\176\143\231\182\191\231\190\138", "\229\176\143\231\187\181\231\190\138" }, -- 小綿羊 / 小绵羊
    cow = { "Cow", "\230\175\141\231\137\155" }, -- 母牛
    bull = { "Bull", "\229\133\172\231\137\155" }, -- 公牛
    raccoon = { "Raccoon", "\230\181\163\231\134\138" }, -- 浣熊
    rat = { "Male Rat (Buck)", "\229\133\172\232\128\129\233\188\160" }, -- 公老鼠
    ratbaby = { "Rat Pup", "\229\176\143\232\128\129\233\188\160" }, -- 小老鼠
    ratfemale = { "Female Rat (Doe)", "\230\175\141\232\128\129\233\188\160" }, -- 母老鼠
    cowcalf = { "Calf", "\229\176\143\231\137\155" }, -- 小牛
}

local WILD_SOURCE_SUFFIXES = {
    " (Wild)",
    " (\233\135\142\231\148\159)", -- " (野生)"
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

-- 給 ItemNameApi_Flx.lua（CatLangFor42.fixItemNames）逐件呼叫
AnimalProductNameFlx = AnimalProductNameFlx or {}
AnimalProductNameFlx.fixItemName = fixAnimalProductName

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
    local inv = pane and pane.inventory
    -- 開著的大容器不必每次 refresh／每遊戲分鐘逐件重掃（OpenPageScanGate_Flx.lua）
    if OpenPageScanGateFlx and OpenPageScanGateFlx.skip("AnimalProductName", inv) then return 0 end
    return fixContainer(inv)
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
    if OpenPageScanGateFlx then OpenPageScanGateFlx.invalidate("AnimalProductName") end
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

-- ============================================================
-- 活體動物顯示名修復：IsoAnimal.getFullName 顯示層包裝
-- ------------------------------------------------------------
-- 官方多處會把組譯結果烘焙進「活體」動物 customName 並存檔 / MP 原樣同步：
-- 牧場世界生成的幼崽（RandomizedRanchBase 直接 setCustomName 翻譯結果）、
-- 由屍體或抓取物重建動物時原樣複製屍體 customName、AnimalPacket 同步。
-- IsoAnimal.getFullName 有 customName 時原樣回傳，造成右鍵選單標題、
-- 撿起/宰殺選項、動物資訊面板、畜牧區 UI 等顯示生成端語言（如 Holstein Bull）。
--
-- 此處以 __classmetatables 包裝 getFullName：customName 完全匹配
-- 系統生成名模式（EN/CH/CN 來源名表）時，改回傳當前語言重組結果；
-- 玩家自訂名與無 customName（本就即時組譯）走原始邏輯。
-- 純顯示層：不呼叫 setCustomName、不寫存檔，MP 安全。
-- ============================================================

AnimalProductNameFlx = AnimalProductNameFlx or {}

-- 由 installAnimalCustomNameOverride 設定為 IsoAnimal 原始 getCustomName，
-- 供 translateLiveAnimalCustomName 取「未翻譯的原始 customName」，
-- 避免與後面新增的 getCustomName 覆寫互相遞迴 / 重複翻譯。
local origAnimalGetCustomName = nil

local function getLiveAnimalBreedName(animal)
    local breedName
    pcall(function()
        local data = animal:getData()
        local breed = data and data:getBreed()
        breedName = breed and breed:getName() or nil
    end)
    return breedName
end

local function translateLiveAnimalCustomName(animal)
    if not animal then return nil end

    local customName = origAnimalGetCustomName and origAnimalGetCustomName(animal) or animal:getCustomName()
    if not customName or customName == "" then return nil end

    local animalType = animal:getAnimalType()
    if not animalType or animalType == "" then return nil end

    local breed = getLiveAnimalBreedName(animal)
    if not sourceAnimalNameMatches(customName, animalType, breed) then return nil end

    local typeName = translatedText("IGUI_AnimalType_" .. animalType)
    if not typeName then return nil end

    local breedName = breed and translatedText("IGUI_Breed_" .. breed) or nil
    local name = breedName and (breedName .. " " .. typeName) or typeName

    local _baseName, hadWildSuffix = stripKnownWildSuffix(customName)
    if hadWildSuffix or animal:isWild() then
        local wild = translatedText("IGUI_Animal_Wild")
        if wild then
            name = name .. " (" .. wild .. ")"
        end
    end
    return name
end

AnimalProductNameFlx.translateLiveAnimalCustomName = translateLiveAnimalCustomName

local function installLiveAnimalNameOverride()
    if not shouldRunClientRepair() then return end

    local ok, err = pcall(function()
        local classMeta = __classmetatables[IsoAnimal.class]
        local indexTable = classMeta and classMeta.__index
        local origGetFullName = indexTable and indexTable.getFullName
        if type(origGetFullName) ~= "function" then
            error("IsoAnimal.getFullName not accessible")
        end

        indexTable.getFullName = function(self)
            local translatedOk, translated = pcall(translateLiveAnimalCustomName, self)
            if translatedOk and translated and translated ~= "" then
                return translated
            end
            return origGetFullName(self)
        end
    end)

    if not ok then
        print(TAG .. " [AnimalProductName] live animal name override unavailable: " .. tostring(err))
    end
end
installLiveAnimalNameOverride()

-- ============================================================
-- getCustomName 顯示層修復：補齊「直接讀 getCustomName」的官方 UI
-- ------------------------------------------------------------
-- 上面的 getFullName 覆寫補不到官方多處「直接讀 getCustomName()」的顯示點，例如：
--   活體 IsoAnimal：ISAnimalUI 資訊面板標題、ISAnimalGenomeUI、
--                   ISAnimalContextMenu attach 子選單、ISVehicleAnimalUI 拖車。
--   屍體 IsoDeadBody：ISDesignationAnimalZoneUI 畜牧指定區「屍體清單」（紅字，
--                     玩家回報來源）、ISAnimalContextMenu 屍體右鍵 / 取骨、
--                     ISButcherHookUI 屠宰鉤。
-- 對策：包裝 IsoAnimal 與 IsoDeadBody 兩個類別的 getCustomName，僅當原始
-- customName 完全比中「系統生成名」（sourceAnimalNameMatches，EN/CH/CN 來源名表）
-- 時，回傳當前語言重組的「動物名本身」。
--
-- 鐵則：
--   A. 只回傳動物名（如「灰色 母浣熊」），不外加 IGUI_Item_AnimalCorpse /
--      IGUI_Item_AnimalSkeleton 外殼 —— 那層由各 UI 自行 getText 包，否則雙重包殼。
--   B. 絕不呼叫 setCustomName 回寫欄位 —— 純顯示層；存檔 / load / MP 同步皆走
--      customName 欄位（非 getter），不受 Lua 覆寫影響。
--   C. 玩家自訂名不比中 → 透傳原值，零影響（改名比對 ISAnimalUI:474 兩端一致）。
-- 純顯示層、dedicated server 不安裝（shouldRunClientRepair）。
-- ============================================================

-- 純文字重組：比中系統生成名才回傳重組動物名，否則 nil。與 getCustomName 語義一致：
-- 僅當原始 customName 自身帶 (Wild)/(野生) 後綴時才補回後綴（不依 isWild 主動加）。
local function buildTranslatedNameFromParts(customName, animalType, breed)
    if not customName or customName == "" then return nil end
    if not animalType or animalType == "" then return nil end
    if not sourceAnimalNameMatches(customName, animalType, breed) then return nil end

    local typeName = translatedText("IGUI_AnimalType_" .. animalType)
    if not typeName then return nil end

    local breedName = breed and translatedText("IGUI_Breed_" .. breed) or nil
    local name = breedName and (breedName .. " " .. typeName) or typeName

    local _baseName, hadWildSuffix = stripKnownWildSuffix(customName)
    if hadWildSuffix then
        local wild = translatedText("IGUI_Animal_Wild")
        if wild then
            name = name .. " (" .. wild .. ")"
        end
    end
    return name
end

AnimalProductNameFlx.buildTranslatedNameFromParts = buildTranslatedNameFromParts

-- 活體 IsoAnimal:getCustomName 顯示層包裝
local function installAnimalCustomNameOverride()
    if not shouldRunClientRepair() then return end

    local ok, err = pcall(function()
        local classMeta = __classmetatables[IsoAnimal.class]
        local indexTable = classMeta and classMeta.__index
        local origGetCustomName = indexTable and indexTable.getCustomName
        if type(origGetCustomName) ~= "function" then
            error("IsoAnimal.getCustomName not accessible")
        end
        origAnimalGetCustomName = origGetCustomName

        indexTable.getCustomName = function(self)
            local raw = origGetCustomName(self)
            local translatedOk, translated = pcall(function()
                return buildTranslatedNameFromParts(raw, self:getAnimalType(), getLiveAnimalBreedName(self))
            end)
            if translatedOk and translated and translated ~= "" then
                return translated
            end
            return raw
        end
    end)

    if not ok then
        print(TAG .. " [AnimalProductName] live animal getCustomName override unavailable: " .. tostring(err))
    end
end
installAnimalCustomNameOverride()

-- 屍體 IsoDeadBody:getCustomName 顯示層包裝（畜牧區屍體清單等紅字殘留來源）
local function installCorpseCustomNameOverride()
    if not shouldRunClientRepair() then return end

    local ok, err = pcall(function()
        local classMeta = __classmetatables[IsoDeadBody.class]
        local indexTable = classMeta and classMeta.__index
        local origGetCustomName = indexTable and indexTable.getCustomName
        if type(origGetCustomName) ~= "function" then
            error("IsoDeadBody.getCustomName not accessible")
        end

        indexTable.getCustomName = function(self)
            local raw = origGetCustomName(self)
            local translatedOk, translated = pcall(function()
                if not self:isAnimal() then return nil end
                return buildTranslatedNameFromParts(raw, self:getAnimalType(), self:getBreed())
            end)
            if translatedOk and translated and translated ~= "" then
                return translated
            end
            return raw
        end
    end)

    if not ok then
        print(TAG .. " [AnimalProductName] dead body getCustomName override unavailable: " .. tostring(err))
    end
end
installCorpseCustomNameOverride()
