-- 測試 AnimalProductName_Flx／RecipeLiterature_Flx 以 CH／CN 生成端名稱反查回 key
-- 執行：lua scripts/test_source_language_names.lua（須在 repo 根目錄）
--
-- 兩檔的反查表收 EN／CH／CN 三種生成端語言的名稱。中文名以前直接寫在 Lua 字面值裡，
-- Kahlua 編譯時截成低位 byte（kahlua_load.lua 檔頭），實機永遠比不中：中文伺服器或
-- 舊存檔生成的動物屍體、肉品、食譜剪報，換語言後一直維持生成端的中文名。
-- 以 kahlua_load 載入待測檔，字面值照 Kahlua 的行為處理；直接 dofile 的話修前也會綠。

local kahluaDofile = dofile("scripts/kahlua_load.lua")
local ROOT = "MOD/MinidoracatLangFor42/Contents/mods/MinidoracatLangFor42/42/media/lua/shared/Items/"

-- ============ PZ global stubs（模擬 EN client） ============
local TEXT = {
    IGUI_Breed_leghorn = "Leghorn",
    IGUI_Breed_suffolk = "Suffolk",
    IGUI_Breed_largeblack = "Large Black",
    IGUI_AnimalType_hen = "Hen",
    IGUI_AnimalType_ram = "Ram",
    IGUI_AnimalType_boar = "Boar",
    IGUI_Animal_Wild = "Wild",
    IGUI_AnimalMeat = "%1 %2",
    IGUI_AnimalMeat_Beef = "Beef",
    IGUI_AnimalMeat_PrimeCut = "(Prime Cut)",
    IGUI_AnimalMeat_PoorCut = "(Poor Cut)",
    IGUI_MagazineNameNoIssue = "%1: %2",
}
local RECIPES = {
    MakeBreadDough = "Prepare Bread Dough",
    PrepareMuffins = "Prepare Muffins",
}

function getTextOrNull(key, a, b)
    local value = TEXT[key]
    if not value then return nil end
    if a ~= nil then value = value:gsub("%%1", function() return a end) end
    if b ~= nil then value = value:gsub("%%2", function() return b end) end
    return value
end
function getText(key, a, b) return getTextOrNull(key, a, b) or key end
function isServer() return false end
function isClient() return true end
function instanceof() return true end
Translator = { getRecipeName = function(name) return RECIPES[name] or name end }

local handlers = {}
Events = setmetatable({}, { __index = function(_, name)
    return { Add = function(fn) handlers[name] = fn end }
end })

local deadBodyIndex = {
    getCustomName = function(self) return self.customName end,
    isAnimal = function() return true end,
    getAnimalType = function(self) return self.animalType end,
    getBreed = function(self) return self.breed end,
}
IsoAnimal = { class = "IsoAnimal" }
IsoDeadBody = { class = "IsoDeadBody" }
__classmetatables = {
    IsoAnimal = { __index = { getFullName = function() end, getCustomName = function() end } },
    IsoDeadBody = { __index = deadBodyIndex },
}

-- ============ stubs ============
local function makeItem(def)
    return {
        getFullType = function() return def.fullType end,
        getName = function() return def.name end,
        setName = function(_, name) def.name = name end,
        setCustomName = function() end,
        getModData = function() return {} end,
        getDeadBodyObject = function() return nil end,
        getLearnedRecipes = function()
            return { size = function() return 1 end, get = function() return def.recipe end }
        end,
        getScriptItem = function() return { getDisplayName = function() return def.display end } end,
        IsInventoryContainer = function() return false end,
    }
end

local function fillContainer(def)
    local item = makeItem(def)
    local container = { getItems = function()
        return { size = function() return 1 end, get = function() return item end }
    end }
    handlers.OnFillContainer(nil, nil, container)
    return def.name
end

local passed, failed = 0, 0
local function check(label, got, expected)
    if got == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("FAIL %s\n  expected: %s\n  got:      %s", label, expected, tostring(got)))
    end
end

-- ============ AnimalProductName：屍體顯示名（IsoDeadBody:getCustomName 包裝）與肉品 ============
kahluaDofile(ROOT .. "AnimalProductName_Flx.lua")

local function corpseName(customName, animalType, breed)
    local corpse = setmetatable({ customName = customName, animalType = animalType, breed = breed },
        { __index = deadBodyIndex })
    return corpse:getCustomName()
end

check("CH 品種＋類型", corpseName("來亨雞 母雞", "hen", "leghorn"), "Leghorn Hen")
check("CN 品種＋類型", corpseName("萨福克羊 公绵羊", "ram", "suffolk"), "Suffolk Ram")
check("CH 野生後綴", corpseName("大黑豬 公豬 (野生)", "boar", "largeblack"), "Large Black Boar (Wild)")
check("EN 原名（修前即可達）", corpseName("Leghorn Hen", "hen", "leghorn"), "Leghorn Hen")
check("玩家自訂名不動", corpseName("小花", "hen", "leghorn"), "小花")

check("CH 肉品品質", fillContainer({ fullType = "Base.Beef", name = "牛肉 (上等肉塊)" }), "Beef (Prime Cut)")
check("CN 肉品品質", fillContainer({ fullType = "Base.Beef", name = "牛肉 (劣质肉块)" }), "Beef (Poor Cut)")

-- ============ RecipeLiterature：食譜剪報的 learnedRecipes 存生成端語言的配方名 ============
handlers = {}
kahluaDofile(ROOT .. "RecipeLiterature_Flx.lua")

check("CH 配方名剪報",
    fillContainer({ fullType = "Base.RecipeClipping", name = "食譜剪報: 製作麵包麵糰",
        recipe = "製作麵包麵糰", display = "Recipe Clipping" }),
    "Recipe Clipping: Prepare Bread Dough")
check("CN 配方名剪報",
    fillContainer({ fullType = "Base.RecipeClipping", name = "食谱剪报: 准备玛芬蛋糕",
        recipe = "准备玛芬蛋糕", display = "Recipe Clipping" }),
    "Recipe Clipping: Prepare Muffins")

print(string.format("passed=%d failed=%d", passed, failed))
os.exit(failed == 0 and 0 or 1)
