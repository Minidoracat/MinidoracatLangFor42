-- VehicleKey_Flx.lua
-- 修復車鑰匙顯示名稱的英文硬編碼問題
--
-- 問題根因（經 projectzomboid.jar 反編譯確認）：
--   Java 層 zombie/inventory/ItemPickerJava$KeyNamer.nameKey() 與
--   BaseVehicle.keyNamerVehicle() 會在車輛 spawn 時呼叫
--   item:setName("Vehicle Key - " .. 英文車名) 將名稱寫入物品實例與存檔。
--   即使玩家語言為繁/簡中文，之後也不會重算。
--
-- 修復策略：
--   1. 事件觸發時掃描玩家物品欄內 Base.CarKey 物品
--   2. 解析 getName() 找出 "Vehicle Key - {英文車名}" 格式
--   3. 用預先生成的反查表找出對應的 IGUI_VehicleName* key
--   4. 以當前語言呼叫 getText() 取翻譯，組合後 setName() 寫回
--
-- 反查表由 scripts/sync_translations.py gen-vehicle-map 從
-- vanilla EN/IG_UI.json 產生，執行時依語言 getText() 自動對應 CH/CN。
--
-- 同一 pattern 來源：SpawnItems_Flx.lua（修復 ID Card/Passport 等）

local TAG = "[CatLangFor42]"

