-- 測試 EvolvedRecipeName_Flx.lua 的 fixItemName（演化食譜句式名固化英文修復）
-- 執行：lua scripts/test_evolved_recipe_name.lua（須在 repo 根目錄，dofile 走相對路徑）
--
-- 情境前提：MP dedicated server 語言=EN、client 語言=CH。
-- server 端 ISAddItemInRecipe.checkName 以英文組名後 setName，經 InventoryItem
-- save/load 的 flag 8 同步到 client，於是 this.name（＝getDisplayName()）整串英文。
-- 本檔的修復是「以本機語言重跑官方 checkName」，故測試預設載入 vanilla 的
-- ISAddItemInRecipe.lua 跑真實演算法；找不到 vanilla 時退回 stub 版（只驗守衛）。
--
-- vanilla 路徑可用環境變數 PZ_PATH 覆蓋（同 scripts/*.py 慣例）。

local PZ_PATH = os.getenv("PZ_PATH") or "D:/SteamLibrary/steamapps/common/ProjectZomboid"
local VANILLA_CHECKNAME = PZ_PATH .. "/media/lua/shared/TimedActions/ISAddItemInRecipe.lua"

-- ============ PZ global stubs（模擬 CH client） ============

local FAKE_TEXT = {
    ["ContextMenu_FoodType_Game"] = "野味",
    ["ContextMenu_FoodType_Fish"] = "魚",
    ["ContextMenu_FoodType_Dressing"] = "調味醬",
    ["ContextMenu_FoodType_Vegetables"] = "蔬菜",
    ["ContextMenu_FoodType_Bread"] = "麵包",
    ["ContextMenu_FoodType_Cheese"] = "起司",
    ["ContextMenu_EvolvedRecipe_Roasted Vegetables"] = "燒烤",
    -- vanilla 實況：key 不同、譯文相同
    ["ContextMenu_EvolvedRecipe_SoupBucket"] = "燉湯",
    ["ContextMenu_EvolvedRecipe_SoupBucket2"] = "燉湯",
    ["ContextMenu_EvolvedRecipe_Stew"] = "燉菜",
    ["ContextMenu_EvolvedRecipe_Soup"] = "湯",
    ["ContextMenu_EvolvedRecipe_RecipeName"] = "%1 %2",
    ["ContextMenu_EvolvedRecipe_RecipeNameNew"] = "%1 %2 配 %3",
    ["ContextMenu_EvolvedRecipe_and"] = "和",
    ["ContextMenu_EvolvedRecipe_comma"] = ",",
}

function getText(key, a, b, c)
    local value = FAKE_TEXT[key]
    if not value then return key end
    if a ~= nil then value = value:gsub("%%1", function() return tostring(a) end) end
    if b ~= nil then value = value:gsub("%%2", function() return tostring(b) end) end
    if c ~= nil then value = value:gsub("%%3", function() return tostring(c) end) end
    return value
end

-- fullType → { name = CH 顯示名, foodType = FoodType }
local ITEM_DB = {
    ["Base.RabbitMeat"]      = { name = "兔肉",   foodType = "Game" },
    ["Base.SmallAnimalMeat"] = { name = "小獸肉", foodType = "Game" },
    ["Base.FishFillet"]      = { name = "魚片",   foodType = "Fish" },
    ["Base.Perch"]           = { name = "鱸魚",   foodType = "Fish" },
    ["Base.Soysauce"]        = { name = "醬油",   foodType = "Dressing" },
    ["Base.Carrots"]         = { name = "胡蘿蔔", foodType = "Vegetables" },
    ["Base.BreadSlices"]     = { name = "麵包片", foodType = "Bread" },
    ["Base.Cheese"]          = { name = "起司",   foodType = "Cheese" },
}

function isItemFood(fullType) return ITEM_DB[fullType] ~= nil end
function getItemFoodType(fullType) return ITEM_DB[fullType] and ITEM_DB[fullType].foodType end
function getItemDisplayName(fullType) return ITEM_DB[fullType] and ITEM_DB[fullType].name or fullType end
-- Lua 全域綁的是 LuaManager.java:8694 `return item != null ? item.evolvedRecipeName : null`，
-- 而 Item.evolvedRecipeName 只有腳本寫了 `EvolvedRecipeName=` 才有值——多數食材是 nil，
-- 所以 vanilla checkName 的 `getItemEvolvedRecipeName(food) or getItemDisplayName(food)`
-- 常走後半段。stub 必須照這個語意回 nil，否則測不到真實路徑。
function getItemEvolvedRecipeName(fullType)
    return ITEM_DB[fullType] and ITEM_DB[fullType].evolvedRecipeName or nil
end
function hasItemTag(_fullType, _tag) return false end
ItemTag = { MINOR_INGREDIENT = "MINOR_INGREDIENT" }

function isServer() return false end
function isClient() return true end
function getSpecificPlayer() return nil end
function getPlayer() return nil end
function getPlayerInventory() return nil end
function getPlayerLoot() return nil end

ISInventoryPage = { dirtyUI = function() end }

local noopEvent = { Add = function() end }
Events = setmetatable({}, { __index = function() return noopEvent end })

-- ============ Java 容器／物品 stub ============

local function arrayList(entries)
    local list = { _entries = entries or {} }
    function list:size() return #self._entries end
    function list:get(i) return self._entries[i + 1] end   -- Java 0-based
    function list:isEmpty() return #self._entries == 0 end
    return list
end

local FoodProto = {}
FoodProto.__index = FoodProto
function FoodProto:getFullType() return self._fullType end
function FoodProto:getType() return (self._fullType:gsub("^.*%.", "")) end
function FoodProto:getDisplayName() return self._name end   -- Java 實作即 raw this.name
function FoodProto:setName(name) self._name = name end
function FoodProto:isCustomName() return self._customName == true end
function FoodProto:IsInventoryContainer() return false end
function FoodProto:getExtraItems() return self._extraItems end
function FoodProto:getSpices() return self._spices end

-- getSpices() 只定義在 Food.java:2013，InventoryItem 完全沒有這個方法——
-- stub 必須忠實反映，否則「非 Food 守衛」那案在守衛被拔掉時仍會通過（假鑑別力）。
local function makeFood(spec)
    local item = setmetatable({
        _fullType = spec.fullType or "Base.PanFriedVegetables2",
        _name = spec.name,
        _customName = spec.customName,
        _extraItems = spec.extraItems and arrayList(spec.extraItems) or nil,
        _isFood = spec.isFood ~= false,
    }, FoodProto)
    if spec.isFood == false then
        item.getSpices = function() error("getSpices is Food-only（InventoryItem 沒有這個方法）") end
    else
        item._spices = spec.spices and arrayList(spec.spices) or nil
    end
    return item
end

-- 巢狀容器 stub：ItemContainer.getItems()，內含物可再是容器
local function makeContainer(items, opts)
    opts = opts or {}
    return {
        __isContainer = true,
        getItems = function() return opts.nilItems and nil or arrayList(items or {}) end,
    }
end

local function makeBag(childContainer)
    return {
        _isFood = false,
        IsInventoryContainer = function() return true end,
        getInventory = function() return childContainer end,
    }
end

function instanceof(obj, cls)
    if cls == "Food" then return type(obj) == "table" and obj._isFood == true end
    if cls == "ItemContainer" then return type(obj) == "table" and obj.__isContainer == true end
    return false
end

-- ============ ScriptManager stub ============

-- getFullResultItem() 回傳腳本原始字面值（EvolvedRecipe.java:670），本檔索引拿它當鍵，
-- 對齊 vanilla 決定食譜適用性的權威路徑 RecipeManager.getEvolvedRecipe
-- （`baseItem.getFullType().equals(recipe.resultItem)`，RecipeManager.java:505）。
local RecipeProto = {}
RecipeProto.__index = RecipeProto
function RecipeProto:getFullResultItem() return self._result end
function RecipeProto:getUntranslatedName() return self._name end

local RECIPES = {
    setmetatable({ _name = "Roasted Vegetables", _result = "Base.PanFriedVegetables2" }, RecipeProto),
    -- **key 不同但譯文相同** → 可合併。這正是 vanilla 的 BucketOfSoup ←
    -- SoupBucket/SoupBucket2：拿 key 比會誤判成不可判而整組不修（實機 log 抓到）。
    setmetatable({ _name = "SoupBucket", _result = "Base.BucketOfSoup" }, RecipeProto),
    setmetatable({ _name = "SoupBucket2", _result = "Base.BucketOfSoup" }, RecipeProto),
    -- 譯文不同 → 無法消歧，必須整個跳過而不是亂猜一個
    setmetatable({ _name = "Stew", _result = "Base.AmbiguousBowl" }, RecipeProto),
    setmetatable({ _name = "Soup", _result = "Base.AmbiguousBowl" }, RecipeProto),
    -- 無 module 前綴：CreateItem 的 moduleDefaultsToBase=true，產物實際是 Base.MyStew
    setmetatable({ _name = "Stew", _result = "MyStew" }, RecipeProto),
}

function getScriptManager()
    return { getAllEvolvedRecipesList = function() return arrayList(RECIPES) end }
end

-- ============ 官方 checkName：優先載 vanilla，否則 stub ============

local usingVanillaCheckName = false
do
    local f = io.open(VANILLA_CHECKNAME, "r")
    if f then
        f:close()
        ISBaseTimedAction = { derive = function() return { new = function() end } end }
        function sendItemStats() end
        -- vanilla 檔頭是 require "TimedActions/ISBaseTimedAction"，離線環境沒有搜尋路徑
        package.preload["TimedActions/ISBaseTimedAction"] = function() return ISBaseTimedAction end
        local ok = pcall(dofile, VANILLA_CHECKNAME)
        usingVanillaCheckName = ok and ISAddItemInRecipe ~= nil and ISAddItemInRecipe.checkName ~= nil
    end
    if not usingVanillaCheckName then
        ISAddItemInRecipe = {
            checkName = function(baseItem, _recipe) baseItem:setName("STUB") end,
        }
    end
end

-- ============ 載入待測檔案 ============

dofile("MOD/MinidoracatLangFor42/Contents/mods/MinidoracatLangFor42/42/media/lua/shared/Items/EvolvedRecipeName_Flx.lua")

local fixItemName = EvolvedRecipeNameFlx.fixItemName

-- ============ 測試框架 ============

local passed, failed = 0, 0

local function check(label, actual, expected)
    if actual == expected then
        passed = passed + 1
        print(string.format("  ok   %-58s %s", label, tostring(actual)))
    else
        failed = failed + 1
        print(string.format("  FAIL %-58s got=%s want=%s", label, tostring(actual), tostring(expected)))
    end
end

print("vanilla checkName: " .. (usingVanillaCheckName and VANILLA_CHECKNAME or "找不到，改用 stub（只驗守衛分支）"))
print("")

-- ============ 守衛分支（不依賴 vanilla） ============

print("[守衛] 不該動的情形")

-- 守衛案一律連名稱一起斷言：「回 0」不等於「一字未改」，
-- 前後自比對「先改再改回來」也是 0（同 scripts/test_item_name_fix.lua 的做法）。
local function checkUntouched(label, spec)
    local item = makeFood(spec)
    check(label, fixItemName(item), 0)
    check("  名稱未被動到", item:getDisplayName(), spec.name)
end

check("nil 物品", fixItemName(nil), 0)

checkUntouched("非 Food（instanceof 失敗，且不得碰 getSpices）", {
    name = "Game Roast", extraItems = { "Base.RabbitMeat" }, isFood = false,
})

checkUntouched("玩家自訂名／unique recipe 名", {
    name = "阿嬤的私房菜", customName = true,
    extraItems = { "Base.RabbitMeat", "Base.SmallAnimalMeat" }, spices = { "Base.Soysauce" },
})

checkUntouched("extraItems 與 spices 皆空", {
    name = "Roast", extraItems = {}, spices = {},
})

checkUntouched("兩者皆 nil", { name = "Roast" })

checkUntouched("type 不在食譜索引內（非演化食譜產物）", {
    fullType = "SomeMod.MysteryStew", name = "Mystery Stew",
    extraItems = { "Base.RabbitMeat", "Base.SmallAnimalMeat" },
})

do  -- 查不到 recipe 必須早退，不能靠 pcall 吞掉 checkName 的錯
    local saved = ISAddItemInRecipe.checkName
    local calls = 0
    ISAddItemInRecipe.checkName = function(...) calls = calls + 1 return saved(...) end
    fixItemName(makeFood({
        fullType = "SomeMod.MysteryStew", name = "Mystery Stew",
        extraItems = { "Base.RabbitMeat" },
    }))
    check("  查不到 recipe 時 checkName 未被呼叫", calls, 0)
    ISAddItemInRecipe.checkName = saved
end

do  -- checkName 拋錯時不得炸掉事件鏈
    local saved = ISAddItemInRecipe.checkName
    ISAddItemInRecipe.checkName = function() error("boom") end
    check("checkName 拋錯被 pcall 攔下", fixItemName(makeFood({
        name = "Game Roast", extraItems = { "Base.RabbitMeat", "Base.SmallAnimalMeat" },
    })), 0)
    ISAddItemInRecipe.checkName = saved
end

do  -- checkName 不是原子的：食材段先 setName 才跑調味料段，中途拋錯留下半成品名
    local saved = ISAddItemInRecipe.checkName
    ISAddItemInRecipe.checkName = function(baseItem)
        baseItem:setName("PARTIAL-LOCAL-NAME")
        error("boom after setName")
    end
    local item = makeFood({
        name = "Game Roast with Soy Sauce",
        extraItems = { "Base.RabbitMeat", "Base.SmallAnimalMeat" }, spices = { "Base.Soysauce" },
    })
    check("半途拋錯回報未變動", fixItemName(item), 0)
    check("  半成品名已復原", item:getDisplayName(), "Game Roast with Soy Sauce")
    ISAddItemInRecipe.checkName = saved
end

do  -- checkName 不存在時必須早退（升版 SOP 必查項）
    local saved = ISAddItemInRecipe.checkName
    ISAddItemInRecipe.checkName = nil
    check("checkName 不存在時早退", fixItemName(makeFood({
        name = "Game Roast", extraItems = { "Base.RabbitMeat", "Base.SmallAnimalMeat" },
    })), 0)
    ISAddItemInRecipe.checkName = saved
end

print("")
print("[索引] resultItem → recipe")

do
    local index = EvolvedRecipeNameFlx.rebuildIndex()
    check("鍵是 fullType，不是 bare type", index["Base.PanFriedVegetables2"] ~= nil, true)
    check("  沒有 bare type 形式的鍵", index["PanFriedVegetables2"], nil)
    -- 消歧比的是譯文不是 key：SoupBucket/SoupBucket2 key 不同、譯文都是「燉湯」
    check("同 result、key 不同但譯文相同 → 合併", type(index["Base.BucketOfSoup"]), "table")
    check("同 result、譯文不同 → 標記跳過", index["Base.AmbiguousBowl"], false)
    check("無 module 前綴補成 Base.", index["Base.MyStew"] ~= nil, true)
end

do  -- 跨 module 同名不得誤配：SomeMod.PanFriedVegetables2 不是 vanilla 食譜的產物
    local item = makeFood({
        fullType = "SomeMod.PanFriedVegetables2", name = "Third-party preserved name",
        extraItems = { "Base.RabbitMeat", "Base.SmallAnimalMeat" }, spices = { "Base.Soysauce" },
    })
    check("跨 module 同名不誤配", fixItemName(item), 0)
    check("  第三方物品名未被動到", item:getDisplayName(), "Third-party preserved name")
end

do  -- ambiguous 標記的物品必須完全不碰
    local item = makeFood({
        fullType = "Base.AmbiguousBowl", name = "Ambiguous Stew",
        extraItems = { "Base.RabbitMeat" },
    })
    check("ambiguous resultItem 的物品不動", fixItemName(item), 0)
    check("  名稱未被動到", item:getDisplayName(), "Ambiguous Stew")
end

-- ============ dirtyUI 抑制與重入防護 ============
-- 官方 checkName 兩個出口都無條件呼叫 ISInventoryPage.dirtyUI()，而 dirtyUI
-- → refreshBackpacks() → triggerEvent("OnRefreshInventoryWindowContainers", ..., "end")
-- 正是本檔掛的事件之一，不擋就無限遞迴。

print("")
print("[重入] dirtyUI 抑制與遞迴防護")

do
    local runRepair = EvolvedRecipeNameFlx.runRepair
    local realCalls, suppressedCalls = 0, 0
    local realDirtyUI = function() realCalls = realCalls + 1 end
    ISInventoryPage.dirtyUI = realDirtyUI

    -- 模擬 checkName：修復途中呼叫 dirtyUI（此時應被換成 no-op）
    local function pretendFix(n)
        ISInventoryPage.dirtyUI()
        if ISInventoryPage.dirtyUI ~= realDirtyUI then suppressedCalls = suppressedCalls + 1 end
        return n
    end

    check("修完有改名 → 只補呼叫一次真 dirtyUI", runRepair(pretendFix, 3), 3)
    check("  修復途中的 dirtyUI 被抑制", suppressedCalls, 1)
    check("  真 dirtyUI 只跑一次", realCalls, 1)
    check("  結束後 dirtyUI 已還原", ISInventoryPage.dirtyUI == realDirtyUI, true)

    realCalls = 0
    check("修完沒改名 → 不呼叫 dirtyUI", runRepair(pretendFix, 0), 0)
    check("  真 dirtyUI 零次", realCalls, 0)

    -- 重入：dirtyUI 觸發的事件會再打進來，第二層必須直接回 0
    local depth, maxDepth = 0, 0
    local function reentrant()
        depth = depth + 1
        if depth > maxDepth then maxDepth = depth end
        if depth < 5 then runRepair(reentrant) end
        depth = depth - 1
        return 1
    end
    check("重入被擋在第二層", runRepair(reentrant), 1)
    check("  未遞迴下去", maxDepth, 1)

    check("修復函式拋錯不外洩", runRepair(function() error("boom") end), 0)
    check("  拋錯後 dirtyUI 仍已還原", ISInventoryPage.dirtyUI == realDirtyUI, true)
    check("  拋錯後重入旗標已清除", runRepair(function() return 0 end), 0)

    -- 收尾補呼叫的那次 dirtyUI 是唯一會打回本檔事件掛勾的路徑
    -- （refreshBackpacks → triggerEvent("OnRefreshInventoryWindowContainers", ..., "end")）。
    -- 旗標若在補呼叫之前就清掉，這條就不受保護，終止性只能仰賴 checkName 的冪等。
    local nestedPasses = 0
    ISInventoryPage.dirtyUI = function()
        realCalls = realCalls + 1
        nestedPasses = nestedPasses + runRepair(function() return 1 end)
    end
    realCalls = 0
    check("補呼叫 dirtyUI 時旗標仍生效", runRepair(function() return 2 end), 2)
    check("  真 dirtyUI 有跑", realCalls, 1)
    check("  它引發的巢狀 pass 被擋掉", nestedPasses, 0)

    ISInventoryPage.dirtyUI = realDirtyUI
    check("  拋錯的 dirtyUI 不外洩", runRepair(function()
        ISInventoryPage.dirtyUI = function() error("dirtyUI boom") end
        return 1
    end), 1)

    ISInventoryPage.dirtyUI = function() end
end

-- ============ 容器遍歷 ============

print("")
print("[容器] 巢狀走訪與 nil 安全")

do
    local fixContainer = EvolvedRecipeNameFlx.fixContainer

    check("非 ItemContainer 直接回 0", fixContainer({}), 0)
    check("nil 容器直接回 0", fixContainer(nil), 0)
    check("getItems() 回 nil 不炸", fixContainer(makeContainer(nil, { nilItems = true })), 0)

    local function englishRoast()
        return makeFood({
            name = "Game Roast with Soy Sauce",
            extraItems = { "Base.RabbitMeat", "Base.SmallAnimalMeat" },
            spices = { "Base.Soysauce" },
        })
    end

    if usingVanillaCheckName then
        local inner = makeContainer({ englishRoast() })
        local outer = makeContainer({ englishRoast(), makeBag(inner) })
        check("巢狀兩層各修一個", fixContainer(outer), 2)

        -- 容器環（存檔損毀／MOD）不得讓 worklist 永遠跑不完
        local a = makeContainer({})
        local b = makeContainer({ makeBag(a) })
        a.getItems = function() return arrayList({ makeBag(b) }) end
        check("容器成環不會無限迴圈", fixContainer(a), 0)
    end
end

-- ============ 真實重算（需要 vanilla checkName） ============

if not usingVanillaCheckName then
    -- 沒跑到重算組就不算通過：stub 版只驗守衛，綠燈會給人「全部驗過」的錯覺。
    -- 真的要在沒有 PZ 的機器上跑，明確加 --allow-no-vanilla。
    local allowed = false
    for _, a in ipairs(arg or {}) do
        if a == "--allow-no-vanilla" then allowed = true end
    end
    print("")
    print(string.format("passed=%d failed=%d（**已跳過真實重算組**——設定 PZ_PATH 後重跑）", passed, failed))
    if not allowed then
        print("找不到 vanilla ISAddItemInRecipe.lua，視為未通過；確定只要驗守衛請加 --allow-no-vanilla")
        os.exit(2)
    end
    os.exit(failed == 0 and 0 or 1)
end

print("")
print("[重算] 英文烘死名 → 本機語言")
-- 刻意不測 2–3 種食材類型的組合：checkName 用 pairs 疊字串，順序由 hash 決定，
-- 測了必 flaky。以下案例都是 1 型或 >max_base，與走訪順序無關。

do  -- 主場景：截圖回報的那一盤
    local item = makeFood({
        name = "Game Roast with Soy Sauce",
        extraItems = { "Base.RabbitMeat", "Base.SmallAnimalMeat" },
        spices = { "Base.Soysauce" },
    })
    check("同型食材多樣 → 收斂為食物類型名", fixItemName(item), 1)
    check("  重算結果", item:getDisplayName(), "野味 燒烤 配 醬油")
    check("冪等：再跑一次不再變動", fixItemName(item), 0)
    check("  名稱維持", item:getDisplayName(), "野味 燒烤 配 醬油")
end

do  -- 單一食材時官方會顯示食材本名而非類型名
    local item = makeFood({
        name = "Rabbit Meat Roast",
        extraItems = { "Base.RabbitMeat" },
    })
    check("單一食材 → 用食材本名", fixItemName(item), 1)
    check("  重算結果", item:getDisplayName(), "兔肉 燒烤")
end

do  -- 只有調味料沒有食材：官方走的是 RecipeName（%1 %2）不是 RecipeNameNew，
    -- 句型完全不同。vanilla 有 40/56 個食譜 CanAddSpicesEmpty=true，這條是常態。
    local item = makeFood({
        name = "Soy Sauce Roast",
        spices = { "Base.Soysauce" },
    })
    check("只有調味料 → 走 RecipeName 句型", fixItemName(item), 1)
    check("  重算結果", item:getDisplayName(), "醬油 燒烤")
end

do  -- 超過 max_base(3) 種類型時官方只留食譜名
    local item = makeFood({
        name = "Game, Fish, Vegetables and Bread Roast",
        extraItems = {
            "Base.RabbitMeat", "Base.SmallAnimalMeat",
            "Base.FishFillet", "Base.Perch",
            "Base.Carrots", "Base.BreadSlices", "Base.Cheese",
        },
    })
    check("種類過多 → 只留食譜名", fixItemName(item), 1)
    check("  重算結果", item:getDisplayName(), "燒烤")
end

do  -- 已經是中文（單人本機煮的）不該被動到
    local item = makeFood({
        name = "野味 燒烤 配 醬油",
        extraItems = { "Base.RabbitMeat", "Base.SmallAnimalMeat" },
        spices = { "Base.Soysauce" },
    })
    check("本機已正確的中文名不變動", fixItemName(item), 0)
    check("  名稱維持", item:getDisplayName(), "野味 燒烤 配 醬油")
end

print("")
print(string.format("passed=%d failed=%d", passed, failed))
os.exit(failed == 0 and 0 or 1)
