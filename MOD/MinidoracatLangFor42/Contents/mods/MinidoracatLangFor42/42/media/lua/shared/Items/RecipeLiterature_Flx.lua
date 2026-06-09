-- RecipeLiterature_Flx.lua
-- 修復配方圖紙 / 計劃 / 剪報在 MP 或舊存檔中保留生成端語言名稱的問題。
--
-- PZ 42.19 的 ItemCodeOnCreate 會在部分 literature 物品生成時把
-- "{物品名}: {配方名}" 寫進 InventoryItem.name。Dedicated server 若以英文
-- 環境生成物品，client 端即使已有 ItemName / Recipes 翻譯仍會看到英文。

local TAG = "[CatLangFor42]"
local RECIPE_CLIPPING_TYPE = "Base.RecipeClipping"

local RECIPE_SCHEMATIC_TYPES = {
    "Base.ArmorSchematic",
    "Base.BSToolsSchematic",
    "Base.CookwareSchematic",
    "Base.ExplosiveSchematic",
    "Base.MeleeWeaponSchematic",
    "Base.SurvivalSchematic",
    "Base.SewingPattern",
}

local DYNAMIC_RECIPE_LITERATURE_TYPE_SET = {
    [RECIPE_CLIPPING_TYPE] = true,
}
for _, fullType in ipairs(RECIPE_SCHEMATIC_TYPES) do
    DYNAMIC_RECIPE_LITERATURE_TYPE_SET[fullType] = true
end

-- RecipeClipping 在 Java 生成時把當時語言的 recipe name 存進 learnedRecipes，
-- 不是 recipe id；因此需要把已知 EN/CH/CN 名稱反查回 recipe id。
local FOOD_RECIPE_NAME_TO_KEY = {
    -- EN
    ["Prepare Baguette"] = "MakeBaguetteDough",
    ["Prepare Biscuits"] = "MakeBiscuits",
    ["Prepare Bread Dough"] = "MakeBreadDough",
    ["Make 4 Cabbage Rolls"] = "MakeCabbageRolls",
    ["Make Cake Batter"] = "MakeCakeBatter",
    ["Prepare Chocolate Chip Cookies"] = "MakeChocolateChipCookieDough",
    ["Prepare Chocolate Cookies"] = "MakeChocolateCookieDough",
    ["Prepare 2 Breaded Onion Rings"] = "MakeFriedOnionRings",
    ["Prepare Breaded Shrimp"] = "MakeFriedShrimp",
    ["Make Guacamole"] = "MakeGuacamole",
    ["Make Jar of Preserved Food"] = "MakeJar",
    ["Prepare Maki"] = "MakeMaki",
    ["Prepare Oatmeal Cookies"] = "MakeOatmealCookieDough",
    ["Prepare Onigiri"] = "MakeOnigiri",
    ["Prepare Pie Dough"] = "MakePieDough",
    ["Prepare Pizza"] = "MakePizza",
    ["Prepare Shortbread Cookies"] = "MakeShortbreadCookieDough",
    ["Prepare Sugar Cookies"] = "MakeSugarCookieDough",
    ["Prepare Sushi"] = "MakeSushi",
    ["Prepare Muffins"] = "PrepareMuffins",

    -- CH
    ["準備法棍麵包團"] = "MakeBaguetteDough",
    ["製作軟餅"] = "MakeBiscuits",
    ["製作麵包麵糰"] = "MakeBreadDough",
    ["製作4個捲心菜卷"] = "MakeCabbageRolls",
    ["製作蛋糕麵糊"] = "MakeCakeBatter",
    ["製作巧克力豆餅乾"] = "MakeChocolateChipCookieDough",
    ["製作巧克力曲奇"] = "MakeChocolateCookieDough",
    ["製作炸洋蔥圈"] = "MakeFriedOnionRings",
    ["製作炸蝦"] = "MakeFriedShrimp",
    ["製作牛油果醬"] = "MakeGuacamole",
    ["製作醃製食品罐頭"] = "MakeJar",
    ["製作海苔包飯"] = "MakeMaki",
    ["製作燕麥曲奇"] = "MakeOatmealCookieDough",
    ["製作飯糰"] = "MakeOnigiri",
    ["製作餡餅麵糰"] = "MakePieDough",
    ["製作披薩"] = "MakePizza",
    ["製作脆餅曲奇"] = "MakeShortbreadCookieDough",
    ["製作糖餅乾"] = "MakeSugarCookieDough",
    ["製作壽司"] = "MakeSushi",
    ["準備瑪芬蛋糕"] = "PrepareMuffins",

    -- CN
    ["准备法棍面包团"] = "MakeBaguetteDough",
    ["制作软饼"] = "MakeBiscuits",
    ["制作面包面团"] = "MakeBreadDough",
    ["制作4个卷心菜卷"] = "MakeCabbageRolls",
    ["制作蛋糕面糊"] = "MakeCakeBatter",
    ["制作巧克力豆饼干"] = "MakeChocolateChipCookieDough",
    ["制作巧克力曲奇"] = "MakeChocolateCookieDough",
    ["制作炸洋葱圈"] = "MakeFriedOnionRings",
    ["制作炸虾"] = "MakeFriedShrimp",
    ["制作牛油果酱"] = "MakeGuacamole",
    ["制作腌制食品罐头"] = "MakeJar",
    ["制作海苔包饭"] = "MakeMaki",
    ["制作燕麦曲奇"] = "MakeOatmealCookieDough",
    ["制作饭团"] = "MakeOnigiri",
    ["制作馅饼面团"] = "MakePieDough",
    ["制作披萨"] = "MakePizza",
    ["制作脆饼曲奇"] = "MakeShortbreadCookieDough",
    ["制作糖饼干"] = "MakeSugarCookieDough",
    ["制作寿司"] = "MakeSushi",
    ["准备玛芬蛋糕"] = "PrepareMuffins",
}

