-- ISCharacterScreen_Flx.lua
-- 角色資訊面板「慣用武器」欄位顯示英文武器名（HARDCODE_REGISTRY A24）
--
-- 非缺鍵：Base.BaseballBat_RakeHead 等在官方與我方 CH/CN 皆有正確譯文，
-- 但此欄位根本不查 ItemName 表。官方鏈路：
--   1. 寫入 server/XpSystem/XpUpdate.lua:63-66
--      modData["Fav:" .. weapon:getScriptItem():getDisplayName()]，
--      key 由寫入端當下語言的 DisplayName 組成，持久化進玩家存檔。
--   2. MP 下 WeaponHit.java 在 `if (GameServer.server)` 分支才觸發
--      OnWeaponHitXp，故 key 是**伺服器語言**（通常 EN）；單機走
--      CombatManager 的 !GameServer.server 路徑、寫入本機語言，不受影響。
--   3. 讀取 ISCharacterScreen.lua:650-661 以 string.gmatch(key, "^Fav:(.+)")
--      取 key 後綴當顯示字串，:224 直接 drawText，全程無 getText。
-- 同函式 :223 的欄位標題有 getText，所以玩家看到「慣用武器」是中文、值是英文。
--
-- 修法：借 A20（ItemNameFix_Flx）已產的 EN_NAME 反查表把英文名還原成
-- fullType，再以官方 Lua 全域 getItemNameFromFullType 取當前語言譯名。
-- 不新增任何翻譯鍵、不新增資料表——A20 的 gen-item-name-map 升版重跑時
-- 本檔自動受惠。
--
-- **合併次數是必要的，不是附加功能**：官方 :655 以 `vPData > swing` 取
-- count 最大者。玩家切回中文後只會新增一個從 1 起算的中文 key，舊英文 key
-- 的高 count 永遠勝出；若只翻譯不合併，同一把武器被拆成兩筆統計會讓
-- 「慣用武器」判定失真。故以「還原後的顯示名」為單位加總。
--
-- 已知上限（與 A1 世界容器、A20 同一天花板）：這是顯示層遷移，伺服器仍會
-- 持續以英文寫入新 key；改 server 端的 XpUpdate.lua 在 MP 對 client 無效。
-- 反查表若有多個 fullType 共用同一英文顯示名，取第一個（撞名者譯名通常一致）。
-- 第三方 MOD 武器查無反查表時原樣沿用，安全穿透、不會改壞。

require "XpSystem/ISUI/ISCharacterScreen"

local TAG = "[CatLangFor42]"

-- 延遲建表：避開 shared/ 與 client/ 的載入順序不確定性
local enToFullType = nil

local function buildReverseMap()
    enToFullType = {}
    if ItemNameFixFlx and ItemNameFixFlx.EN_NAME then
        -- EN 名撞名時取 fullType 字典序最小者：pairs() 順序未指定，若取「先掃到的」
        -- 會不確定。實測 423 組英文撞名、其中 218 組譯文相異（如 Ball-peen Hammer
        -- → 圓頭錘／圓頭錘 (鍛造)），字典序讓基礎物品（Base.Hammer）穩定勝過
        -- 變體（Base.HammerForged）。
        for fullType, enName in pairs(ItemNameFixFlx.EN_NAME) do
            if enToFullType[enName] == nil or fullType < enToFullType[enName] then
                enToFullType[enName] = fullType
            end
        end
    else
        print(TAG .. " [FavWeapon] WARNING: ItemNameFixFlx.EN_NAME unavailable, passthrough only")
    end
end

local _orig_loadFavouriteWeapon = ISCharacterScreen.loadFavouriteWeapon

ISCharacterScreen.loadFavouriteWeapon = function(self)
    local ok = pcall(function()
        if enToFullType == nil then buildReverseMap() end

        local totals = {}
        for key, count in pairs(self.char:getModData()) do
            local suffix = type(key) == "string" and string.match(key, "^Fav:(.+)") or nil
            if suffix and type(count) == "number" then
                local fullType = enToFullType[suffix]
                -- 查無＝已是本地語言名或第三方 MOD 武器，原樣沿用
                local name = suffix
                if fullType then
                    local translated = getItemNameFromFullType(fullType)
                    if translated and translated ~= "" then name = translated end
                end
                totals[name] = (totals[name] or 0) + count
            end
        end

        local best, bestSwing = nil, 0
        for name, count in pairs(totals) do
            if count > bestSwing then
                best, bestSwing = name, count
            end
        end
        self.favouriteWeapon = best
    end)

    if not ok then
        _orig_loadFavouriteWeapon(self)
    end
end
