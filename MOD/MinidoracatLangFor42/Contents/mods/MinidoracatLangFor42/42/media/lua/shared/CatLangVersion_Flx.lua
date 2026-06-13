-- CatLangFor42 版本資訊工具（shared，client / server 皆會載入）
-- 用途：動態讀取 mod.info 的 modversion，避免版本字串寫死後過期。
-- 公開 API：
--   CatLangFor42.getVersion()         -> 版本字串，例如 "42.19.0-1.6.6"；讀取失敗回 "unknown"
--   CatLangFor42.printBanner(context) -> 印出版本橫幅到主控台 / log；context 例如 "Client" / "Server"

CatLangFor42 = CatLangFor42 or {}

local MOD_ID = "CatLangFor42"
local TAG = "[CatLangFor42]"

--- 動態取得本 MOD 版本（讀 mod.info 的 modversion=）。
-- 使用 base-game 驗證過的寫法：getModInfoByID(id):getModVersion()
function CatLangFor42.getVersion()
    local ok, info = pcall(getModInfoByID, MOD_ID)
    if ok and info then
        local ok2, ver = pcall(function() return info:getModVersion() end)
        if ok2 and ver and ver ~= "" then
            return ver
        end
    end
    return "unknown"
end

--- 印出版本橫幅到主控台 / log（會出現在 DebugLog / server log，方便比對回報玩家版本）。
-- @param context string  情境標籤，例如 "Client" / "Server"
function CatLangFor42.printBanner(context)
    local ver = CatLangFor42.getVersion()
    -- 全程使用 ASCII：PZ 的 print() -> DebugLog/console 不支援 UTF-8 中文（會變 ? 亂碼），
    -- 版本資訊本來就全是 ASCII，顯示正常；中文只放在註解，不進 log。
    print(TAG .. " ========================================")
    print(TAG .. " CatLangFor42 v" .. ver .. " [" .. tostring(context) .. "]")
    print(TAG .. " Traditional/Simplified Chinese translation by Minidoracat")
    print(TAG .. " ========================================")
    return ver
end
