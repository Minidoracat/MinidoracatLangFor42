-- FishWindow_Flx.lua
-- 釣魚視窗標題與分頁翻譯。
--
-- 防護：vanilla 模板在 lua 載入期即帶完整 children 結構，但第三方 MOD 可能
-- 替換/破壞 PZAPI.UI.FishWindow（2026-07 玩家回報實例：children 為 null），
-- 未來 PZ 改版也可能變更結構——鏈上任一節點缺失即安靜跳過該項（僅該視窗
-- 維持原文），不產生錯誤。刻意不用 pcall 整包吞錯：只防節點缺失，
-- 其他問題（typo、API 行為變更）照常暴露。

local function get(node, ...)
    for i = 1, select("#", ...) do
        if type(node) ~= "table" then return nil end
        node = node[select(i, ...)]
    end
    return node
end

local FishWindow = PZAPI and PZAPI.UI and PZAPI.UI.FishWindow

local title = get(FishWindow, "children", "bar", "children", "name")
if title then title.text = getText("IGUI_Fish_Window_Title") end

local info = get(FishWindow, "children", "body", "children", "tabPanel", "children", "info")
if info then info.name = getText("IGUI_Fish_Window_Tab_Info") end

local guide = get(FishWindow, "children", "body", "children", "tabPanel", "children", "guide")
if guide then guide.name = getText("IGUI_Fish_Window_Tab_Guide") end

if not (title and info and guide) then
    print("[CatLangFor42] FishWindow 模板不完整，部分翻譯跳過（可能為 MOD 衝突或 PZ 結構變更）")
end
