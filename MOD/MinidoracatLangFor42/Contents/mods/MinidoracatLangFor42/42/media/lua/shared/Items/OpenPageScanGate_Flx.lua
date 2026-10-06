-- MinidoracatLangFor42 — shared/Items 遷移層共用的「開啟中物品欄重掃節流」。
--
-- 七個遷移層（ItemNameFix、DynamicItemName、EvolvedRecipeName、AnimalProductName、RecipeLiterature、
-- RecordedMediaName、VehicleKey）在 OnRefreshInventoryWindowContainers 與 EveryOneMinute 都會把目前開著的
-- 物品欄／戰利品容器逐件重掃。戰利品視窗每轉一次向、每走一格就 refresh（原版與 CleanUI 的
-- ISInventoryPage:update），日長 1 小時的伺服器每 2.5 秒就有一次 EveryOneMinute：6000 件的容器開著時，
-- 站著不動每 2.5 秒卡約 40 ms，每轉一次向多約 30 ms（2026-10-07 實機量測，DevProfiler 逐函式歸因）。
--
-- 物品名只在物品進出、被替換或被改名時才需要再修，所以各遷移層記住上次掃某容器時的「件數＋頭尾物品 ID」
-- 與時間：三者都沒變、RESCAN_MS 內掃過就略過。
-- - server 補送內容（AddInventoryItemToContainerPacket）與替換物品（ReplaceInventoryItemInContainerPacket）
--   都不觸發 Lua 事件，但前者件數變、後者把新物品接在清單尾端（ItemContainer.addItem 一律 append），
--   簽章都會變。
-- - 簽章看不出的就地改名，最晚 RESCAN_MS 後補修。
-- - OnContainerUpdate（內容真的變了）先 invalidate 再全掃；OnFillContainer、OnGameStart、OnCreatePlayer
--   直接修容器或玩家物品，不經過這裡。
OpenPageScanGateFlx = OpenPageScanGateFlx or {}
local Gate = OpenPageScanGateFlx

-- 簽章沒變時的最長重掃間隔
Gate.RESCAN_MS = 30000
-- 每個遷移層最多記幾個容器，超過就整批重來。每頁一次只顯示一個容器，16 個綽綽有餘；
-- 紀錄以容器物件為鍵，上限也限制了被留住、不能回收的容器數量
Gate.MAX_TRACKED = 16

local records = {}

local function itemId(items, index)
    local item = items:get(index)
    return item and item:getID()
end

--- 這次能不能略過重掃。回傳 true＝同一遷移層 RESCAN_MS 內掃過這個容器且簽章沒變；
--- 回傳 false 時已把這次當成「掃過」記下，呼叫端接著照常掃。
--- @param owner string 遷移層名稱（各檔各自一份紀錄，互不影響）
--- @param container ItemContainer|nil
function Gate.skip(owner, container)
    if not container then return false end
    local items = container:getItems()
    if not items then return false end
    local count = items:size()
    local first, last
    if count > 0 then
        first, last = itemId(items, 0), itemId(items, count - 1)
    end
    local now = getTimestampMs()
    local book = records[owner]
    if not book then
        book = { n = 0, byContainer = {} }
        records[owner] = book
    end
    local rec = book.byContainer[container]
    if rec and rec.count == count and rec.first == first and rec.last == last
        and now - rec.at < Gate.RESCAN_MS then
        return true
    end
    if not rec then
        if book.n >= Gate.MAX_TRACKED then
            book.byContainer, book.n = {}, 0
        end
        rec = {}
        book.byContainer[container] = rec
        book.n = book.n + 1
    end
    rec.count, rec.first, rec.last, rec.at = count, first, last, now
    return false
end

--- 內容有變（OnContainerUpdate）：丟掉這個遷移層的紀錄，下一次一律重掃。
function Gate.invalidate(owner)
    records[owner] = nil
end
