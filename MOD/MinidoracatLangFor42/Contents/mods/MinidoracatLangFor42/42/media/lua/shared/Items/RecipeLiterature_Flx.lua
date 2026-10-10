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
-- 中文名寫成 UTF-8 位元組的十進位跳脫，行尾註解是原文：直接寫的非 ASCII 字面值會被 Kahlua 截壞、
-- 實機永遠比不中（verify_mod 4b；scripts/test_source_language_names.lua）。
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
    ["\230\186\150\229\130\153\230\179\149\230\163\141\233\186\181\229\140\133\229\156\152"] = "MakeBaguetteDough", -- 準備法棍麵包團
    ["\232\163\189\228\189\156\232\187\159\233\164\133"] = "MakeBiscuits", -- 製作軟餅
    ["\232\163\189\228\189\156\233\186\181\229\140\133\233\186\181\231\179\176"] = "MakeBreadDough", -- 製作麵包麵糰
    ["\232\163\189\228\189\1564\229\128\139\230\141\178\229\191\131\232\143\156\229\141\183"] = "MakeCabbageRolls", -- 製作4個捲心菜卷
    ["\232\163\189\228\189\156\232\155\139\231\179\149\233\186\181\231\179\138"] = "MakeCakeBatter", -- 製作蛋糕麵糊
    ["\232\163\189\228\189\156\229\183\167\229\133\139\229\138\155\232\177\134\233\164\133\228\185\190"] = "MakeChocolateChipCookieDough", -- 製作巧克力豆餅乾
    ["\232\163\189\228\189\156\229\183\167\229\133\139\229\138\155\230\155\178\229\165\135"] = "MakeChocolateCookieDough", -- 製作巧克力曲奇
    ["\232\163\189\228\189\156\231\130\184\230\180\139\232\148\165\229\156\136"] = "MakeFriedOnionRings", -- 製作炸洋蔥圈
    ["\232\163\189\228\189\156\231\130\184\232\157\166"] = "MakeFriedShrimp", -- 製作炸蝦
    ["\232\163\189\228\189\156\231\137\155\230\178\185\230\158\156\233\134\172"] = "MakeGuacamole", -- 製作牛油果醬
    ["\232\163\189\228\189\156\233\134\131\232\163\189\233\163\159\229\147\129\231\189\144\233\160\173"] = "MakeJar", -- 製作醃製食品罐頭
    ["\232\163\189\228\189\156\230\181\183\232\139\148\229\140\133\233\163\175"] = "MakeMaki", -- 製作海苔包飯
    ["\232\163\189\228\189\156\231\135\149\233\186\165\230\155\178\229\165\135"] = "MakeOatmealCookieDough", -- 製作燕麥曲奇
    ["\232\163\189\228\189\156\233\163\175\231\179\176"] = "MakeOnigiri", -- 製作飯糰
    ["\232\163\189\228\189\156\233\164\161\233\164\133\233\186\181\231\179\176"] = "MakePieDough", -- 製作餡餅麵糰
    ["\232\163\189\228\189\156\230\138\171\232\150\169"] = "MakePizza", -- 製作披薩
    ["\232\163\189\228\189\156\232\132\134\233\164\133\230\155\178\229\165\135"] = "MakeShortbreadCookieDough", -- 製作脆餅曲奇
    ["\232\163\189\228\189\156\231\179\150\233\164\133\228\185\190"] = "MakeSugarCookieDough", -- 製作糖餅乾
    ["\232\163\189\228\189\156\229\163\189\229\143\184"] = "MakeSushi", -- 製作壽司
    ["\230\186\150\229\130\153\231\145\170\232\138\172\232\155\139\231\179\149"] = "PrepareMuffins", -- 準備瑪芬蛋糕

    -- CN
    ["\229\135\134\229\164\135\230\179\149\230\163\141\233\157\162\229\140\133\229\155\162"] = "MakeBaguetteDough", -- 准备法棍面包团
    ["\229\136\182\228\189\156\232\189\175\233\165\188"] = "MakeBiscuits", -- 制作软饼
    ["\229\136\182\228\189\156\233\157\162\229\140\133\233\157\162\229\155\162"] = "MakeBreadDough", -- 制作面包面团
    ["\229\136\182\228\189\1564\228\184\170\229\141\183\229\191\131\232\143\156\229\141\183"] = "MakeCabbageRolls", -- 制作4个卷心菜卷
    ["\229\136\182\228\189\156\232\155\139\231\179\149\233\157\162\231\179\138"] = "MakeCakeBatter", -- 制作蛋糕面糊
    ["\229\136\182\228\189\156\229\183\167\229\133\139\229\138\155\232\177\134\233\165\188\229\185\178"] = "MakeChocolateChipCookieDough", -- 制作巧克力豆饼干
    ["\229\136\182\228\189\156\229\183\167\229\133\139\229\138\155\230\155\178\229\165\135"] = "MakeChocolateCookieDough", -- 制作巧克力曲奇
    ["\229\136\182\228\189\156\231\130\184\230\180\139\232\145\177\229\156\136"] = "MakeFriedOnionRings", -- 制作炸洋葱圈
    ["\229\136\182\228\189\156\231\130\184\232\153\190"] = "MakeFriedShrimp", -- 制作炸虾
    ["\229\136\182\228\189\156\231\137\155\230\178\185\230\158\156\233\133\177"] = "MakeGuacamole", -- 制作牛油果酱
    ["\229\136\182\228\189\156\232\133\140\229\136\182\233\163\159\229\147\129\231\189\144\229\164\180"] = "MakeJar", -- 制作腌制食品罐头
    ["\229\136\182\228\189\156\230\181\183\232\139\148\229\140\133\233\165\173"] = "MakeMaki", -- 制作海苔包饭
    ["\229\136\182\228\189\156\231\135\149\233\186\166\230\155\178\229\165\135"] = "MakeOatmealCookieDough", -- 制作燕麦曲奇
    ["\229\136\182\228\189\156\233\165\173\229\155\162"] = "MakeOnigiri", -- 制作饭团
    ["\229\136\182\228\189\156\233\166\133\233\165\188\233\157\162\229\155\162"] = "MakePieDough", -- 制作馅饼面团
    ["\229\136\182\228\189\156\230\138\171\232\144\168"] = "MakePizza", -- 制作披萨
    ["\229\136\182\228\189\156\232\132\134\233\165\188\230\155\178\229\165\135"] = "MakeShortbreadCookieDough", -- 制作脆饼曲奇
    ["\229\136\182\228\189\156\231\179\150\233\165\188\229\185\178"] = "MakeSugarCookieDough", -- 制作糖饼干
    ["\229\136\182\228\189\156\229\175\191\229\143\184"] = "MakeSushi", -- 制作寿司
    ["\229\135\134\229\164\135\231\142\155\232\138\172\232\155\139\231\179\149"] = "PrepareMuffins", -- 准备玛芬蛋糕
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
    local inv = pane and pane.inventory
    -- 開著的大容器不必每次 refresh／每遊戲分鐘逐件重掃（OpenPageScanGate_Flx.lua）
    if OpenPageScanGateFlx and OpenPageScanGateFlx.skip("RecipeLiterature", inv) then return 0 end
    return fixContainer(inv)
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
    if OpenPageScanGateFlx then OpenPageScanGateFlx.invalidate("RecipeLiterature") end
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
