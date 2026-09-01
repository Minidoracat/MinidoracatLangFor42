-- 測試 ItemNameFix_Flx.lua 的 fixItemName（A20 死碼修復回歸驗證）
-- 執行：lua scripts/test_item_name_fix.lua（須在 repo 根目錄，dofile 走相對路徑）
--
-- 情境前提：MP dedicated server 語言=EN、client 語言=CH。
-- server 端 setName 把英文烘進 InventoryItem.name 並經 flag 8 同步到 client，
-- 於是 client 的 this.name（＝getDisplayName()）是英文，但 script item 的
-- displayName（＝getScriptItem():getDisplayName()）仍是本機中文譯名。
--
-- 另含 A32（mod 物品 fullType fallback）與 A33（屠宰品質後綴）兩分支的把關。
--
-- 修復前的三個死因（本測試逐條把關）：
--   (a) 寫入來源誤用 item:getDisplayName()（＝this.name，就是要被取代的英文本身）
--   (b) 比對基準誤用 item:getName()（會被 新鮮/染血 等狀態前綴包住而永不相等）
--   (c) 早退判準誤用 this.name == enName（正好攔掉「中文 client 被烘成英文」主場景）

-- ============ PZ global stubs（模擬 CH client） ============
local FAKE = {
    UI_foraging_WildFood = "野生",
    Stash_AnnotedMap = "註記地圖",
    IGUI_SurvivalistKey = "軍用品店",
    -- Translator.tryFillMapFromFile 在載入期把 %N 改寫成 %N$s，故此處比照運行期形態
    IGUI_KeyRingName = "%1$s %2$s的鑰匙圈",
    -- A33 屠宰品質後綴（官方 IGUI_AnimalMeat 檔案原文為 "%1 %2"）
    IGUI_AnimalMeat = "%1$s %2$s",
    IGUI_AnimalMeat_Beef = "牛肉",
    IGUI_AnimalMeat_BeefBrisket = "牛胸肉",
    IGUI_AnimalMeat_PrimeCut = "(上等肉塊)",
    IGUI_AnimalMeat_MediumCut = "(中等肉塊)",
    IGUI_AnimalMeat_PoorCut = "(劣質肉塊)",
    -- IGUI_AnimalMeat_Unknown 刻意缺席：測守衛 (c)「getText miss 回鍵名時不得重組」
}

-- A33：官方 AnimalPartsDefinitions.meat（vanilla 自帶 7 種，mod 自行 table.insert 註冊）
AnimalPartsDefinitions = {
    meat = {
        ["Base.Beef"] = { variants = {
            { item = "Base.Beef", baseName = "IGUI_AnimalMeat_Beef", extraName = "IGUI_AnimalMeat_PrimeCut" },
            { item = "Base.Beef", baseName = "IGUI_AnimalMeat_Beef", extraName = "IGUI_AnimalMeat_MediumCut" },
            { item = "Base.Beef", baseName = "IGUI_AnimalMeat_Beef", extraName = "IGUI_AnimalMeat_PoorCut" },
        } },
        ["VFX.BeefBrisket"] = { variants = {
            { baseName = "IGUI_AnimalMeat_BeefBrisket", extraName = "IGUI_AnimalMeat_PrimeCut" },
            { baseName = "IGUI_AnimalMeat_BeefBrisket", extraName = "IGUI_AnimalMeat_PoorCut" },
        } },
        ["VFX.Unknown"] = { variants = {
            { baseName = "IGUI_AnimalMeat_Unknown", extraName = "IGUI_AnimalMeat_PoorCut" },
        } },
    },
}

function getText(key, a, b)
    local value = FAKE[key]
    if not value then return key end
    if a ~= nil then value = value:gsub("%%1%$s", function() return tostring(a) end) end
    if b ~= nil then value = value:gsub("%%2%$s", function() return tostring(b) end) end
    return value
end

function getTextOrNull(key)
    if FAKE[key] then return getText(key) end
    return nil
end

function instanceof(obj, cls)
    return type(obj) == "table" and cls == "ItemContainer" and obj.__isContainer == true
