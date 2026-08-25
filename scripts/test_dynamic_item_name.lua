-- 測試 DynamicItemName_Flx.lua 的 rawFormat 哨兵取格式與 memoize
-- 執行：lua scripts/test_dynamic_item_name.lua（須在 repo 根目錄，dofile 走相對路徑）
--
-- 修復目標：
--   (a) 修前 rawFormat 每次呼叫都無參數 getText 含佔位符的 key，Translator 每次
--       都噴 "Missing arguments" 警告——inventory 高頻重掃 × 每件物品，正式服
--       log 223 秒 13,758 條。修後帶哨兵參數走官方格式化成功路徑＋memoize，
--       裸查歸零。
--   (b) Translator 載入期把 %N 改寫成 %N$s（tryFillMapFromFile→formatFixer），
--       buildCapturePattern 只認 %N，42.20 起 currentFormat 分支全滅——CH/EN
--       格式相異的 key 修不到（如 CH 烘的「雪花玻璃球 (Louisville)」；格式與
--       EN 相同的 key 仍可靠「EN 格式＋當前錨點」交叉分支僥倖修到）。
--       修後由官方格式化結果換回 %N，分支復活。

-- ============ PZ global stubs（模擬 CH client） ============
-- 翻譯值比照 Translator 載入期 %N→%N$s 改寫後的運行期形態
local FAKE = {
    IGUI_ItemWithDisplayName = "%1$s: %2$s",
    IGUI_ItemWithDisplayNameAndJob = "%1$s: %2$s (%3$s)",
    IGUI_SnowGlobeOf = "%1$s (%2$s)", -- CH 格式 ≠ EN 的 "%1 of %2"，交叉分支救不了
    IGUI_PetName_Rex = "雷克斯",
    IGUI_Doctor = "醫生",
    IGUI_Photo_Louisville = "路易斯維爾",
    IGUI_ScratchingTicketNameWinner = "%1$s (贏家 %2$s)",
    IGUI_ScratchingTicketNameLoser = "%1$s (輸家)",
    -- IGUI_Newspaper_Name 故意缺席：驗證「查無翻譯」也要 memoize
}

-- bareLookups：無參數查詢——只有這種呼叫會觸發 Missing arguments 警告。
-- fetchLookups：格式字串擷取＝裸查或帶哨兵（\1 開頭參數）——釘 memoize 本身；
-- 哨兵路徑永遠帶參數，只算裸查的話 cache 整個廢掉測試照綠（codex mutation
-- 實證過的假綠）。修復器解析成功後帶真實參數重組名字的 getText 不在此列。
-- getText / getTextOrNull 共用單層實作，一次邏輯查詢只計一次
local bareLookups = {}
local fetchLookups = {}

local function lookup(key, a, b, c)
    if a == nil or (type(a) == "string" and a:find("^\1")) then
        fetchLookups[key] = (fetchLookups[key] or 0) + 1
    end
    if a == nil then bareLookups[key] = (bareLookups[key] or 0) + 1 end
    local value = FAKE[key]
    if not value then return nil end
    if a ~= nil then value = value:gsub("%%1%$s", function() return tostring(a) end) end
    if b ~= nil then value = value:gsub("%%2%$s", function() return tostring(b) end) end
    if c ~= nil then value = value:gsub("%%3%$s", function() return tostring(c) end) end
    return value
end

function getText(key, a, b, c)
    return lookup(key, a, b, c) or key
end

function getTextOrNull(key, a, b, c)
    return lookup(key, a, b, c)
end

function instanceof(_obj, _cls) return false end
function isServer() return false end
function isClient() return true end
function getSpecificPlayer() return nil end
function getPlayer() return nil end

local noopEvent = { Add = function() end }
Events = setmetatable({}, { __index = function() return noopEvent end })

-- ============ 載入待測檔案 ============
dofile("MOD/MinidoracatLangFor42/Contents/mods/MinidoracatLangFor42/42/media/lua/shared/Items/DynamicItemName_Flx.lua")

local fixItemName = DynamicItemNameFlx.fixItemName
assert(type(fixItemName) == "function", "fixItemName 未匯出")
assert(DynamicItemNameFlx.MAPS.EN_ITEM_NAMES["Base.DogTag_Pet"] == "Dog Tag", "AUTO-GEN 反查表未載入")

