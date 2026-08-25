-- DynamicItemName_Flx.lua
-- 修復 PZ 官方在物品「生成當下」把翻譯結果寫死進 InventoryItem.name 的動態命名殘留。
--
-- PZ 42.19 的 ItemCodeOnCreate / RecipeCodeHelper / Fishing Lua 會在物品生成時
-- 以生成端語言烘焙名稱（雪花玻璃球、照片、明信片、塗鴉、墜飾、書籍、雜誌、漫畫、
-- 報紙、傳單、型錄、股票、寵物牌、信件、名片、印章戒指、證件、刮刮樂、魚等），
-- 名稱會原樣存檔且載入時不重新翻譯（InventoryItem.save/load 原樣讀寫）。
-- Dedicated server 以英文環境生成、或舊存檔在裝模組前生成的物品，
-- client 端即使翻譯齊全仍顯示英文。
--
-- 修復策略（依 Java 端 modData 寫入內容分二類）：
--   1. modData 存翻譯 key（photo 系 collectibleKey、文獻系 literatureTitle）
--      → 直接用 key 以當前語言重建名稱。
--   2. modData 只存烘焙文字或不存（雪花玻璃球、舊報紙、股票、寵物牌、信件、
--      名片、證件、刮刮樂、魚）→ 以已知格式解析名稱，動態部分經
--      「英文原文 → IGUI key」反查表（AUTO-GEN 區塊，由
--      scripts/sync_translations.py gen-dynamic-name-map 產生）反查後重建。
--      解析不到（例如玩家自訂名）一律不動。
--
-- 不觸碰任何 modData：collectibleKey / literatureTitle 是已讀、收藏追蹤的比對值。
-- 配方剪報與圖紙由 RecipeLiterature_Flx.lua 處理；車鑰匙由 VehicleKey_Flx.lua、
-- 證件人名前綴另有 SpawnItems_Flx.lua（兩者結果一致、可安全共存）。

local TAG = "[CatLangFor42]"

DynamicItemNameFlx = DynamicItemNameFlx or {}

