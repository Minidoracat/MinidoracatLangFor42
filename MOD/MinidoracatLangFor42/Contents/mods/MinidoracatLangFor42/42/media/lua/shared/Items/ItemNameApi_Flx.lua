-- ItemNameApi_Flx.lua
-- 給其他 MOD 的物品名 API。本包平常只在玩家打開容器時修物品名：七個遷移層掛在物品欄與戰利品視窗的事件上
-- （OpenPageScanGate_Flx.lua 檔頭），沒打開過的容器裡還是伺服器組名時的語言，例：屠宰的「Pork Belly (Poor Cut)」
-- （HARDCODE_REGISTRY A5、A33）。其他 MOD 要列出這些容器的內容時（例：Minidoracat 安全屋的物品搜尋）先叫這裡修。
--
-- 公開 API：
--   CatLangFor42.fixItemNames(items)
--     items：InventoryItem 的 Lua 陣列（1 起算）。每一件做玩家打開容器時七個遷移層做的事，名稱換成本機語言；
--     只改本機（setName 不送伺服器）。dedicated server 不做，同各遷移層的 shouldRunClientRepair。
--     演化食譜那層的官方 checkName 每改一件就刷新一次物品欄（ISInventoryPage.dirtyUI），所以整批包在
--     EvolvedRecipeNameFlx.runRepair 裡，真的改了才刷新一次。出錯照常丟出，呼叫端自己 pcall。
-- 新增「打開容器時修」的遷移層時，一起加進這裡（lua-patches.md）。

CatLangFor42 = CatLangFor42 or {}

local function fixEvolved(items)
    local fixed = 0
    for i = 1, #items do
        fixed = fixed + EvolvedRecipeNameFlx.fixItemName(items[i])
    end
    return fixed
end

function CatLangFor42.fixItemNames(items)
    if isServer() and not isClient() then return end
    for i = 1, #items do
        local item = items[i]
        AnimalProductNameFlx.fixItemName(item)
        DynamicItemNameFlx.fixItemName(item)
        ItemNameFixFlx.fixItemName(item)
        RecipeLiteratureFlx.fixItemName(item)
        RecordedMediaNameFlx.fixItemName(item)
        VehicleKeyFlx.fixItemName(item)
    end
    EvolvedRecipeNameFlx.runRepair(fixEvolved, items)
end
