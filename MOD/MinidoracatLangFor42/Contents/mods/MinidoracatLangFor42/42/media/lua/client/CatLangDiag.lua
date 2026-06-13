-- CatLangFor42 翻譯診斷工具
-- 用途：確認 MOD 翻譯是否正確載入
-- 移除方式：刪除此檔案即可，不影響其他功能

-- 版本動態讀取 mod.info（透過 shared/CatLangVersion_Flx.lua），避免寫死後過期
-- 完整版本橫幅由 client/CatLangVersion_Client.lua 負責，此處只印一行診斷標頭避免重複
local MOD_VERSION = (CatLangFor42 and CatLangFor42.getVersion and CatLangFor42.getVersion()) or "unknown"
local TAG = "[CatLangFor42]"

-- ASCII：PZ log 不支援中文（會亂碼）；診斷內文的中文輸出見下方（屬既有行為）
print(TAG .. " Diag tool started (v" .. MOD_VERSION .. ")")

-- ============================================
-- 翻譯載入診斷（OnGameStart 後執行）
-- ============================================
local function runDiagnostics()
    -- 組1：MOD 是否能覆蓋遊戲內建翻譯
    local overrideTests = {
        { key = "IGUI_AdminPanel_AdminPanel",       modValue = "管理面板" },
        { key = "IGUI_AdminPanel_SandboxOptions",   modValue = "沙盒設定" },
    }

    print(TAG .. " --- 翻譯診斷 ---")
    local modOverride = false
    for _, t in ipairs(overrideTests) do
        local result = getText(t.key)
        if result == t.modValue then
            modOverride = true
        end
        print(TAG .. "   " .. t.key .. " = \"" .. tostring(result) .. "\"")
    end

    -- 組2：MOD 獨有翻譯是否載入
    local modOnlyTests = {
        { key = "IGUI_AdminPanel_PVPLogTool",  modValue = "PVP日誌工具" },
        { key = "IGUI_AdminPanel_SeeRoles",    modValue = "角色列表" },
        { key = "IGUI_AdminPanel_SeeUsers",    modValue = "使用者列表" },
        { key = "IGUI_UsersList_Online",        modValue = "線上" },
    }

    local modLoaded = false
    for _, t in ipairs(modOnlyTests) do
        local result = getText(t.key)
        if result == t.modValue then
            modLoaded = true
        end
        print(TAG .. "   " .. t.key .. " = \"" .. tostring(result) .. "\"")
    end

    -- 總結
    if modOverride then
        print(TAG .. " ✓ MOD 翻譯已覆蓋遊戲內建翻譯")
    else
        print(TAG .. " ✗ MOD 翻譯未覆蓋遊戲內建翻譯")
    end
    if modLoaded then
        print(TAG .. " ✓ MOD 獨有翻譯已載入 (JSON 讀取正常)")
    else
        print(TAG .. " ✗ MOD 獨有翻譯未載入 (JSON 可能未被讀取)")
    end
    print(TAG .. " --- 診斷結束 ---")
end

Events.OnGameStart.Add(runDiagnostics)