-- ============================================
-- 自動產生區塊：英文車名 → IGUI key 反查表
-- ============================================
-- <AUTO-GEN:VEHICLE_NAME_MAP START>
-- 由 scripts/sync_translations.py gen-vehicle-map 自動產生，請勿手動編輯
-- 來源：vanilla EN/IG_UI.json（共 144 條）
VehicleKeyFlx = VehicleKeyFlx or {}
VehicleKeyFlx.EN_TO_KEY = {
    ["Airport Catering Chevalier Step Van"] = "IGUI_VehicleNameStepVanAirportCatering",
    ["Airport Chevalier D6"] = "IGUI_VehicleNamePickUpTruckLightsAirport",
    ["Airport Franklin Valuline"] = "IGUI_VehicleNameVanSeatsAirportShuttle",
    ["Airport Security Chevalier D6"] = "IGUI_VehicleNamePickUpTruckLightsAirportSecurity",
    ["Ambulance"] = "IGUI_VehicleNameVanAmbulance",
    ["Beckman's Building Franklin Valuline"] = "IGUI_VehicleNameVanBeckmans",
    ["Brewster & Harbin Franklin Valuline"] = "IGUI_VehicleNameVanBrewsterHarbin",
    ["Bricking It Dash Bulldriver"] = "IGUI_VehicleNamePickUpVanBrickingIt",
    ["Bug Wipers Franklin Valuline"] = "IGUI_VehicleNameVan_BugWipers",
    ["Builder's Dash Bulldriver"] = "IGUI_VehicleNamePickUpVanBuilder",
    ["Builder's Franklin Valuline"] = "IGUI_VehicleNameVanBuilder",
    ["Bulletin Sheriff Chevalier Nyala"] = "IGUI_VehicleNameCarLightsBulletinSheriff",
    ["Burnt %1"] = "IGUI_VehicleNameBurntCar",
    ["Calloway Landscaping Dash Bulldriver"] = "IGUI_VehicleNamePickUpVanCallowayLandscaping",
    ["Carpenter's Dash Bulldriver"] = "IGUI_VehicleNamePickUpVanLightsCarpenter",
    ["Carpenter's Franklin Valuline"] = "IGUI_VehicleNameVanCarpenter",
    ["Cereal Delivery Chevalier Step Van"] = "IGUI_VehicleNameStepVan_Cereal",
    ["Chevalier Cerise Wagon"] = "IGUI_VehicleNameCarStationWagon",
    ["Chevalier Cossette"] = "IGUI_VehicleNameSportsCar",
    ["Chevalier D6"] = "IGUI_VehicleNamePickUpTruck",
    ["Chevalier Dart"] = "IGUI_VehicleNameSmallCar",
    ["Chevalier Nyala"] = "IGUI_VehicleNameCarLights",
    ["Chevalier Primani"] = "IGUI_VehicleNameModernCar02",
    ["Chevalier Step Van"] = "IGUI_VehicleNameStepVan",
    ["Citr8 Chevalier Step Van"] = "IGUI_VehicleNameStepVan_Citr8",
    ["Coast 2 Coast Franklin Valuline"] = "IGUI_VehicleNameVanCoastToCoast",
    ["Complete Repair Shop Chevalier Step Van"] = "IGUI_VehicleNameStepVan_CompleteRepairShop",
    ["Creature Cruiser"] = "IGUI_VehicleNameVanSeats_Creature",
    ["Dash Bulldriver"] = "IGUI_VehicleNamePickUpVan",
    ["Dash Elite"] = "IGUI_VehicleNameModernCar",
    ["Dash Rancher"] = "IGUI_VehicleNameOffRoad",
    ["Deer Valley Power Franklin Valuline"] = "IGUI_VehicleNameVanDeerValley",
    ["Fire Department Chevalier D6"] = "IGUI_VehicleNamePickUpTruckLightsFire",
    ["Fire Department Dash Bulldriver"] = "IGUI_VehicleNamePickUpVanLightsFire",
    ["Fossoil Chevalier D6"] = "IGUI_VehicleNamePickUpTruckLightsFossoil",
    ["Fossoil Dash Bulldriver"] = "IGUI_VehicleNamePickUpVanLightsFossoil",
    ["Fossoil Franklin Valuline"] = "IGUI_VehicleNameVanFossoil",
    ["Franklin All-Terrain"] = "IGUI_VehicleNameSUV",
    ["Franklin Valuline"] = "IGUI_VehicleNameVan",
    ["Garden Gods Franklin Valuline"] = "IGUI_VehicleNameVanGardenGods",
    ["Gardener's Franklin Valuline"] = "IGUI_VehicleNameVanGardener",
    ["Genuine Beer Chevalier Step Van"] = "IGUI_VehicleNameStepVan_Genuine_Beer",
    ["Greenes Franklin Valuline"] = "IGUI_VehicleNameVanVanGreenes",
    ["Helton Metalworking Dash Bulldriver"] = "IGUI_VehicleNamePickUpVanHeltonMetalWorking",
    ["Horse trailer"] = "IGUI_VehicleNameTrailer_Horsebox",
    ["Huang's Laundry Chevalier Step Van"] = "IGUI_VehicleNameStepVan_HuangsLaundry",
    ["JP Landscaping Chevalier D6"] = "IGUI_VehicleNamePickUpTruckJPLandscaping",
    ["John McCoy Woodworking Franklin Valuline"] = "IGUI_VehicleNameVanJohnMcCoy",
    ["Jones Fabrication Franklin Valuline"] = "IGUI_VehicleNameVanJonesFabrication",
    ["Jorgensen Chevalier Step Van"] = "IGUI_VehicleNameStepVan_Jorgensen",
    ["KY Herald Chevalier Step Van"] = "IGUI_VehicleNameStepVan_Heralds",
    ["Kentucky Lumber Dash Bulldriver"] = "IGUI_VehicleNamePickUpVanLightsKentuckyLumber",
    ["Kerr Homes Franklin Valuline"] = "IGUI_VehicleNameVanKerrHomes",
    ["Kimbler Konstruction Dash Bulldriver"] = "IGUI_VehicleNamePickUpVanKimbleKonstruction",
    ["Knob Creek Gas Franklin Valuline"] = "IGUI_VehicleNameVanKnobCreekGas",
    ["Knox Distillery"] = "IGUI_VehicleNameKnoxDistillery",
    ["Knox Distillery Franklin Valuline"] = "IGUI_VehicleNameVan_KnoxDisti",
    ["Knox Telecommunications Franklin Valuline"] = "IGUI_VehicleNameVanKnoxCom",
    ["Korshunov's Car Center Franklin Valuline"] = "IGUI_VehicleNameVanKorshunovs",
    ["LBMW Radio Van"] = "IGUI_VehicleNameVanRadio",
    ["LCPD Chevalier Nyala"] = "IGUI_VehicleNameCarLightsLouisvilleCounty",
    ["LCPD Dash Bulldriver"] = "IGUI_VehicleNamePickUpVanLightsLouisvilleCounty",
    ["Lectromax"] = "IGUI_VehicleNameLectroMax",
    ["Lectromax Franklin Valuline"] = "IGUI_VehicleNameVan_LectroMax",
    ["Livestock Trailer"] = "IGUI_VehicleNameTrailer_Livestock",
    ["Louisville Landscaping Franklin Valuline"] = "IGUI_VehicleNameVanLouisvilleLandscaping",
    ["Louisville Motorshop Chevalier Step Van"] = "IGUI_VehicleNameStepVan_LouisvilleMotorShop",
    ["Louisville Police Dash Elite"] = "IGUI_VehicleNameModernCarLightsCityLouisvillePD",
    ["Louisville SWAT Chevalier Step Van"] = "IGUI_VehicleNameStepVan_LouisvilleSWAT",
    ["Mail Chevalier Step Van"] = "IGUI_VehicleNameStepVanMail",
    ["Mail Franklin Valuline"] = "IGUI_VehicleNameVanMail",
    ["March Ridge Construction Dash Bulldriver"] = "IGUI_VehicleNamePickUpVanMarchRidgeConstruction",
    ["Marine Bites Chevalier Step Van"] = "IGUI_VehicleNameStepVan_MarineBites",
    ["Mass GenFac Franklin Valuline"] = "IGUI_VehicleNameVan_MassGenFac",
    ["Mass-Genfac"] = "IGUI_VehicleNameMassGenFac",
    ["Masterson Horizon"] = "IGUI_VehicleNameSmallCar02",
    ["McCoy Chevalier D6"] = "IGUI_VehicleNamePickUpTruckMccoy",
    ["McCoy Dash Bulldriver"] = "IGUI_VehicleNamePickUpVanMccoy",
    ["McCoy Franklin Valuline"] = "IGUI_VehicleNameVanMccoy",
    ["McCoy Logging"] = "IGUI_VehicleNameMccoyLogging",
    ["Meade Sheriff Dash Elite"] = "IGUI_VehicleNameModernCarLightsMeadeSheriff",
    ["Mechanic's Chevalier Step Van"] = "IGUI_VehicleNameStepVan_Mechanic",
    ["Mechanic's Franklin Valuline"] = "IGUI_VehicleNameVanMechanic",
    ["Melting Point Metal Franklin Valuline"] = "IGUI_VehicleNameVanMeltingPointMetal",
    ["Mercia Lang 4000"] = "IGUI_VehicleNameCarLuxury",
    ["Mesmer Wagon"] = "IGUI_VehicleNameVanSeats_Trippy",
    ["Metalheads Franklin Valuline"] = "IGUI_VehicleNameVanMetalheads",
    ["Metalworker's Dash Bulldriver"] = "IGUI_VehicleNamePickUpVanMetalworker",
    ["Metalworker's Franklin Valuline"] = "IGUI_VehicleNameVanMetalworker",
    ["Michele's Woodshop Franklin Valuline"] = "IGUI_VehicleNameVanMicheles",
    ["Mobile Mechanics Franklin Valuline"] = "IGUI_VehicleNameVanMobileMechanics",
    ["Moore Mechanics Franklin Valuline"] = "IGUI_VehicleNameVanMooreMechanics",
    ["Muldraugh Police Chevalier Nyala"] = "IGUI_VehicleNameCarLightsMuldraughPolice",
    ["Old Mill Water Company Franklin Valuline"] = "IGUI_VehicleNameVanOldMill",
    ["Penn S. Ham Construction Franklin Valuline"] = "IGUI_VehicleNameVanPennSHam",
    ["Platt Auto Repair Franklin Valuline"] = "IGUI_VehicleNameVanPlattAuto",
    ["Plonkies Chevalier Step Van"] = "IGUI_VehicleNameStepVan_Plonkies",
    ["Plugged In Electrics Franklin Valuline"] = "IGUI_VehicleNameVanPluggedInElectrics",
    ["Police"] = "IGUI_VehicleNamePolice",
    ["Police Chevalier Nyala"] = "IGUI_VehicleNameCarLightsPolice",
    ["Police Dash Bulldriver"] = "IGUI_VehicleNamePickUpVanLightsPolice",
    ["Postal"] = "IGUI_VehicleNamePostal",
    ["Prisoner Transport Franklin Valuline"] = "IGUI_VehicleNameVanSeats_Prison",
    ["Quantum Vessel"] = "IGUI_VehicleNameVanSeats_Space",
    ["Race Car"] = "IGUI_VehicleNameRaceCar",
    ["Randi's Plants Chevalier Step Van"] = "IGUI_VehicleNameStepVan_RandisPlants",
    ["Ranger Chevalier D6"] = "IGUI_VehicleNamePickUpTruckLightsRanger",
    ["Ranger Chevalier Nyala"] = "IGUI_VehicleNameCarLightsRanger",
    ["Ranger Dash Bulldriver"] = "IGUI_VehicleNamePickUpVanLightsRanger",
    ["Riverside Fabrication Franklin Valuline"] = "IGUI_VehicleNameVanRiversideFabrication",
    ["Rosewoodworking Franklin Valuline"] = "IGUI_VehicleNameVanRosewoodworking",
    ["Scarlet Oak Chevalier Step Van"] = "IGUI_VehicleNameStepVan_Scarlet",
    ["Schwab Sheet Metal Franklin Valuline"] = "IGUI_VehicleNameVanSchwabSheetMetal",
    ["South Eastern Hospitality Chevalier Step Van"] = "IGUI_VehicleNameStepVan_SouthEasternHosp",
    ["South Eastern Paint Chevalier Step Van"] = "IGUI_VehicleNameStepVan_SouthEasternPaint",
    ["Spiffo Van"] = "IGUI_VehicleNameVanSpiffo",
    ["State Trooper Chevalier Nyala"] = "IGUI_VehicleNameCarLightsKST",
    ["State Trooper Dash Bulldriver"] = "IGUI_VehicleNamePickUpVanLightsStatePolice",
    ["Taxi"] = "IGUI_VehicleNameCarTaxi",
    ["The Lady Delighter"] = "IGUI_VehicleNameVanSeats_LadyDelighter",
    ["Trailer"] = "IGUI_VehicleNameTrailer",
    ["Transit Franklin Valuline"] = "IGUI_VehicleNameVan_Transit",
    ["Trey Baines Franklin Valuline"] = "IGUI_VehicleNameVanTreyBaines",
    ["Triple-N Van"] = "IGUI_VehicleNameVanRadio_3N",
    ["USL Chevalier Step Van"] = "IGUI_VehicleNameStepVan_USL",
    ["Uncloggers Franklin Valuline"] = "IGUI_VehicleNameVanUncloggers",
    ["Utility Franklin Valuline"] = "IGUI_VehicleNameVanUtility",
    ["Valkyrie's Spear"] = "IGUI_VehicleNameVanSeats_Valkyrie",
    ["Van Yings Wood Dash Bulldriver"] = "IGUI_VehicleNamePickUpVanYingsWood",
    ["Volt Mojo Franklin Valuline"] = "IGUI_VehicleNameVan_VoltMojo",
    ["WP Carpentry Franklin Valuline"] = "IGUI_VehicleNameVanWPCarpentry",
    ["Welding by Camille Dash Bulldriver"] = "IGUI_VehicleNamePickUpVanWeldingbyCamille",
    ["West Point Police Dash Elite"] = "IGUI_VehicleNameModernCarLightsWestPoint",
    ["Wrecked Chevalier Cerise Wagon"] = "IGUI_VehicleNameCarStationWagonSmashedFront",
    ["Wrecked Chevalier D6"] = "IGUI_VehicleNamePickUpTruckLightsSmashedFront",
    ["Wrecked Chevalier Dart"] = "IGUI_VehicleNameCarSmallSmashedFront",
    ["Wrecked Chevalier Nyala"] = "IGUI_VehicleNameCarLightsSmashedFront",
    ["Wrecked Chevalier Step Van"] = "IGUI_VehicleNameStepVanMailSmashedFront",
    ["Wrecked Dash Bulldriver"] = "IGUI_VehicleNamePickUpVanLightsSmashedFront",
    ["Wrecked Dash Rancher"] = "IGUI_VehicleNameOffRoadSmashedFront",
    ["Wrecked Franklin All-Terrain"] = "IGUI_VehicleNameSUVSmashedFront",
    ["Wrecked Masterson Horizon"] = "IGUI_VehicleNameCarSmall02SmashedFront",
    ["Wrecked Mercia Lang 4000"] = "IGUI_VehicleNameCarLuxurySmashedFront",
    ["Zippee Chevalier Step Van"] = "IGUI_VehicleNameStepVan_Zippee",
}
-- <AUTO-GEN:VEHICLE_NAME_MAP END>

