-- BrushTool_Flx.lua
-- 修復 Brush Tool 除錯視窗內部的硬編碼英文按鈕/下拉/標題（HARDCODE_REGISTRY.md B12）。
--
-- 這些不是情境選單的 addOption，而是 ISButton 建構參數、ISComboBox 的 addOption
-- 與視窗 title 欄位 —— A16 的選單樹 walker 結構上涵蓋不到，必須包裝各自的
-- createChildren / new 後改寫既有元件。
--
-- 查表 miss 一律原樣保留（getTextOrNull，非 CH/CN 語系回 nil）。
-- 純除錯工具（Brush Tool 僅在除錯模式可開），一般玩家路徑不會載入這些視窗。

for _, path in ipairs({
    "DebugUIs/BrushTool/BrushToolManager",
    "DebugUIs/BrushTool/FireBrushUI",
    "DebugUIs/BrushTool/BrushToolChooseTileUI",
}) do
    pcall(require, path)
end

local function tr(key)
    return getTextOrNull(key)
end

--- 改寫 ISButton 標題；查無譯文不動
local function setButtonTitle(btn, key)
    if btn and btn.setTitle then
        local t = tr(key)
        if t then btn:setTitle(t) end
    end
end

--- 包裝 createChildren，建好子元件後改寫文字
local function wrapCreateChildren(class, apply)
    if type(class) ~= "table" or type(class.createChildren) ~= "function" then
        return
    end
    local _orig = class.createChildren
    class.createChildren = function(self, ...)
        local result = _orig(self, ...)
        pcall(apply, self)
        return result
    end
end

-- BrushToolManager：三顆按鈕（說明視窗內文為長段自由文字，刻意不譯）
wrapCreateChildren(BrushToolManager, function(self)
    setButtonTitle(self.chooseTile, "IGUI_CatLangBrush_ChooseTile")
    setButtonTitle(self.controlFire, "IGUI_CatLangBrush_ControlFire")
    setButtonTitle(self.help, "IGUI_CatLangBrush_Help")
end)

-- FireBrushUI：類型下拉三項 ＋ 五顆按鈕
local FIRE_TYPE_KEYS = {
    ["Fire"] = "IGUI_CatLangBrush_TypeFire",
    ["Smoke"] = "IGUI_CatLangBrush_TypeSmoke",
    ["Explosion"] = "IGUI_CatLangBrush_TypeExplosion",
}

wrapCreateChildren(FireBrushUI, function(self)
    local combo = self.brushType
    if combo and combo.options then
        -- ISComboBox:addOption(option) 直接 table.insert 原始值，故純字串；
        -- addOptionWithData 才會產生 {text=,data=,tooltip=} 表。兩種都處理，
        -- 只改顯示文字，不動索引順序（FireBrushUI 靠 selected 索引判斷類型）。
        for i, opt in ipairs(combo.options) do
            if type(opt) == "string" then
                local t = FIRE_TYPE_KEYS[opt] and tr(FIRE_TYPE_KEYS[opt])
                if t then combo.options[i] = t end
            elseif type(opt) == "table" and type(opt.text) == "string" then
                local t = FIRE_TYPE_KEYS[opt.text] and tr(FIRE_TYPE_KEYS[opt.text])
                if t then opt.text = t end
            end
        end
    end
    setButtonTitle(self.addByClick, "IGUI_CatLangBrush_AddByClick")
    setButtonTitle(self.removeByClick, "IGUI_CatLangBrush_RemoveByClick")
    setButtonTitle(self.addByArea, "IGUI_CatLangBrush_AddByArea")
    setButtonTitle(self.removeByArea, "IGUI_CatLangBrush_RemoveByArea")
    setButtonTitle(self.close, "IGUI_CatLangBrush_Close")
end)

-- BrushToolChooseTileUI：視窗標題在 new() 內以 o.title 設定，須包 new
if type(BrushToolChooseTileUI) == "table" and type(BrushToolChooseTileUI.new) == "function" then
    local _origNew = BrushToolChooseTileUI.new
    function BrushToolChooseTileUI:new(...)
        local o = _origNew(self, ...)
        if o and o.title == "Tiles" then
            local t = tr("IGUI_CatLangBrush_Tiles")
            if t then o.title = t end
        end
        return o
    end
end
