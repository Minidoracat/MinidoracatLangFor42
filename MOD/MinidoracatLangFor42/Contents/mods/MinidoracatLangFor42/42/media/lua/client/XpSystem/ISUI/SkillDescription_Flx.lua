-- SkillDescription_Flx.lua
-- 技能面板 tooltip 的技能描述修復（HARDCODE_REGISTRY A23）
--
-- 官方 ISSkillProgressBar:updateTooltip（client/XpSystem/ISUI/ISSkillProgressBar.lua:78）
-- 用 perk:getName()（= 當前語言譯名，PerkFactory.java:148 由 IGUI_perks_<translation> 固化）
-- 拼 "IGUI_perks_" .. 譯名 .. "_Description"；但官方翻譯資料全語系（含 EN/CH/CN）的
-- Description 鍵一律以「EN 顯示名」為鍵（如 IGUI_perks_Short Blunt_Description，含空白），
-- 只有 EN 環境 getName() == EN 名能命中。中文環境 getText miss 原樣回鍵
-- （Translator.java:398），tooltip 顯示 IGUI_perks_短棍_Description。
--
-- 修法：包裝 updateTooltip，_orig 跑完後若 self.message 內含 miss 的原始鍵，
-- 用 perk.translation（public 欄位，PerkName_Flx 已驗證 Lua 可讀）對回 EN 顯示名，
-- 取回官方 CH/CN 早已翻好的描述值原地替換。譯文不動、不新增任何翻譯鍵，
-- 官方日後改描述文字自動跟進；EN 環境 find 不到鍵直接 return，零改動。
--
-- 刻意不處理 line 79 的 _Description1..10 分級描述：42.20 官方 EN 無此類鍵
-- （getTextOrNull 回 nil，官方 guard 直接跳過），全語系同果，無可修內容。
-- 分類 perk（Combat/Crafting 等 7 個 parent==None）不會生成進度條
-- （ISCharacterInfo.lua:272 只收 getParent() ~= Perks.None 的子技能），不在範圍。
-- 第三方 mod perk：先試 token 鍵（其常見鍵法），miss 則維持原狀，無迴歸。

require "XpSystem/ISUI/ISSkillProgressBar"

-- perk.translation token → 42.20 官方 EN 顯示名（EN/IG_UI.json 的 IGUI_perks_<token> 值）
-- 35 個子技能全收；PZ 升版時依 HARDCODE_REGISTRY A23 的 SOP 重新核對本表
local EN_NAME = {
    Axe = "Axe",
    Blunt = "Long Blunt",
    SmallBlunt = "Short Blunt",
    LongBlade = "Long Blade",
    SmallBlade = "Short Blade",
    Spear = "Spear",
    Maintenance = "Maintenance",
    Aiming = "Aiming",
    Reloading = "Reloading",
    Carpentry = "Carpentry",
    Carving = "Carving",
    Cooking = "Cooking",
    Electricity = "Electrical",
    Doctor = "First Aid",
    Glassmaking = "Glassmaking",
    FlintKnapping = "Knapping",
    Masonry = "Masonry",
    Blacksmith = "Blacksmithing",
    Mechanics = "Mechanics",
    Pottery = "Pottery",
    Tailoring = "Tailoring",
    MetalWelding = "Welding",
    Fishing = "Fishing",
    Foraging = "Foraging",
    Tracking = "Tracking",
    Trapping = "Trapping",
    Fitness = "Fitness",
    Strength = "Strength",
    Lightfooted = "Lightfooted",
    Nimble = "Nimble",
    Sprinting = "Running",
    Sneaking = "Sneaking",
    Farming = "Agriculture",
    Husbandry = "Animal Care",
    Butchering = "Butchering",
}

local _orig_updateTooltip = ISSkillProgressBar.updateTooltip

function ISSkillProgressBar:updateTooltip(lvlSelected)
    _orig_updateTooltip(self, lvlSelected)
    if not self.message or not self.perk then return end

    -- getText miss 時鍵會逐字出現在 message；有命中（EN 環境）就 find 不到，直接離開
    local missKey = "IGUI_perks_" .. self.perk:getName() .. "_Description"
    local s, e = string.find(self.message, missKey, 1, true)
    if not s then return end

    local token = self.perk.translation and tostring(self.perk.translation) or nil
    local fixed = token and getTextOrNull("IGUI_perks_" .. token .. "_Description") or nil
    if (not fixed or fixed == "") and token and EN_NAME[token] then
        fixed = getTextOrNull("IGUI_perks_" .. EN_NAME[token] .. "_Description")
    end
    if fixed and fixed ~= "" then
        self.message = string.sub(self.message, 1, s - 1) .. fixed .. string.sub(self.message, e + 1)
    end
end
