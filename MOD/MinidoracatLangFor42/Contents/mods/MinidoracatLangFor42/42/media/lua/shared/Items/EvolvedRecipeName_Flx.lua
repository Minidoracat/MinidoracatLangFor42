-- EvolvedRecipeName_Flx.lua
-- 修復演化食譜（湯／燉菜／烤盤／沙拉／三明治…）句式名固化英文的殘留。
--
-- 行號僅供參考，一律以錨點字串 grep 為準（HARDCODE_REGISTRY.md 使用規則 4）。
--
-- 官方 media/lua/shared/TimedActions/ISAddItemInRecipe.lua 的 `checkName`
-- （錨點 `ISAddItemInRecipe.checkName = function(baseItem, recipe)`，:99）本身
-- 用 getText 組名，並沒有硬編碼英文；問題出在組完之後：
--   setName → InventoryItem.save 錨點 `!this.name.equals(this.originalName)`（:1708）
--   把「成品字串」整串序列化（flag 8）→ load 錨點 `this.name = GameWindow.ReadString`
--   （:2035）原樣讀回，不重譯。
-- 於是語言在「做菜當下」被烘死。MP dedicated server（EN）重建／同步物品時，
-- client 端即使翻譯齊全也會收到 `Game and Fish Roast with Soy Sauce`；
-- 外層的「(新鮮, 已烹飪)」則因為是 Food.getName（錨點 `IGUI_FoodNaming`，
-- Food.java:1371-1408）每次即時組而仍是中文。
--
-- 修復策略：不解析英文句式，直接以本機語言重跑官方演算法。
--   Food 的 extraItems / spices 存的是 fullType 字串列表（跨語言不變，且各自過
--   save/load：`InventoryItem.java:1721/2052`、`Food.java:988/1212`），
--   ScriptManager 可由 EvolvedRecipe 的 resultItem 反查所屬食譜，
--   兩者湊齊即可原樣呼叫官方 `checkName`——結果與本機新煮出來的名稱逐字一致，
--   第三方 MOD 的食材與食譜也一併涵蓋（但見 buildRecipeIndex 內註的兩處已知上限）。
--
-- 這也是 HARDCODE_REGISTRY A20 當初「需句式反查、誤傷風險高」而擱置的那一項；
-- 改走 resultItem 重算之後句式反查不再需要，主要誤傷面收斂為下方那道自訂名守衛。

local TAG = "[CatLangFor42]"

EvolvedRecipeNameFlx = EvolvedRecipeNameFlx or {}

-- 失效訊號。本檔所有失敗路徑都會讓修補靜靜地變成 no-op（A20 就這樣死了好幾個月
-- 才被抓到），但掛勾在 OnContainerUpdate／EveryOneMinute 這種高頻事件上，
-- 持續性錯誤照印會塞爆 log——故一個原因只印一次。
local warned = {}

local function warnOnce(key, message)
    if warned[key] then return end
    warned[key] = true
    print(TAG .. " [EvolvedRecipeName] " .. message)
end

-- ============================================================
-- resultItem（fullType）→ EvolvedRecipe（執行期建表）
-- ============================================================
-- 鍵用 fullType，對齊 vanilla 決定「哪個食譜適用於這個物品」的**權威**路徑：
-- `RecipeManager.getEvolvedRecipe` 錨點
-- `baseItem.getFullType().equals(recipe.baseItem) || baseItem.getFullType().equals(recipe.resultItem)`
-- （`RecipeManager.java:505`）——拿 fullType 比對 `resultItem` 的原始字面值。
-- （`EvolvedRecipe.isResultItem`（`:682`）確實是 bare type 比對，但那是 `addItem`
-- 內部「baseItem 是不是已經是結果物」的近似判斷，不是食譜選擇的判準。用它建索引會讓
-- `SomeMod.PanFriedVegetables2` 誤配到 vanilla 食譜、把別人的物品改名。）
-- 無 module 前綴時補 `Base.`：`addItem` 走 `InventoryItemFactory.CreateItem(this.resultItem)`
-- （`EvolvedRecipe.java:233`），而該多載的 `moduleDefaultsToBase` 是 true
-- （`InventoryItemFactory.java:55-57`），所以無前綴的 `ResultItem = MyStew`
-- 產出的物品 fullType 就是 `Base.MyStew`。vanilla 63 個食譜全部自帶前綴。