end

function isServer() return false end
function isClient() return true end
function getSpecificPlayer() return nil end
function getPlayer() return nil end

local noopEvent = { Add = function() end }
Events = setmetatable({}, { __index = function() return noopEvent end })

-- ============ 載入待測檔案 ============
dofile("MOD/MinidoracatLangFor42/Contents/mods/MinidoracatLangFor42/42/media/lua/shared/Items/ItemNameFix_Flx.lua")

local fixItemName = ItemNameFixFlx.fixItemName
assert(type(fixItemName) == "function", "fixItemName 未匯出")
assert(ItemNameFixFlx.EN_NAME["Base.Poppies"] == "Poppies", "AUTO-GEN 反查表未載入")
assert(ItemNameFixFlx.CUT_SUFFIX_EN["IGUI_AnimalMeat_PoorCut"] == " (Poor Cut)",
    "AUTO-GEN CUT_SUFFIX_EN 未載入（gen-item-name-map 需重跑）")

-- ============ item stub ============
-- name    = InventoryItem.name（getDisplayName 直接回傳此欄位，InventoryItem.java:3204）
-- display = script item 的 displayName（本機語言譯名，Item.java:493→:3053）
-- deco    = getName() 的狀態裝飾前綴（Food 新鮮/腐爛、Clothing 染血…）
local function makeItem(def)
    return {
        getFullType = function() return def.fullType end,
        getDisplayName = function() return def.name end,
        getName = function()
            -- 比照 InventoryItem.java:2478 / Food.java:1408 的 "%2 (%1)" 包法
            if def.deco then return def.name .. " (" .. def.deco .. ")" end
            return def.name
        end,
        setName = function(_, newName) def.name = newName end,
        isCustomName = function() return def.custom == true end,
        getScriptItem = function()
            if def.noScript then return nil end
            return { getDisplayName = function() return def.display end }
        end,
    }
end

local passed, failed = 0, 0
local function check(label, def, expected)
    local item = makeItem(def)
    fixItemName(item)
    if def.name == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("FAIL %s\n  expected: %s\n  got:      %s", label, expected, def.name))
    end
end

-- ============ 修復目標：這四條在修復前全都不成立 ============

-- (1) 純烘死英文名。修前：早退 (c) 攔掉；就算進來 setName(this.name) 也是恆等式。
check("烘死英文名 → 中文",
    { fullType = "Base.Bacon", name = "Bacon", display = "培根" }, "培根")

-- (1) 帶狀態裝飾仍須命中：比對基準若用 getName() 會拿到 "Bacon (新鮮)" 而 miss。
check("烘死英文名＋新鮮前綴 → 中文",
    { fullType = "Base.Bacon", name = "Bacon", display = "培根", deco = "新鮮" }, "培根")

-- (2) 野採。Poppies 有 DaysFresh，getName() 恆帶前綴 → 修前 100% miss。
check("野採 Poppies（有 DaysFresh）→ 中文 (野生)",
    { fullType = "Base.Poppies", name = "Poppies (Wild)", display = "罌粟", deco = "新鮮" },
    "罌粟 (野生)")

-- (2) Peanuts 無 DaysFresh，修前唯一可達者——但輸出是 "Peanuts (Wild) (野生)"。
check("野採 Peanuts（無 DaysFresh）→ 中文 (野生)，英文須消失",
    { fullType = "Base.Peanuts", name = "Peanuts (Wild)", display = "花生" },
    "花生 (野生)")

-- (3) 建築鑰匙。修前可達但只接尾巴："Key - Army Surplus Store - 軍用品店"。
check("建築鑰匙 → 中文 - 中文場所（不得殘留英文）",
    { fullType = "Base.Key1", name = "Key - Army Surplus Store", display = "鑰匙" },
    "鑰匙 - 軍用品店")

-- ============ 不得迴歸：(4) 鑰匙圈必須繼續用 this.name（人名只在裡面） ============

check("鑰匙圈 → 保留人名、只換後綴",
    { fullType = "Base.KeyRing", name = "John Smith's Key Ring", display = "鑰匙圈" },
    "John Smith的鑰匙圈")

