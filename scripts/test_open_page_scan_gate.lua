-- 測試 OpenPageScanGate_Flx.lua：開著的物品欄什麼時候可以略過重掃
-- 執行：lua scripts/test_open_page_scan_gate.lua（須在 repo 根目錄，dofile 走相對路徑）
--
-- 略過錯了的代價是玩家看到沒修好的英文名，所以每一種「內容變了」都要逼出重掃：
-- 件數變、尾端被替換（server 替換物品是 remove＋append）、頭端換掉、時間到、OnContainerUpdate。

local now = 0
function getTimestampMs() return now end

dofile("MOD/MinidoracatLangFor42/Contents/mods/MinidoracatLangFor42/42/media/lua/shared/Items/OpenPageScanGate_Flx.lua")
local Gate = OpenPageScanGateFlx

-- 假容器：ids 是物品 ID 清單，順序即 ItemContainer.items 的順序
local function makeContainer(ids)
    local list = {}
    function list:size() return #ids end
    function list:get(i)
        local id = ids[i + 1]
        return id and { getID = function() return id end }
    end
    return { ids = ids, getItems = function() return list end }
end

local passed, failed = 0, 0
local function check(name, got, want)
    if got == want then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("FAIL %s: got %s, want %s", name, tostring(got), tostring(want)))
    end
end

local box = makeContainer({ 1, 2, 3 })

check("nil 容器交給呼叫端處理", Gate.skip("A", nil), false)
check("第一次一定掃", Gate.skip("A", box), false)
check("沒變、剛掃過→略過", Gate.skip("A", box), true)

table.insert(box.ids, 4)
check("件數變→重掃", Gate.skip("A", box), false)
check("重掃後沒變→略過", Gate.skip("A", box), true)

-- server 替換物品：移除舊的、新物品接在尾端，件數不變
table.remove(box.ids, 2)
table.insert(box.ids, 9)
check("替換物品（件數不變、尾端換新）→重掃", Gate.skip("A", box), false)

box.ids[1] = 7
check("頭端換掉→重掃", Gate.skip("A", box), false)

now = now + Gate.RESCAN_MS - 1
check("未滿重掃間隔→略過", Gate.skip("A", box), true)
now = now + 1
check("滿重掃間隔→重掃", Gate.skip("A", box), false)

Gate.invalidate("A")
check("invalidate 後→重掃", Gate.skip("A", box), false)

check("另一個遷移層有自己的紀錄", Gate.skip("B", box), false)
check("另一個容器有自己的紀錄", Gate.skip("A", makeContainer({ 1, 2, 3 })), false)

local empty = makeContainer({})
check("空容器第一次掃", Gate.skip("A", empty), false)
check("空容器沒變→略過", Gate.skip("A", empty), true)

print(string.format("passed=%d failed=%d", passed, failed))
os.exit(failed == 0 and 0 or 1)