-- <AUTO-GEN:DYNAMIC_NAME_MAP START>
-- 由 scripts/sync_translations.py gen-dynamic-name-map 自動產生，請勿手動編輯
-- 來源：vanilla EN/IG_UI.json、ItemName.json、Print_Media.json（EN_ITEM_NAMES 46、PLACE 900、NEWSPAPER_TITLE 25、PETNAME 229、LETTER 24、BUSINESS 63、JOB 116）
DynamicItemNameFlx = DynamicItemNameFlx or {}
DynamicItemNameFlx.MAPS = {
    EN_ITEM_NAMES = {
        ["Base.AligatorGar"] = "Alligator Gar",
        ["Base.Badge"] = "Badge",
        ["Base.BlackCrappie"] = "Black Crappie",
        ["Base.BlueCatfish"] = "Blue Catfish",
        ["Base.Bluegill"] = "Bluegill",
        ["Base.BrassNameplate"] = "Brass Nameplate",
        ["Base.BusinessCard"] = "Business Card",
        ["Base.BusinessCard_Nolans"] = "Business Card",
        ["Base.BusinessCard_Personal"] = "Business Card",
        ["Base.ChannelCatfish"] = "Channel Catfish",
        ["Base.CreditCard"] = "Credit Card",
        ["Base.CreditCard_Stolen"] = "Credit Card",
        ["Base.DogTag_Pet"] = "Dog Tag",
        ["Base.FlatheadCatfish"] = "Flathead Catfish",
        ["Base.FreshwaterDrum"] = "Freshwater Drum",
        ["Base.GreenSunfish"] = "Green Sunfish",
        ["Base.IDcard"] = "ID Card",
        ["Base.IDcard_Female"] = "ID Card",
        ["Base.IDcard_Male"] = "ID Card",
        ["Base.IDcard_Stolen"] = "ID Card",
        ["Base.LargemouthBass"] = "Largemouth Bass",
        ["Base.Muskellunge"] = "Muskellunge",
        ["Base.Necklace_DogTag"] = "Dog Tags",
        ["Base.Necklace_DogTag_Female"] = "Dog Tags",
        ["Base.Necklace_DogTag_Male"] = "Dog Tags",
        ["Base.Newspaper"] = "Old Newspaper",
        ["Base.Paddlefish"] = "Paddlefish",
        ["Base.Passport"] = "Passport",
        ["Base.PressID"] = "Press Badge",
        ["Base.RedearSunfish"] = "Redear Sunfish",
        ["Base.Ring_Left_MiddleFinger_Signet"] = "Signet Ring",
        ["Base.Ring_Left_RingFinger_Signet"] = "Signet Ring",
        ["Base.Ring_Right_MiddleFinger_Signet"] = "Signet Ring",
        ["Base.Ring_Right_RingFinger_Signet"] = "Signet Ring",
        ["Base.Sauger"] = "Sauger",
        ["Base.ScratchTicket_Winner"] = "Scratch Ticket",
        ["Base.SmallmouthBass"] = "Smallmouth Bass",
        ["Base.SnowGlobe"] = "Snow Globe",
        ["Base.SpeedingTicket"] = "Speeding Ticket",
        ["Base.SpottedBass"] = "Spotted Bass",
        ["Base.StockCertificate"] = "Stock Certificate",
        ["Base.StripedBass"] = "Striped Bass",
        ["Base.Walleye"] = "Walleye",
        ["Base.WhiteBass"] = "White Bass",
        ["Base.WhiteCrappie"] = "White Crappie",
        ["Base.YellowPerch"] = "Yellow Perch",
    },
    PLACE = {
        ["Alaska"] = "IGUI_Photo_Alaska",
        ["Alcatraz"] = "IGUI_Photo_Alcatraz",
        ["Amsterdam"] = "IGUI_Photo_Amsterdam",
        ["Animals"] = "IGUI_Photo_Animals",
        ["Antarctica"] = "IGUI_Photo_Antarctica",
        ["Argentina"] = "IGUI_Photo_Argentina",
        ["Asia"] = "IGUI_Photo_Asia",
        ["Aspen"] = "IGUI_Photo_Aspen",
        ["Athens"] = "IGUI_Photo_Athens",
        ["Atlanta"] = "IGUI_Photo_Atlanta",
        ["Australia"] = "IGUI_Photo_Australia",
        ["Austria"] = "IGUI_Photo_Austria",
        ["Ayers Rock"] = "IGUI_Photo_AyersRock",
        ["Bali"] = "IGUI_Photo_Bali",
        ["Barcelona"] = "IGUI_Photo_Barcelona",
        ["Baton Rouge"] = "IGUI_Photo_BatonRouge",
        ["Beacon Hill"] = "IGUI_Photo_BeaconHill",
        ["Beijing"] = "IGUI_Photo_Beijing",
        ["Berlin"] = "IGUI_Photo_Berlin",
        ["Bermuda"] = "IGUI_Photo_Bermuda",
        ["Big Sur"] = "IGUI_Photo_BigSur",
        ["Boston"] = "IGUI_Photo_Boston",
        ["Brazil"] = "IGUI_Photo_Brazil",
        ["Bridesmaids"] = "IGUI_Photo_Bridesmaids",
        ["Brooklyn"] = "IGUI_Photo_Brooklyn",
        ["Buckingham Palace"] = "IGUI_Photo_BuckinghamPalace",
        ["Buenos Aires"] = "IGUI_Photo_BuenosAires",
        ["Buildings"] = "IGUI_Photo_Buildings",
        ["Butterflies"] = "IGUI_Photo_Butterflies",
        ["Cairo"] = "IGUI_Photo_Cairo",
        ["Calcutta"] = "IGUI_Photo_Calcutta",
        ["California"] = "IGUI_Photo_California",
        ["Cambodia"] = "IGUI_Photo_Cambodia",
        ["Campers"] = "IGUI_Photo_Campers",
        ["Canada"] = "IGUI_Photo_Canada",
        ["Cape Canaveral"] = "IGUI_Photo_CapeCanaveral",
        ["Cape Cod"] = "IGUI_Photo_CapeCod",
        ["Carnegie Hall"] = "IGUI_Photo_CarnegieHall",
        ["Cash"] = "IGUI_Photo_Cash",
        ["Chicago"] = "IGUI_Photo_Chicago",
        ["Children"] = "IGUI_Photo_Children",
        ["Children Playing"] = "IGUI_Photo_ChildrenPlaying",
        ["Children Playing Baseball"] = "IGUI_Photo_ChildrenPlayingBaseball",
        ["Children Playing Basketball"] = "IGUI_Photo_ChildrenPlayingBasketball",
        ["Children Playing Football"] = "IGUI_Photo_ChildrenPlayingFootball",
        ["Children Playing Soccer"] = "IGUI_Photo_ChildrenPlayingSoccer",
        ["Children Playing on a Slide"] = "IGUI_Photo_ChildrenPlayingonaSlide",
        ["Children Playing on a Swing"] = "IGUI_Photo_ChildrenPlayingonaSwing",
        ["Children and Babies"] = "IGUI_Photo_ChildrenandBabies",
        ["Children and a Baby"] = "IGUI_Photo_ChildrenandaBaby",
        ["Children in a Playground"] = "IGUI_Photo_ChildreninaPlayground",
        ["China"] = "IGUI_Photo_China",
        ["Christmas"] = "IGUI_Photo_Christmas",
        ["Cleveland"] = "IGUI_Photo_Cleveland",
        ["Clouds"] = "IGUI_Photo_Clouds",
        ["Co-workers"] = "IGUI_Photo_Co-workers",
        ["Colonial Williamsburg"] = "IGUI_Photo_ColonialWilliamsburg",
        ["Colorado"] = "IGUI_Photo_Colorado",
        ["Coney Island"] = "IGUI_Photo_ConeyIsland",
        ["Copenhagen"] = "IGUI_Photo_Copenhagen",
        ["Cops"] = "IGUI_Photo_Cops",
        ["Costa Rica"] = "IGUI_Photo_CostaRica",
        ["Cumberland Falls"] = "IGUI_Photo_CumberlandFalls",
        ["Cyprus"] = "IGUI_Photo_Cyprus",
        ["Czech Republic"] = "IGUI_Photo_CzechRepublic",
        ["Czechoslovakia"] = "IGUI_Photo_Czechoslovakia",
        ["Dallas"] = "IGUI_Photo_Dallas",
        ["Dead Stick Figures"] = "IGUI_Photo_DeadStickFigures",
        ["Death Valley"] = "IGUI_Photo_DeathValley",
        ["Dogs Playing"] = "IGUI_Photo_DogsPlaying",
        ["Dublin"] = "IGUI_Photo_Dublin",
        ["Easter Island"] = "IGUI_Photo_EasterIsland",
        ["Edinburgh"] = "IGUI_Photo_Edinburgh",
        ["Egypt"] = "IGUI_Photo_Egypt",
        ["El Capitan"] = "IGUI_Photo_ElCapitan",
        ["Ellis Island"] = "IGUI_Photo_EllisIsland",
        ["England"] = "IGUI_Photo_England",
        ["Europe"] = "IGUI_Photo_Europe",
        ["Faneuil Hall"] = "IGUI_Photo_FaneuilHall",
        ["Farm Animals"] = "IGUI_Photo_FarmAnimals",
        ["Finland"] = "IGUI_Photo_Finland",
        ["Fireworks"] = "IGUI_Photo_Fireworks",
        ["Florence"] = "IGUI_Photo_Florence",
        ["Florida"] = "IGUI_Photo_Florida",
        ["Flowers"] = "IGUI_Photo_Flowers",
        ["Food"] = "IGUI_Photo_Food",
        ["Fort Independence"] = "IGUI_Photo_FortIndependence",
        ["Fort Sumter"] = "IGUI_Photo_FortSumter",
        ["Four People"] = "IGUI_Photo_FourPeople",
        ["France"] = "IGUI_Photo_France",
        ["Funny Characters"] = "IGUI_Photo_FunnyCharacters",
        ["Galleria dell'Accademia"] = "IGUI_Photo_GalleriadellAccademia",
        ["Garbage"] = "IGUI_Photo_Garbage",
        ["Germany"] = "IGUI_Photo_Germany",
        ["Gettysburg"] = "IGUI_Photo_Gettysburg",
        ["Gibraltar"] = "IGUI_Photo_Gibraltar",
        ["Gifts"] = "IGUI_Photo_Gifts",
        ["Glen Canyon"] = "IGUI_Photo_GlenCanyon",
        ["Golden Gate Park"] = "IGUI_Photo_GoldenGatePark",
        ["Grandparents"] = "IGUI_Photo_Grandparents",
        ["Grandparents With a Grandchild"] = "IGUI_Photo_GrandparentsWithaGrandchild",
        ["Grandparents and Grandchildren"] = "IGUI_Photo_GrandparentsandGrandchildren",
        ["Great Barrier Reef"] = "IGUI_Photo_GreatBarrierReef",
        ["Greece"] = "IGUI_Photo_Greece",
        ["Griffith Observatory"] = "IGUI_Photo_GriffithObservatory",
        ["Groomsmen"] = "IGUI_Photo_Groomsmen",
        ["Ha Long Bay"] = "IGUI_Photo_HaLongBay",
        ["Haiti"] = "IGUI_Photo_Haiti",
        ["Hanoi"] = "IGUI_Photo_Hanoi",
        ["Hawaii"] = "IGUI_Photo_Hawaii",
        ["Hearts"] = "IGUI_Photo_Hearts",
        ["Hikers"] = "IGUI_Photo_Hikers",
        ["Ho Chi Minh City"] = "IGUI_Photo_HoChiMinhCity",
        ["Hollywood"] = "IGUI_Photo_Hollywood",
        ["Hong Kong"] = "IGUI_Photo_HongKong",
        ["Honolulu"] = "IGUI_Photo_Honolulu",
        ["Hunters"] = "IGUI_Photo_Hunters",
        ["Iceland"] = "IGUI_Photo_Iceland",
        ["Illinois"] = "IGUI_Photo_Illinois",
        ["Immigrants"] = "IGUI_Photo_Immigrants",
        ["Immigrants in their Native Dress"] = "IGUI_Photo_ImmigrantsintheirNativeDress",
        ["India"] = "IGUI_Photo_India",
        ["Indiana"] = "IGUI_Photo_Indiana",
        ["Indonesia"] = "IGUI_Photo_Indonesia",
        ["Insects"] = "IGUI_Photo_Insects",
        ["Ireland"] = "IGUI_Photo_Ireland",
        ["Istanbul"] = "IGUI_Photo_Istanbul",
        ["Italy"] = "IGUI_Photo_Italy",
        ["Jamaica"] = "IGUI_Photo_Jamaica",
        ["Jamestown"] = "IGUI_Photo_Jamestown",
        ["Japan"] = "IGUI_Photo_Japan",
        ["Jerusalem"] = "IGUI_Photo_Jerusalem",
        ["Joshua Tree National Park"] = "IGUI_Photo_JoshuaTreeNationalPark",
        ["Kenya"] = "IGUI_Photo_Kenya",
        ["Key West"] = "IGUI_Photo_KeyWest",
        ["Killarney"] = "IGUI_Photo_Killarney",
        ["Kingsmouth Island"] = "IGUI_Photo_KingsmouthIsland",
        ["Kittens"] = "IGUI_Photo_Kittens",
        ["Lake Baikal"] = "IGUI_Photo_LakeBaikal",
        ["Lake Como"] = "IGUI_Photo_LakeComo",
        ["Lake Garda"] = "IGUI_Photo_LakeGarda",
        ["Lake Lucerne"] = "IGUI_Photo_LakeLucerne",
        ["Lake Mead"] = "IGUI_Photo_LakeMead",
        ["Lake Placid"] = "IGUI_Photo_LakePlacid",
        ["Lake Superior"] = "IGUI_Photo_LakeSuperior",
        ["Lake Tahoe"] = "IGUI_Photo_LakeTahoe",
        ["Lake Titicaca"] = "IGUI_Photo_LakeTiticaca",
        ["Lambs"] = "IGUI_Photo_Lambs",
        ["Land Between the Lakes"] = "IGUI_Photo_LandBetweentheLakes",
        ["Lapland"] = "IGUI_Photo_Lapland",
        ["Las Vegas"] = "IGUI_Photo_LasVegas",
        ["Lisbon"] = "IGUI_Photo_Lisbon",
        ["Loch Ness"] = "IGUI_Photo_LochNess",
        ["London"] = "IGUI_Photo_London",
        ["Los Angeles"] = "IGUI_Photo_LosAngeles",
        ["Louisiana"] = "IGUI_Photo_Louisiana",
        ["Louisville"] = "IGUI_Photo_Louisville",
        ["Machu Picchu"] = "IGUI_Photo_MachuPicchu",
        ["Madrid"] = "IGUI_Photo_Madrid",
        ["Malaysia"] = "IGUI_Photo_Malaysia",
        ["Maldives"] = "IGUI_Photo_Maldives",
        ["Malibu"] = "IGUI_Photo_Malibu",
        ["Malta"] = "IGUI_Photo_Malta",
        ["Manhattan"] = "IGUI_Photo_Manhattan",
        ["Marengo Cave"] = "IGUI_Photo_MarengoCave",
        ["Martha's Vineyard"] = "IGUI_Photo_MarthasVineyard",
        ["Massachusetts"] = "IGUI_Photo_Massachusetts",
        ["Maui"] = "IGUI_Photo_Maui",
        ["Memphis"] = "IGUI_Photo_Memphis",
        ["Mesa Verde"] = "IGUI_Photo_MesaVerde",
        ["Mexico"] = "IGUI_Photo_Mexico",
        ["Miami"] = "IGUI_Photo_Miami",
        ["Miami Beach"] = "IGUI_Photo_MiamiBeach",
        ["Milwaukee"] = "IGUI_Photo_Milwaukee",
        ["Miners"] = "IGUI_Photo_Miners",
        ["Minnesota"] = "IGUI_Photo_Minnesota",
        ["Missouri"] = "IGUI_Photo_Missouri",
        ["Monaco"] = "IGUI_Photo_Monaco",
        ["Mongolia"] = "IGUI_Photo_Mongolia",
        ["Monroe Lake"] = "IGUI_Photo_MonroeLake",
        ["Monroeville"] = "IGUI_Photo_Monroeville",
        ["Mont Blanc"] = "IGUI_Photo_MontBlanc",
        ["Mont-Saint-Michel"] = "IGUI_Photo_MontSaintMichel",
        ["Montana"] = "IGUI_Photo_Montana",
        ["Monticello"] = "IGUI_Photo_Monticello",
        ["Montreal"] = "IGUI_Photo_Montreal",
        ["Montserrat"] = "IGUI_Photo_Montserrat",
        ["Monument Valley"] = "IGUI_Photo_MonumentValley",
        ["Morocco"] = "IGUI_Photo_Morocco",
        ["Moscow"] = "IGUI_Photo_Moscow",
        ["Mount Everest"] = "IGUI_Photo_MountEverest",
        ["Mount Fuji"] = "IGUI_Photo_MountFuji",
        ["Mount Kilimanjaro"] = "IGUI_Photo_MountKilimanjaro",
        ["Mount McKinley"] = "IGUI_Photo_MountMcKinley",
        ["Mount Olympus"] = "IGUI_Photo_MountOlympus",
        ["Mount Rainier"] = "IGUI_Photo_MountRainier",
        ["Mount Rushmore"] = "IGUI_Photo_MountRushmore",
        ["Mount Vernon"] = "IGUI_Photo_MountVernon",
        ["Mount Williamson"] = "IGUI_Photo_MountWilliamson",
        ["Mountain Lion Pictures Studio"] = "IGUI_Photo_MountainLionPicturesStudio",
        ["Mountains"] = "IGUI_Photo_Mountains",
        ["My Old Kentucky Home Park"] = "IGUI_Photo_MyOldKentuckyHomePark",
        ["Nashville"] = "IGUI_Photo_Nashville",
        ["Nature"] = "IGUI_Photo_Nature",
        ["Neuschwanstein Castle"] = "IGUI_Photo_NeuschwansteinCastle",
        ["New Orleans"] = "IGUI_Photo_NewOrleans",
        ["New York"] = "IGUI_Photo_NewYork",
        ["New Zealand"] = "IGUI_Photo_NewZealand",
        ["Newcastle"] = "IGUI_Photo_Newcastle",
        ["Newgrange"] = "IGUI_Photo_Newgrange",
        ["Niagara Falls"] = "IGUI_Photo_NiagaraFalls",
        ["Norway"] = "IGUI_Photo_Norway",
        ["Nothing Much"] = "IGUI_Photo_NothingMuch",
        ["Nothing in Particular"] = "IGUI_Photo_NothinginParticular",
        ["Numbers"] = "IGUI_Photo_Numbers",
        ["Ohio"] = "IGUI_Photo_Ohio",
        ["Oklahoma"] = "IGUI_Photo_Oklahoma",
        ["Parents"] = "IGUI_Photo_Parents",
        ["Parents with Teenagers"] = "IGUI_Photo_ParentswithTeenagers",
        ["Parents with Young Children"] = "IGUI_Photo_ParentswithYoungChildren",
        ["Parents with a Daughter"] = "IGUI_Photo_ParentswithaDaughter",
        ["Parents with a Son"] = "IGUI_Photo_ParentswithaSon",
        ["Paris"] = "IGUI_Photo_Paris",
        ["Pearl Harbor"] = "IGUI_Photo_PearlHarbor",
        ["People"] = "IGUI_Photo_People",
        ["People Celebrating Independence Day"] = "IGUI_Photo_PeopleCelebratingIndependenceDay",
        ["People Celebrating Something"] = "IGUI_Photo_PeopleCelebratingSomething",
        ["People Crying"] = "IGUI_Photo_PeopleCrying",
        ["People Dancing"] = "IGUI_Photo_PeopleDancing",
        ["People Dancing at a Wedding"] = "IGUI_Photo_PeopleDancingataWedding",
        ["People Dressed Up"] = "IGUI_Photo_PeopleDressedUp",
        ["People Drinking Together"] = "IGUI_Photo_PeopleDrinkingTogether",
        ["People Farming"] = "IGUI_Photo_PeopleFarming",
        ["People Hanging Out"] = "IGUI_Photo_PeopleHangingOut",
        ["People Having a Good Time"] = "IGUI_Photo_PeopleHavingaGoodTime",
        ["People Hugging"] = "IGUI_Photo_PeopleHugging",
        ["People Partying"] = "IGUI_Photo_PeoplePartying",
        ["People Playing Baseball"] = "IGUI_Photo_PeoplePlayingBaseball",
        ["People Playing Football"] = "IGUI_Photo_PeoplePlayingFootball",
        ["People Playing Sports"] = "IGUI_Photo_PeoplePlayingSports",
        ["People Playing a Game"] = "IGUI_Photo_PeoplePlayingaGame",
        ["People Posing"] = "IGUI_Photo_PeoplePosing",
        ["People Relaxing on Vacation"] = "IGUI_Photo_PeopleRelaxingonVacation",
        ["People Relaxing on a Beach"] = "IGUI_Photo_PeopleRelaxingonaBeach",
        ["People Sitting Together"] = "IGUI_Photo_PeopleSittingTogether",
        ["People Smiling"] = "IGUI_Photo_PeopleSmiling",
        ["People Standing Together"] = "IGUI_Photo_PeopleStandingTogether",
        ["People Standing Together Awkwardly"] = "IGUI_Photo_PeopleStandingTogetherAwkwardly",
        ["People Swimming"] = "IGUI_Photo_PeopleSwimming",
        ["People Waiting in an Airport"] = "IGUI_Photo_PeopleWaitinginanAirport",
        ["People Walking"] = "IGUI_Photo_PeopleWalking",
        ["People With an Early Motorcar"] = "IGUI_Photo_PeopleWithanEarlyMotorcar",
        ["People Working"] = "IGUI_Photo_PeopleWorking",
        ["People Working in a Factory"] = "IGUI_Photo_PeopleWorkinginaFactory",
        ["People at a Barbecue"] = "IGUI_Photo_PeopleataBarbecue",
        ["People in Fancy Dress"] = "IGUI_Photo_PeopleinFancyDress",
        ["People on a Horse-Drawn Buggy"] = "IGUI_Photo_PeopleonaHorseDrawnBuggy",
        ["Petra"] = "IGUI_Photo_Petra",
        ["Pets"] = "IGUI_Photo_Pets",
        ["Philadelphia"] = "IGUI_Photo_Philadelphia",
        ["Pisa"] = "IGUI_Photo_Pisa",
        ["Pompeii"] = "IGUI_Photo_Pompeii",
        ["Portugal"] = "IGUI_Photo_Portugal",
        ["Prague"] = "IGUI_Photo_Prague",
        ["Prisoners"] = "IGUI_Photo_Prisoners",
        ["Puerto Rico"] = "IGUI_Photo_PuertoRico",
        ["Puppies"] = "IGUI_Photo_Puppies",
        ["Quebec"] = "IGUI_Photo_Quebec",
        ["Raleigh"] = "IGUI_Photo_Raleigh",
        ["Random Colors"] = "IGUI_Photo_RandomColors",
        ["Random Crayon Lines"] = "IGUI_Photo_RandomCrayonLines",
        ["Random Lines"] = "IGUI_Photo_RandomLines",
        ["Random Marker Lines"] = "IGUI_Photo_RandomMarkerLines",
        ["Random Shapes"] = "IGUI_Photo_RandomShapes",
        ["Red Rock Canyon"] = "IGUI_Photo_RedRockCanyon",
        ["Richmond"] = "IGUI_Photo_Richmond",
        ["Rio de Janeiro"] = "IGUI_Photo_RiodeJaneiro",
        ["Rome"] = "IGUI_Photo_Rome",
        ["Roswell"] = "IGUI_Photo_Roswell",
        ["Route 66"] = "IGUI_Photo_Route66",
        ["Russia"] = "IGUI_Photo_Russia",
        ["Saint Petersburg"] = "IGUI_Photo_SaintPetersburg",
        ["Salem"] = "IGUI_Photo_Salem",
        ["San Diego"] = "IGUI_Photo_SanDiego",
        ["San Francisco"] = "IGUI_Photo_SanFrancisco",
        ["Santa Catalina Island"] = "IGUI_Photo_SantaCatalinaIsland",
        ["Santa Claus"] = "IGUI_Photo_SantaClaus",
        ["Saudi Arabia"] = "IGUI_Photo_SaudiArabia",
        ["Scotland"] = "IGUI_Photo_Scotland",
        ["Seattle"] = "IGUI_Photo_Seattle",
        ["Security Footage"] = "IGUI_Photo_SecurityFootage",
        ["Sedona"] = "IGUI_Photo_Sedona",
        ["Seoul"] = "IGUI_Photo_Seoul",
        ["Shanghai"] = "IGUI_Photo_Shanghai",
        ["Shapes"] = "IGUI_Photo_Shapes",
        ["Sierra Nevada"] = "IGUI_Photo_SierraNevada",
        ["Singapore"] = "IGUI_Photo_Singapore",
        ["Sleeping Children"] = "IGUI_Photo_SleepingChildren",
        ["Smiling People"] = "IGUI_Photo_SmilingPeople",
        ["Soldiers"] = "IGUI_Photo_Soldiers",
        ["Some Dubious Documents"] = "IGUI_Photo_SomeDubiousDocuments",
        ["Someone Being Arrested"] = "IGUI_Photo_SomeoneBeingArrested",
        ["Someone Committing Ill Deeds"] = "IGUI_Photo_SomeoneCommittingIllDeeds",
        ["Someone Consuming a Suspicious Substance"] = "IGUI_Photo_SomeoneConsumingaSuspiciousSubstance",
        ["Someone Cooking"] = "IGUI_Photo_SomeoneCooking",
        ["Someone Crying"] = "IGUI_Photo_SomeoneCrying",
        ["Someone Doing Carpentry"] = "IGUI_Photo_SomeoneDoingCarpentry",
        ["Someone Doing DIY"] = "IGUI_Photo_SomeoneDoingDIY",
        ["Someone Dressed as a Cowboy"] = "IGUI_Photo_SomeoneDressedasaCowboy",
        ["Someone Dressed as a Cowgirl"] = "IGUI_Photo_SomeoneDressedasaCowgirl",
        ["Someone Dressed as a Ghost"] = "IGUI_Photo_SomeoneDressedasaGhost",
        ["Someone Dressed as a Monster"] = "IGUI_Photo_SomeoneDressedasaMonster",
        ["Someone Dressed as a Vampire"] = "IGUI_Photo_SomeoneDressedasaVampire",
        ["Someone Dressed as an Elf"] = "IGUI_Photo_SomeoneDressedasanElf",
        ["Someone Driving"] = "IGUI_Photo_SomeoneDriving",
        ["Someone Firing a Gun"] = "IGUI_Photo_SomeoneFiringaGun",
        ["Someone Forgotten"] = "IGUI_Photo_SomeoneForgotten",
        ["Someone Giving a Wedding Speech"] = "IGUI_Photo_SomeoneGivingaWeddingSpeech",
        ["Someone Handing Over an Envelope"] = "IGUI_Photo_SomeoneHandingOveranEnvelope",
        ["Someone Holding a Big Fish"] = "IGUI_Photo_SomeoneHoldingaBigFish",
        ["Someone Holding a Newborn Baby"] = "IGUI_Photo_SomeoneHoldingaNewbornBaby",
        ["Someone Holding a Very Large Vegetable"] = "IGUI_Photo_SomeoneHoldingaVeryLargeVegetable",
        ["Someone Making a Rude Gesture at the Camera"] = "IGUI_Photo_SomeoneMakingaRudeGestureattheCamera",
        ["Someone Meeting a Famous Person"] = "IGUI_Photo_SomeoneMeetingaFamousPerson",
        ["Someone Playing Music"] = "IGUI_Photo_SomeonePlayingMusic",
        ["Someone Playing a Game"] = "IGUI_Photo_SomeonePlayingaGame",
        ["Someone Posing with a Big Truck"] = "IGUI_Photo_SomeonePosingwithaBigTruck",
        ["Someone Posing with a Gun"] = "IGUI_Photo_SomeonePosingwithaGun",
        ["Someone Posing with a Motorcycle"] = "IGUI_Photo_SomeonePosingwithaMotorcycle",
        ["Someone Proposing"] = "IGUI_Photo_SomeoneProposing",
        ["Someone Reading"] = "IGUI_Photo_SomeoneReading",
        ["Someone Receiving a Briefcase"] = "IGUI_Photo_SomeoneReceivingaBriefcase",
        ["Someone Receiving a Large Check"] = "IGUI_Photo_SomeoneReceivingaLargeCheck",
        ["Someone Receiving a Package"] = "IGUI_Photo_SomeoneReceivingaPackage",
        ["Someone Receiving an Award"] = "IGUI_Photo_SomeoneReceivinganAward",
        ["Someone Showing Off"] = "IGUI_Photo_SomeoneShowingOff",
        ["Someone Sitting"] = "IGUI_Photo_SomeoneSitting",
        ["Someone Sleeping"] = "IGUI_Photo_SomeoneSleeping",
        ["Someone Smiling"] = "IGUI_Photo_SomeoneSmiling",
        ["Someone Speaking on a Stage"] = "IGUI_Photo_SomeoneSpeakingonaStage",
        ["Someone Standing"] = "IGUI_Photo_SomeoneStanding",
        ["Someone Trying to Hide"] = "IGUI_Photo_SomeoneTryingtoHide",
        ["Someone Unclothed"] = "IGUI_Photo_SomeoneUnclothed",
        ["Someone Using a Computer"] = "IGUI_Photo_SomeoneUsingaComputer",
        ["Someone Watching TV"] = "IGUI_Photo_SomeoneWatchingTV",
        ["Someone Who Clearly Hates Photos"] = "IGUI_Photo_SomeoneWhoClearlyHatesPhotos",
        ["Someone With Their Eyes Shut"] = "IGUI_Photo_SomeoneWithTheirEyesShut",
        ["Someone Working"] = "IGUI_Photo_SomeoneWorking",
        ["Someone Working on a Car"] = "IGUI_Photo_SomeoneWorkingonaCar",
        ["Someone in Hospital"] = "IGUI_Photo_SomeoneinHospital",
        ["Someone in a Strange Outfit"] = "IGUI_Photo_SomeoneinaStrangeOutfit",
        ["Someone's Ancestors"] = "IGUI_Photo_SomeonesAncestors",
        ["Something Blurry"] = "IGUI_Photo_SomethingBlurry",
        ["Something Boring"] = "IGUI_Photo_SomethingBoring",
        ["Something Crude"] = "IGUI_Photo_SomethingCrude",
        ["Something Horrible"] = "IGUI_Photo_SomethingHorrible",
        ["Something Indiscernible"] = "IGUI_Photo_SomethingIndiscernible",
        ["Something Nice"] = "IGUI_Photo_SomethingNice",
        ["Something Overexposed"] = "IGUI_Photo_SomethingOverexposed",
        ["Something Rude"] = "IGUI_Photo_SomethingRude",
        ["Something Saucy"] = "IGUI_Photo_SomethingSaucy",
        ["Something Spooky"] = "IGUI_Photo_SomethingSpooky",
        ["Something Strange"] = "IGUI_Photo_SomethingStrange",
        ["Something Too Faded to Make Out"] = "IGUI_Photo_SomethingTooFadedtoMakeOut",
        ["Something Too Stained to Make Out"] = "IGUI_Photo_SomethingTooStainedtoMakeOut",
        ["South Africa"] = "IGUI_Photo_SouthAfrica",
        ["South America"] = "IGUI_Photo_SouthAmerica",
        ["South Korea"] = "IGUI_Photo_SouthKorea",
        ["Spain"] = "IGUI_Photo_Spain",
        ["Spiffo"] = "IGUI_Photo_DoodleofSpiffo",
        ["Spiffo World"] = "IGUI_Photo_SpiffoWorld",
        ["Squiggly Lines"] = "IGUI_Photo_SquigglyLines",
        ["Stick Figures"] = "IGUI_Photo_StickFigures",
        ["Stick Figures Fighting"] = "IGUI_Photo_StickFiguresFighting",
        ["Stonehenge"] = "IGUI_Photo_Stonehenge",
        ["Strange Blurry Shapes"] = "IGUI_Photo_StrangeBlurryShapes",
        ["Sweden"] = "IGUI_Photo_Sweden",
        ["Switzerland"] = "IGUI_Photo_Switzerland",
        ["Sydney"] = "IGUI_Photo_Sydney",
        ["Symbols"] = "IGUI_Photo_Symbols",
        ["Taiwan"] = "IGUI_Photo_Taiwan",
        ["Tanzania"] = "IGUI_Photo_Tanzania",
        ["Teenagers"] = "IGUI_Photo_Teenagers",
        ["Tennessee"] = "IGUI_Photo_Tennessee",
        ["Texas"] = "IGUI_Photo_Texas",
        ["Text"] = "IGUI_Photo_Text",
        ["Thailand"] = "IGUI_Photo_Thailand",
        ["Thanksgiving"] = "IGUI_Photo_Thanksgiving",
        ["Three People"] = "IGUI_Photo_ThreePeople",
        ["Three People in Bed"] = "IGUI_Photo_ThreePeopleinBed",
        ["Tibet"] = "IGUI_Photo_Tibet",
        ["Tijuana"] = "IGUI_Photo_Tijuana",
        ["Times Square"] = "IGUI_Photo_TimesSquare",
        ["Tokyo"] = "IGUI_Photo_Tokyo",
        ["Toronto"] = "IGUI_Photo_Toronto",
        ["Trick-or-Treaters"] = "IGUI_Photo_Trick-or-Treaters",
        ["Turkey"] = "IGUI_Photo_Turkey",
        ["Two Children Playing"] = "IGUI_Photo_TwoChildrenPlaying",
        ["Two Men Kissing"] = "IGUI_Photo_TwoMenKissing",
        ["Two People"] = "IGUI_Photo_TwoPeople",
        ["Two People Kissing"] = "IGUI_Photo_TwoPeopleKissing",
        ["Two People Shaking Hands"] = "IGUI_Photo_TwoPeopleShakingHands",
        ["Two People Wearing Matching Halloween Costumes"] = "IGUI_Photo_TwoPeopleWearingMatchingHalloweenCostumes",
        ["Two People in Bed"] = "IGUI_Photo_TwoPeopleinBed",
        ["Two Women Kissing"] = "IGUI_Photo_TwoWomenKissing",
        ["Ukraine"] = "IGUI_Photo_Ukraine",
        ["Uruguay"] = "IGUI_Photo_Uruguay",
        ["Valley Forge"] = "IGUI_Photo_ValleyForge",
        ["Vancouver"] = "IGUI_Photo_Vancouver",
        ["Vatican City"] = "IGUI_Photo_VaticanCity",
        ["Venice"] = "IGUI_Photo_Venice",
        ["Venice Beach"] = "IGUI_Photo_VeniceBeach",
        ["Victoria Falls"] = "IGUI_Photo_VictoriaFalls",
        ["Vietnam"] = "IGUI_Photo_Vietnam",
        ["Virginia"] = "IGUI_Photo_Virginia",
        ["Washington D.C."] = "IGUI_Photo_WashingtonDC",
        ["Wedding Guests"] = "IGUI_Photo_WeddingGuests",
        ["Weird Faces"] = "IGUI_Photo_WeirdFaces",
        ["Well-Dressed Old People"] = "IGUI_Photo_WellDressedOldPeople",
        ["Well-Dressed People"] = "IGUI_Photo_WellDressedPeople",
        ["West Virginia"] = "IGUI_Photo_WestVirginia",
        ["Wild Animals"] = "IGUI_Photo_WildAnimals",
        ["Wild Birds"] = "IGUI_Photo_WildBirds",
        ["Wisconsin"] = "IGUI_Photo_Wisconsin",
        ["Yellowstone"] = "IGUI_Photo_Yellowstone",
        ["Yosemite"] = "IGUI_Photo_Yosemite",
        ["Yugoslavia"] = "IGUI_Photo_Yugoslavia",
        ["Zion National Park"] = "IGUI_Photo_ZionNationalPark",
        ["a \"Ghost\""] = "IGUI_Photo_aGhost",
        ["a Baby"] = "IGUI_Photo_aBaby",
        ["a Baby Learning to Walk"] = "IGUI_Photo_aBabyLearningtoWalk",
        ["a Baby Playing With Toys"] = "IGUI_Photo_aBabyPlayingWithToys",
        ["a Baby With a Teddy Bear"] = "IGUI_Photo_aBabyWithaTeddyBear",
        ["a Baby with a Kitten"] = "IGUI_Photo_aBabywithaKitten",
        ["a Baby with a Puppy"] = "IGUI_Photo_aBabywithaPuppy",
        ["a Band"] = "IGUI_Photo_aBand",
        ["a Baseball Game"] = "IGUI_Photo_aBaseballGame",
        ["a Basketball Game"] = "IGUI_Photo_aBasketballGame",
        ["a Battle"] = "IGUI_Photo_aBattle",
        ["a Battlefield Medic"] = "IGUI_Photo_aBattlefieldMedic",
        ["a Battlefield Nurse"] = "IGUI_Photo_aBattlefieldNurse",
        ["a Beach Party"] = "IGUI_Photo_aBeachParty",
        ["a Beachside Vacation"] = "IGUI_Photo_aBeachsideVacation",
        ["a Bear"] = "IGUI_Photo_aBear",
        ["a Beautiful Vista"] = "IGUI_Photo_aBeautifulVista",
        ["a Beautiful Young Woman"] = "IGUI_Photo_aBeautifulYoungWoman",
        ["a Big House"] = "IGUI_Photo_aBigHouse",
        ["a Bird"] = "IGUI_Photo_aBird",
        ["a Birth Certificate"] = "IGUI_Photo_aBirthCertificate",
        ["a Birthday Party"] = "IGUI_Photo_aBirthdayParty",
        ["a Boat"] = "IGUI_Photo_aBoat",
        ["a Boy"] = "IGUI_Photo_aBoy",
        ["a Bride"] = "IGUI_Photo_aBride",
        ["a Bride Getting Ready For Her Wedding"] = "IGUI_Photo_aBrideGettingReadyForHerWedding",
        ["a Bride Walking Down the Aisle"] = "IGUI_Photo_aBrideWalkingDowntheAisle",
        ["a Bride and Groom Exchanging Rings"] = "IGUI_Photo_aBrideandGroomExchangingRings",
        ["a Bride with a Bouquet"] = "IGUI_Photo_aBridewithaBouquet",
        ["a Building"] = "IGUI_Photo_aBuilding",
        ["a Building Being Built"] = "IGUI_Photo_aBuildingBeingBuilt",
        ["a Building on Fire"] = "IGUI_Photo_aBuildingonFire",
        ["a Busy Market"] = "IGUI_Photo_aBusyMarket",
        ["a Busy Street"] = "IGUI_Photo_aBusyStreet",
        ["a Cabin"] = "IGUI_Photo_aCabin",
        ["a Camera-Shy Old Lady"] = "IGUI_Photo_aCameraShyOldLady",
        ["a Camera-Shy Old Man"] = "IGUI_Photo_aCameraShyOldMan",
        ["a Camp"] = "IGUI_Photo_aCamp",
        ["a Car"] = "IGUI_Photo_aCar",
        ["a Car Crash"] = "IGUI_Photo_aCarCrash",
        ["a Carnival"] = "IGUI_Photo_aCarnival",
        ["a Cartoon"] = "IGUI_Photo_aCartoon",
        ["a Cartoon Character"] = "IGUI_Photo_aCartoonCharacter",
        ["a Cat"] = "IGUI_Photo_aCat",
        ["a Cattle Drive"] = "IGUI_Photo_aCattleDrive",
        ["a Celebration"] = "IGUI_Photo_aCelebration",
        ["a Ceremony"] = "IGUI_Photo_aCeremony",
        ["a Child"] = "IGUI_Photo_aChild",
        ["a Child Playing Chess"] = "IGUI_Photo_aChildPlayingChess",
        ["a Child Playing Dress-up"] = "IGUI_Photo_aChildPlayingDressup",
        ["a Child Playing With a Cat"] = "IGUI_Photo_aChildPlayingWithaCat",
        ["a Child Playing With a Dog"] = "IGUI_Photo_aChildPlayingWithaDog",
        ["a Child Playing With a Doll"] = "IGUI_Photo_aChildPlayingWithaDoll",
        ["a Child Playing With a Toy Car"] = "IGUI_Photo_aChildPlayingWithaToyCar",
        ["a Child Playing With a Toy Rocket"] = "IGUI_Photo_aChildPlayingWithaToyRocket",
        ["a Child Visiting Santa"] = "IGUI_Photo_aChildVisitingSanta",
        ["a Child Wearing a Uniform"] = "IGUI_Photo_aChildWearingaUniform",
        ["a Child's Birthday Party"] = "IGUI_Photo_aChildsBirthdayParty",
        ["a Christmas Dinner"] = "IGUI_Photo_aChristmasDinner",
        ["a Circus"] = "IGUI_Photo_aCircus",
        ["a City"] = "IGUI_Photo_aCity",
        ["a Civil War Battlefield"] = "IGUI_Photo_aCivilWarBattlefield",
        ["a Civil War Soldier"] = "IGUI_Photo_aCivilWarSoldier",
        ["a Classroom"] = "IGUI_Photo_aClassroom",
        ["a Concert"] = "IGUI_Photo_aConcert",
        ["a Couple"] = "IGUI_Photo_aCouple",
        ["a Couple Cutting Their Wedding Cake"] = "IGUI_Photo_aCoupleCuttingTheirWeddingCake",
        ["a Couple Dancing"] = "IGUI_Photo_aCoupleDancing",
        ["a Couple Having a Romantic Dinner"] = "IGUI_Photo_aCoupleHavingaRomanticDinner",
        ["a Couple Having a Romantic Picnic"] = "IGUI_Photo_aCoupleHavingaRomanticPicnic",
        ["a Couple Holding Hands"] = "IGUI_Photo_aCoupleHoldingHands",
        ["a Couple Kissing"] = "IGUI_Photo_aCoupleKissing",
        ["a Couple Laughing"] = "IGUI_Photo_aCoupleLaughing",
        ["a Couple Relaxing on a Beach"] = "IGUI_Photo_aCoupleRelaxingonaBeach",
        ["a Couple Wearing Matching Outfits"] = "IGUI_Photo_aCoupleWearingMatchingOutfits",
        ["a Couple With a Baby"] = "IGUI_Photo_aCoupleWithaBaby",
        ["a Couple in Front of a House"] = "IGUI_Photo_aCoupleinFrontofaHouse",
        ["a Cow"] = "IGUI_Photo_aCow",
        ["a Cowboy"] = "IGUI_Photo_aCowboy",
        ["a Crawling Baby"] = "IGUI_Photo_aCrawlingBaby",
        ["a Crowd"] = "IGUI_Photo_aCrowd",
        ["a Crying Child"] = "IGUI_Photo_aCryingChild",
        ["a Crying Child Visiting Santa"] = "IGUI_Photo_aCryingChildVisitingSanta",
        ["a Cute Animal"] = "IGUI_Photo_aCuteAnimal",
        ["a Dance"] = "IGUI_Photo_aDance",
        ["a Darkly-Dressed Teenager"] = "IGUI_Photo_aDarklyDressedTeenager",
        ["a Dead Animal"] = "IGUI_Photo_aDeadAnimal",
        ["a Dead Body"] = "IGUI_Photo_aDeadBody",
        ["a Dead Stick Figure"] = "IGUI_Photo_aDeadStickFigure",
        ["a Death Certificate"] = "IGUI_Photo_aDeathCertificate",
        ["a Deceased Loved One"] = "IGUI_Photo_aDeceasedLovedOne",
        ["a Deer"] = "IGUI_Photo_aDeer",
        ["a Dog"] = "IGUI_Photo_aDog",
        ["a Dog and a Cat"] = "IGUI_Photo_aDogandaCat",
        ["a Face"] = "IGUI_Photo_aFace",
        ["a Family"] = "IGUI_Photo_aFamily",
        ["a Family Celebrating Thanksgiving"] = "IGUI_Photo_aFamilyCelebratingThanksgiving",
        ["a Family Having Christmas Dinner"] = "IGUI_Photo_aFamilyHavingChristmasDinner",
        ["a Family Relaxing on a Beach"] = "IGUI_Photo_aFamilyRelaxingonaBeach",
        ["a Family Wearing Matching Halloween Costumes"] = "IGUI_Photo_aFamilyWearingMatchingHalloweenCostumes",
        ["a Family Wearing Matching Outfits"] = "IGUI_Photo_aFamilyWearingMatchingOutfits",
        ["a Family in a Car"] = "IGUI_Photo_aFamilyinaCar",
        ["a Family in a Garden"] = "IGUI_Photo_aFamilyinaGarden",
        ["a Family on the Beach"] = "IGUI_Photo_aFamilyontheBeach",
        ["a Family with Children"] = "IGUI_Photo_aFamilywithChildren",
        ["a Family with a Baby"] = "IGUI_Photo_aFamilywithaBaby",
        ["a Family with a Child"] = "IGUI_Photo_aFamilywithaChild",
        ["a Family with a Pet"] = "IGUI_Photo_aFamilywithaPet",
        ["a Famous Outlaw"] = "IGUI_Photo_aFamousOutlaw",
        ["a Famous Person"] = "IGUI_Photo_aFamousPerson",
        ["a Famous Person From a Long Time Ago"] = "IGUI_Photo_aFamousPersonFromaLongTimeAgo",
        ["a Famous Place"] = "IGUI_Photo_aFamousPlace",
        ["a Farmer"] = "IGUI_Photo_aFarmer",
        ["a Father and Children"] = "IGUI_Photo_aFatherandChildren",
        ["a Father and Daughter"] = "IGUI_Photo_aFatherandDaughter",
        ["a Father and Son"] = "IGUI_Photo_aFatherandSon",
        ["a Finished Project"] = "IGUI_Photo_aFinishedProject",
        ["a First Birthday Party"] = "IGUI_Photo_aFirstBirthdayParty",
        ["a First World War Soldier"] = "IGUI_Photo_aFirstWorldWarSoldier",
        ["a Flood"] = "IGUI_Photo_aFlood",
        ["a Football Game"] = "IGUI_Photo_aFootballGame",
        ["a Foreign Vacation"] = "IGUI_Photo_aForeignVacation",
        ["a Forest"] = "IGUI_Photo_aForest",
        ["a Fort"] = "IGUI_Photo_aFort",
        ["a Fox"] = "IGUI_Photo_aFox",
        ["a Friendly Alien"] = "IGUI_Photo_aFriendlyAlien",
        ["a Friendly Creature"] = "IGUI_Photo_aFriendlyCreature",
        ["a Frontier Family"] = "IGUI_Photo_aFrontierFamily",
        ["a Frontiersman"] = "IGUI_Photo_aFrontiersman",
        ["a Funny Scene"] = "IGUI_Photo_aFunnyScene",
        ["a Fussy Child"] = "IGUI_Photo_aFussyChild",
        ["a Garden"] = "IGUI_Photo_aGarden",
        ["a Gentleman"] = "IGUI_Photo_aGentleman",
        ["a Get-Together"] = "IGUI_Photo_aGetTogether",
        ["a Girl"] = "IGUI_Photo_aGirl",
        ["a Graduation"] = "IGUI_Photo_aGraduation",
        ["a Groom"] = "IGUI_Photo_aGroom",
        ["a Groom Getting Ready For His Wedding"] = "IGUI_Photo_aGroomGettingReadyForHisWedding",
        ["a Group of Abolitionists"] = "IGUI_Photo_aGroupofAbolitionists",
        ["a Group of Children"] = "IGUI_Photo_aGroupofChildren",
        ["a Group of Civil War Soldiers"] = "IGUI_Photo_aGroupofCivilWarSoldiers",
        ["a Group of Cowboys"] = "IGUI_Photo_aGroupofCowboys",
        ["a Group of Cyclists"] = "IGUI_Photo_aGroupofCyclists",
        ["a Group of First World War Soldiers"] = "IGUI_Photo_aGroupofFirstWorldWarSoldiers",
        ["a Group of Horses"] = "IGUI_Photo_aGroupofHorses",
        ["a Group of Hunters"] = "IGUI_Photo_aGroupofHunters",
        ["a Group of Korean War Soldiers"] = "IGUI_Photo_aGroupofKoreanWarSoldiers",
        ["a Group of Men"] = "IGUI_Photo_aGroupofMen",
        ["a Group of Native Americans"] = "IGUI_Photo_aGroupofNativeAmericans",
        ["a Group of Pacifists"] = "IGUI_Photo_aGroupofPacifists",
        ["a Group of People"] = "IGUI_Photo_aGroupofPeople",
        ["a Group of People Laughing"] = "IGUI_Photo_aGroupofPeopleLaughing",
        ["a Group of People in Bed"] = "IGUI_Photo_aGroupofPeopleinBed",
        ["a Group of Prohibitionists"] = "IGUI_Photo_aGroupofProhibitionists",
        ["a Group of Protestors"] = "IGUI_Photo_aGroupofProtestors",
        ["a Group of Schoolboys"] = "IGUI_Photo_aGroupofSchoolboys",
        ["a Group of Schoolchildren"] = "IGUI_Photo_aGroupofSchoolchildren",
        ["a Group of Schoolgirls"] = "IGUI_Photo_aGroupofSchoolgirls",
        ["a Group of Second World War Soldiers"] = "IGUI_Photo_aGroupofSecondWorldWarSoldiers",
        ["a Group of Spiritualists"] = "IGUI_Photo_aGroupofSpiritualists",
        ["a Group of Students"] = "IGUI_Photo_aGroupofStudents",
        ["a Group of Suffragettes"] = "IGUI_Photo_aGroupofSuffragettes",
        ["a Group of Unclothed People"] = "IGUI_Photo_aGroupofUnclothedPeople",
        ["a Group of Unusual Plants"] = "IGUI_Photo_aGroupofUnusualPlants",
        ["a Group of Women"] = "IGUI_Photo_aGroupofWomen",
        ["a Group of Young People"] = "IGUI_Photo_aGroupofYoungPeople",
        ["a Group, With a Person Cut Out"] = "IGUI_Photo_aPhotoWithaPersonCutOut",
        ["a Gruesome Scene"] = "IGUI_Photo_aGruesomeScene",
        ["a Gun"] = "IGUI_Photo_aGun",
        ["a Hamster"] = "IGUI_Photo_aHamster",
        ["a Handsome Man"] = "IGUI_Photo_aHandsomeMan",
        ["a Handsome Young Man"] = "IGUI_Photo_aHandsomeYoungMan",
        ["a Happy Family"] = "IGUI_Photo_aHappyFamily",
        ["a Homesteader Family"] = "IGUI_Photo_aHomesteaderFamily",
        ["a Horse"] = "IGUI_Photo_aHorse",
        ["a Horse Drawing a Plow"] = "IGUI_Photo_aHorseDrawingaPlow",
        ["a Horse Race"] = "IGUI_Photo_aHorseRace",
        ["a Horse-drawn Carriage Arriving at a Church"] = "IGUI_Photo_aHorsedrawnCarriageArrivingataChurch",
        ["a House"] = "IGUI_Photo_aHouse",
        ["a House Being Built"] = "IGUI_Photo_aHouseBeingBuilt",
        ["a House with a Family"] = "IGUI_Photo_aHousewithaFamily",
        ["a Hunter"] = "IGUI_Photo_aHunter",
        ["a Hunter Posing with Their Kill"] = "IGUI_Photo_aHunterPosingwithTheirKill",
        ["a Kitten"] = "IGUI_Photo_aKitten",
        ["a Korean War Soldier"] = "IGUI_Photo_aKoreanWarSoldier",
        ["a Lady"] = "IGUI_Photo_aLady",
        ["a Lake"] = "IGUI_Photo_aLake",
        ["a Landmark"] = "IGUI_Photo_aLandmark",
        ["a Landmark Being Built"] = "IGUI_Photo_aLandmarkBeingBuilt",
        ["a Landscape"] = "IGUI_Photo_aLandscape",
        ["a Large Family"] = "IGUI_Photo_aLargeFamily",
        ["a Large Group of People"] = "IGUI_Photo_aLargeGroupofPeople",
        ["a Large Public Event"] = "IGUI_Photo_aLargePublicEvent",
        ["a Laughing Child"] = "IGUI_Photo_aLaughingChild",
        ["a Leader"] = "IGUI_Photo_aLeader",
        ["a License Plate"] = "IGUI_Photo_aLicensePlate",
        ["a Logo"] = "IGUI_Photo_aLogo",
        ["a Lonely-Looking Child"] = "IGUI_Photo_aLonelyLookingChild",
        ["a Loved One"] = "IGUI_Photo_aLovedOne",
        ["a Man"] = "IGUI_Photo_aMan",
        ["a Man Laughing"] = "IGUI_Photo_aManLaughing",
        ["a Man Wearing a Uniform"] = "IGUI_Photo_aManWearingaUniform",
        ["a Man With a Baby"] = "IGUI_Photo_aManWithaBaby",
        ["a Man on a Bicycle"] = "IGUI_Photo_aManonaBicycle",
        ["a Man with a Baby"] = "IGUI_Photo_aManwithaBaby",
        ["a Man with a Large Mustache"] = "IGUI_Photo_aManwithaLargeMustache",
        ["a Man with a Long Beard"] = "IGUI_Photo_aManwithaLongBeard",
        ["a Man's Face"] = "IGUI_Photo_aMan'sFace",
        ["a Map"] = "IGUI_Photo_aMap",
        ["a Marriage Certificate"] = "IGUI_Photo_aMarriageCertificate",
        ["a Married Couple"] = "IGUI_Photo_aMarriedCouple",
        ["a Meal"] = "IGUI_Photo_aMeal",
        ["a Messy Baby"] = "IGUI_Photo_aMessyBaby",
        ["a Military Camp"] = "IGUI_Photo_aMilitaryCamp",
        ["a Military Officer"] = "IGUI_Photo_aMilitaryOfficer",
        ["a Missing Person"] = "IGUI_Photo_aMissingPerson",
        ["a Monster"] = "IGUI_Photo_aMonster",
        ["a Mother and Children"] = "IGUI_Photo_aMotherandChildren",
        ["a Mother and Son"] = "IGUI_Photo_aMotherandSon",
        ["a Motorcycle"] = "IGUI_Photo_aMotorcycle",
        ["a Movie Character"] = "IGUI_Photo_aMovieCharacter",
        ["a Mugshot"] = "IGUI_Photo_aMugshot",
        ["a Native American"] = "IGUI_Photo_aNativeAmerican",
        ["a Nature Scene"] = "IGUI_Photo_aNatureScene",
        ["a Neatly Dressed Child"] = "IGUI_Photo_aNeatlyDressedChild",
        ["a Nervous Person"] = "IGUI_Photo_aNervousPerson",
        ["a Newly Married Couple Dancing Together"] = "IGUI_Photo_aNewlyMarriedCoupleDancingTogether",
        ["a Newly Married Couple Holding Hands"] = "IGUI_Photo_aNewlyMarriedCoupleHoldingHands",
        ["a Newly Married Couple Kissing"] = "IGUI_Photo_aNewlyMarriedCoupleKissing",
        ["a Nice Day"] = "IGUI_Photo_aNiceDay",
        ["a Nice Teacher"] = "IGUI_Photo_aNiceTeacher",
        ["a Nineteenth Century Family"] = "IGUI_Photo_aNineteenthCenturyFamily",
        ["a Paddle Steamer on the Ohio"] = "IGUI_Photo_aPaddleSteamerontheOhio",
        ["a Pair of Sleeping Children"] = "IGUI_Photo_aPairofSleepingChildren",
        ["a Pair of Teenagers in Love"] = "IGUI_Photo_aPairofTeenagersinLove",
        ["a Parade"] = "IGUI_Photo_aParade",
        ["a Party"] = "IGUI_Photo_aParty",
        ["a Paternity Test"] = "IGUI_Photo_aPaternityTest",
        ["a Pattern"] = "IGUI_Photo_aPattern",
        ["a Person"] = "IGUI_Photo_aPerson",
        ["a Person Who's Tied Up"] = "IGUI_Photo_aPersonWho'sTiedUp",
        ["a Person With Their Face Crossed Out"] = "IGUI_Photo_aPersonWithTheirFaceCrossedOut",
        ["a Person in a Compromising Position"] = "IGUI_Photo_aPersoninaCompromisingPosition",
        ["a Person with Crosshairs on Their Face"] = "IGUI_Photo_aPersonwithCrosshairsonTheirFace",
        ["a Pet"] = "IGUI_Photo_aPet",
        ["a Picnic"] = "IGUI_Photo_aPicnic",
        ["a Pile of Cash"] = "IGUI_Photo_aPileofCash",
        ["a Plane"] = "IGUI_Photo_aPlane",
        ["a Police Officer"] = "IGUI_Photo_aPoliceOfficer",
        ["a Political Meeting"] = "IGUI_Photo_aPoliticalMeeting",
        ["a Political Rally"] = "IGUI_Photo_aPoliticalRally",
        ["a Politician"] = "IGUI_Photo_aPolitician",
        ["a President"] = "IGUI_Photo_aPresident",
        ["a Prom"] = "IGUI_Photo_aProm",
        ["a Puppy"] = "IGUI_Photo_aPuppy",
        ["a Rabbit"] = "IGUI_Photo_aRabbit",
        ["a Raccoon"] = "IGUI_Photo_aRaccoon",
        ["a Rainbow"] = "IGUI_Photo_aRainbow",
        ["a Rainy Day"] = "IGUI_Photo_aRainyDay",
        ["a Recital"] = "IGUI_Photo_aRecital",
        ["a Religious Figure"] = "IGUI_Photo_aReligiousFigure",
        ["a Religious Leader"] = "IGUI_Photo_aReligiousLeader",
        ["a Religious Scene"] = "IGUI_Photo_aReligiousScene",
        ["a Religious Service"] = "IGUI_Photo_aReligiousService",
        ["a Reunion"] = "IGUI_Photo_aReunion",
        ["a River"] = "IGUI_Photo_aRiver",
        ["a Road"] = "IGUI_Photo_aRoad",
        ["a Road Trip"] = "IGUI_Photo_aRoadTrip",
        ["a Romantic Nature"] = "IGUI_Photo_aRomanticNature",
        ["a Room"] = "IGUI_Photo_aRoom",
        ["a Rugged Cabin"] = "IGUI_Photo_aRuggedCabin",
        ["a Sailing Ship"] = "IGUI_Photo_aSailingShip",
        ["a Saloon"] = "IGUI_Photo_aSaloon",
        ["a Scary Alien"] = "IGUI_Photo_aScaryAlien",
        ["a Scary Monster"] = "IGUI_Photo_aScaryMonster",
        ["a School Play"] = "IGUI_Photo_aSchoolPlay",
        ["a Second Birthday Party"] = "IGUI_Photo_aSecondBirthdayParty",
        ["a Second World War Soldier"] = "IGUI_Photo_aSecondWorldWarSoldier",
        ["a Sheriff"] = "IGUI_Photo_aSheriff",
        ["a Ship"] = "IGUI_Photo_aShip",
        ["a Skiing Vacation"] = "IGUI_Photo_aSkiingVacation",
        ["a Sleeping Baby"] = "IGUI_Photo_aSleepingBaby",
        ["a Sleeping Cat"] = "IGUI_Photo_aSleepingCat",
        ["a Sleeping Child"] = "IGUI_Photo_aSleepingChild",
        ["a Sleeping Dog"] = "IGUI_Photo_aSleepingDog",
        ["a Sleeping Grandfather"] = "IGUI_Photo_aSleepingGrandfather",
        ["a Sleeping Grandmother"] = "IGUI_Photo_aSleepingGrandmother",
        ["a Sleeping Kitten"] = "IGUI_Photo_aSleepingKitten",
        ["a Sleeping Puppy"] = "IGUI_Photo_aSleepingPuppy",
        ["a Small Child's Birthday Party"] = "IGUI_Photo_aSmallChildsBirthdayParty",
        ["a Small House"] = "IGUI_Photo_aSmallHouse",
        ["a Smiling Baby"] = "IGUI_Photo_aSmilingBaby",
        ["a Smiling Couple"] = "IGUI_Photo_aSmilingCouple",
        ["a Smiling Family"] = "IGUI_Photo_aSmilingFamily",
        ["a Smiling Man"] = "IGUI_Photo_aSmilingMan",
        ["a Smiling Sun"] = "IGUI_Photo_aSmilingSun",
        ["a Smiling Woman"] = "IGUI_Photo_aSmilingWoman",
        ["a Snake"] = "IGUI_Photo_aSnake",
        ["a Soccer Game"] = "IGUI_Photo_aSoccerGame",
        ["a Soldier"] = "IGUI_Photo_aSoldier",
        ["a Space Scene"] = "IGUI_Photo_aSpaceScene",
        ["a Special Event"] = "IGUI_Photo_aSpecialEvent",
        ["a Sports Car"] = "IGUI_Photo_aSportsCar",
        ["a Sports Game"] = "IGUI_Photo_aSportsGame",
        ["a Steam Train"] = "IGUI_Photo_aSteamTrain",
        ["a Steamship"] = "IGUI_Photo_aSteamship",
        ["a Stick Figure"] = "IGUI_Photo_aStickFigure",
        ["a Street"] = "IGUI_Photo_aStreet",
        ["a Street of Wooden Buildings"] = "IGUI_Photo_aStreetofWoodenBuildings",
        ["a Sunny Day"] = "IGUI_Photo_aSunnyDay",
        ["a Sunrise"] = "IGUI_Photo_aSunrise",
        ["a Sunset"] = "IGUI_Photo_aSunset",
        ["a Surreal Scene"] = "IGUI_Photo_aSurrealScene",
        ["a Suspicious Group of People"] = "IGUI_Photo_aSuspiciousGroupofPeople",
        ["a Suspicious Meeting"] = "IGUI_Photo_aSuspiciousMeeting",
        ["a Suspicious Object"] = "IGUI_Photo_aSuspiciousObject",
        ["a Suspicious Person"] = "IGUI_Photo_aSuspiciousPerson",
        ["a Séance"] = "IGUI_Photo_aSeance",
        ["a Teenage Band"] = "IGUI_Photo_aTeenageBand",
        ["a Teenager"] = "IGUI_Photo_aTeenager",
        ["a Teenager's Birthday Party"] = "IGUI_Photo_aTeenagersBirthdayParty",
        ["a Third Birthday Party"] = "IGUI_Photo_aThirdBirthdayParty",
        ["a Town"] = "IGUI_Photo_aTown",
        ["a Train"] = "IGUI_Photo_aTrain",
        ["a Train Station in the Old Days"] = "IGUI_Photo_aTrainStationintheOldDays",
        ["a Tree"] = "IGUI_Photo_aTree",
        ["a Typical Western Scene"] = "IGUI_Photo_aTypicalWesternScene",
        ["a Vacation"] = "IGUI_Photo_aVacation",
        ["a Vacation to Asia"] = "IGUI_Photo_aVacationtoAsia",
        ["a Vacation to California"] = "IGUI_Photo_aVacationtoCalifornia",
        ["a Vacation to Europe"] = "IGUI_Photo_aVacationtoEurope",
        ["a Vacation to Florida"] = "IGUI_Photo_aVacationtoFlorida",
        ["a Vacation to Hawaii"] = "IGUI_Photo_aVacationtoHawaii",
        ["a Vacation to Las Vegas"] = "IGUI_Photo_aVacationtoLasVegas",
        ["a Vacation to London"] = "IGUI_Photo_aVacationtoLondon",
        ["a Vacation to New York"] = "IGUI_Photo_aVacationtoNewYork",
        ["a Vacation to Paris"] = "IGUI_Photo_aVacationtoParis",
        ["a Vacation to South America"] = "IGUI_Photo_aVacationtoSouthAmerica",
        ["a Vacation to Washington D.C."] = "IGUI_Photo_aVacationtoWashingtonDC",
        ["a Vacation to the Grand Canyon"] = "IGUI_Photo_aVacationtotheGrandCanyon",
        ["a Vehicle"] = "IGUI_Photo_aVehicle",
        ["a View from a Window"] = "IGUI_Photo_aViewfromaWindow",
        ["a Violent Scene"] = "IGUI_Photo_aViolentScene",
        ["a Wagon Train"] = "IGUI_Photo_aWagonTrain",
        ["a Wanted Fugitive"] = "IGUI_Photo_aWantedFugitive",
        ["a Wedding"] = "IGUI_Photo_aWedding",
        ["a Wedding Car Arriving at a Church"] = "IGUI_Photo_aWeddingCarArrivingataChurch",
        ["a Wedding Reception"] = "IGUI_Photo_aWeddingReception",
        ["a Wedding, With a Person Cut Out"] = "IGUI_Photo_aWeddingPhotoWithaPersonCutOut",
        ["a Weird Face"] = "IGUI_Photo_aWeirdFace",
        ["a Well-Built Cabin"] = "IGUI_Photo_aWellBuiltCabin",
        ["a Well-Dressed Old Man"] = "IGUI_Photo_aWellDressedOldMan",
        ["a Wild Animal"] = "IGUI_Photo_aWildAnimal",
        ["a Wild Bird"] = "IGUI_Photo_aWildBird",
        ["a Woman"] = "IGUI_Photo_aWoman",
        ["a Woman Laughing"] = "IGUI_Photo_aWomanLaughing",
        ["a Woman Wearing a Uniform"] = "IGUI_Photo_aWomanWearingaUniform",
        ["a Woman With a Baby"] = "IGUI_Photo_aWomanWithaBaby",
        ["a Woman on a Bicycle"] = "IGUI_Photo_aWomanonaBicycle",
        ["a Woman with a Baby"] = "IGUI_Photo_aWomanwithaBaby",
        ["a Woman with a Huge Hat"] = "IGUI_Photo_aWomanwithaHugeHat",
        ["a Woman's Face"] = "IGUI_Photo_aWoman'sFace",
        ["a Young Couple"] = "IGUI_Photo_aYoungCouple",
        ["a Young Couple Dancing"] = "IGUI_Photo_aYoungCoupleDancing",
        ["a Young Man"] = "IGUI_Photo_aYoungMan",
        ["a Young Man Wearing a Uniform"] = "IGUI_Photo_aYoungManWearingaUniform",
        ["a Young Man's Birthday Party"] = "IGUI_Photo_aYoungMansBirthdayParty",
        ["a Young Woman"] = "IGUI_Photo_aYoungWoman",
        ["a Young Woman Wearing a Uniform"] = "IGUI_Photo_aYoungWomanWearingaUniform",
        ["a Young Woman's Birthday Party"] = "IGUI_Photo_aYoungWomansBirthdayParty",
        ["an African Safari"] = "IGUI_Photo_anAfricanSafari",
        ["an Alien"] = "IGUI_Photo_anAlien",
        ["an Angry Man"] = "IGUI_Photo_anAngryMan",
        ["an Angry Person"] = "IGUI_Photo_anAngryPerson",
        ["an Angry Teacher"] = "IGUI_Photo_anAngryTeacher",
        ["an Angry Woman"] = "IGUI_Photo_anAngryWoman",
        ["an Article About a Crime"] = "IGUI_Photo_anArticleAboutaCrime",
        ["an Artwork"] = "IGUI_Photo_Artwork",
        ["an Attractive Lady"] = "IGUI_Photo_anAttractiveLady",
        ["an Award Ceremony"] = "IGUI_Photo_anAwardCeremony",
        ["an Awkward Young Couple"] = "IGUI_Photo_anAwkwardYoungCouple",
        ["an Elderly Couple"] = "IGUI_Photo_anElderlyCouple",
        ["an Embarrassed Old Lady"] = "IGUI_Photo_anEmbarrassedOldLady",
        ["an Embarrassed Old Man"] = "IGUI_Photo_anEmbarrassedOldMan",
        ["an Embarrassed Teenager"] = "IGUI_Photo_anEmbarrassedTeenager",
        ["an Empty Room"] = "IGUI_Photo_anEmptyRoom",
        ["an Empty Street"] = "IGUI_Photo_anEmptyStreet",
        ["an Engagement Ring"] = "IGUI_Photo_anEngagementRing",
        ["an Everyday Object"] = "IGUI_Photo_anEverydayObject",
        ["an Exotic Animal"] = "IGUI_Photo_anExoticAnimal",
        ["an Ice Hockey Game"] = "IGUI_Photo_anIceHockeyGame",
        ["an Illicit Nature"] = "IGUI_Photo_anIllicitNature",
        ["an Oddly Colored Scene"] = "IGUI_Photo_anOddlyColoredScene",
        ["an Oddly Proportioned Person"] = "IGUI_Photo_anOddlyProportionedPerson",
        ["an Old Car"] = "IGUI_Photo_anOldCar",
        ["an Old Couple"] = "IGUI_Photo_anOldCouple",
        ["an Old Couple Dancing"] = "IGUI_Photo_anOldCoupleDancing",
        ["an Old Lady in Her Best Hat"] = "IGUI_Photo_anOldLadyinHerBestHat",
        ["an Old Man"] = "IGUI_Photo_anOldMan",
        ["an Old Tree"] = "IGUI_Photo_anOldTree",
        ["an Old Woman"] = "IGUI_Photo_anOldWoman",
        ["an Outdated Piece of Technology"] = "IGUI_Photo_anOutdatedPieceofTechnology",
        ["an Outing"] = "IGUI_Photo_anOuting",
        ["an Outlaw"] = "IGUI_Photo_anOutlaw",
        ["an Unclothed Couple"] = "IGUI_Photo_anUnclothedCouple",
        ["the Alamo"] = "IGUI_Photo_theAlamo",
        ["the Alps"] = "IGUI_Photo_theAlps",
        ["the Amazon"] = "IGUI_Photo_theAmazon",
        ["the American Gun Museum"] = "IGUI_Photo_theAmericanGunMuseum",
        ["the American History Museum"] = "IGUI_Photo_theAmericanHistoryMuseum",
        ["the American Media Museum"] = "IGUI_Photo_theAmericanMediaMuseum",
        ["the American Music Hall of Fame"] = "IGUI_Photo_theAmericanMusicHallofFame",
        ["the American WWII Museum"] = "IGUI_Photo_theAmericanWWIIMuseum",
        ["the Andes"] = "IGUI_Photo_theAndes",
        ["the Appalachian Trail"] = "IGUI_Photo_theAppalachianTrail",
        ["the Appalachians"] = "IGUI_Photo_theAppalachians",
        ["the Austin Parker Mansion"] = "IGUI_Photo_theAustinParkerMansion",
        ["the Australian Outback"] = "IGUI_Photo_theAustralianOutback",
        ["the Bahamas"] = "IGUI_Photo_theBahamas",
        ["the British Museum"] = "IGUI_Photo_theBritishMuseum",
        ["the Bronx"] = "IGUI_Photo_theBronx",
        ["the California Science Museum"] = "IGUI_Photo_theCaliforniaScienceMuseum",
        ["the Caribbean"] = "IGUI_Photo_theCaribbean",
        ["the Chevalier Museum"] = "IGUI_Photo_theChevalierMuseum",
        ["the Cinque Terre"] = "IGUI_Photo_theCinqueTerre",
        ["the Colosseum"] = "IGUI_Photo_theColosseum",
        ["the Dead Sea"] = "IGUI_Photo_theDeadSea",
        ["the Empire State Building"] = "IGUI_Photo_theEmpireStateBuilding",
        ["the Everglades"] = "IGUI_Photo_theEverglades",
        ["the Forbidden City"] = "IGUI_Photo_theForbiddenCity",
        ["the Frankie Monro Museum"] = "IGUI_Photo_theFrankieMonroMuseum",
        ["the Galapagos Islands"] = "IGUI_Photo_theGalapagosIslands",
        ["the Grand Canyon"] = "IGUI_Photo_theGrandCanyon",
        ["the Great Smoky Mountains"] = "IGUI_Photo_theGreatSmokyMountains",
        ["the Great Wall of China"] = "IGUI_Photo_theGreatWallofChina",
        ["the Hagia Sophia"] = "IGUI_Photo_theHagiaSophia",
        ["the Hank Gilman Museum"] = "IGUI_Photo_theHankGilmanMuseum",
        ["the Himalayas"] = "IGUI_Photo_theHimalayas",
        ["the Hoover Dam"] = "IGUI_Photo_theHooverDam",
        ["the Klamath Mountains"] = "IGUI_Photo_theKlamathMountains",
        ["the Lincoln Memorial"] = "IGUI_Photo_theLincolnMemorial",
        ["the Louvre"] = "IGUI_Photo_theLouvre",
        ["the Magical Woodland"] = "IGUI_Photo_DoodleofMagicalWoodland",
        ["the Matterhorn"] = "IGUI_Photo_theMatterhorn",
        ["the Modern Art Museum"] = "IGUI_Photo_theModernArtMuseum",
        ["the Mojave"] = "IGUI_Photo_theMojave",
        ["the National Air and Space Museum"] = "IGUI_Photo_theNationalAirandSpaceMuseum",
        ["the National Art Gallery"] = "IGUI_Photo_theNationalArtGallery",
        ["the National Baseball Museum"] = "IGUI_Photo_theNationalBaseballMuseum",
        ["the National Basketball Museum"] = "IGUI_Photo_theNationalBasketballMuseum",
        ["the National Car Museum"] = "IGUI_Photo_theNationalCarMuseum",
        ["the National Football Museum"] = "IGUI_Photo_theNationalFootballMuseum",
        ["the National Natural History Museum"] = "IGUI_Photo_theNationalNaturalHistoryMuseum",
        ["the North Pole"] = "IGUI_Photo_theNorthPole",
        ["the OSCC Hall of Fame"] = "IGUI_Photo_theOSCCHallofFame",
        ["the Ohio River"] = "IGUI_Photo_theOhioRiver",
        ["the Pacific Coast Highway"] = "IGUI_Photo_thePacificCoastHighway",
        ["the Palace of Versailles"] = "IGUI_Photo_thePalaceofVersailles",
        ["the Pyramids at Giza"] = "IGUI_Photo_thePyramidsatGiza",
        ["the RMS Queen Mary"] = "IGUI_Photo_theRMSQueenMary",
        ["the Red Sea"] = "IGUI_Photo_theRedSea",
        ["the Rockies"] = "IGUI_Photo_theRockies",
        ["the Sky"] = "IGUI_Photo_theSky",
        ["the Soviet Union"] = "IGUI_Photo_theSovietUnion",
        ["the Statue of Liberty"] = "IGUI_Photo_theStatueofLiberty",
        ["the Taj Mahal"] = "IGUI_Photo_theTajMahal",
        ["the US Capitol"] = "IGUI_Photo_theUSCapitol",
        ["the Uffizi"] = "IGUI_Photo_theUffizi",
        ["the Virginia Patterson Museum"] = "IGUI_Photo_theVirginiaPattersonMuseum",
        ["the Washington Monument"] = "IGUI_Photo_theWashingtonMonument",
        ["the White House"] = "IGUI_Photo_theWhiteHouse",
        ["the Zócalo"] = "IGUI_Photo_theZocalo",
    },
    NEWSPAPER_TITLE = {
        ["Bowling Green Post"] = "IGUI_NewspaperTitle_BowlingGreenPost",
        ["Brandenburg Bugle"] = "IGUI_NewspaperTitle_BrandenburgBugle",
        ["Christian Bulletin"] = "IGUI_NewspaperTitle_ChristianBulletin",
        ["Evansville Post"] = "IGUI_NewspaperTitle_EvansvillePost",
        ["Kentucky Observer"] = "IGUI_NewspaperTitle_KentuckyObserver",
        ["Knox Frontline"] = "IGUI_NewspaperTitle_KnoxFrontline",
        ["Knox Knews"] = "IGUI_NewspaperTitle_KnoxKnews",
        ["Louisville Student"] = "IGUI_NewspaperTitle_LouisvilleStudent",
        ["Louisville Sun"] = "IGUI_NewspaperTitle_LouisvilleSun",
        ["Louisville Sun Times"] = "IGUI_NewspaperTitle_LouisvilleSunTimes",
        ["Muldraugh Messenger"] = "IGUI_NewspaperTitle_MuldraughMessenger",
        ["National Finance"] = "IGUI_NewspaperTitle_NationalFinance",
        ["Owensboro Outsider"] = "IGUI_NewspaperTitle_OwensboroOutsider",
        ["Paducah Post"] = "IGUI_NewspaperTitle_PaducahPost",
        ["The Cincinnati Times"] = "IGUI_NewspaperTitle_TheCincinnatiTimes",
        ["The Kentucky Defender"] = "IGUI_NewspaperTitle_TheKentuckyDefender",
        ["The Kentucky Herald"] = "IGUI_NewspaperTitle_KentuckyHerald",
        ["The Knox Frontline"] = "IGUI_NewspaperTitle_TheKnoxFrontline",
        ["The Lexington Voice"] = "IGUI_NewspaperTitle_TheLexingtonVoice",
        ["The London Post"] = "IGUI_NewspaperTitle_TheLondonPost",
        ["The Louisville Bear"] = "IGUI_NewspaperTitle_TheLouisvilleBear",
        ["The Louisville Student"] = "IGUI_NewspaperTitle_TheLouisvilleStudent",
        ["The National Dispatch"] = "IGUI_NewspaperTitle_NationalDispatch",
        ["Wall Street Insider"] = "IGUI_NewspaperTitle_WallStreetInsider",
        ["Washington Herald"] = "IGUI_NewspaperTitle_WashingtonHerald",
    },
    PETNAME = {
        ["Ace"] = "IGUI_PetName_Ace",
        ["Acorn"] = "IGUI_PetName_Acorn",
        ["America"] = "IGUI_PetName_America",
        ["Archie"] = "IGUI_PetName_Archie",
        ["Avocado"] = "IGUI_PetName_Avocado",
        ["Baby"] = "IGUI_PetName_Baby",
        ["Bacon"] = "IGUI_PetName_Bacon",
        ["Badger"] = "IGUI_PetName_Badger",
        ["Bagel"] = "IGUI_PetName_Bagel",
        ["Bailey"] = "IGUI_PetName_Bailey",
        ["Bandit"] = "IGUI_PetName_Bandit",
        ["Beanie"] = "IGUI_PetName_Beanie",
        ["Beans"] = "IGUI_PetName_Beans",
        ["Bella"] = "IGUI_PetName_Bella",
        ["Belle"] = "IGUI_PetName_Belle",
        ["Ben"] = "IGUI_PetName_Ben",
        ["Berserker"] = "IGUI_PetName_Berserker",
        ["Bert"] = "IGUI_PetName_Bert",
        ["Bess"] = "IGUI_PetName_Bess",
        ["Biscuit"] = "IGUI_PetName_Biscuit",
        ["Blondie"] = "IGUI_PetName_Blondie",
        ["Blossom"] = "IGUI_PetName_Blossom",
        ["Boris"] = "IGUI_PetName_Boris",
        ["Boxer"] = "IGUI_PetName_Boxer",
        ["Brandy"] = "IGUI_PetName_Brandy",
        ["Bruce"] = "IGUI_PetName_Bruce",
        ["Bruno"] = "IGUI_PetName_Bruno",
        ["Bubble"] = "IGUI_PetName_Bubble",
        ["Bubbles"] = "IGUI_PetName_Bubbles",
        ["Buck"] = "IGUI_PetName_Buck",
        ["Buckshot"] = "IGUI_PetName_Buckshot",
        ["Bud"] = "IGUI_PetName_Bud",
        ["Buddy"] = "IGUI_PetName_Buddy",
        ["Bullet"] = "IGUI_PetName_Bullet",
        ["Buttercup"] = "IGUI_PetName_Buttercup",
        ["Cally"] = "IGUI_PetName_Cally",
        ["Chaplin"] = "IGUI_PetName_Chaplin",
        ["Charlie"] = "IGUI_PetName_Charlie",
        ["Chief"] = "IGUI_PetName_Chief",
        ["Chocolate"] = "IGUI_PetName_Chocolate",
        ["Chopper"] = "IGUI_PetName_Chopper",
        ["Chronos"] = "IGUI_PetName_Chronos",
        ["Claude"] = "IGUI_PetName_Claude",
        ["Cleaver"] = "IGUI_PetName_Cleaver",
        ["Cloud"] = "IGUI_PetName_Cloud",
        ["Clover"] = "IGUI_PetName_Clover",
        ["Coco"] = "IGUI_PetName_Coco",
        ["Coffee"] = "IGUI_PetName_Coffee",
        ["Cookie"] = "IGUI_PetName_Cookie",
        ["Cooper"] = "IGUI_PetName_Cooper",
        ["Copper"] = "IGUI_PetName_Copper",
        ["Crockett"] = "IGUI_PetName_Crockett",
        ["Cupcake"] = "IGUI_PetName_Cupcake",
        ["Daisy"] = "IGUI_PetName_Daisy",
        ["Dakota"] = "IGUI_PetName_Dakota",
        ["Doctor"] = "IGUI_PetName_Doctor",
        ["Dot"] = "IGUI_PetName_Dot",
        ["Dude"] = "IGUI_PetName_Dude",
        ["Duke"] = "IGUI_PetName_Duke",
        ["Dylan"] = "IGUI_PetName_Dylan",
        ["Ed"] = "IGUI_PetName_Ed",
        ["Elle"] = "IGUI_PetName_Elle",
        ["Fifi"] = "IGUI_PetName_Fifi",
        ["Flora"] = "IGUI_PetName_Flora",
        ["Fluffy"] = "IGUI_PetName_Fluffy",
        ["Fluffyfoot"] = "IGUI_PetName_Fluffyfoot",
        ["Fraidy"] = "IGUI_PetName_Fraidy",
        ["Freddy"] = "IGUI_PetName_Freddy",
        ["Freedom"] = "IGUI_PetName_Freedom",
        ["Frosty"] = "IGUI_PetName_Frosty",
        ["Fudge"] = "IGUI_PetName_Fudge",
        ["Furbert"] = "IGUI_PetName_Furbert",
        ["Ginger"] = "IGUI_PetName_Ginger",
        ["Goblin"] = "IGUI_PetName_Goblin",
        ["Goldie"] = "IGUI_PetName_Goldie",
        ["Gravy"] = "IGUI_PetName_Gravy",
        ["Griffin"] = "IGUI_PetName_Griffin",
        ["Gunner"] = "IGUI_PetName_Gunner",
        ["Hargrave"] = "IGUI_PetName_Hargrave",
        ["Harry"] = "IGUI_PetName_Harry",
        ["Hazel"] = "IGUI_PetName_Hazel",
        ["Herb"] = "IGUI_PetName_Herb",
        ["Holly"] = "IGUI_PetName_Holly",
        ["Honey"] = "IGUI_PetName_Honey",
        ["Jack"] = "IGUI_PetName_Jack",
        ["Jacques"] = "IGUI_PetName_Jacques",
        ["Jay"] = "IGUI_PetName_Jay",
        ["Jenny"] = "IGUI_PetName_Jenny",
        ["Jill"] = "IGUI_PetName_Jill",
        ["Jilly"] = "IGUI_PetName_Jilly",
        ["Joker"] = "IGUI_PetName_Joker",
        ["Josh"] = "IGUI_PetName_Josh",
        ["Joshie"] = "IGUI_PetName_Joshie",
        ["Joss"] = "IGUI_PetName_Joss",
        ["Juliet"] = "IGUI_PetName_Juliet",
        ["Kai"] = "IGUI_PetName_Kai",
        ["Katana"] = "IGUI_PetName_Katana",
        ["Katja"] = "IGUI_PetName_Katja",
        ["Kentucky"] = "IGUI_PetName_Kentucky",
        ["Laddie"] = "IGUI_PetName_Laddie",
        ["Lady"] = "IGUI_PetName_Lady",
        ["Larry"] = "IGUI_PetName_Larry",
        ["Laser"] = "IGUI_PetName_Laser",
        ["Lavender"] = "IGUI_PetName_Lavender",
        ["Laz"] = "IGUI_PetName_Laz",
        ["Lester"] = "IGUI_PetName_Lester",
        ["Liberty"] = "IGUI_PetName_Liberty",
        ["Lily"] = "IGUI_PetName_Lily",
        ["Lincoln"] = "IGUI_PetName_Lincoln",
        ["Little Gray"] = "IGUI_PetName_LittleGray",
        ["Lord Puddington"] = "IGUI_PetName_Lord Puddington",
        ["Louis"] = "IGUI_PetName_Louis",
        ["Louise"] = "IGUI_PetName_Louise",
        ["Lovely"] = "IGUI_PetName_Lovely",
        ["Lucy"] = "IGUI_PetName_Lucy",
        ["Lulu"] = "IGUI_PetName_Lulu",
        ["Luna"] = "IGUI_PetName_Luna",
        ["Machete"] = "IGUI_PetName_Machete",
        ["Madame"] = "IGUI_PetName_Madame",
        ["Magnum"] = "IGUI_PetName_Magnum",
        ["Mango"] = "IGUI_PetName_Mango",
        ["Mantell"] = "IGUI_PetName_Mantell",
        ["Marge"] = "IGUI_PetName_Marge",
        ["Maria"] = "IGUI_PetName_Maria",
        ["Mauler"] = "IGUI_PetName_Mauler",
        ["Max"] = "IGUI_PetName_Max",
        ["Mayo"] = "IGUI_PetName_Mayo",
        ["Milkshake"] = "IGUI_PetName_Milkshake",
        ["Mister"] = "IGUI_PetName_Mister",
        ["Misty"] = "IGUI_PetName_Misty",
        ["Molly"] = "IGUI_PetName_Molly",
        ["Moon"] = "IGUI_PetName_Moon",
        ["Moss"] = "IGUI_PetName_Moss",
        ["Mr Waffles"] = "IGUI_PetName_Mr Waffles",
        ["Mr. Cheese"] = "IGUI_PetName_MrCheese",
        ["Muffin"] = "IGUI_PetName_Muffin",
        ["Nicki"] = "IGUI_PetName_Nicki",
        ["Niko"] = "IGUI_PetName_Niko",
        ["Nugget"] = "IGUI_PetName_Nugget",
        ["Odin"] = "IGUI_PetName_Odin",
        ["Orca"] = "IGUI_PetName_Orca",
        ["Orchid"] = "IGUI_PetName_Orchid",
        ["Oscar"] = "IGUI_PetName_Oscar",
        ["Pancake"] = "IGUI_PetName_Pancake",
        ["Pancho"] = "IGUI_PetName_Pancho",
        ["Patriot"] = "IGUI_PetName_Patriot",
        ["Pauly"] = "IGUI_PetName_Pauly",
        ["Penny"] = "IGUI_PetName_Penny",
        ["Pepper"] = "IGUI_PetName_Pepper",
        ["Pike"] = "IGUI_PetName_Pike",
        ["Pipsqueak"] = "IGUI_PetName_Pipsqueak",
        ["Pistol"] = "IGUI_PetName_Pistol",
        ["Plonkie"] = "IGUI_PetName_Plonkie",
        ["Pointer"] = "IGUI_PetName_Pointer",
        ["Polly"] = "IGUI_PetName_Polly",
        ["Poppy"] = "IGUI_PetName_Poppy",
        ["Primrose"] = "IGUI_PetName_Primrose",
        ["Prince"] = "IGUI_PetName_Prince",
        ["Princess"] = "IGUI_PetName_Princess",
        ["Pudding"] = "IGUI_PetName_Pudding",
        ["Pumpkin"] = "IGUI_PetName_Pumpkin",
        ["Puppers"] = "IGUI_PetName_Puppers",
        ["Rada"] = "IGUI_PetName_Rada",
        ["Rainbow"] = "IGUI_PetName_Rainbow",
        ["Ranger"] = "IGUI_PetName_Ranger",
        ["Raspberry"] = "IGUI_PetName_Raspberry",
        ["Revolver"] = "IGUI_PetName_Revolver",
        ["Rex"] = "IGUI_PetName_Rex",
        ["River"] = "IGUI_PetName_River",
        ["Rocky"] = "IGUI_PetName_Rocky",
        ["Rodney"] = "IGUI_PetName_Rodney",
        ["Roman"] = "IGUI_PetName_Roman",
        ["Romeo"] = "IGUI_PetName_Romeo",
        ["Roosevelt"] = "IGUI_PetName_Roosevelt",
        ["Rosemary"] = "IGUI_PetName_Rosemary",
        ["Rosie"] = "IGUI_PetName_Rosie",
        ["Rover"] = "IGUI_PetName_Rover",
        ["Roy"] = "IGUI_PetName_Roy",
        ["Rua"] = "IGUI_PetName_Rua",
        ["Ruby"] = "IGUI_PetName_Ruby",
        ["Ruca"] = "IGUI_PetName_Ruca",
        ["Sage"] = "IGUI_PetName_Sage",
        ["Sally"] = "IGUI_PetName_Sally",
        ["Sam"] = "IGUI_PetName_Sam",
        ["Sammy"] = "IGUI_PetName_Sammy",
        ["Sandy"] = "IGUI_PetName_Sandy",
        ["Santa"] = "IGUI_PetName_Santa",
        ["Scott"] = "IGUI_PetName_Scott",
        ["Scout"] = "IGUI_PetName_Scout",
        ["Shadow"] = "IGUI_PetName_Shadow",
        ["Shep"] = "IGUI_PetName_Shep",
        ["Sid"] = "IGUI_PetName_Sid",
        ["Silver"] = "IGUI_PetName_Silver",
        ["Siren"] = "IGUI_PetName_Siren",
        ["Sniper"] = "IGUI_PetName_Sniper",
        ["Snowie"] = "IGUI_PetName_Snowie",
        ["Soldier"] = "IGUI_PetName_Soldier",
        ["Sparky"] = "IGUI_PetName_Sparky",
        ["Spiffo"] = "IGUI_PetName_Spiffo",
        ["Spiral"] = "IGUI_PetName_Spiral",
        ["Spot"] = "IGUI_PetName_Spot",
        ["Squeak"] = "IGUI_PetName_Squeak",
        ["Strawberry"] = "IGUI_PetName_Strawberry",
        ["Sugar"] = "IGUI_PetName_Sugar",
        ["Sweetie"] = "IGUI_PetName_Sweetie",
        ["Tammy"] = "IGUI_PetName_Tammy",
        ["Ted"] = "IGUI_PetName_Ted",
        ["Teddy"] = "IGUI_PetName_Teddy",
        ["Terry"] = "IGUI_PetName_Terry",
        ["Thor"] = "IGUI_PetName_Thor",
        ["Tia"] = "IGUI_PetName_Tia",
        ["Tiger"] = "IGUI_PetName_Tiger",
        ["Tinkler"] = "IGUI_PetName_Tinkler",
        ["Toby"] = "IGUI_PetName_Toby",
        ["Toffee"] = "IGUI_PetName_Toffee",
        ["Tommy"] = "IGUI_PetName_Tommy",
        ["Trixie"] = "IGUI_PetName_Trixie",
        ["Twinkle"] = "IGUI_PetName_Twinkle",
        ["Vic"] = "IGUI_PetName_Vic",
        ["Violet"] = "IGUI_PetName_Violet",
        ["Wally"] = "IGUI_PetName_Wally",
        ["Washington"] = "IGUI_PetName_Washington",
        ["Waterfall"] = "IGUI_PetName_Waterfall",
        ["Whimbly"] = "IGUI_PetName_Whimbly",
        ["Whiskey"] = "IGUI_PetName_Whiskey",
        ["Willow"] = "IGUI_PetName_Willow",
        ["Woody"] = "IGUI_PetName_Woody",
        ["Yorkie"] = "IGUI_PetName_Yorkie",
        ["Zuko"] = "IGUI_PetName_Zuko",
    },
    LETTER = {
        ["Acceptance Letter"] = "IGUI_AcceptanceLetter",
        ["Application Letter"] = "IGUI_ApplicationLetter",
        ["Bank Letter"] = "IGUI_BankLetter",
        ["Bill"] = "IGUI_Bill",
        ["Business Letter"] = "IGUI_BusinessLetter",
        ["Charity Letter"] = "IGUI_CharityLetter",
        ["Child's Letter"] = "IGUI_ChildsLetter",
        ["Condolence Letter"] = "IGUI_CondolenceLetter",
        ["Employment Letter"] = "IGUI_EmploymentLetter",
        ["Friendly Letter"] = "IGUI_FriendlyLetter",
        ["Government Letter"] = "IGUI_GovernmentLetter",
        ["Invitation Letter"] = "IGUI_InvitationLetter",
        ["Legal Letter"] = "IGUI_LegalLetter",
        ["Letter"] = "IGUI_Letter",
        ["Official Letter"] = "IGUI_OfficialLetter",
        ["Overdue Bill"] = "IGUI_OverdueBill",
        ["Rejection Letter"] = "IGUI_RejectionLetter",
        ["Resignation Letter"] = "IGUI_ResignationLetter",
        ["Romantic Letter"] = "IGUI_RomanticLetter",
        ["Rude Letter"] = "IGUI_RudeLetter",
        ["Sad Letter"] = "IGUI_SadLetter",
        ["Scam Letter"] = "IGUI_ScamLetter",
        ["Thank You Letter"] = "IGUI_ThankYouLetter",
        ["Threatening Letter"] = "IGUI_ThreateningLetter",
    },
    BUSINESS = {
        ["Algol Electronics"] = "IGUI_AlgolElectronics",
        ["AmeriGlobe Inc."] = "IGUI_AmeriGlobeInc",
        ["American Tire"] = "IGUI_AmericanTire",
        ["Bank of Kentucky"] = "IGUI_BankofKentucky",
        ["Banshee-Holloway"] = "IGUI_BansheeHolloway",
        ["Beanz"] = "IGUI_Beanz",
        ["Bering Company"] = "IGUI_BeringCompany",
        ["Brucey Soups"] = "IGUI_BruceySoups",
        ["Busan Telecommunications"] = "IGUI_BusanTelecommunications",
        ["Butterfly Machinery"] = "IGUI_ButterflyMachinery",
        ["Chinese Petroleum"] = "IGUI_ChinesePetroleum",
        ["Chrysalis"] = "IGUI_Chrysalis",
        ["Cobber Metals"] = "IGUI_CobberMetals",
        ["Double Entry Accounting"] = "IGUI_DoubleEntryAccounting",
        ["Egenerex"] = "IGUI_Egenerex",
        ["Fellow's Inc."] = "IGUI_FellowsInc",
        ["Fibroil"] = "IGUI_Fibroil",
        ["Finnegan Group"] = "IGUI_FinneganGroup",
        ["Fossoil"] = "IGUI_Fossoil",
        ["Franklin Motors"] = "IGUI_FranklinMotors",
        ["FunXtreme Inc."] = "IGUI_FunXtremeInc",
        ["General Broadcast Corporation"] = "IGUI_GeneralBroadcastCorporation",
        ["GigaMart"] = "IGUI_GigaMart",
        ["Global Computer Solutions"] = "IGUI_GlobalComputerSolutions",
        ["Grennade Chemicals"] = "IGUI_GrennadeChemicals",
        ["Halloway & Framer"] = "IGUI_HallowayFramer",
        ["Havisham Hotels"] = "IGUI_HavishamHotels",
        ["Hawthorn Oil"] = "IGUI_HawthornOil",
        ["Herr Flick-Knives"] = "IGUI_HerrFlickKnives",
        ["Imekagi"] = "IGUI_Imekagi",
        ["Invisible Sledgehammer Corp"] = "IGUI_InvisibleSledgehammerCorp",
        ["Killian Foodstuffs"] = "IGUI_KillianFoodstuffs",
        ["Kirrus Inc."] = "IGUI_KirrusInc",
        ["Kitten Knives"] = "IGUI_KittenKnives",
        ["Loveheart Shipbuilding"] = "IGUI_LoveheartShipbuilding",
        ["Mass-Genfac Co."] = "IGUI_MassGenfacCo",
        ["McCoy Logging"] = "IGUI_McCoyLogging",
        ["Mmm! Inc."] = "IGUI_MmmInc",
        ["Newcastle Paper and Ink"] = "IGUI_NewcastlePaperandInk",
        ["Nikoda"] = "IGUI_Nikoda",
        ["Palm Travel"] = "IGUI_PalmTravel",
        ["Panther Motors"] = "IGUI_PantherMotors",
        ["Parasol Inc."] = "IGUI_ParasolInc",
        ["Perfick Potato Co."] = "IGUI_PerfickPotatoCo",
        ["Pharmahug"] = "IGUI_Pharmahug",
        ["PopCo"] = "IGUI_PopCo",
        ["Premium Technologies"] = "IGUI_PremiumTechnologies",
        ["Redmond 'N' Redmond"] = "IGUI_RedmondRedmond",
        ["Sanchez-Goldberg"] = "IGUI_SanchezGoldberg",
        ["Scitt & Wilker Firearms"] = "IGUI_ScittWilkerFirearms",
        ["Seahorse Coffee Corp"] = "IGUI_SeahorseCoffeeCorp",
        ["Specific Electric"] = "IGUI_SpecificElectric",
        ["Spiffo Corp"] = "IGUI_SpiffoCorp",
        ["Steely Revolve Metalworking"] = "IGUI_ReallyHardSteel",
        ["Swift-Thompson Aerospace"] = "IGUI_SwiftThompsonAerospace",
        ["T.I.S. Construction"] = "IGUI_TISConstruction",
        ["United Shipping Logistics"] = "IGUI_UnitedShippingLogistics",
        ["Valu-Insurance"] = "IGUI_ValuInsurance",
        ["ValuTech"] = "IGUI_ValuTech",
        ["Wirklichlangeswort AG"] = "IGUI_WirklichlangeswortAG",
        ["Wolfram Waffen"] = "IGUI_WolframWaffen",
        ["Yuri Design"] = "IGUI_YuriDesign",
        ["Zippee"] = "IGUI_Zippee",
    },
    JOB = {
        ["Accountant"] = "IGUI_Accountant",
        ["Actor"] = "IGUI_Actor",
        ["Alarm Installer"] = "IGUI_AlarmInstaller",
        ["Animal Expert"] = "IGUI_AnimalExpert",
        ["Architect"] = "IGUI_Architect",
        ["Artist"] = "IGUI_Artist",
        ["Babysitter"] = "IGUI_Babysitter",
        ["Barber"] = "IGUI_Barber",
        ["Bodyguard"] = "IGUI_Bodyguard",
        ["Builder"] = "IGUI_Builder",
        ["Business Card Maker"] = "IGUI_BusinessCardMaker",
        ["Business Consultant"] = "IGUI_BusinessConsultant",
        ["Business Owner"] = "IGUI_BusinessOwner",
        ["Butcher"] = "IGUI_Butcher",
        ["Car Salesperson"] = "IGUI_CarSalesperson",
        ["Carpenter"] = "IGUI_Carpenter",
        ["Cleaner"] = "IGUI_Cleaner",
        ["Clothing Designer"] = "IGUI_ClothingDesigner",
        ["Clown"] = "IGUI_Clown",
        ["Coder"] = "IGUI_Coder",
        ["Cook"] = "IGUI_Cook",
        ["Cult Deprogrammer"] = "IGUI_CultDeprogrammer",
        ["DIY"] = "IGUI_DIY",
        ["Dancer"] = "IGUI_Dancer",
        ["Dentist"] = "IGUI_Dentist",
        ["Dermatologist"] = "IGUI_Dermatologist",
        ["Dietician"] = "IGUI_Dietician",
        ["Doctor"] = "IGUI_Doctor",
        ["Drafter"] = "IGUI_Drafter",
        ["Driver"] = "IGUI_Driver",
        ["Dry Cleaner"] = "IGUI_DryCleaner",
        ["Efficiency Expert"] = "IGUI_EfficiencyExpert",
        ["Electrician"] = "IGUI_Electrician",
        ["Engineer"] = "IGUI_Engineer",
        ["Escort"] = "IGUI_Escort",
        ["Exorcist"] = "IGUI_Exorcist",
        ["Exotic Dancer"] = "IGUI_ExoticDancer",
        ["Exterminator"] = "IGUI_Exterminator",
        ["Factory Manager"] = "IGUI_FactoryManager",
        ["Fencer"] = "IGUI_Fencer",
        ["Film/TV Crew"] = "IGUI_Film/TVCrew",
        ["Financial Advisor"] = "IGUI_FinancialAdvisor",
        ["Fitness Instructor"] = "IGUI_FitnessInstructor",
        ["Floorer"] = "IGUI_Floorer",
        ["Fortune Teller"] = "IGUI_FortuneTeller",
        ["Framer"] = "IGUI_Framer",
        ["Gardener"] = "IGUI_Gardener",
        ["General Manager"] = "IGUI_GeneralManager",
        ["Graphic Designer"] = "IGUI_GraphicDesigner",
        ["Hairdresser"] = "IGUI_Hairdresser",
        ["Head Chef"] = "IGUI_HeadChef",
        ["Historian"] = "IGUI_Historian",
        ["Humorous Fake Occupation Name"] = "IGUI_HumorousFakeOccupationName",
        ["Hunter"] = "IGUI_Hunter",
        ["IT Technician"] = "IGUI_ITTechnician",
        ["Insurance Agent"] = "IGUI_InsuranceAgent",
        ["Intimate Disease Specialist"] = "IGUI_IntimateDiseaseSpecialist",
        ["Jack-of-all-Trades"] = "IGUI_JackofallTrades",
        ["Journalist"] = "IGUI_Journalist",
        ["Laborer"] = "IGUI_Laborer",
        ["Lawyer"] = "IGUI_Lawyer",
        ["Lecturer"] = "IGUI_Lecturer",
        ["Local History Expert"] = "IGUI_LocalHistoryExpert",
        ["Local Politician"] = "IGUI_LocalPolitician",
        ["Locksmith"] = "IGUI_Locksmith",
        ["Logger"] = "IGUI_Logger",
        ["Logistics Expert"] = "IGUI_LogisticsExpert",
        ["Machine Operator"] = "IGUI_MachineOperator",
        ["Make-up Artist"] = "IGUI_MakeupArtist",
        ["Masseuse"] = "IGUI_Masseuse",
        ["Mechanic"] = "IGUI_Mechanic",
        ["Metalworker"] = "IGUI_Metalworker",
        ["Midwife"] = "IGUI_Midwife",
        ["Nanny"] = "IGUI_Nanny",
        ["Nolan's Used Cars"] = "Print_Media_NolansUsedCars_title",
        ["Nurse"] = "IGUI_Nurse",
        ["Optician"] = "IGUI_Optician",
        ["Orthodontist"] = "IGUI_Orthodontist",
        ["Painter"] = "IGUI_Painter",
        ["Pediatrician"] = "IGUI_Pediatrician",
        ["Personal Trainer"] = "IGUI_PersonalTrainer",
        ["Pharmacist"] = "IGUI_Pharmacist",
        ["Photographer"] = "IGUI_Photographer",
        ["Physiotherapist"] = "IGUI_Physiotherapist",
        ["Pilot"] = "IGUI_Pilot",
        ["Plumber"] = "IGUI_Plumber",
        ["Private Investigator"] = "IGUI_PrivateInvestigator",
        ["Producer"] = "IGUI_Producer",
        ["Psychiatrist"] = "IGUI_Psychiatrist",
        ["Psychic"] = "IGUI_Psychic",
        ["Publisher"] = "IGUI_Publisher",
        ["Real Estate Agent"] = "IGUI_RealEstateAgent",
        ["Rehab"] = "IGUI_Rehab",
        ["Repairer"] = "IGUI_Repairman",
        ["Sailor"] = "IGUI_Sailor",
        ["Salesperson"] = "IGUI_Salesperson",
        ["Scientist"] = "IGUI_Scientist",
        ["Scrapyard Worker"] = "IGUI_ScrapyardWorker",
        ["Secretary"] = "IGUI_Secretary",
        ["Security Guard"] = "IGUI_SecurityGuard",
        ["Singer"] = "IGUI_Singer",
        ["Stock Market Expert"] = "IGUI_StockMarketExpert",
        ["Stonemason"] = "IGUI_Stonemason",
        ["Tailor"] = "IGUI_Tailor",
        ["Tax Expert"] = "IGUI_TaxExpert",
        ["Taxi Driver"] = "IGUI_TaxiDriver",
        ["Teacher"] = "IGUI_Teacher",
        ["Technician"] = "IGUI_Technician",
        ["Tour Guide"] = "IGUI_TourGuide",
        ["Travel Agent"] = "IGUI_TravelAgent",
        ["Tutor"] = "IGUI_Tutor",
        ["Undertaker"] = "IGUI_Undertaker",
        ["Veterinarian"] = "IGUI_Veterinarian",
        ["Welder"] = "IGUI_Welder",
        ["Window Fitter"] = "IGUI_WindowFitter",
        ["Writer"] = "IGUI_Writer",
    },
}
-- <AUTO-GEN:DYNAMIC_NAME_MAP END>

