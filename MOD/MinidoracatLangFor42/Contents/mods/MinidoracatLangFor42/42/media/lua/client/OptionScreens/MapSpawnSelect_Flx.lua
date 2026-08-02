-- MapSpawnSelect_Flx.lua
-- 出生點選擇畫面的中文地圖底圖
--
-- 官方英文底圖在 media/maps/Muldraugh, KY/spawnSelectImagePyramid.zip，
-- 中文版只能放 media/maps/Riverside, KY/ —— Muldraugh 目錄承載全世界的
-- lotheader/lotpack，MOD 建同名目錄會讓 IsoMetaGrid 只看到空殼（見 AGENTS.md
-- ANTI-PATTERNS），所以不能靠 VFS 同路徑覆蓋換圖。
--
-- 官方 fillList() 的迴圈是「最後一個有底圖的城鎮贏」（only one is supported），
-- 順序由 MapGroups 決定、不保證，因此在這裡攔截 setImagePyramid 換掉檔名。
-- 只包裝 setImagePyramid（官方全碼僅 fillList:516 一處呼叫），不複製 fillList，
-- 官方日後改清單／過濾／排序邏輯都會自動跟進（1.10.0 曾因整份複製漏抄
-- only_for_game_mode，導致 7 個沙盒限定城鎮出現在非沙盒模式的清單）。
--
-- 必須用 info.spawnSelectImagePyramid 的絕對路徑：Lua 會把原始參數存進
-- pyramidFileName，之後查圖片尺寸時不會再做一次 VFS 解析。
--
-- 這是條件式替換：只在官方決定使用 image pyramid 時換掉參數。固定出生點、
-- 安全屋等 synthetic region 沒有 map.info，官方走 initMapData fallback、
-- 不會呼叫此 setter，維持原版行為（不可強加底圖，那些 region 沒有 zoom 值）。
-- log 一律 ASCII：PZ 的 print() 不支援 UTF-8，中文只留在註解（見 CatLangVersion_Flx）。

require "OptionScreens/MapSpawnSelect"

local TAG = "[CatLangFor42]"

local _orig_setImagePyramid = MapSpawnSelectImage.setImagePyramid

function MapSpawnSelectImage:setImagePyramid(fileName)
    local info = getMapInfo("Riverside, KY")
    local chinesePyramid = info and info.spawnSelectImagePyramid

    if chinesePyramid then
        if fileName ~= chinesePyramid then
            print(TAG .. " [SpawnSelect] loaded Chinese map pyramid: " .. chinesePyramid)
        end
        return _orig_setImagePyramid(self, chinesePyramid)
    end

    print(TAG .. " [SpawnSelect] WARNING: Chinese map pyramid not found, using original: " .. tostring(fileName))
    return _orig_setImagePyramid(self, fileName)
end
