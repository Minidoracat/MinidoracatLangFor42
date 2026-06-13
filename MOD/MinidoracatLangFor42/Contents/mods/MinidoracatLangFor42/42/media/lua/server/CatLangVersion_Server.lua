-- CatLangFor42 伺服器端版本顯示
-- 用途：伺服器啟動完成時，把 MOD 版本印到伺服器主控台 / server log，
--       方便管理員與作者比對「回報玩家是否使用最新版本」。
-- 版本來源為動態讀取 mod.info（見 shared/CatLangVersion_Flx.lua），不寫死。

local function printServerVersion()
    if CatLangFor42 and CatLangFor42.printBanner then
        CatLangFor42.printBanner("Server")
    else
        -- shared 版本工具未載入時的保底輸出（理論上不會發生）；用 ASCII 避免 PZ log 亂碼
        print("[CatLangFor42] version helper not loaded (shared/CatLangVersion_Flx.lua missing?)")
    end
end

-- OnServerStarted：專用 / 連線主機伺服器初始化完成時觸發，此時 mod.info 必已就緒
Events.OnServerStarted.Add(printServerVersion)
