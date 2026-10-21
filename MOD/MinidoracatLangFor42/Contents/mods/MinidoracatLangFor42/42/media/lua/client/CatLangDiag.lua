-- CatLangFor42 翻譯診斷工具
-- 用途：確認 MOD 翻譯是否正確載入
-- 移除方式：刪除此檔案即可，不影響其他功能

-- 版本動態讀取 mod.info（透過 shared/CatLangVersion_Flx.lua），避免寫死後過期
-- 完整版本橫幅由 client/CatLangVersion_Client.lua 負責，此處只印一行診斷標頭避免重複
local MOD_VERSION = (CatLangFor42 and CatLangFor42.getVersion and CatLangFor42.getVersion()) or "unknown"
local TAG = "[CatLangFor42]"

-- log 一律 ASCII；期望值的中文寫成 UTF-8 位元組跳脫（行尾註解是原文）：直接寫的非 ASCII 字面值
-- 會被 Kahlua 截壞，以前的中文 log 是亂碼、比對也永遠不中（verify_mod 4b）。
print(TAG .. " Diag tool started (v" .. MOD_VERSION .. ")")

-- ============================================
-- 翻譯載入診斷（OnGameStart 後執行）
-- ============================================
local function runDiagnostics()
    -- 期望值是繁中字（簡中的「管理面板」「角色列表」同字也比得中）；其他語言一定比不中，印 FAIL 會讓人以為翻譯包壞了
    local lang = Translator.getLanguage():name()
    if lang ~= "CH" and lang ~= "CN" then
        print(TAG .. " translation diagnostics skipped (language " .. tostring(lang) .. ")")
        return
    end

    -- 組1：MOD 是否能覆蓋遊戲內建翻譯
    local overrideTests = {
        { key = "IGUI_AdminPanel_AdminPanel",       modValue = "\231\174\161\231\144\134\233\157\162\230\157\191" }, -- 管理面板
        { key = "IGUI_AdminPanel_SandboxOptions",   modValue = "\230\178\153\231\155\146\232\168\173\229\174\154" }, -- 沙盒設定
    }

    print(TAG .. " --- translation diagnostics ---")
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
        { key = "IGUI_AdminPanel_PVPLogTool",  modValue = "PVP\230\151\165\232\170\140\229\183\165\229\133\183" }, -- PVP日誌工具
        { key = "IGUI_AdminPanel_SeeRoles",    modValue = "\232\167\146\232\137\178\229\136\151\232\161\168" }, -- 角色列表
        { key = "IGUI_AdminPanel_SeeUsers",    modValue = "\228\189\191\231\148\168\232\128\133\229\136\151\232\161\168" }, -- 使用者列表
        { key = "IGUI_UsersList_Online",        modValue = "\231\183\154\228\184\138" }, -- 線上
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
        print(TAG .. " OK: MOD translation overrides built-in translation")
    else
        print(TAG .. " FAIL: MOD translation does not override built-in translation")
    end
    if modLoaded then
        print(TAG .. " OK: MOD-only translations loaded (JSON read OK)")
    else
        print(TAG .. " FAIL: MOD-only translations not loaded (JSON may not have been read)")
    end
    print(TAG .. " --- end of diagnostics ---")
end

Events.OnGameStart.Add(runDiagnostics)
