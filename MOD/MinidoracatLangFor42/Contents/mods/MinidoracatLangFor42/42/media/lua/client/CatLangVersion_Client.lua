-- CatLangFor42 客戶端版本顯示
-- 用途：遊戲啟動時把 MOD 版本印到客戶端主控台 / DebugLog.txt，
--       玩家回報問題通常會附 DebugLog，作者可一眼確認其使用版本是否為最新。
-- 版本來源為動態讀取 mod.info（見 shared/CatLangVersion_Flx.lua），不寫死。
-- 注意：此為永久功能，與可刪除的 CatLangDiag.lua 診斷工具獨立。

-- OnGameBoot 在主選單開機與載入進世界等路徑可能多次觸發，用 upvalue 旗標確保每 process 只印一次
local printed = false

local function printClientVersion()
    if printed then return end
    printed = true
    if CatLangFor42 and CatLangFor42.printBanner then
        CatLangFor42.printBanner("Client")
    else
        -- ASCII：避免 PZ log 中文亂碼
        print("[CatLangFor42] version helper not loaded (shared/CatLangVersion_Flx.lua missing?)")
    end
end

-- OnGameBoot：所有 mod 載入完成後觸發，此時 mod.info 必已就緒
Events.OnGameBoot.Add(printClientVersion)