-- ============================================================
-- 物品類型集合（來源：42.19.0 generation/*.java 的 onCreate 掛載點）
-- ============================================================

local PHOTO_TYPE_SET = {
    ["Base.Photo"] = true,
    ["Base.Photo_Secret"] = true,
    ["Base.Photo_Racy"] = true,
    ["Base.Photo_VeryOld"] = true,
    ["Base.Doodle"] = true,
    ["Base.DoodleKids"] = true,
    ["Base.Postcard"] = true,
}

-- 名稱為 "{物品名}: {Print_Media 標題}" 的傳單類；其餘 Print_Media 文獻（新報紙）
-- 名稱直接等於 getText(literatureTitle)
local PRINT_WRAPPED_TYPE_SET = {
    ["Base.Brochure"] = true,
    ["Base.Flier"] = true,
    ["Base.Flier_Nolans"] = true,
}

-- "{物品名}: {隨機人名}"（IGUI_ItemWithDisplayName）——人名為語言中立隨機英文名
local NAMED_DESCRIPTOR_TYPE_SET = {
    ["Base.Ring_Left_MiddleFinger_Signet"] = true,
    ["Base.Ring_Left_RingFinger_Signet"] = true,
    ["Base.Ring_Right_MiddleFinger_Signet"] = true,
    ["Base.Ring_Right_RingFinger_Signet"] = true,
    ["Base.Badge"] = true,
    ["Base.BrassNameplate"] = true,
    ["Base.BusinessCard_Personal"] = true,
    ["Base.CreditCard"] = true,
    ["Base.CreditCard_Stolen"] = true,
    ["Base.IDcard"] = true,
    ["Base.IDcard_Stolen"] = true,
    ["Base.IDcard_Female"] = true,
    ["Base.IDcard_Male"] = true,
    ["Base.Necklace_DogTag"] = true,
    ["Base.Necklace_DogTag_Female"] = true,
    ["Base.Necklace_DogTag_Male"] = true,
    ["Base.Passport"] = true,
    ["Base.PressID"] = true,
    ["Base.SpeedingTicket"] = true,
}

local BUSINESS_CARD_TYPE_SET = {
    ["Base.BusinessCard"] = true,
    ["Base.BusinessCard_Nolans"] = true,
}

local LETTER_TYPE_SET = {
    ["Base.GenericMail"] = true,
    ["Base.LetterHandwritten"] = true,
}

-- Fishing.onCreateFish / Fish.lua 會烘焙 "{大小} {魚名}[ - Ncm]"
local FISH_TYPE_SET = {
    ["Base.AligatorGar"] = true,
    ["Base.BlackCrappie"] = true,
    ["Base.BlueCatfish"] = true,
    ["Base.Bluegill"] = true,
    ["Base.ChannelCatfish"] = true,
    ["Base.FlatheadCatfish"] = true,
    ["Base.FreshwaterDrum"] = true,
    ["Base.GreenSunfish"] = true,
    ["Base.LargemouthBass"] = true,
    ["Base.Muskellunge"] = true,
    ["Base.Paddlefish"] = true,
    ["Base.RedearSunfish"] = true,
    ["Base.Sauger"] = true,
    ["Base.SmallmouthBass"] = true,
    ["Base.SpottedBass"] = true,
    ["Base.StripedBass"] = true,
    ["Base.Walleye"] = true,
    ["Base.WhiteBass"] = true,
    ["Base.WhiteCrappie"] = true,
    ["Base.YellowPerch"] = true,
}

-- ============================================================
-- 命名格式（EN 值對應 42.19.0 vanilla EN/IG_UI.json，殘留名稱以這些格式解析）
-- ============================================================

local EN_FORMATS = {
    SnowGlobeOf = "%1 of %2",
    ItemWithDisplayName = "%1: %2",
    ItemWithDisplayNameNoQuote = "%1 (%2)",
    ItemWithDisplayNameAndJob = "%1: %2 (%3)",
    Newspaper_Name = "%1: %2",
    ScratchingTicketNameWinner = "%1 - Winner %2",
}

-- 雪花玻璃球舊版格式（CH 1.6.4 前為 "%1 的 %2"，已改 "%1 (%2)"；CN 現行仍為 "%1 的 %2"）
local LEGACY_SNOWGLOBE_FORMATS = { "%1 的 %2" }

-- 魚的大小字首（EN 值 → IGUI key；fixFish 會同時嘗試當前語言值）
local FISH_SIZE_EN_TO_KEY = {
    ["Small"] = "IGUI_Fish_Small",
    ["Medium"] = "IGUI_Fish_Medium",
    ["Big"] = "IGUI_Fish_Big",
}
local FISH_SIZE_KEYS = { "IGUI_Fish_Small", "IGUI_Fish_Medium", "IGUI_Fish_Big" }

-- Fishing.onCreateChum 烘焙的 EN 值（vanilla EN/UI.json UI_Chum_Blank）
local CHUM_EN_NAME = "Chum Base"

-- ============================================================
-- 共用工具
-- ============================================================

local function escapeLuaPattern(text)
    return (text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

-- key 存在且翻譯非空時回傳翻譯文字，否則 nil
local function translatedText(key)
    if not key or key == "" then return nil end
    local text
    if getTextOrNull then
        text = getTextOrNull(key)
    else
        text = getText(key)
    end
    if text and text ~= "" and text ~= key then return text end
    return nil
end

-- 取 key 的「原始格式字串」（%1/%2/%3 佔位符保留）。不可無參數呼叫 getText 解格式：
-- Translator 載入期把 %N 改寫成 %N$s（formatFixer），無參數呼叫含佔位符的 key
-- 每次都噴 "Missing arguments" 警告（42.20.2 reportMissingArgumentsFromPastAbuse，
-- 無狀態、逐次觸發），掛在 inventory 高頻重掃上就是警告洪水。比照 ItemNameFix
-- 的 keyRingSuffixLocal：帶哨兵參數讓官方自己格式化（成功路徑、零警告）再把
-- 哨兵換回 %N，免疫格式規格改寫。結果整場不變，memoize 每 key 只查一次
--（查無翻譯以 false 佔位，同樣只查一次）。
local RAW_S1, RAW_S2, RAW_S3 = "\1\2", "\1\3", "\1\4"
local rawFormatCache = {}
local function rawFormat(key)
    if not key or key == "" then return nil end
    local cached = rawFormatCache[key]
    if cached == nil then
        local text
        if getTextOrNull then
            text = getTextOrNull(key, RAW_S1, RAW_S2, RAW_S3)
        else
            text = getText(key, RAW_S1, RAW_S2, RAW_S3)
        end
        if text and text ~= "" and text ~= key then
            cached = text:gsub(RAW_S1, "%%1"):gsub(RAW_S2, "%%2"):gsub(RAW_S3, "%%3")
        else
            cached = false
        end
        rawFormatCache[key] = cached
    end
    return cached or nil
end

-- 把 "%1 of %2" 這類格式編成 Lua pattern：%1 代入錨點字面值，%2/%3 變成捕獲
local function buildCapturePattern(formatStr, anchor)
    local out = { "^" }
    local index = 1
    local length = #formatStr
    while index <= length do
        local startPos, endPos, token = formatStr:find("%%([123])", index)
        if not startPos then
            out[#out + 1] = escapeLuaPattern(formatStr:sub(index))
            break
        end
        if startPos > index then
            out[#out + 1] = escapeLuaPattern(formatStr:sub(index, startPos - 1))
        end
        if token == "1" then
            out[#out + 1] = escapeLuaPattern(anchor)
        else
            out[#out + 1] = "(.+)"
        end
        index = endPos + 1
    end
    out[#out + 1] = "$"
    return table.concat(out)
end

-- 以格式 + 錨點解析名稱，回傳 %2（與 %3）對應的捕獲
local function matchFormat(formatStr, anchor, name)
    if not formatStr or not anchor or anchor == "" or not name then return nil end
    return name:match(buildCapturePattern(formatStr, anchor))
end

-- 物品的當前語言基底名（取 script 定義的翻譯名，不取已烘焙的 item name）
local function getBaseDisplayName(item)
    local scriptItem = item and item:getScriptItem()
    local displayName = scriptItem and scriptItem:getDisplayName()
    if displayName and displayName ~= "" then return displayName end
    return nil
end

local function getEnglishItemName(item)
    local maps = DynamicItemNameFlx.MAPS
    local enNames = maps and maps.EN_ITEM_NAMES
    return enNames and enNames[item:getFullType()] or nil
end

-- 反查表查詢：先查 EN 反查表，再 lazy 建立「當前語言文字 → key」表
local lazyDomainMaps = {}

local function resolveDomainKey(domainName, text)
    if not text or text == "" then return nil end
    local maps = DynamicItemNameFlx.MAPS
    local domain = maps and maps[domainName]
    if not domain then return nil end
    if domain[text] then return domain[text] end

    local lazy = lazyDomainMaps[domainName]
    if not lazy then
        lazy = {}
        for _, key in pairs(domain) do
            local current = translatedText(key)
            if current then lazy[current] = key end
        end
        lazyDomainMaps[domainName] = lazy
    end
    return lazy[text]
end

local function getModDataString(item, field)
    local modData = item:getModData()
    local value = modData and modData[field]
    if type(value) == "string" and value ~= "" then return value end
    return nil
end

-- 對「{EN 格式 + EN 錨點}、{當前格式 + 當前錨點}、額外舊格式」依序解析名稱
local function matchKnownFormats(item, currentName, enFormat, formatKey, extraFormats)
    local enName = getEnglishItemName(item)
    local baseName = getBaseDisplayName(item)
    local currentFormat = formatKey and rawFormat(formatKey) or nil

    if enFormat and enName then
        local a, b = matchFormat(enFormat, enName, currentName)
        if a then return a, b end
    end
    if currentFormat and baseName then
        local a, b = matchFormat(currentFormat, baseName, currentName)
        if a then return a, b end
    end
    if extraFormats and baseName then
        for _, fmt in ipairs(extraFormats) do
            local a, b = matchFormat(fmt, baseName, currentName)
            if a then return a, b end
        end
    end
    -- 殘留名稱可能是「EN 格式 + EN 錨點」以外的混合（例如 EN 錨點 + 當前格式），
    -- 再交叉嘗試一次
    if currentFormat and enName then
        local a, b = matchFormat(currentFormat, enName, currentName)
        if a then return a, b end
    end
    if enFormat and baseName then
        local a, b = matchFormat(enFormat, baseName, currentName)
        if a then return a, b end
    end
    return nil
end

-- ============================================================
-- 各類修復器：回傳重建後名稱，解析不到回傳 nil
-- ============================================================

-- 照片 / 明信片 / 塗鴉：collectibleKey = IGUI_Photo_* 翻譯 key
local function fixPhotoLike(item, _currentName)
    local key = getModDataString(item, "collectibleKey")
    if not key or not key:find("^IGUI_") then
        local literatureTitle = getModDataString(item, "literatureTitle")
        key = literatureTitle and literatureTitle:match("^%w+_(IGUI_.+)_%d+$") or nil
    end
    if not key then return nil end
    local subject = translatedText(key)
    local baseName = getBaseDisplayName(item)
    if not subject or not baseName then return nil end
    return getText("IGUI_PhotoOf", baseName, subject)
end

-- 雪花玻璃球：collectibleKey 是烘焙文字，解析名稱取地名後反查 IGUI_Photo_*
local function fixSnowGlobe(item, currentName)
    local place = matchKnownFormats(item, currentName, EN_FORMATS.SnowGlobeOf, "IGUI_SnowGlobeOf", LEGACY_SNOWGLOBE_FORMATS)
    if not place then return nil end
    local key = resolveDomainKey("PLACE", place)
    local translatedPlace = key and translatedText(key)
    local baseName = getBaseDisplayName(item)
    if not translatedPlace or not baseName then return nil end
    return getText("IGUI_SnowGlobeOf", baseName, translatedPlace)
end

-- 墜飾：collectibleKey = "{type}_IGUI_Photo_*"
local function fixLocket(item, _currentName)
    local collectibleKey = getModDataString(item, "collectibleKey")
    if not collectibleKey then return nil end
    local key = collectibleKey:match("^" .. escapeLuaPattern(item:getType()) .. "_(IGUI_.+)$")
    local subject = key and translatedText(key)
    local baseName = getBaseDisplayName(item)
    if not subject or not baseName then return nil end
    return getText("IGUI_LocketText", baseName, subject)
end

-- 舊報紙：解析 "{物品名}: {報名}" 後反查 IGUI_NewspaperTitle_*
local function fixOldNewspaper(item, currentName)
    local title = matchKnownFormats(item, currentName, EN_FORMATS.Newspaper_Name, "IGUI_Newspaper_Name")
    if not title then return nil end
    local key = resolveDomainKey("NEWSPAPER_TITLE", title)
    local translatedTitle = key and translatedText(key)
    local baseName = getBaseDisplayName(item)
    if not translatedTitle or not baseName then return nil end
    return getText("IGUI_Newspaper_Name", baseName, translatedTitle)
end

-- 股票：解析 "{物品名} ({公司名})" 後反查公司 IGUI key
local function fixStockCertificate(item, currentName)
    local business = matchKnownFormats(item, currentName, EN_FORMATS.ItemWithDisplayNameNoQuote, "IGUI_ItemWithDisplayNameNoQuote")
    if not business then return nil end
    local key = resolveDomainKey("BUSINESS", business)
    local translatedBusiness = key and translatedText(key)
    local baseName = getBaseDisplayName(item)
    if not translatedBusiness or not baseName then return nil end
    return getText("IGUI_ItemWithDisplayNameNoQuote", baseName, translatedBusiness)
end

-- 寵物牌：解析 "{物品名}: {寵物名}" 後反查 IGUI_PetName_*
local function fixDogTagPet(item, currentName)
    local pet = matchKnownFormats(item, currentName, EN_FORMATS.ItemWithDisplayName, "IGUI_ItemWithDisplayName")
    if not pet then return nil end
    local key = resolveDomainKey("PETNAME", pet)
    local translatedPet = key and translatedText(key) or pet
    local baseName = getBaseDisplayName(item)
    if not baseName then return nil end
    return getText("IGUI_ItemWithDisplayName", baseName, translatedPet)
end

-- 證件 / 印章戒指："{物品名}: {人名}"——人名語言中立，僅翻譯前綴
local function fixNamedDescriptor(item, currentName)
    local personName = matchKnownFormats(item, currentName, EN_FORMATS.ItemWithDisplayName, "IGUI_ItemWithDisplayName")
    local baseName = getBaseDisplayName(item)
    if not personName or not baseName then return nil end
    return getText("IGUI_ItemWithDisplayName", baseName, personName)
end

-- 名片："{物品名}: {人名} ({職業})"——人名保留、職業反查
local function fixBusinessCard(item, currentName)
    local personName, job = matchKnownFormats(item, currentName, EN_FORMATS.ItemWithDisplayNameAndJob, "IGUI_ItemWithDisplayNameAndJob")
    if not personName or not job then return nil end
    local key = resolveDomainKey("JOB", job)
    local translatedJob = key and translatedText(key) or job
    local baseName = getBaseDisplayName(item)
    if not baseName then return nil end
    return getText("IGUI_ItemWithDisplayNameAndJob", baseName, personName, translatedJob)
end

-- 信件 / 郵件：名稱即 getText(信件 key) 整串，全名反查
local function fixLetter(item, currentName)
    local key = resolveDomainKey("LETTER", currentName)
    local translatedLetter = key and translatedText(key)
    if not translatedLetter then return nil end
    return translatedLetter
end

-- 中獎刮刮樂："{物品名} - Winner $N"——金額語言中立
local function fixScratchTicketWinner(item, currentName)
    local amount = currentName:match("%$%d+")
    local baseName = getBaseDisplayName(item)
    if not amount or not baseName then return nil end
    return getText("IGUI_ScratchingTicketNameWinner", baseName, amount)
end

-- 已刮開的刮刮樂（fullType 仍是 Base.ScratchTicket）：官方刮票 recipe 只 setName／
-- setTexture 不換型別（RecipeCodeOnCreate.scratchTicket），42.20.0 起 MP 改由 server 端
-- 組名再 sendReplaceItemInContainer 推送覆蓋，非中文伺服器產生「中文基底名 - Winner $N／
-- - Loser」混血烘焙名。判定依官方同函式寫入的 modData.scratched（fail-closed：無標記
-- 即未刮，不重組）。有金額＝中獎，無金額＝未中獎。
local function fixScratchedTicket(item, currentName)
    local modData = item:getModData()
    if not modData or modData.scratched ~= true then return nil end
    if currentName:find("%$%d") then
        return fixScratchTicketWinner(item, currentName)
    end
    local baseName = getBaseDisplayName(item)
    if not baseName then return nil end
    return getText("IGUI_ScratchingTicketNameLoser", baseName)
end

-- 魚："{大小} {魚名} " 或 "{大小} {魚名} - Ncm"
local function fixFish(item, currentName)
    local baseName = getBaseDisplayName(item)
    local enName = getEnglishItemName(item)
    if not baseName then return nil end

    for _, sizeKey in ipairs(FISH_SIZE_KEYS) do
        local sizeTexts = {}
        for enSize, key in pairs(FISH_SIZE_EN_TO_KEY) do
            if key == sizeKey then sizeTexts[#sizeTexts + 1] = enSize end
        end
        local currentSize = translatedText(sizeKey)
        if currentSize then sizeTexts[#sizeTexts + 1] = currentSize end

        for _, sizeText in ipairs(sizeTexts) do
            local prefix = sizeText .. " "
            if currentName:sub(1, #prefix) == prefix then
                local rest = currentName:sub(#prefix + 1)
                local fishPart, lengthPart = rest:match("^(.-)%s*%-%s*(%d+%.?%d*)cm$")
                local suffix
                if fishPart then
                    suffix = " - " .. lengthPart .. "cm"
                else
                    fishPart = rest:match("^(.-)%s*$")
                    suffix = " "
                end
                if fishPart == enName or fishPart == baseName then
                    local translatedSize = translatedText(sizeKey)
                    if translatedSize then
                        return translatedSize .. " " .. baseName .. suffix
                    end
                end
            end
        end
    end
    return nil
end

-- 魚餌底料：名稱整串為 UI_Chum_Blank
local function fixChum(_item, currentName)
    if currentName ~= CHUM_EN_NAME then return nil end
    local translatedChum = translatedText("UI_Chum_Blank")
    return translatedChum
end

-- 文獻通用修復：依 literatureTitle 形態重建（書籍/漫畫/雜誌/新報紙/傳單/型錄/手冊）
local function fixLiteratureByModData(item, currentName)
    local literatureTitle = getModDataString(item, "literatureTitle")
    if not literatureTitle then return nil end
    local baseName = getBaseDisplayName(item)
    if not baseName then return nil end

    -- 新報紙 / 傳單：literatureTitle = "Print_Media_*_title"
    if literatureTitle:find("^Print_Media_") and literatureTitle:find("_title$") then
        local title = translatedText(literatureTitle)
        if not title then return nil end
        if PRINT_WRAPPED_TYPE_SET[item:getFullType()] then
            return getText("IGUI_Newspaper_Name", baseName, title)
        end
        return title
    end

    -- 漫畫：literatureTitle = "IGUI_ComicTitle_*" 或 "IGUI_ComicTitle_*#N"
    if literatureTitle:find("^IGUI_ComicTitle_") then
        local key, issueNumber = literatureTitle:match("^(IGUI_ComicTitle_[^#]+)#(%d+)$")
        if not key then key = literatureTitle end
        local title = translatedText(key)
        if not title then return nil end
        if not issueNumber then
            return getText("IGUI_MagazineNameNoIssue", baseName, title)
        end
        -- 期數標記沿用現名（保留 Java 端補零寬度），取不到再用未補零期數
        local issueToken = currentName and currentName:match("(#%d+)%s*$") or ("#" .. issueNumber)
        return getText("IGUI_MagazineName", baseName, title, issueToken)
    end

    -- 書籍：literatureTitle = "IGUI_BookTitle_*"
    if literatureTitle:find("^IGUI_BookTitle_") then
        local title = translatedText(literatureTitle)
        if not title then return nil end
        return getText("IGUI_MagazineNameNoIssue", baseName, title)
    end

    -- 雜誌：literatureTitle = "{IGUI_MagazineTitle_*|HottieZ|HunkZ|TVMagazine}_{月}_{年}"
    local magazineType, month, year = literatureTitle:match("^(.+)_(%d+)_(%d+)$")
    if magazineType then
        local titleText
        if magazineType == "HunkZ" then
            titleText = translatedText("IGUI_MagazineTitle_HunkZ")
        elseif magazineType == "HottieZ" or magazineType == "TVMagazine" then
            titleText = baseName
        elseif magazineType:find("^IGUI_MagazineTitle_") then
            titleText = translatedText(magazineType)
        end
        local monthNumber = tonumber(month)
        if titleText and monthNumber and monthNumber >= 1 and monthNumber <= 12 then
            local monthName = translatedText("Sandbox_StartMonth_option" .. monthNumber)
            if monthName then
                return getText("IGUI_MagazineName", titleText, monthName, year)
            end
        end
        -- 落到這裡代表不是雜誌樣式，繼續嘗試其他形態
    end

    -- 型錄 / RPG 手冊：literatureTitle = "{type}_IGUI_*"
    local typedKey = literatureTitle:match("^" .. escapeLuaPattern(item:getType()) .. "_(IGUI_.+)$")
    if typedKey then
        local title = translatedText(typedKey)
        if not title then return nil end
        return getText("IGUI_MagazineNameNoIssue", baseName, title)
    end

    return nil
end

-- ============================================================
-- 分派
-- ============================================================

local function computeFixedName(item)
    local currentName = item:getName()
    if not currentName or currentName == "" then return nil end

    local fullType = item:getFullType()

    if PHOTO_TYPE_SET[fullType] then return fixPhotoLike(item, currentName) end
    if fullType == "Base.SnowGlobe" then return fixSnowGlobe(item, currentName) end
    if fullType == "Base.Locket" then return fixLocket(item, currentName) end
    if fullType == "Base.Newspaper" then return fixOldNewspaper(item, currentName) end
    if fullType == "Base.StockCertificate" then return fixStockCertificate(item, currentName) end
    if fullType == "Base.DogTag_Pet" then return fixDogTagPet(item, currentName) end
    if NAMED_DESCRIPTOR_TYPE_SET[fullType] then return fixNamedDescriptor(item, currentName) end
    if BUSINESS_CARD_TYPE_SET[fullType] then return fixBusinessCard(item, currentName) end
    if LETTER_TYPE_SET[fullType] then return fixLetter(item, currentName) end
    if fullType == "Base.ScratchTicket_Winner" then return fixScratchTicketWinner(item, currentName) end
    if fullType == "Base.ScratchTicket" then return fixScratchedTicket(item, currentName) end
    if FISH_TYPE_SET[fullType] then return fixFish(item, currentName) end
    if fullType == "Base.Chum" then return fixChum(item, currentName) end

    if instanceof and instanceof(item, "Literature") then
        return fixLiteratureByModData(item, currentName)
    end
    return nil
end

DynamicItemNameFlx.computeFixedName = computeFixedName

local function fixItemName(item)
    if not item then return 0 end
    local ok, newName = pcall(computeFixedName, item)
    if not ok or not newName or newName == "" then return 0 end
    local currentName = item:getName()
    if not currentName or newName == currentName then return 0 end
    item:setName(newName)
    return 1
end

DynamicItemNameFlx.fixItemName = fixItemName

-- ============================================================
-- 事件掛載（與 RecipeLiterature_Flx / AnimalProductName_Flx 同構）
-- ============================================================

local function shouldRunClientRepair()
    return not (isServer() and not isClient())
end

local function fixContainer(container)
    if not container or not instanceof(container, "ItemContainer") then return 0 end

    local stack = { container }
    local fixed = 0
    while #stack > 0 do
        local currentContainer = table.remove(stack)
        local items = currentContainer and currentContainer:getItems()
        if items then
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                fixed = fixed + fixItemName(item)

                if item and item:IsInventoryContainer() then
                    local childContainer = item:getInventory()
                    if childContainer then
                        table.insert(stack, childContainer)
                    end
                end
            end
        end
    end
    return fixed
end

local function fixPlayerItems(playerObj)
    if not playerObj then return 0 end
    return fixContainer(playerObj:getInventory())
end

local function fixInventoryPage(page)
    local pane = page and page.inventoryPane
    return fixContainer(pane and pane.inventory)
end

local function fixOpenInventoryPages()
    if not getPlayerInventory or not getPlayerLoot then return 0 end

    local fixed = 0
    for playerIndex = 0, 3 do
        if getSpecificPlayer(playerIndex) then
            fixed = fixed + fixInventoryPage(getPlayerInventory(playerIndex))
            fixed = fixed + fixInventoryPage(getPlayerLoot(playerIndex))
        end
    end
    return fixed
end

local function getPrimaryPlayer()
    return getSpecificPlayer(0) or getPlayer()
end

local function onCreatePlayer(_playerIndex, playerObj)
    if not shouldRunClientRepair() then return end
    fixPlayerItems(playerObj)
end
Events.OnCreatePlayer.Add(onCreatePlayer)

local function onGameStart()
    if not shouldRunClientRepair() then return end

    local fixed = fixPlayerItems(getPrimaryPlayer())
    if fixed > 0 then
        print(TAG .. " [DynamicItemName] Fixed persisted dynamic item names: " .. tostring(fixed))
    end
end
Events.OnGameStart.Add(onGameStart)

local function onFillContainer(_roomName, _containerType, container)
    if not shouldRunClientRepair() then return end
    fixContainer(container)
end
Events.OnFillContainer.Add(onFillContainer)

local function onContainerUpdate()
    if not shouldRunClientRepair() then return end
    fixOpenInventoryPages()
end
Events.OnContainerUpdate.Add(onContainerUpdate)

local function onRefreshInventoryWindowContainers(_page, state)
    if state ~= "end" or not shouldRunClientRepair() then return end
    fixOpenInventoryPages()
end
Events.OnRefreshInventoryWindowContainers.Add(onRefreshInventoryWindowContainers)

local function onEveryOneMinute()
    if not shouldRunClientRepair() then return end
    fixPlayerItems(getPrimaryPlayer())
    fixOpenInventoryPages()
end
Events.EveryOneMinute.Add(onEveryOneMinute)
