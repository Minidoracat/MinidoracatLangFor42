-- ISExtendedPlacementUI_Flx.lua
-- 延伸 3D 放置模式視窗打不開
--
-- 原版 ISExtendedPlacementUI:adjust() 在 Z 軸標籤比 X、Y 都寬時讀 self.labelaxisz.name
-- （ISExtendedPlacementUI.lua:301），這個欄位從未賦值，應為 labelzmov。原版字型的
-- Z 軸標籤不會最寬；本包 2x 圖集（字級「中」）的 Z 比 X 寬 1px，initialise() 因此丟錯、
-- 視窗不出現。執行前補上別名即可，不複製原版排版邏輯。
-- 官方修掉筆誤（原版 grep self.labelaxisz 零命中）後刪除本檔。

require "ISUI/ISExtendedPlacementUI"

local _orig_adjust = ISExtendedPlacementUI.adjust

function ISExtendedPlacementUI:adjust()
    self.labelaxisz = self.labelaxisz or self.labelzmov
    return _orig_adjust(self)
end