-- ============================================
-- 核心修復邏輯
-- ============================================

--- 將 "Vehicle Key - {英文車名}" 翻譯為當前語言版本
--- @param item InventoryItem 車鑰匙物品
local function fixVehicleKeyName(item)
    if not item then return end
    if item:getFullType() ~= "Base.CarKey" then return end

    local currentName = item:getName()
    if not currentName then return end

    -- 偵測 "Vehicle Key - XXX" 格式（Java 硬編碼分隔符為 " - "）
    local dashPos = string.find(currentName, " - ", 1, true)
    if not dashPos then return end

    local prefix = string.sub(currentName, 1, dashPos - 1)
    local enVehicleName = string.sub(currentName, dashPos + 3)

    -- 只處理確定是英文原始前綴的情況，避免重複處理或誤改
    if prefix ~= "Vehicle Key" then return end

    -- 反查英文車名 → IGUI key
    local iguiKey = VehicleKeyFlx.EN_TO_KEY[enVehicleName]
    if not iguiKey then
        -- 未知車名（可能是其他 MOD 新增的車輛或已是翻譯鍵的錯誤值），跳過
        return
    end

    -- 用當前語言取翻譯
    local translatedVehicleName = getTextOrNull(iguiKey)
    if not translatedVehicleName or translatedVehicleName == "" then return end

    -- 前綴用 Base.CarKey 的 scriptItem DisplayName（= 當前語言的「汽車鑰匙」）
    local scriptItem = item:getScriptItem()
    local translatedPrefix = scriptItem and scriptItem:getDisplayName() or getText("IGUI_CarKeyNew")
    if not translatedPrefix or translatedPrefix == "" then return end

    local newName = translatedPrefix .. " - " .. translatedVehicleName
    if newName ~= currentName then
        item:setName(newName)
    end