check("鑰匙圈：玩家自訂名不得改動",
    { fullType = "Base.KeyRing", name = "My Stuff's Key Ring", display = "鑰匙環", custom = true },
    "My Stuff's Key Ring")

-- ============ 玩家自訂名一律不得改動（2026-08-04 codex review 抓到的迴歸） ============
-- 玩家可以把物品改名成剛好等於某個英文建構形。改動前這些情境是「意外」被擋住的：
-- 一般名靠早退判準恰好用 this.name、野採靠 Food 狀態前綴恰好讓比對 miss——
-- 兩個意外都隨死碼修復消失，故必須改用明確的 isCustomName 全域守衛。
check("自訂名剛好等於 EN 原名 → 不得改動",
    { fullType = "Base.Bacon", name = "Bacon", display = "培根", custom = true }, "Bacon")

check("自訂名剛好等於 EN 野採形 → 不得改動",
    { fullType = "Base.Poppies", name = "Poppies (Wild)", display = "罌粟", custom = true },
    "Poppies (Wild)")

check("自訂名剛好等於 EN 建築鑰匙形 → 不得改動",
    { fullType = "Base.Key1", name = "Key - Army Surplus Store", display = "鑰匙", custom = true },
    "Key - Army Surplus Store")

check("自訂名剛好等於 Annotated Map → 不得改動",
    { fullType = "Base.Map", name = "Annotated Map", display = "地圖", custom = true },
    "Annotated Map")

-- ============ 不得誤傷 ============

check("EN client（localName == enName）→ 完全不動",
    { fullType = "Base.Bacon", name = "Bacon", display = "Bacon" }, "Bacon")

check("CH client 未被烘過 → 完全不動",
    { fullType = "Base.Bacon", name = "培根", display = "培根" }, "培根")

check("不在反查表的第三方 MOD 物品 → 完全不動",
    { fullType = "SomeMod.Widget", name = "Widget", display = "小工具" }, "Widget")

check("場所名不在 KEY_SUFFIX → 完全不動",
    { fullType = "Base.Key1", name = "Key - Nonexistent Place", display = "鑰匙" },
    "Key - Nonexistent Place")

check("getScriptItem() 回 nil → 安全穿透，不得 crash",
    { fullType = "Base.Bacon", name = "Bacon", display = "培根", noScript = true }, "Bacon")

-- ============ 藏寶圖：比對基準改 rawName 後，帶裝飾也要命中 ============

check("藏寶圖 → 譯名",
    { fullType = "Base.Map", name = "Annotated Map", display = "地圖" }, "註記地圖")

check("藏寶圖＋染血（修前因 getName() 裝飾而 miss）",
    { fullType = "Base.Map", name = "Annotated Map", display = "地圖", deco = "染血" }, "註記地圖")

-- ============ A32：mod 物品的 fullType fallback ============
-- server 端翻譯 map 永遠不含 mod 鍵，故 Item.displayName 落到 getFullName()＝fullType。

check("mod 物品 name==fullType → script 譯名",
    { fullType = "VFX.SourdoughStarter", name = "VFX.SourdoughStarter", display = "酸種酵頭 (已餵養)" },
    "酸種酵頭 (已餵養)")

check("fullType 形＋狀態裝飾仍命中（比對基準為 rawName）",
    { fullType = "VFX.SourdoughStarter", name = "VFX.SourdoughStarter", display = "酸種酵頭 (已餵養)", deco = "新鮮" },
    "酸種酵頭 (已餵養)")

check("未收錄譯文（localName == fullType）→ 不動，不得無意義寫入",
    { fullType = "SomeMod.Widget", name = "SomeMod.Widget", display = "SomeMod.Widget" },
    "SomeMod.Widget")

check("fullType 形＋玩家自訂名 → 不動",
    { fullType = "VFX.SourdoughStarter", name = "VFX.SourdoughStarter", display = "酸種酵頭", custom = true },
    "VFX.SourdoughStarter")

