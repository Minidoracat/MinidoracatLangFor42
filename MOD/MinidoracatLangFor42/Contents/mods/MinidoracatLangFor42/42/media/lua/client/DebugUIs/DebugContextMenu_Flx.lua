-- DebugContextMenu_Flx.lua
-- 修復管理員/除錯右鍵選單的官方硬編碼英文（HARDCODE_REGISTRY.md B1-B11、B13）。
--
-- 官方在 DebugContextMenu / AdminContextMenu / ISWorldObjectContextMenu.doBrushToolOptions /
-- ISBuildMenu.buildRampsMenu 直接 addOption("英文") 且無翻譯鍵；Java 端另以
-- getText("Tile Report") 這類無前綴偽 key 塞入選項（Translator 前綴路由查不到，
-- 永遠回退英文）；Randomized Building/Vehicle/Zone 故事名來自 Java getName() 的
-- 硬編碼字面值。翻譯 JSON 無從介入，只能在顯示層後處理。
--
-- 修補策略：選單建好後遞迴走訪整棵選單樹（option.name + option.subOption）——
--   1. 先精確比對自動推導 key：ContextMenu_CatDebug_<英文轉換>（+→Plus、-→Minus、
--      :→Colon、再剝除非英數；與 scripts 產生 JSON 鍵的規則一致。冒號需編碼：
--      AdminContextMenu 的 "Vehicle:" 不可與一般選單硬編碼 "Vehicle"
--      （ISVehicleMenu.lua:597）撞 key）
--   2. miss 再依 PATTERNS 由上而下套用（動態組合字串）；查無譯文一律原樣保留
--   3. 兩者皆 miss 原樣保留。第三方 mod 字串僅在「與已登記官方字串逐字相同」時
--      才會被同一譯文命中（語義相同，可接受）；pattern 另有 guard 防誤傷
--
-- 掛載點（三處互補、walker 冪等）：
--   1. 包裝 DebugContextMenu.doDebugMenu——Java（ISWorldObjectContextMenuLogic）以
--      callLuaClass 依名稱動態呼叫，包裝全域函式有效
--   2. Events.OnFillWorldObjectContextMenu——本檔於 mod 階段載入，handler 必定
--      註冊在 vanilla AdminContextMenu.doMenu 之後（也涵蓋 Farming/FeedingTrough/
--      Animal/Hutch/Vehicle/Foraging 等系統掛在同一事件鏈的 debug 選項）
--   3. Events.OnFillInventoryObjectContextMenu——物品欄右鍵選單的 debug 選項
--   4. 包裝 ISWorldMap.onRightMouseUp——大地圖右鍵選單（視窗內自建
--      ISContextMenu.get(0,...)，不走事件鏈；vanilla 自帶 debug/admin gate）
--
-- 權限 gate 對齊 vanilla：admin / moderator / UseDebugContextMenu capability / SP 除錯模式；
-- 一般玩家路徑零開銷。

require "DebugUIs/DebugContextMenu"
require "ISUI/Maps/ISWorldMap"

-- 動態組合字串規則。順序即優先序：較特定的放前面
-- （"No loot distro for %1 in %2" 必須先於 "No loot distro for %1"）。
-- n = 擷取數；guard 回傳 false 時放棄改寫（原樣保留）
local PATTERNS = {
    { match = "^Set Door Key ID %((%-?%d+)%)$", key = "ContextMenu_CatDebug_Pat_SetDoorKeyID", n = 1 },
    { match = "^Tile Report: (.+)$", key = "ContextMenu_CatDebug_Pat_TileReport", n = 1 },
    { match = "^Room Report: (.+), x: (%-?%d+), y: (%-?%d+), z: (%-?%d+)$", key = "ContextMenu_CatDebug_Pat_RoomReportxyz", n = 4 },
    { match = "^Coordinates Report x: (%-?%d+), y: (%-?%d+), z: (%-?%d+)$", key = "ContextMenu_CatDebug_Pat_CoordinatesReportxyz", n = 3 },
    { match = "^No loot distro for (.+) in (.+)$", key = "ContextMenu_CatDebug_Pat_Nolootdistroforin", n = 2 },
    { match = "^No loot distro for (.+)$", key = "ContextMenu_CatDebug_Pat_Nolootdistrofor", n = 1 },
    { match = "^'other' container distro used for (.+) in (.+)$", key = "ContextMenu_CatDebug_Pat_othercontainerdistrousedforin", n = 2 },
    { match = "^'all' container distro used for (.+) in (.+)$", key = "ContextMenu_CatDebug_Pat_allcontainerdistrousedforin", n = 2 },
    { match = "^'all' roomdef distro used for (.+) in (.+)$", key = "ContextMenu_CatDebug_Pat_allroomdefdistrousedforin", n = 2 },
    { match = "^(.+) %- Jump$", key = "ContextMenu_CatDebug_Pat_MinusJump", n = 1 },
    { match = "^(.+) %- Landmine!$", key = "ContextMenu_CatDebug_Pat_MinusLandmine", n = 1 },
    -- 搜尋（覓食）除錯選單「Create All From <分類 ID>」（ISSearchManager.lua:1616）
    { match = "^Create All From (.+)$", key = "ContextMenu_CatDebug_Pat_CreateAllFrom", n = 1 },
    -- 動物子選單 "Add <已翻譯動物名>"；guard 限定擷取段不含 ASCII 字母，
    -- 避免誤改第三方 mod 的 "Add Xxx" 類英文選項
    { match = "^Add (.+)$", key = "ContextMenu_CatDebug_Pat_Add", n = 1,
      guard = function(c) return not c:find("%a") end },
}

