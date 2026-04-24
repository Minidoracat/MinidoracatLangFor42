-- VehicleKey_Flx.lua
-- 修復車鑰匙名稱在多人 / 舊存檔中持久化為英文或 raw IGUI key 的問題。
--
-- PZ 42.17 已將 BaseVehicle.keyNamerVehicle 改為 Translator.getText(...),
-- 但 Java 仍會在生成時呼叫 item:setName(...)，把「當時語言」的結果寫進
-- InventoryItem.name。Dedicated server 常以英文環境生成物品，因此 MP client
-- 可能收到已固化的 `Vehicle Key - Chevalier Dart`；舊存檔也會保留舊名稱。
--
-- 本檔只在 client / single player 端作為顯示名稱遷移層：
--   1. 掃描 Base.CarKey
--   2. 將英文車名反查回 IGUI_VehicleName* key
--   3. 用玩家端當前語言重新組合名稱並 setName()
--
-- 反查表由 scripts/sync_translations.py gen-vehicle-map 從 vanilla EN/IG_UI.json 產生。

local TAG = "[CatLangFor42]"
local VEHICLE_NAME_PREFIX = "IGUI_VehicleName"
local ENGLISH_KEY_PREFIX = "Vehicle Key"

VehicleKeyFlx = VehicleKeyFlx or {}
VehicleKeyFlx._unknownLogged = VehicleKeyFlx._unknownLogged or {}

-- ============================================
-- 自動產生區塊：英文車名 → IGUI key 反查表
-- ============================================
-- <AUTO-GEN:VEHICLE_NAME_MAP START>
-- 由 scripts/sync_translations.py gen-vehicle-map 自動產生，請勿手動編輯
-- 來源：vanilla EN/IG_UI.json（共 144 條）
-- 注意：重複英文車名已保留第一個 vanilla key；詳見 generator 執行輸出
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

local function startsWith(value, prefix)
    return value and prefix and string.sub(value, 1, #prefix) == prefix
end

local function normalizeVehicleNameKey(value)
    if not startsWith(value, VEHICLE_NAME_PREFIX) then return nil end

    -- 防禦性處理：若車輛 script 已錯放 IGUI prefix，Java 又補一次，可能變成
    -- IGUI_VehicleNameIGUI_VehicleNameSmallCar。
    local doubledPrefix = VEHICLE_NAME_PREFIX .. VEHICLE_NAME_PREFIX
    while startsWith(value, doubledPrefix) do
        value = VEHICLE_NAME_PREFIX .. string.sub(value, #doubledPrefix + 1)
    end

    if getTextOrNull(value) then
        return value
    end
    return nil
end

local function resolveVehicleNameKey(vehicleNamePart)
    if not vehicleNamePart or vehicleNamePart == "" then return nil end

    local rawKey = normalizeVehicleNameKey(vehicleNamePart)
    if rawKey then
        return rawKey
    end

    return VehicleKeyFlx.EN_TO_KEY[vehicleNamePart]
end

local function getTranslatedCarKeyPrefix(item)
    local scriptItem = item and item:getScriptItem()
    local displayName = scriptItem and scriptItem:getDisplayName()
    if displayName and displayName ~= "" and displayName ~= ENGLISH_KEY_PREFIX and displayName ~= "Base.CarKey" then
        return displayName
    end

    return getTextOrNull("IGUI_CarKeyNew") or displayName or ENGLISH_KEY_PREFIX
end

local function isRepairablePrefix(prefix, translatedPrefix)
    if prefix == ENGLISH_KEY_PREFIX then return true end
    if translatedPrefix and prefix == translatedPrefix then return true end

    local shortPrefix = getTextOrNull("IGUI_CarKeyNew")
    if shortPrefix and prefix == shortPrefix then return true end

    return false
end

local function logUnknownOnce(vehicleNamePart)
    if not vehicleNamePart or vehicleNamePart == "" then return end
    if VehicleKeyFlx._unknownLogged[vehicleNamePart] then return end
    VehicleKeyFlx._unknownLogged[vehicleNamePart] = true
    print(TAG .. " [VehicleKey] Unknown vehicle key name, skipped: " .. tostring(vehicleNamePart))
end

--- 修復單一 Base.CarKey 的顯示名稱。
--- @param item InventoryItem
local function fixVehicleKeyName(item)
    if not item then return end
    if item:getFullType() ~= "Base.CarKey" then return end

    local currentName = item:getName()
    if not currentName then return end

    local dashPos = string.find(currentName, " - ", 1, true)
    if not dashPos then return end

    local prefix = string.sub(currentName, 1, dashPos - 1)
    local vehicleNamePart = string.sub(currentName, dashPos + 3)
    local vehicleNameKey = resolveVehicleNameKey(vehicleNamePart)

    if not vehicleNameKey then
        if prefix == ENGLISH_KEY_PREFIX or startsWith(vehicleNamePart, VEHICLE_NAME_PREFIX) then
            logUnknownOnce(vehicleNamePart)
        end
        return
    end

    local translatedVehicleName = getTextOrNull(vehicleNameKey)
    if not translatedVehicleName or translatedVehicleName == "" then return end

    local translatedPrefix = getTranslatedCarKeyPrefix(item)
    if not isRepairablePrefix(prefix, translatedPrefix) and not startsWith(vehicleNamePart, VEHICLE_NAME_PREFIX) then
        return
    end

    local newName = translatedPrefix .. " - " .. translatedVehicleName
    if newName ~= currentName then
        item:setName(newName)
    end
end

--- 掃描容器內所有 Base.CarKey（含子容器）並修復。
--- @param container ItemContainer
local function fixContainer(container)
    if not container then return end

    local keys = container:getAllTypeRecurse("Base.CarKey")
    if not keys then return end

    for i = 0, keys:size() - 1 do
        fixVehicleKeyName(keys:get(i))
    end
end

--- 掃描單一玩家的物品欄。
--- @param playerObj IsoPlayer
local function fixPlayerKeys(playerObj)
    if not playerObj then return end
    fixContainer(playerObj:getInventory())
end

local function getPrimaryPlayer()
    return getSpecificPlayer(0) or getPlayer()
end

-- Dedicated server 不做語言遷移，避免用 server 語言覆寫名稱；
-- MP client / listen host / SP 才執行本地修復。
local function shouldRunClientRepair()
    return not (isServer() and not isClient())
end

local function onCreatePlayer(_playerIndex, playerObj)
    if not shouldRunClientRepair() then return end
    fixPlayerKeys(playerObj)
end
Events.OnCreatePlayer.Add(onCreatePlayer)

local function onGameStart()
    if not shouldRunClientRepair() then return end
    local player = getPrimaryPlayer()
    if player then
        fixPlayerKeys(player)
        print(TAG .. " [VehicleKey] Fixed persisted vehicle key names")
    end
end
Events.OnGameStart.Add(onGameStart)

local function onFillContainer(_roomName, _containerType, container)
    if not shouldRunClientRepair() then return end
    fixContainer(container)
end
Events.OnFillContainer.Add(onFillContainer)

local function onEveryOneMinute()
    if not shouldRunClientRepair() then return end
    fixPlayerKeys(getPrimaryPlayer())
end
Events.EveryOneMinute.Add(onEveryOneMinute)