-- ============ item stub ============
local function makeItem(def)
    return {
        getFullType = function() return def.fullType end,
        getName = function() return def.name end,
        setName = function(_, newName) def.name = newName end,
        getModData = function() return def.modData or {} end,
        getScriptItem = function()
            return { getDisplayName = function() return def.display end }
        end,
        IsInventoryContainer = function() return false end,
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

-- ============ 迴歸守門：修前已可達的路徑照舊 ============

check("EN 烘焙寵物牌 → 中文",
    { fullType = "Base.DogTag_Pet", name = "Dog Tag: Rex", display = "狗牌" }, "狗牌: 雷克斯")

check("EN 烘焙名片（三參數格式）→ 人名保留、職業反查",
    { fullType = "Base.BusinessCard", name = "Business Card: John Smith (Doctor)", display = "名片" },
    "名片: John Smith (醫生)")

-- 寵物牌 CH 格式與 EN 相同，修前靠「EN 格式＋當前錨點」交叉分支僥倖可達（迴歸守門）
check("CH 烘焙寵物牌 → 寵物名補翻",
    { fullType = "Base.DogTag_Pet", name = "狗牌: Rex", display = "狗牌" }, "狗牌: 雷克斯")

-- ============ (b) currentFormat 分支：CH/EN 格式相異時是唯一解析路徑 ============

-- 修前 rawFormat 回傳 "%1$s (%2$s)"，pattern 要求字面 "$s" → 永不命中
check("CH 烘焙雪花球（CH/EN 格式相異，只有取回 %N 格式後可達）→ 地名補翻",
    { fullType = "Base.SnowGlobe", name = "雪花玻璃球 (Louisville)", display = "雪花玻璃球" },
    "雪花玻璃球 (路易斯維爾)")

-- ============ 已刮開刮刮樂（fullType 不變，靠官方 modData.scratched 判定） ============

-- 42.20.0+ MP：刮票改由 server 端組名並 sendReplaceItemInContainer 推送覆蓋，
-- 非中文伺服器產生「中文基底名 + EN 格式」混血烘焙名
check("混血烘焙中獎票（EN 格式 + 中文基底名）→ 現行譯名重組",
    { fullType = "Base.ScratchTicket", name = "刮刮樂彩票 - Winner $10", display = "刮刮樂",
      modData = { scratched = true } },
    "刮刮樂 (贏家 $10)")

check("混血烘焙未中獎票 → 現行譯名重組",
    { fullType = "Base.ScratchTicket", name = "刮刮樂彩票 - Loser", display = "刮刮樂",
      modData = { scratched = true } },
    "刮刮樂 (輸家)")

check("全英文烘焙中獎票（server EN 完整生成）→ 中文",
    { fullType = "Base.ScratchTicket", name = "Scratch Ticket - Winner $5", display = "刮刮樂",
      modData = { scratched = true } },
    "刮刮樂 (贏家 $5)")

check("42.19 全中文舊烘焙名 → 基底名更新為現行譯名",
    { fullType = "Base.ScratchTicket", name = "刮刮樂彩票 (贏家 $1)", display = "刮刮樂",
      modData = { scratched = true } },
    "刮刮樂 (贏家 $1)")

check("已正名輸家票冪等",
    { fullType = "Base.ScratchTicket", name = "刮刮樂 (輸家)", display = "刮刮樂",
      modData = { scratched = true } },
    "刮刮樂 (輸家)")

-- fail-closed：無 scratched 標記＝未刮，一律不碰
check("未刮票不重組（無 modData.scratched）",
    { fullType = "Base.ScratchTicket", name = "刮刮樂彩票 - Winner $10", display = "刮刮樂" },
    "刮刮樂彩票 - Winner $10")

-- 世界生成 _Winner 型別既有路徑迴歸守門
check("世界生成中獎票（_Winner 型別，EN 烘焙）→ 中文",
    { fullType = "Base.ScratchTicket_Winner", name = "Scratch Ticket - Winner $2", display = "刮刮樂 (中獎)" },
    "刮刮樂 (中獎) (贏家 $2)")

-- 冪等性：已修好的名字重掃不得疊加。直呼 computeFixedName 繞過 fixItemName 的
-- pcall——快取層若拋錯要顯性炸出來，不得被吞成「名字沒變」的假綠
local idem = { fullType = "Base.DogTag_Pet", name = "狗牌: 雷克斯", display = "狗牌" }
local it = makeItem(idem)
local recomputed = DynamicItemNameFlx.computeFixedName(it)
fixItemName(it)
if idem.name == "狗牌: 雷克斯" and (recomputed == nil or recomputed == "狗牌: 雷克斯") then
    passed = passed + 1
else
    failed = failed + 1
    print(string.format("FAIL 寵物牌重掃不冪等\n  name: %s\n  recomputed: %s", idem.name, tostring(recomputed)))
end

-- ============ (a) 警告經濟＋memoize：模擬 inventory 重掃 50 次 ============

bareLookups = {}
fetchLookups = {}
for _ = 1, 50 do
    fixItemName(makeItem({ fullType = "Base.DogTag_Pet", name = "Dog Tag: Rex", display = "狗牌" }))
    fixItemName(makeItem({ fullType = "Base.BusinessCard", name = "Business Card: John Smith (Doctor)", display = "名片" }))
    fixItemName(makeItem({ fullType = "Base.Newspaper", name = "Old Newspaper: The Kentucky Herald", display = "舊報紙" }))
end

-- 裸查歸零（修前＝每次掃描都裸查、每次都是一條警告）
for _, key in ipairs({ "IGUI_ItemWithDisplayName", "IGUI_ItemWithDisplayNameAndJob", "IGUI_Newspaper_Name" }) do
    local n = bareLookups[key] or 0
    if n == 0 then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("FAIL %s 無參數查詢 %d 次（哨兵後應為 0；修前＝每次掃描都裸查）", key, n))
    end
end

-- memoize：窗內格式字串擷取次數——前段案例已暖過的 key 為 0；
-- 缺翻譯的 IGUI_Newspaper_Name 首查在窗內，負快取（false 佔位）下恰為 1
local EXPECTED_FETCHES = {
    IGUI_ItemWithDisplayName = 0,
    IGUI_ItemWithDisplayNameAndJob = 0,
    IGUI_Newspaper_Name = 1,
}
for key, expected in pairs(EXPECTED_FETCHES) do
    local n = fetchLookups[key] or 0
    if n == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("FAIL %s 窗內格式擷取 %d 次（memoize 後應恰為 %d；cache 失效＝每次掃描都查）", key, n, expected))
    end
end

print(string.format("passed=%d failed=%d", passed, failed))
os.exit(failed == 0 and 0 or 1)