local function deriveKey(name)
    local s = name:gsub("%+", "Plus"):gsub("%-", "Minus"):gsub(":", "Colon"):gsub("[^%w]", "")
    return "ContextMenu_CatDebug_" .. s
end

--- 回傳譯文；查不到回傳 nil（呼叫端原樣保留）
local function translateName(name)
    if type(name) ~= "string" or name == "" or not name:find("%a") then
        return nil
    end
    local exact = getTextOrNull(deriveKey(name))
    if exact then
        return exact
    end
    for _, p in ipairs(PATTERNS) do
        local c1, c2, c3, c4 = name:match(p.match)
        if c1 ~= nil then
            if not p.guard or p.guard(c1) then
                -- getTextOrNull：鍵未載入（如非 CH/CN 語系）時回 nil 保留原文，
                -- 不可用 getText（miss 會把選單改成 raw key 字串）
                if p.n == 1 then return getTextOrNull(p.key, c1) end
                if p.n == 2 then return getTextOrNull(p.key, c1, c2) end
                if p.n == 3 then return getTextOrNull(p.key, c1, c2, c3) end
                return getTextOrNull(p.key, c1, c2, c3, c4)
            end
            return nil
        end
    end
    return nil
end

local function walkMenu(menu, depth, visited)
    if not menu or depth > 8 or visited[menu] then return end
    visited[menu] = true
    if not menu.options then return end
    local changed = false
    for _, opt in ipairs(menu.options) do
        if opt.name then
            local t = translateName(opt.name)
            if t then
                opt.name = t
                changed = true
            end
        end
        if opt.subOption and menu.getSubMenu then
            walkMenu(menu:getSubMenu(opt.subOption), depth + 1, visited)
        end
    end
    if changed and menu.calcWidth and menu.setWidth then
        menu:setWidth(menu:calcWidth())
    end
end

-- 各系統作弊選單各有自己的旗標 gate（管理員面板 ISAdminPowerUI / 除錯選單切換）；
-- 任一開啟就代表本地玩家看得到對應的英文作弊選項，walker 需要跟著啟動
local function anyCheatFlagOn()
    return (ISFarmingMenu and ISFarmingMenu.cheat)
        or (ISVehicleMechanics and ISVehicleMechanics.cheat)
        or (AnimalContextMenu and AnimalContextMenu.cheat)
        or (ISLootZed and ISLootZed.cheat)
end

local function shouldTranslate(playerIndex)
    -- debug 模式先判（SP 與 MP `-debug` 皆放行：ISWorldMap/ISVehicleMenu 等
    -- vanilla gate 用 getDebug()，MP 非管理員掛 -debug 也看得到英文選單）
    if isDebugEnabled() then
        return true
    end
    if anyCheatFlagOn() then
        return true
    end
    if isClient() then
        if isAdmin() or getAccessLevel() == "moderator" then
            return true
        end
        local playerObj = getSpecificPlayer(playerIndex)
        if playerObj then
            local ok, has = pcall(function()
                return playerObj:getRole():hasCapability(Capability.UseDebugContextMenu)
            end)
            return ok and has == true
        end
    end
    return false
end

local function translateContextTree(context)
    -- 選單後處理失敗不可拖垮右鍵選單本體；留一行診斷方便回報排查
    local ok, err = pcall(walkMenu, context, 1, {})
    if not ok then
        print("[CatLangFor42] DebugContextMenu_Flx walk error: " .. tostring(err))
    end
end

local _origDoDebugMenu = DebugContextMenu.doDebugMenu
DebugContextMenu.doDebugMenu = function(player, context, worldobjects, test)
    local result = _origDoDebugMenu(player, context, worldobjects, test)
    if not test and context and shouldTranslate(player) then
        translateContextTree(context)
    end
    return result
end

Events.OnFillWorldObjectContextMenu.Add(function(player, context, worldobjects, test)
    if test or not context then return end
    if not shouldTranslate(player) then return end
    translateContextTree(context)
end)

-- 物品欄右鍵選單同一機制（如動物屍體 Debug 子選單的 "Turn into skeleton"，
-- ISInventoryPaneContextMenu.lua:4697）
Events.OnFillInventoryObjectContextMenu.Add(function(player, context, items)
    if not context then return end
    if not shouldTranslate(player) then return end
    translateContextTree(context)
end)

-- 大地圖右鍵選單（ISWorldMap.lua onRightMouseUp 自建於玩家選單單例，
-- vanilla 寫死 playerNum=0；選單建好後對單例做同一走訪）
local _origMapRightMouseUp = ISWorldMap.onRightMouseUp
function ISWorldMap:onRightMouseUp(x, y)
    local result = _origMapRightMouseUp(self, x, y)
    -- 只有真正建出選單的路徑回傳 true（symbolsUI 先吃掉／無權限／主選單皆否），
    -- 其餘路徑不必走訪殘留單例
    if result == true and shouldTranslate(0) then
        translateContextTree(getPlayerContextMenu(0))
    end
    return result
end