end

--- 掃描容器內所有 Base.CarKey（含子容器）並修復
--- @param container ItemContainer
local function fixContainer(container)
    if not container then return end
    -- getAllTypeRecurse 會遞迴掃描所有子容器，避免手動處理背包巢狀
    local keys = container:getAllTypeRecurse("Base.CarKey")
    if not keys then return end
    for i = 0, keys:size() - 1 do
        fixVehicleKeyName(keys:get(i))
    end
end

--- 掃描玩家身上所有容器（主物品欄 + 所有子容器）
--- @param playerObj IsoPlayer
local function fixAllPlayerKeys(playerObj)
    if not playerObj then return end
    fixContainer(playerObj:getInventory())
end

-- ============================================
-- 事件掛鉤
-- ============================================

-- 開局：角色建立後立刻修復（新角色身上可能帶鑰匙）
local function onCreatePlayer(playerIndex, playerObj)
    fixAllPlayerKeys(playerObj)
end
Events.OnCreatePlayer.Add(onCreatePlayer)

-- 載入存檔：修復存檔中既有的車鑰匙
local function onGameStart()
    if isServer() and not isClient() then return end
    local player = getSpecificPlayer(0)
    if player then
        fixAllPlayerKeys(player)
        print(TAG .. " [VehicleKey] 已修復玩家物品欄內車鑰匙名稱")
    end
end
Events.OnGameStart.Add(onGameStart)

-- 容器初次填充（撿屍、搜索櫃子、開手套箱等）：修復該容器內新生成的鑰匙
local function onFillContainer(roomName, containerType, container)
    fixContainer(container)
end
Events.OnFillContainer.Add(onFillContainer)

-- 每分鐘掃描一次玩家物品欄，捕捉即時撿取或從其他來源取得的鑰匙
local function onEveryOneMinute()
    local player = getSpecificPlayer(0)
    if player then
        fixAllPlayerKeys(player)
    end
end
Events.EveryOneMinute.Add(onEveryOneMinute)
