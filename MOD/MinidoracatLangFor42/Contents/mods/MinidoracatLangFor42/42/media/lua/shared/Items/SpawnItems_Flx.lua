-- SpawnItems_Flx.lua
-- 修復動態命名物品（護照、身分證等）的翻譯前綴
-- nameAfterDescriptor() 在 Java 層使用英文名稱，導致物品顯示為 "Passport: 角色名"
-- 使用事件掛鉤在物品建立後修復名稱
--
-- 注意：SpawnItems 在原始檔案中是 local 變數，無法從外部存取
-- 因此使用 Events.OnCreatePlayer + Events.OnGameStart 取代直接覆寫

local TAG = "[CatLangFor42]"

-- 需要修復的物品 fullType 列表
local NAMED_ITEM_TYPES = {
    "Base.IDcard",
    "Base.Passport",
    "Base.SpeedingTicket",
    "Base.Badge",
}

--- 修復單一物品的動態名稱
--- @param item InventoryItem 要修復的物品
local function fixItemDynamicName(item)
    if not item then return end

    local currentName = item:getName()
    if not currentName then return end

    -- nameAfterDescriptor 的格式: "{英文名}: {角色名}"
    local colonPos = string.find(currentName, ": ", 1, true)
    if not colonPos then return end

    local charPart = string.sub(currentName, colonPos) -- ": Aurora Mathias"

    -- 使用 ScriptItem 的 getDisplayName() 取得翻譯名
    -- ScriptItem.getDisplayName() 是 Java 層翻譯查詢，
    -- 會回傳當前語言的翻譯名稱（如「護照」）
    local scriptItem = item:getScriptItem()
    if not scriptItem then return end
    local translatedName = scriptItem:getDisplayName()

    local engPrefix = string.sub(currentName, 1, colonPos - 1)
    -- 只在英文前綴與翻譯名不同時才修復（避免重複處理）
    if engPrefix ~= translatedName then
        item:setName(translatedName .. charPart)
    end
end

--- 修復 DogTag 物品名稱
--- @param inv ItemContainer 背包
local function fixDogTagName(inv)
    -- DogTag 可能是透過 tag 或 type 取得
    local dogTag = inv:getFirstTagRecurse(ItemTag.DOG_TAG)
    if not dogTag then
        dogTag = inv:getFirstTypeRecurse("Necklace_DogTag")
    end
    if not dogTag then return end

    local currentName = dogTag:getName()
    if not currentName then return end

    local colonPos = string.find(currentName, ": ", 1, true)
    if not colonPos then return end

    local charPart = string.sub(currentName, colonPos)
    local scriptItem = dogTag:getScriptItem()
    if not scriptItem then return end
    local translatedName = scriptItem:getDisplayName()

    if translatedName and translatedName ~= "" then
        local engPrefix = string.sub(currentName, 1, colonPos - 1)
        if engPrefix ~= translatedName then
            dogTag:setName(translatedName .. charPart)
        end
    end
end

--- 修復玩家背包中所有動態命名物品
--- @param playerObj IsoPlayer 玩家物件
local function fixAllNamedItems(playerObj)
    if not playerObj then return end
    local inv = playerObj:getInventory()
    if not inv then return end

    for _, fullType in ipairs(NAMED_ITEM_TYPES) do
        local item = inv:getFirstTypeRecurse(fullType)
        fixItemDynamicName(item)
    end

    fixDogTagName(inv)
end

-- ============================================
-- OnCreatePlayer：新角色建立後修復動態命名
-- 在 SpawnItems.OnNewGame 之後觸發
-- ============================================
local function onCreatePlayer(playerIndex, playerObj)
    fixAllNamedItems(playerObj)
    print(TAG .. " [SpawnItems] Fixed dynamic item names for new player: " .. tostring(playerObj:getUsername()))
end

Events.OnCreatePlayer.Add(onCreatePlayer)

-- ============================================
-- OnGameStart：修復已存在存檔中的物品
-- ============================================
local function fixExistingSaveItems()
    -- 只在客戶端執行（server 端沒有 getSpecificPlayer）
    if isServer() and not isClient() then return end
    local player = getSpecificPlayer(0)
    if not player then return end

    fixAllNamedItems(player)
    print(TAG .. " [SpawnItems] Fixed existing save item names")
end

Events.OnGameStart.Add(fixExistingSaveItems)