check("fullType 形＋getScriptItem() 回 nil → 安全穿透",
    { fullType = "VFX.Ghost", name = "VFX.Ghost", display = "幽靈", noScript = true },
    "VFX.Ghost")

-- ============ A33：屠宰品質後綴 ============
-- 官方 ButcheringUtil.lua:394-395 setName + setCustomName(true)；vanilla 7 種肉同樣中招。

check("vanilla 肉品英文形 → 中文（本體自身 bug）",
    { fullType = "Base.Beef", name = "Beef (Prime Cut)", display = "牛肉" },
    "牛肉 (上等肉塊)")

check("vanilla 肉品英文形＋狀態裝飾仍命中",
    { fullType = "Base.Beef", name = "Beef (Poor Cut)", display = "牛肉", deco = "新鮮" },
    "牛肉 (劣質肉塊)")

check("mod 肉品英文形 → 中文（零 mod 資料，鍵取自官方 runtime 表）",
    { fullType = "VFX.BeefBrisket", name = "Beef Brisket (Poor Cut)", display = "牛胸肉" },
    "牛胸肉 (劣質肉塊)")

check("官方設的 customName 不得擋掉本分支（刻意置於守衛之前）",
    { fullType = "Base.Beef", name = "Beef (Prime Cut)", display = "牛肉", custom = true },
    "牛肉 (上等肉塊)")

check("baseName 鍵不存在（getText 回鍵名）→ 不動，不得產出裸鍵名",
    { fullType = "VFX.Unknown", name = "Whatever (Poor Cut)", display = "某物" },
    "Whatever (Poor Cut)")

check("已是本地形 → 不動",
    { fullType = "Base.Beef", name = "牛肉 (上等肉塊)", display = "牛肉" },
    "牛肉 (上等肉塊)")

check("fullType 不在官方肉品表 → 不動",
    { fullType = "Base.Bacon", name = "Bacon (Poor Cut)", display = "培根" },
    "Bacon (Poor Cut)")

check("後綴非 EN 品質形 → 不動",
    { fullType = "Base.Beef", name = "Beef (Something)", display = "牛肉" },
    "Beef (Something)")

-- ============ 冪等性：掃描每 tick 重跑，二次套用不得疊加 ============

local idem = { fullType = "Base.Key1", name = "Key - Army Surplus Store", display = "鑰匙" }
local it = makeItem(idem)
fixItemName(it); fixItemName(it); fixItemName(it)
if idem.name == "鑰匙 - 軍用品店" then
    passed = passed + 1
else
    failed = failed + 1
    print("FAIL 建築鑰匙三次套用不冪等\n  got: " .. idem.name)
end

local idem2 = { fullType = "Base.KeyRing", name = "John Smith's Key Ring", display = "鑰匙圈" }
local it2 = makeItem(idem2)
fixItemName(it2); fixItemName(it2); fixItemName(it2)
if idem2.name == "John Smith的鑰匙圈" then
    passed = passed + 1
else
    failed = failed + 1
    print("FAIL 鑰匙圈三次套用不冪等\n  got: " .. idem2.name)
end

local idem3 = { fullType = "Base.Beef", name = "Beef (Prime Cut)", display = "牛肉" }
local it3 = makeItem(idem3)
fixItemName(it3); fixItemName(it3); fixItemName(it3)
if idem3.name == "牛肉 (上等肉塊)" then
    passed = passed + 1
else
    failed = failed + 1
    print("FAIL 肉品品質後綴三次套用不冪等\n  got: " .. idem3.name)
end

local idem4 = { fullType = "VFX.SourdoughStarter", name = "VFX.SourdoughStarter", display = "酸種酵頭" }
local it4 = makeItem(idem4)
fixItemName(it4); fixItemName(it4); fixItemName(it4)
if idem4.name == "酸種酵頭" then
    passed = passed + 1
else
    failed = failed + 1
    print("FAIL mod fullType 形三次套用不冪等\n  got: " .. idem4.name)
end

print(string.format("passed=%d failed=%d", passed, failed))
os.exit(failed == 0 and 0 or 1)