local function shouldRunClientRepair()
    return not (isServer() and not isClient())
end

local function getSingleLearnedRecipe(item)
    local recipes = item and item:getLearnedRecipes()
    if not recipes or recipes:size() ~= 1 then return nil end
    return recipes:get(0)
end

local function getTranslatedRecipeName(recipe)
    if not recipe or recipe == "" or not Translator then return nil end

    local translatedName = Translator.getRecipeName(recipe)
    if translatedName and translatedName ~= "" and translatedName ~= recipe then
        return translatedName
    end

    local recipeKey = FOOD_RECIPE_NAME_TO_KEY[recipe]
    if not recipeKey then return translatedName end

    translatedName = Translator.getRecipeName(recipeKey)
    if translatedName and translatedName ~= "" then
        return translatedName
    end
    return recipe
end

local function getTranslatedItemName(item)
    local scriptItem = item and item:getScriptItem()
    local displayName = scriptItem and scriptItem:getDisplayName()
    if displayName and displayName ~= "" and displayName ~= item:getFullType() then
        return displayName
    end
    return item and item:getDisplayName()
end

local function buildTranslatedRecipeLiteratureName(item)
    local recipe = getSingleLearnedRecipe(item)
    if not recipe or recipe == "" then return nil end

    local itemName = getTranslatedItemName(item)
    local recipeName = getTranslatedRecipeName(recipe)
    if not itemName or itemName == "" or not recipeName or recipeName == "" then return nil end

    return getText("IGUI_MagazineNameNoIssue", itemName, recipeName)
end

local function fixRecipeLiteratureName(item)
    if not item then return 0 end
    if not DYNAMIC_RECIPE_LITERATURE_TYPE_SET[item:getFullType()] then return 0 end

    local newName = buildTranslatedRecipeLiteratureName(item)
    local currentName = item:getName()
    if not newName or not currentName or newName == currentName then return 0 end

    item:setName(newName)

    local modData = item:getModData()
    if modData and modData.collectibleKey ~= nil then
        modData.collectibleKey = newName
    end

    return 1
end

local function fixContainer(container)
    if not container or not instanceof(container, "ItemContainer") then return 0 end

    local stack = { container }
    local fixed = 0
    while #stack > 0 do
        local currentContainer = table.remove(stack)
        local items = currentContainer and currentContainer:getItems()
        if items then
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                fixed = fixed + fixRecipeLiteratureName(item)

                if item and item:IsInventoryContainer() then
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
        if getSpecificPlayer(playerIndex) then
            fixed = fixed + fixInventoryPage(getPlayerInventory(playerIndex))
            fixed = fixed + fixInventoryPage(getPlayerLoot(playerIndex))
        end
    end
    return fixed
end

local function getPrimaryPlayer()
    return getSpecificPlayer(0) or getPlayer()
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
        print(TAG .. " [RecipeLiterature] Fixed persisted recipe literature names: " .. tostring(fixed))
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