local recipeByResult = nil

-- 消歧要比的是**最終顯示字串**，不是食譜 key。checkName 用的是
-- `getText("ContextMenu_EvolvedRecipe_" .. recipe:getUntranslatedName())`，
-- 而 `getUntranslatedName()` 回的是 key 名——vanilla 的 SoupBucket/SoupBucket2
-- key 本來就不同、譯文卻都是「燉湯」，拿 key 比會把它們誤判成不可判而整組不修
-- （2026-08-10 實機 log 抓到：`ambiguous resultItem, skipped: Base.BucketOfSoup,
-- Base.BucketOfStew`）。譯文相同就代表選哪個 recipe 結果都一樣，可以安全合併。
local function recipeLabel(recipe)
    local name = recipe and recipe:getUntranslatedName()
    if not name then return nil end
    return getText("ContextMenu_EvolvedRecipe_" .. name)
end

local function buildRecipeIndex()
    local index = {}
    if not getScriptManager then return index end

    local scriptManager = getScriptManager()
    local recipes = scriptManager and scriptManager:getAllEvolvedRecipesList()
    if not recipes then return index end

    -- 索引可能在翻譯載入完成前被 lazy 建過一次（那時 getText 回 key 名，會誤判成
    -- 不可判）；OnGameStart 重建時把警告清掉，才不會被第一次的誤判 latch 住。
    warned["ambiguous-recipe"] = nil

    local ambiguous = nil
    for i = 0, recipes:size() - 1 do
        local recipe = recipes:get(i)
        local result = recipe and recipe:getFullResultItem()
        if result and result ~= "" then
            if not result:find("%.") then result = "Base." .. result end

            local existing = index[result]
            if existing == nil then
                index[result] = recipe
            elseif existing ~= false and recipeLabel(existing) ~= recipeLabel(recipe) then
                -- 兩個食譜產出同一物品、顯示名卻不同：物品本身帶不出是哪一道，
                -- 猜錯就是把玩家的菜改成另一道菜的名字。標記為不可判並跳過。
                index[result] = false
                ambiguous = (ambiguous and ambiguous .. ", " or "") .. result
            end
        end
    end

    if ambiguous then
        warnOnce("ambiguous-recipe", "ambiguous resultItem, skipped: " .. ambiguous)
    end
    return index
end

local function getRecipeFor(item)
    if not recipeByResult then recipeByResult = buildRecipeIndex() end
    local fullType = item:getFullType()
    return fullType and recipeByResult[fullType] or nil
end

EvolvedRecipeNameFlx.rebuildIndex = function()
    recipeByResult = buildRecipeIndex()
    return recipeByResult
end

-- ============================================================
-- 單一物品修復
-- ============================================================

