-- SkillDescription_Flx.lua
-- 技能面板 tooltip 的技能描述修復（HARDCODE_REGISTRY A23）
--
-- 官方 ISSkillProgressBar:updateTooltip（client/XpSystem/ISUI/ISSkillProgressBar.lua:78）
-- 用 perk:getName()（= 當前語言譯名，PerkFactory 由 IGUI_perks_<translation> 固化）
-- 拼 "IGUI_perks_" .. 譯名 .. "_Description"；但官方翻譯資料全語系（含 EN/CH/CN）的
-- Description 鍵一律以「EN 顯示名」為鍵（如 IGUI_perks_Short Blunt_Description，含空白），
-- 只有 EN 環境 getName() == EN 名能命中。中文環境 getText miss 原樣回鍵
-- （Translator.java:398），tooltip 顯示 IGUI_perks_維護_Description。
--
-- 修法：包裝 updateTooltip，_orig 跑完後若 self.message 內含 miss 的原始鍵，
-- 對回 EN 顯示名鍵取回官方 CH/CN 早已翻好的描述值原地替換。譯文不動、不新增
-- 任何翻譯鍵；EN 環境 find 不到鍵直接 return，零改動。
--
-- v2（1.14.2）強化——玩家回報 1.14.1 後仍見原始鍵（MP、掛 SRJ/BCI 環境）：
-- 1. 解析鏈全改「方法呼叫」：pcall(perk.getId)（PerkFactory.java:210 回 id 字串）
--    → tostring(perk)（toString 同回 id）→ perk.translation 欄位（最後備援）。
--    v1 只讀 .translation 欄位，Kahlua 對 Java 欄位的暴露在部分環境不可靠。
-- 2. 譯名反查表雙保險：以 getText("IGUI_perks_"..translation) 建
--    「當前語言技能名 → EN 顯示名」映射（與官方拼 miss 鍵用的是同一個
--    getName() 值，天然一致），token 全滅時仍可由名稱對回。語言切換後
--    查 miss 會自動重建一次。
-- 3. Events.OnGameStart 重新掛裝：若有第三方 mod 在載入期「非鏈式」整份
--    覆寫 updateTooltip 把本 wrapper 蓋掉，開局時再包最外層一次（鏈式
--    mod 如 Skill Recovery Journal 不受影響，其附加內容照常保留）。
-- 4. console 一次性 ASCII log（installed / first fix / unmapped），玩家附
--    console.txt 即可判斷 wrapper 是否在鏈上、解析到哪一步。
--
-- 刻意不處理 _Description1..10 分級描述：42.20 官方 EN 無此類鍵
-- （getTextOrNull 回 nil，官方 guard 直接跳過），全語系同果，無可修內容。
-- 分類 perk（7 個 parent==None）不會生成進度條，不在範圍。
-- 第三方 mod perk：先試 token 鍵（其常見鍵法），miss 則維持原狀，無迴歸。

require "XpSystem/ISUI/ISSkillProgressBar"

local TAG = "[CatLangFor42]"

-- perk translation token → 42.20 官方 EN 顯示名（EN/IG_UI.json 的 IGUI_perks_<token> 值）。
-- 另含 4 個 id 別名（getId 與 translation 不同者：Woodwork/PlantScavenging/Lightfoot/Sneak），
-- 讓 id 解析路徑也能直接命中。PZ 升版依 HARDCODE_REGISTRY A23 SOP 重核本表。
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
    -- id 別名（getId ≠ translation 的 4 個）
    Woodwork = "Carpentry",
    PlantScavenging = "Foraging",
    Lightfoot = "Lightfooted",
    Sneak = "Sneaking",
}

-- 當前語言技能名 → EN 顯示名（懶建；語言切換後 miss 時重建一次）
local nameToEn = nil
local function buildNameMap()
    nameToEn = {}
    for token, en in pairs(EN_NAME) do
        local nm = getTextOrNull("IGUI_perks_" .. token)
        if nm and nm ~= "" then
            nameToEn[nm] = en
        end
    end
end

local loggedFix, loggedMiss = false, false

local function resolveDescription(perk, perkName)
    -- 1) token：getId 方法 → toString → translation 欄位
    local ok, token = pcall(function() return perk:getId() end)
    if not ok or not token then token = tostring(perk) end
    if type(token) ~= "string" then token = nil end
    -- 真正的 backstop 是下方的 nameToEn 譯名反查，不是這裡；token 只是快路徑。
    -- （第三方 mod 的 perk 物件不保證 getId 回字串，型別不符就交給反查。）

    if token and token ~= "" then
        -- 第三方 mod perk 慣用 token 鍵，優先試
        local byToken = getTextOrNull("IGUI_perks_" .. token .. "_Description")
        if byToken and byToken ~= "" then return byToken end
        local en = EN_NAME[token]
        if en then
            local byEn = getTextOrNull("IGUI_perks_" .. en .. "_Description")
            if byEn and byEn ~= "" then return byEn end
        end
    end

    -- 2) 譯名反查（與官方拼鍵同源的 getName 值）
    if not nameToEn then buildNameMap() end
    local en = nameToEn[perkName]
    if not en then
        buildNameMap() -- 語言切換後重建一次再試
        en = nameToEn[perkName]
    end
    if en then
        local byEn = getTextOrNull("IGUI_perks_" .. en .. "_Description")
        if byEn and byEn ~= "" then return byEn end
    end
    return nil
end

local function wrappedUpdateTooltip(self, lvlSelected, orig)
    orig(self, lvlSelected)
    if not self.message or not self.perk then return end

    local perkName = self.perk:getName()
    local missKey = "IGUI_perks_" .. perkName .. "_Description"
    local s, e = string.find(self.message, missKey, 1, true)
    if not s then return end -- EN 環境或已被前一層修好

    local fixed = resolveDescription(self.perk, perkName)
    if fixed and fixed ~= "" then
        self.message = string.sub(self.message, 1, s - 1) .. fixed .. string.sub(self.message, e + 1)
        if not loggedFix then
            loggedFix = true
            print(TAG .. " [SkillDesc] first fix applied: " .. missKey)
        end
    elseif not loggedMiss then
        loggedMiss = true
        print(TAG .. " [SkillDesc] WARNING: no mapping for key: " .. missKey)
    end
end

local function installWrapper(stage)
    local current = ISSkillProgressBar.updateTooltip
    if ISSkillProgressBar._CatLangSkillDescWrapped == current then return end
    local fn = function(self, lvlSelected)
        return wrappedUpdateTooltip(self, lvlSelected, current)
    end
    ISSkillProgressBar.updateTooltip = fn
    ISSkillProgressBar._CatLangSkillDescWrapped = fn
    print(TAG .. " [SkillDesc] wrapper installed (" .. stage .. ")")
end

installWrapper("load")

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function()
        installWrapper("OnGameStart")
        nameToEn = nil -- 進場語言可能與載入時不同，強制重建
    end)
end
