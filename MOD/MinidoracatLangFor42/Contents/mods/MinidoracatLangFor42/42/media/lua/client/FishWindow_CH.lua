local UI = PZAPI.UI

local FishWindow = UI.FishWindow
FishWindow.children.bar.children.name.text = getText("IGUI_Fish_Window_Title")

local info = FishWindow.children.body.children.tabPanel.children.info
local guide = FishWindow.children.body.children.tabPanel.children.guide

info.name = getText("IGUI_Fish_Window_Tab_Info")
guide.name = getText("IGUI_Fish_Window_Tab_Guide")