local function fixItemName(item)
    if not item or not instanceof(item, "Food") then return 0 end

    -- 官方 checkName 只有食材段帶 isCustomName 守衛（錨點
    -- `if instanceof(baseItem, "Food") and not baseItem:isCustomName() then`，:108-158）；
    -- 其後全部無守衛，會真的 setName 的是調味料段（錨點 `if baseItem:getSpices() then`，
    -- :166 起）。所以有 spices 的物品直接呼叫會覆寫玩家自訂名與
    -- EvolvedRecipe.checkUniqueRecipe（錨點 `food.setCustomName(true)`，:494）的
    -- unique recipe 名，故在此自行擋掉。同 ItemNameFix_Flx 的全域守衛：
    -- setName 不動 customName 旗標，checkName 走的正是 setName，
    -- 所以這道閘不會擋掉本檔真正的目標。
    if item:isCustomName() then return 0 end

    local extraItems = item:getExtraItems()
    local spices = item:getSpices()
    local hasExtra = extraItems and extraItems:size() > 0
    local hasSpices = spices and spices:size() > 0
    if not hasExtra and not hasSpices then return 0 end

    if not ISAddItemInRecipe or not ISAddItemInRecipe.checkName then
        -- 升版 SOP 的必查項之一；沒有這行訊號，整個修補會靜靜地永久 no-op。
        warnOnce("no-checkname", "ISAddItemInRecipe.checkName unavailable, repair disabled")
        return 0
    end

    -- 查不到 recipe 絕大多數是「此物品本來就不是演化食譜產物」（正常，不記錄）；
    -- 「索引整個是空的」那種全滅情形由 onGameStart 的索引檢查負責報。
    local recipe = getRecipeFor(item)
    if not recipe then return 0 end

    -- 比對基準用 getDisplayName()：Java 實作就是 `return this.name`
    -- （InventoryItem.java:3204，全繼承鏈僅 Moveable.java:77 覆寫，Food 未覆寫），
    -- 直接取到 checkName 寫進去的那個字串，不必經 Food.getName() 的狀態前綴組裝，
    -- 也免疫 InventoryItem.getName() 的 fluidContainer／remoteControl 提前返回分支
    -- （:2433-2438）。**注意**這裡是前後自比，A20 那條「狀態前綴會讓比對永不相等」
    -- 的陷阱在此不成立（前綴兩側相消），別把那個理由搬過來。
    --
    -- checkName **不是原子的**：它先在食材段 setName（錨點 `baseItem:setName(getText(name))`），
    -- 之後才跑調味料段，中途拋錯就留下半套用的名字（有食材、缺調味料）。那種半成品
    -- 既不可預期、下一輪還會再試一次，所以失敗時復原並回報未變動，讓行為維持冪等。
    -- pcall 包住的是官方＋任何 MOD 都能覆寫的外部程式碼，失敗原因必須留下訊號
    -- （PZ 改簽名、MOD 把 checkName 覆寫成吃 self 的 method 形式都會走到這裡）。
    local before = item:getDisplayName()
    local ok, err = pcall(ISAddItemInRecipe.checkName, item, recipe)
    if not ok then
        if item:getDisplayName() ~= before then item:setName(before) end
        warnOnce("checkname-failed", "checkName failed, names rolled back: " .. tostring(err))
        return 0
    end

    return item:getDisplayName() ~= before and 1 or 0
end

EvolvedRecipeNameFlx.fixItemName = fixItemName

-- ============================================================
-- 事件掛載（與 DynamicItemName_Flx / ItemNameFix_Flx 同構）
-- ============================================================

local function shouldRunClientRepair()
    return not (isServer() and not isClient())
end

local function fixContainer(container)
    if not container or not instanceof(container, "ItemContainer") then return 0 end

    -- visited：vanilla 的容器樹不會成環，但存檔損毀或 MOD 造成的環會讓這個 worklist
    -- 永遠跑不完，而它跑在主執行緒上——一個 table 換掉整個遊戲卡死的風險，值得。
    local visited = { [container] = true }
    local stack = { container }
    local fixed = 0
    while #stack > 0 do
        local currentContainer = table.remove(stack)
        local items = currentContainer and currentContainer:getItems()
        if items then
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                fixed = fixed + fixItemName(item)

                if item and item:IsInventoryContainer() then
                    local childContainer = item:getInventory()
                    if childContainer and not visited[childContainer] then
                        visited[childContainer] = true
                        table.insert(stack, childContainer)
                    end
                end
            end
        end
    end
    return fixed
end

EvolvedRecipeNameFlx.fixContainer = fixContainer

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

-- 官方 checkName 三個出口中有兩個**無條件**呼叫 ISInventoryPage.dirtyUI()
-- （錨點 `ISInventoryPage.dirtyUI();`，`ISAddItemInRecipe.lua:161`／`:220`，其
-- `not isServer()` 條件在 SP/client 恆真；第三個出口是開頭無食材無調味料的早退，
-- 已被下方 fixItemName 的 hasExtra/hasSpices 閘擋成不可達）。
-- 而 dirtyUI → refreshBackpacks()（錨點 `function ISInventoryPage:refreshBackpacks()`）
-- → triggerEvent("OnRefreshInventoryWindowContainers", self, "end")——正是本檔掛的事件
-- 之一。不擋就是無限遞迴；而且逐物品觸發整組背包 UI 重建，一櫃鍋菜就是一輪 N 次
-- refreshBackpacks。故整批修復期間把 dirtyUI 換成 no-op，結束後只有真的改過名字
-- 才補呼叫一次。
--
-- 這裡的 pcall **不是**為了隔離其他 MOD——`Event.trigger()`（Event.java）本來就把每個
-- callback 各自包在 try/catch 裡、catch 完繼續跑迴圈，拋錯既不會斷別人也會被
-- ExceptionLogger 印出 stack trace。它是為了**狀態還原**：沒有它，途中拋錯會讓
-- ISInventoryPage.dirtyUI 永遠停在 no-op、inRepair 永遠是 true，
-- 全遊戲的背包 UI 從此不再刷新。
local inRepair = false

local function runRepair(fn, arg)
    if inRepair then return 0 end
    inRepair = true

    local realDirtyUI = ISInventoryPage and ISInventoryPage.dirtyUI
    if realDirtyUI then
        ISInventoryPage.dirtyUI = function() end
    else
        -- 官方 checkName 結尾會無條件呼叫它，沒有這個函式就等於每顆物品都會拋錯
        warnOnce("no-dirtyui", "ISInventoryPage.dirtyUI unavailable, repair may fail per-item")
    end

    local ok, result = pcall(fn, arg)

    if realDirtyUI then ISInventoryPage.dirtyUI = realDirtyUI end

    -- 補呼叫**必須**在旗標仍為 true 時進行：它是唯一會打回本檔事件掛勾的路徑，
    -- 先清旗標就等於把終止性外包給 checkName 的冪等性（官方哪天改成非冪等就爆）。
    if ok and result > 0 and realDirtyUI then pcall(realDirtyUI) end

    inRepair = false

    if not ok then
        warnOnce("repair-pass-failed", "repair pass failed: " .. tostring(result))
        return 0
    end
    return result
end

EvolvedRecipeNameFlx.runRepair = runRepair

local function onCreatePlayer(_playerIndex, playerObj)
    if not shouldRunClientRepair() then return end
    runRepair(fixPlayerItems, playerObj)
end
Events.OnCreatePlayer.Add(onCreatePlayer)

local function onGameStart()
    if not shouldRunClientRepair() then return end

    -- 腳本此時已全數載入，重建索引以涵蓋 MOD 追加的演化食譜
    local index = EvolvedRecipeNameFlx.rebuildIndex()
    local count = 0
    for _ in pairs(index) do count = count + 1 end
    if count == 0 then
        -- 空索引＝每個物品都查不到 recipe＝整個修補靜靜地 no-op。
        -- 升版時 getScriptManager／getAllEvolvedRecipesList 改名就會走到這裡。
        warnOnce("empty-index", "evolved recipe index is empty, repair disabled")
    else
        print(TAG .. " [EvolvedRecipeName] Repair path active (" .. tostring(count) .. " evolved recipes indexed)")
    end

    local fixed = runRepair(fixPlayerItems, getPrimaryPlayer())
    if fixed > 0 then
        print(TAG .. " [EvolvedRecipeName] Fixed persisted evolved recipe names: " .. tostring(fixed))
    end
end
Events.OnGameStart.Add(onGameStart)

local function onFillContainer(_roomName, _containerType, container)
    if not shouldRunClientRepair() then return end
    runRepair(fixContainer, container)
end
Events.OnFillContainer.Add(onFillContainer)

local function onContainerUpdate()
    if not shouldRunClientRepair() then return end
    runRepair(fixOpenInventoryPages)
end
Events.OnContainerUpdate.Add(onContainerUpdate)

local function onRefreshInventoryWindowContainers(_page, state)
    if state ~= "end" or not shouldRunClientRepair() then return end
    runRepair(fixOpenInventoryPages)
end
Events.OnRefreshInventoryWindowContainers.Add(onRefreshInventoryWindowContainers)

local function onEveryOneMinute()
    if not shouldRunClientRepair() then return end
    runRepair(function()
        return fixPlayerItems(getPrimaryPlayer()) + fixOpenInventoryPages()
    end)
end
Events.EveryOneMinute.Add(onEveryOneMinute)
