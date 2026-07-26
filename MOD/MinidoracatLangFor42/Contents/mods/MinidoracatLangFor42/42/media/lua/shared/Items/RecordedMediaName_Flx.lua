-- RecordedMediaName_Flx.lua
-- 修復 VHS/CD 媒體物品在 media index 失效後名稱永久保留生成端英文的問題。
--
-- 42.19 的 InventoryItem.load() 對 index 有效的媒體物品，本來就會以載入端
-- 當下翻譯重刷名稱（load → setRecordedMediaIndex → getTranslatedItemDisplayName），
-- 該情境不需要也不該由本檔處理。真正會永久卡英文的是 load 時
-- getMediaDataFromIndex 解析失敗的物品：index 被重設為 -1、存檔舊名保留、
-- getMediaData() 為 nil（媒體功能一併失效）。本檔仿 VehicleKey_Flx 的
-- 英文名反查表模式處理這類物品：
--   * SP（單機，含分割畫面）：setRecordedMediaData() 重新連結媒體資料
--     （恢復播放功能，名稱由 Java 以現行翻譯重寫）
--   * MP client（含 co-op host 的遊戲進程）：僅 setName() 作顯示層遷移
-- 反查表由 scripts/sync_translations.py gen-media-map 自動產生；
-- PZ 版本更新後重跑該命令再生。
-- 環境分支實況：重連結僅發生於單機 SP（含分割畫面，isClient()==false）；
-- co-op host 的遊戲進程是 MP client（isClient()==true），與一般 client 同走
-- 顯示層改名；dedicated server 進程被 shouldRunClientRepair 排除。
-- ponytail: 名稱帶任何 getName() 前綴（磨損/破損/血跡等 IGUI_ClothingNaming
-- 包裝）的卡英文磁帶不會被精確比對命中，屬已知覆蓋缺口（僅漏修、不誤傷）；
-- 若實際回報再加前綴剝離。isCustomName 旗標經 save flag 64 序列化、跨存檔
-- 持久，自訂名防線可靠。

local TAG = "[CatLangFor42]"

RecordedMediaNameFlx = RecordedMediaNameFlx or {}

-- ============================================
-- 自動產生區塊：英文媒體物品名 → {RM key, media guid} 反查表
-- ============================================
-- <AUTO-GEN:MEDIA_NAME_MAP START>
-- 由 scripts/sync_translations.py gen-media-map 自動產生，請勿手動編輯
-- 來源：vanilla recorded_media.lua + EN/Recorded_Media.json（共 352 條）
RecordedMediaNameFlx = RecordedMediaNameFlx or {}
RecordedMediaNameFlx.EN_TO_MEDIA = {
    ["CD: A Boy from Kentucky"] = { key = "RM_47f7ee00-e726-4321-821f-20b0301cd879", id = "7c8a1990-f45c-49eb-ac3b-e5332fefb5d1" },
    ["CD: A Truck Full of Love"] = { key = "RM_4b030747-c500-43f3-ae85-0b5b5bf44c70", id = "01424d67-7587-47d4-8f0e-bdbf7df48510" },
    ["CD: Bartleby, the Scrivener - Audio Book"] = { key = "RM_6c0ec758-7b90-4ae2-bc6f-aa908f82f33e", id = "6d1dd169-6942-4055-8e30-c38a7a7bb4e8" },
    ["CD: Berlin nach Stuttgart"] = { key = "RM_157aa532-54bb-49af-b0b1-9d8253ebcca2", id = "b6355549-6cad-454d-a29b-03882c44e1dd" },
    ["CD: Best of the Bojangles"] = { key = "RM_e4d02aae-dfe8-42d1-aaa5-8e814d8be32b", id = "c0a6fc65-9aae-4abc-b8dc-dcc20c94847c" },
    ["CD: Bible Readings - Genesis"] = { key = "RM_d7ca5c7f-4fff-4be7-ab1e-57cdc630a4c7", id = "87844aba-b48f-43e8-b3b6-d8d041179138" },
    ["CD: Bible Readings - Revelation"] = { key = "RM_d8392ba2-f11c-4885-96f2-f0d673d2e16d", id = "0607ad40-fa78-4e00-8bfc-b0bd2f62e554" },
    ["CD: Bible Readings - Sermon on the Mount"] = { key = "RM_ca29a3bb-8ca9-4279-8cfc-24746306d43b", id = "09cfd631-b1a0-426c-aa55-2a25f67c761c" },
    ["CD: Bible Readings - The Crucifixion"] = { key = "RM_5829d27a-cab3-41d9-a052-df2369ef094e", id = "d8a54f2b-3288-473b-b570-29441d2d62dc" },
    ["CD: Bible Readings - Tower of Babel"] = { key = "RM_74d8e6da-4d36-4e07-968a-060a3f37bb75", id = "6fed2f1b-d9c5-4120-9f54-7134c3b6ffdb" },
    ["CD: Buck's Plum Outta Luck"] = { key = "RM_619059f5-d13a-4f9b-9aa4-18fe846928d5", id = "f26f41b1-eca0-4d68-97e5-0b38a82a1c42" },
    ["CD: Can of Tomatoes"] = { key = "RM_3afe0acf-1813-488b-ae62-fff6c685799b", id = "1f452ba8-52b0-4150-8890-541127fe5fee" },
    ["CD: Carmina Burana"] = { key = "RM_4afaa407-53fe-4db1-a2bb-ba6aed3cc369", id = "8c12c79d-08f6-44a8-9848-5f3913a370a2" },
    ["CD: Collected Yeats - Audio Book"] = { key = "RM_ddc020f1-f3ed-43b6-9a2d-599305d2c0a1", id = "2aba6585-8eba-47fc-8069-34ad9fd595e9" },
    ["CD: Constant Worship"] = { key = "RM_0e7a682a-f328-430e-8f24-49dfdd9b40ce", id = "598421e1-4c61-4310-94e1-b2ecd0b6bea3" },
    ["CD: Constant Worship - Vol 2"] = { key = "RM_6e4f763a-6aa1-42c1-adfe-cc7b0ff99cd3", id = "504ed5e2-f901-422e-b810-c338d983f1e1" },
    ["CD: Cries of the Damned"] = { key = "RM_62d24526-859f-4609-ad41-95c723ce287f", id = "8dfedf9e-3322-4ddf-bed0-e11e5e77ee7e" },
    ["CD: Down the Road"] = { key = "RM_8e071953-8bd3-4817-9634-3d97c0d821d4", id = "13d6ca10-6a8d-4222-b3d6-e1ce37199394" },
    ["CD: Dying Strike Official Soundtrack"] = { key = "RM_38b844c0-9b7c-46a8-b81a-0df56bd107a0", id = "8e86efde-b60f-43f3-81d1-23454a526ffe" },
    ["CD: Eurodance '92"] = { key = "RM_83a36065-93aa-4529-800f-eaae83c24aed", id = "c3b9fd54-f013-48b9-ac55-1b4a11efa340" },
    ["CD: Freddy's Big Balloon"] = { key = "RM_84c6b585-63bf-4d89-8d1e-b6a28ae22360", id = "6cf66309-e56f-42e3-9178-595a41555143" },
    ["CD: Fright Night"] = { key = "RM_2706bfd3-3bec-49d7-aab6-930a6d2c9ef0", id = "7053a51c-d55e-43a6-bffa-52536d7fda16" },
    ["CD: Get Funky!"] = { key = "RM_2d25a80f-a08e-4028-b5c1-8265f10d7502", id = "34ba6ab4-915f-4903-a9f8-aec78611c226" },
    ["CD: Get Your Feet Wet"] = { key = "RM_cb5d6349-bf8d-4849-85bd-288d98427d5f", id = "69e6e2d6-51db-4f05-bcda-59d8fb82010a" },
    ["CD: Got Me Thinkin'"] = { key = "RM_ff839931-0617-4088-85d2-2a4e98209dc8", id = "7ac03fdf-560e-4496-8de4-53903404c0f2" },
    ["CD: Heading for the Heat"] = { key = "RM_06c3e9f3-23c7-4b5f-8635-3d4f2021021f", id = "cee92348-75a3-404c-b0e6-7124f7346e22" },
    ["CD: Hell Has Opened"] = { key = "RM_9ff782b0-1402-4e7e-8d08-ba20fc57acd6", id = "1fadc63a-ff45-4da3-82bd-a842a45cb446" },
    ["CD: Hidden"] = { key = "RM_9132763a-3fff-4fb0-bf1d-dd4b144f2165", id = "5764c415-d689-41c5-9fbd-da320c352af7" },
    ["CD: I Need You More"] = { key = "RM_29bb9ff2-a598-4d61-81d0-4b74cabb2365", id = "4edd74be-d4ff-403a-aab8-4484744580a6" },
    ["CD: I Swear"] = { key = "RM_aaa8f476-93d6-4eb6-b91d-7aa794c4c377", id = "21d0cf8f-d5a4-4efb-ab23-0d5265d9a679" },
    ["CD: I'll Look After You"] = { key = "RM_cecf9899-df0b-47f4-a5b5-7cce224204ff", id = "b3e9c731-c5dc-4c9b-b87a-939b4e99f2c2" },
    ["CD: Jane Eyre - Audio Book"] = { key = "RM_c5faa8d5-b947-482a-ae00-a99a949d6cc0", id = "279c63c0-1499-451b-9369-12d517e718fc" },
    ["CD: Let's Make Love"] = { key = "RM_b068ad7f-0ba1-486b-87e0-ccc42ad30f13", id = "7c17de42-23e6-4100-a4bb-64941b782480" },
    ["CD: Loretta"] = { key = "RM_1614e9ba-4b35-4e57-bc3b-cacddfe11feb", id = "e08ca516-30b5-4584-a6be-c975869e6f79" },
    ["CD: Meditation Now!"] = { key = "RM_a908545b-e7e7-4ce1-8459-45147bc06fa7", id = "6597509e-d8e7-4b21-9eec-c008436cb09b" },
    ["CD: Moments in American History - Day of Infamy"] = { key = "RM_f08e5a5d-e9cf-4c1e-bc57-a05e581f2efb", id = "a0c98d75-decb-4aab-9d91-c29f20d0ba2b" },
    ["CD: Moments in American History - Gettysburg Address"] = { key = "RM_b6a79bcc-daf1-49ee-933b-79b4e3f8e2f3", id = "d069e31c-a1ad-4f05-8363-4c4d978ad207" },
    ["CD: Moments in American History - The Constitution"] = { key = "RM_14bd9852-2d4b-4b52-9abe-6161f4503185", id = "c214d739-ffef-492d-be6d-96511100c437" },
    ["CD: Moments in American History - The Moon Landing"] = { key = "RM_23b5ef62-35e4-4369-957a-4a6f9e11ccc3", id = "86f5f6a0-7d09-490e-8f04-c23adfdc6c50" },
    ["CD: Moments in American History - Watergate"] = { key = "RM_a739708d-23a2-4b52-bbad-7d0e8fd1154e", id = "881a12c2-ef70-4a10-8732-cad03393a315" },
    ["CD: Moon Madness"] = { key = "RM_ff967067-5af8-4689-baf1-d80d41f7bd66", id = "d93fca54-eb8f-45d2-bfd5-f3c92a7e91e7" },
    ["CD: Mother Earth"] = { key = "RM_64975a8b-b13f-4585-a1e9-b155b808dccc", id = "e721ba21-b725-4ae5-8a73-99cf138bf76d" },
    ["CD: My Boy Asked Me..."] = { key = "RM_35896838-a039-4788-89ba-7391caa327e1", id = "ec7fd24e-be0c-4198-ab32-484c35442398" },
    ["CD: Our Love Goes On"] = { key = "RM_7c7de31d-a074-4c06-a53d-ebf4ff30e4bb", id = "732847fd-53aa-4d17-9d5e-dcd6756e200d" },
    ["CD: Over"] = { key = "RM_4c48f74e-ee55-41b3-930a-2e05fd52c868", id = "c654d451-19bc-4135-85d7-96a5c455a75a" },
    ["CD: Philosophical Quotes - Aristotle"] = { key = "RM_72143ae1-8871-4180-b138-8dbc9867c3ba", id = "b8c1d37d-ffe9-4794-8059-3d8bbd59d369" },
    ["CD: Philosophical Quotes - Confucius"] = { key = "RM_bcdb725f-80f7-4442-ba29-5fc896d21b08", id = "4bea3e0c-b8c6-4477-b8e1-c10e4f40ca56" },
    ["CD: Philosophical Quotes - Machiavelli"] = { key = "RM_063a7be6-db4e-4ae7-8f2e-8720a6fa5f87", id = "9831f1dc-dacf-4f73-9a53-be0236b5f073" },
    ["CD: Philosophical Quotes - Rumi"] = { key = "RM_831ad499-cb3d-47dc-b046-f29dc6fb7252", id = "37fc2a5f-b309-426d-85d2-c161cffc45f9" },
    ["CD: Philosophical Quotes - The Art of War"] = { key = "RM_a510682f-397b-4c82-9fa8-c732aef81b49", id = "14755483-faeb-488a-86e1-3cef433b1de2" },
    ["CD: Philosophical Quotes - The Buddha"] = { key = "RM_1bb94e7f-15a1-46cf-8200-a7d098e416b2", id = "bddec6d5-fb00-4aba-aa66-5c3fa4011ae9" },
    ["CD: Pride and Prejudice - Audio Book"] = { key = "RM_60d8e8af-91f6-41b9-9692-fabc3de3127d", id = "2000971d-6dd0-4a40-a02c-b16b465a0986" },
    ["CD: Raps for Christ"] = { key = "RM_7ad5a50e-c8cc-4c5c-98b1-ad64d2bfefc4", id = "5b80fd14-9667-4bbf-b466-b9b160c195e3" },
    ["CD: Reasons for War"] = { key = "RM_4d17859f-ffc1-4510-8eee-5de7a1d55d3e", id = "a7daa3b8-81c0-4b6b-82e2-a0229c6860f9" },
    ["CD: Robinson Crusoe - Audio Book"] = { key = "RM_24d4c30e-3c96-4f9b-935f-f3be7fdd4628", id = "49329116-0be0-437a-975e-f11028afa0ab" },
    ["CD: Rock Gods"] = { key = "RM_8d94bfa6-0cf1-454d-a348-1253de3824f5", id = "fcb1279d-3a42-4be4-b104-d03679af5480" },
    ["CD: Rosewood Prison"] = { key = "RM_860656e4-11f9-47ca-9538-f6e5ab116cb5", id = "1c93b0d3-e8fc-4e74-817c-7e97a8e43b3b" },
    ["CD: Running on Fumes"] = { key = "RM_d67cc360-7a20-4838-90a6-ec48b70e0e83", id = "1e75a2c7-2d95-4399-a3f8-74e7561ccce3" },
    ["CD: Sarcastic"] = { key = "RM_176074c2-e080-4b8b-a367-351978c7fbed", id = "7f455072-e0ca-4486-8b21-b426cf2957bb" },
    ["CD: The Depth of Your Love"] = { key = "RM_7452ab76-0608-40d4-88ba-7f4eba297b76", id = "c7ff45aa-14f2-4335-b08e-5ed9bfda83bb" },
    ["CD: The Metamorphosis - Audio Book"] = { key = "RM_3f6bf4c7-0c36-41f1-96ed-8ef41aaf06a9", id = "e1164c65-4d03-4112-b6be-866af2700963" },
    ["CD: Time for Love"] = { key = "RM_bc48aa8c-2cf0-447a-ae85-7e969af96f54", id = "b8d9e7aa-2a07-4d05-80b8-a4ec3d24b652" },
    ["CD: Uncle Billy's Kentucky Moonshine"] = { key = "RM_9d547f20-5bd4-4ec3-983f-b1bce3b99345", id = "e3e2d8d9-25a7-4428-87ea-79ea69502fea" },
    ["CD: Walden - Audio Book"] = { key = "RM_6f6e9136-d177-425f-bf23-d5eef9797493", id = "a8abf964-1598-43a8-874a-3c10148e8b16" },
    ["CD: Where is Everybody?"] = { key = "RM_5c37377e-13ee-4ca5-a8e5-ec545152d8c1", id = "e9353f2a-3976-4485-96bc-8c758f5fc56f" },
    ["CD: Who's Better?"] = { key = "RM_99ce7104-4234-4376-a09d-e3b80d75afe2", id = "b7b8d081-f2a4-4529-b551-53c739cd5219" },
    ["CD: You Love Me Too"] = { key = "RM_d64a8423-df49-484b-828e-2c06e76b48b2", id = "226a3c97-cb71-4cb9-9621-260973b3c67e" },
    ["CD: You're Gone"] = { key = "RM_4fc658ae-3063-4ba0-b571-d9c5a5e7e1cd", id = "4ec05fe5-a783-4c82-9dd8-147be943d662" },
    ["CD: Your Smile. Your Kiss."] = { key = "RM_d088ff63-6c0d-43b0-bcd6-b023967a1b1a", id = "89108e07-fc70-4eec-a267-790d6f4b9831" },
    ["Home VHS: #012"] = { key = "RM_6caee2a4-766c-4c1c-b6c9-25dd71a68320", id = "6bf936ee-53d7-47b7-b3a7-c3ea0b88d44b" },
    ["Home VHS: 8th Birthday"] = { key = "RM_738784ad-f6b4-4047-9a9b-a335795eed41", id = "ae29b686-4d07-48d4-b67e-7fdc842c287a" },
    ["Home VHS: ARRA Pitch"] = { key = "RM_960d7953-ffe4-4f67-9f64-9ec80e8051ce", id = "dc19ba88-190a-43d0-9788-442bc2fad653" },
    ["Home VHS: Alaskan Gulf Documentary"] = { key = "RM_3b34884f-9ffb-4775-80b2-94f726677f87", id = "991bce00-11e3-4152-ad22-32660217c8cc" },
    ["Home VHS: Alva Richards (Ashling Dwyer)"] = { key = "RM_e812d9aa-c5e9-4931-b41b-8c1cd13f2b9e", id = "d0ee8b5a-4e37-4952-9e7b-58db9436ef9a" },
    ["Home VHS: Alva Richards (Pierce Daniels)"] = { key = "RM_440ed4de-04c6-4d74-ab44-0e95b5044354", id = "ff18eec0-59c4-43ce-92c4-4349bd4dee63" },
    ["Home VHS: Baby Summer!"] = { key = "RM_502a55d5-a64f-4cb6-8683-83ab27ec5a0e", id = "37912243-f832-4a64-99cb-71ac909ded01" },
    ["Home VHS: Basic Gun Handling (Officer Use Only)"] = { key = "RM_49e5614b-76d9-48fa-9e23-47a6d67f7736", id = "f33ce778-8d37-4fba-889d-d736434aad22" },
    ["Home VHS: Bauman and Triskel (Pleistocene Land)"] = { key = "RM_dd3e30ea-16bf-4c12-8880-e2698b10efe0", id = "c5678180-fa6f-429e-90c8-39cfacb7f0ba" },
    ["Home VHS: Bauman and Triskel April 15"] = { key = "RM_3ba7ddbd-33c0-4584-be4d-8068bf4df1d5", id = "a5d4c1aa-647c-4eeb-8a97-222d6182cfc0" },
    ["Home VHS: Bauman and Triskel April 8"] = { key = "RM_2031e4d0-7829-401b-a675-c6e480629b36", id = "50d79409-cfe5-4ced-8e5a-2eec36aef61c" },
    ["Home VHS: Bauman/Triskel 14"] = { key = "RM_f4521aef-eeb6-4793-8de1-e4f47c850c25", id = "348f5cea-ac75-4fb9-a3c4-c504dc0d8df5" },
    ["Home VHS: Black Holes space doc"] = { key = "RM_697b45bd-3164-4180-a660-fa7aa32df2e8", id = "47c6a97e-2ca0-4614-b3b6-1403a59ab42d" },
    ["Home VHS: Brent's 21st"] = { key = "RM_38069b57-0c6f-42f5-a12e-43d7906f1413", id = "05b31204-ed9f-4fee-b181-070c85f6dd18" },
    ["Home VHS: Brushing Your Teeth with Zachary Bunny"] = { key = "RM_151e0c15-fd2a-4d5f-9bce-79d63a8b790c", id = "0fd06ed7-6757-4ae9-b4b7-6ef8316a5c4b" },
    ["Home VHS: CAPE CANAVERAL VACATION July 1990"] = { key = "RM_f60e31f2-dfb3-410b-bc60-45b6a42b1c2d", id = "6cdf2185-d266-4e3f-918f-a1c6e87b0e27" },
    ["Home VHS: CCCW"] = { key = "RM_dcba9231-f02e-41b5-8de5-ce5bb2829bcf", id = "f7da5304-8466-402a-937d-21c92f411811" },
    ["Home VHS: Caring For Your Employees"] = { key = "RM_6cd6a455-f58b-4755-9010-5efa4abc03fa", id = "1f906205-c751-4157-add7-dd79e6b1f823" },
    ["Home VHS: Christmas Eve Visit!"] = { key = "RM_6b2c429c-3275-40b1-bcd5-69e4f9057c27", id = "aae2426f-fff8-49fa-a271-7c3a0d443b17" },
    ["Home VHS: Cities of the World - Lagos"] = { key = "RM_945354da-b77a-4320-b3e5-c649bb8f5ca4", id = "c8a61e36-af9e-4643-b5d7-9e21ddb4f158" },
    ["Home VHS: Cities of the World - Paris"] = { key = "RM_1bac94db-cba0-4002-a89f-1d95007aec3b", id = "78e173e7-021a-46cc-b02f-47bd52595522" },
    ["Home VHS: Cities of the World - Seoul"] = { key = "RM_27d91f3d-b189-4012-8cd2-e4c39f169723", id = "53c1d840-a65b-4472-ae21-e6055cb73dbc" },
    ["Home VHS: Combat Wound Management"] = { key = "RM_fa55f437-59c8-4277-aca1-56114f1ec7f6", id = "8c150873-8bd1-4316-ae3f-a37742ccfa20" },
    ["Home VHS: D&M's Wedding"] = { key = "RM_1217b4a8-5159-426f-975f-89882b7d4068", id = "983acfd3-0ee6-48a8-82fc-aa25a34b5c20" },
    ["Home VHS: DAD'S TAPE DO NOT TOUCH"] = { key = "RM_0f17684d-961f-48dc-9440-af3952e670bd", id = "109373b7-1720-4d95-acd7-062da3f61d2b" },
    ["Home VHS: Dad's boring golf crap"] = { key = "RM_9bf15245-58f1-412b-85ea-35477972e92a", id = "71c5af9d-2d25-4ce7-b2c6-df29b59932d5" },
    ["Home VHS: Dad's shows"] = { key = "RM_dc4587d6-db95-4d57-9b0e-53835cc7211a", id = "3ce70040-2776-4403-9f16-759cf1ce86d9" },
    ["Home VHS: Dangerous Strangers with Jemima Bunny"] = { key = "RM_75946557-e6fe-479a-9ef7-2618a4c6bfb2", id = "538cdb4f-b2ec-4eb0-ab73-b0fc65b70114" },
    ["Home VHS: Dating Agency (Female)"] = { key = "RM_127ddfe6-948e-4a3e-98a4-972c27150f18", id = "1fd47a18-db73-473e-8f80-8379db58b297" },
    ["Home VHS: Dating Agency (Male)"] = { key = "RM_319ab191-4672-4fc6-9a52-cfc198592d7b", id = "c80427f6-3671-4915-929c-7f98a0391f03" },
    ["Home VHS: Dental Care"] = { key = "RM_772e2a9b-6d82-4421-9641-311facf09b63", id = "768e8dd5-99cf-40e0-b832-6f24e5baa771" },
    ["Home VHS: ELIJAH 1ST BDAY"] = { key = "RM_fd094795-ebdf-41bd-8ea9-7b7d9de854f5", id = "5de29f96-9d01-4422-9f61-f999f5816e4b" },
    ["Home VHS: English Cup (4.12.91)"] = { key = "RM_8a320159-085b-4cdc-8c15-741718a5e7da", id = "a8c4eccf-53d9-42ad-8091-b9e562621c8f" },
    ["Home VHS: Every Reason Tape!!"] = { key = "RM_df1cf97b-99ec-4bb8-a1a9-3706bbba082f", id = "e502be90-8631-43d4-9ebd-d28f9401484c" },
    ["Home VHS: FLORIDA VACATION June 1991"] = { key = "RM_874190b7-e4b5-4436-9a7c-6879908e37e9", id = "a3151ce8-1470-41af-81e8-a14a90345b80" },
    ["Home VHS: Fairweather-Mahoney 2/11/93"] = { key = "RM_881319d6-a0f1-420d-bce4-d27657e98abb", id = "2dd905ad-a3e0-4d4e-80a9-91717ad6d75a" },
    ["Home VHS: Final Regards"] = { key = "RM_3b1fe7cd-d9dd-4b10-950d-c22aa146c424", id = "8f0ee6af-7365-4104-bd0d-380d8617980c" },
    ["Home VHS: Flight Training #6"] = { key = "RM_2f8af24c-bfe1-443d-8851-bf6aea9067ce", id = "a3c8a7a1-220b-448e-9225-e98b9a0da1eb" },
    ["Home VHS: For Scott"] = { key = "RM_9b86805a-21a1-4274-8d02-009c2827628f", id = "40d70c31-55a6-4a51-9957-611a190ecead" },
    ["Home VHS: Fort Knox Documentary"] = { key = "RM_38e131c0-ab24-4cd5-bc1c-3112d69de01a", id = "21b95697-6235-4b8a-a1d9-a9ddc0cd1154" },
    ["Home VHS: Gabby first steps"] = { key = "RM_e3b94757-cdea-42c0-a88e-fd3c7c8c79a1", id = "70b48d90-55fc-49f0-99e8-b7f7746d011c" },
    ["Home VHS: Gators doc"] = { key = "RM_c705a9eb-4fdb-4ed8-aa48-1ca5be57e7be", id = "43ac5750-24fc-483b-9458-ed8dd7f0e8cb" },
    ["Home VHS: Golf #14"] = { key = "RM_8cf66b17-9b30-4b24-931b-693e468f451d", id = "ec1c89d4-8b80-4cc6-af2e-e7ee6e029e34" },
    ["Home VHS: Grady v King"] = { key = "RM_d4ca9606-1f35-4e52-bf2a-2e72893120c6", id = "541b5fff-7f01-402a-8e8a-98cfd0c90916" },
    ["Home VHS: Grampa Message"] = { key = "RM_f0544dfe-45c3-4fe3-a924-d2499d22d84e", id = "fa4b520c-dbe3-49da-a543-154d06e32f66" },
    ["Home VHS: Grandma's 80th"] = { key = "RM_173ce186-fed8-4820-bc27-093f80dd62ec", id = "d9c2da55-e946-42ff-82d5-5c65b5c4271e" },
    ["Home VHS: Granny Nani"] = { key = "RM_5929b5c4-1c65-4797-81b3-7963a55769c6", id = "00a8b565-a566-44f3-b6d2-7a1ae2eafb0c" },
    ["Home VHS: HOLLYWOOD INSIDER SPECIAL"] = { key = "RM_b6afcaa9-8411-44b4-8d92-968c6545bc32", id = "ba9a65a7-c471-436d-a2cd-3ceb75af6bca" },
    ["Home VHS: Hair Dyeing at Home"] = { key = "RM_a0956bd4-19a4-42f8-83e8-007e81c006b9", id = "0b26734a-f962-4539-8dda-3822b759173d" },
    ["Home VHS: Hao First Words!"] = { key = "RM_6e6fd7ca-ff6c-4e2a-a1ae-37fbde817d9c", id = "5c60fc4b-8e0f-40c0-8292-da9265414402" },
    ["Home VHS: Hurricanes v. Mothballs 4/22/91"] = { key = "RM_050c7d3b-38e6-46d5-95fa-99d3da6cfd57", id = "59d7200f-6907-4416-8249-0bc6b1bdef84" },
    ["Home VHS: IRELAND VACATION 1989"] = { key = "RM_42976bc0-9efd-415f-9ac2-a20c4b97961f", id = "deed9448-1498-43ce-ba7d-dcf12a8ccfbb" },
    ["Home VHS: J 13th birthday"] = { key = "RM_371cad1a-de29-438b-97d5-f88d99f2a778", id = "5c8893b0-9be3-4a42-8b11-9eb847e37bad" },
    ["Home VHS: Janie's tape"] = { key = "RM_b80ca700-190e-4078-a541-efdb369c3bc2", id = "d64b9df2-f069-4f0c-9891-02fc13715e88" },
    ["Home VHS: Jeff/Kaylee Vegas Wedding"] = { key = "RM_b0b2cee5-dd66-4308-b5be-691063911e15", id = "192752a2-bf3f-4dba-b2e7-6fbb9e27fa79" },
    ["Home VHS: Jenn's 18th"] = { key = "RM_92faa24a-e6b8-400e-a9ea-6ca17e154f6e", id = "b50eed6f-f12d-465e-bbd5-1fd88d6bb8f8" },
    ["Home VHS: Joni-Jim Proposal vid!!"] = { key = "RM_7d0ba4cd-5e54-4850-b32d-dbaafddcc5d7", id = "ca8cb8d3-c126-41a7-bb66-292c617205cd" },
    ["Home VHS: KNCF"] = { key = "RM_4cc3cbfa-a340-47e4-b9b4-ab858bf1a93a", id = "f0ba882b-cda2-4003-873e-078e757acd56" },
    ["Home VHS: Kafka Animated - A Message from the Emperor"] = { key = "RM_d78ace77-5c5c-4ae9-9fbd-0b0b5c374d56", id = "4dabc4a1-9013-455f-a60f-f592ddab4818" },
    ["Home VHS: Keith's Big Birthday!"] = { key = "RM_7c2545ba-049a-4ac1-bbb1-2c44d6f5f77c", id = "2b918617-dd19-42c4-8955-808f57fe5891" },
    ["Home VHS: Kentucky Furlongs (5.2.92)"] = { key = "RM_e839dfee-4b27-41ce-9f7c-bb9aef05c4f7", id = "78f8be75-5819-4edb-a7a5-a953537da19a" },
    ["Home VHS: Kid shows"] = { key = "RM_4deb372c-d949-4ae8-bdcf-3b349ebc77b1", id = "00cf0d94-726c-49c9-9e09-55012b581d49" },
    ["Home VHS: LARRY'S RAP DEMO (PRACTICE)"] = { key = "RM_99812051-e7e7-4605-82f4-02f4f5399d94", id = "f7c3cb91-4e4f-4bb6-aaed-c17ab4ae3e97" },
    ["Home VHS: Little Jackson's 4th Bday"] = { key = "RM_a008c5e7-adbe-4b72-a1b8-d6c534a47268", id = "415f5cf6-fef1-495a-ad50-fb9b7773d178" },
    ["Home VHS: Lopez-Grady fight"] = { key = "RM_91c85f67-2d24-4684-988d-89d21e956cd0", id = "2655efff-166a-4bec-914f-893860760eb9" },
    ["Home VHS: MOM'S TAPE"] = { key = "RM_3afd60e7-ea3e-4959-98b1-7b57bcf5eb4c", id = "60238f85-cf09-4f82-9324-2394c2422c94" },
    ["Home VHS: Magical Woodland Fox"] = { key = "RM_509e7fc1-d03d-4910-9ef9-ebf1a21253b3", id = "2d94b3c1-1860-4406-859c-ab2b5fcb64e2" },
    ["Home VHS: Mathematical Quadratics and Algebraic Configurations"] = { key = "RM_1c903cce-7cf5-41f2-98d4-7c3dc8b0027d", id = "68785929-d79c-4170-9fc8-5289bbf05388" },
    ["Home VHS: Moderators"] = { key = "RM_7bd6bc8d-3c8b-4ebd-b411-a4e921744378", id = "70339435-c441-4518-8040-b6e47ed58e77" },
    ["Home VHS: Mothballs v. Honey Bears 2.16.91"] = { key = "RM_c00ef9ac-f2dc-468d-a028-0f3c8248a6f9", id = "1dc05702-0af2-4087-b120-02376b3e39ad" },
    ["Home VHS: Muhammet's First Words"] = { key = "RM_ffaec6ef-d197-4eee-bddf-541f4f2fdaa7", id = "f37bdc33-7ac0-497b-be9b-82a5a330dbdb" },
    ["Home VHS: Muldraugh AV Club"] = { key = "RM_00755b75-b252-4ed8-8882-a90019dd8030", id = "ffe28381-b743-4300-8c5a-89b4c4983d05" },
    ["Home VHS: New kitties!"] = { key = "RM_b2cb1a08-f3ee-47e3-82d8-9f3a2475f118", id = "89e6d4e0-5b21-44f6-a884-2cebed3937bf" },
    ["Home VHS: OSCC '92"] = { key = "RM_fc675719-0322-4705-af1a-524ca714e3a0", id = "1559a55a-bfc9-4cfc-967b-e26b860894c6" },
    ["Home VHS: Ohio River"] = { key = "RM_81e28e67-64c1-4b69-8202-9e1b9aea56bf", id = "67c1dc61-ea6b-4369-8762-15d74f70b934" },
    ["Home VHS: Omega Department - DO NOT TAPE OVER"] = { key = "RM_e2783c78-96da-4197-8f45-04dc4e9785fd", id = "d84ea32b-e666-470f-91fb-0b4c70a06665" },
    ["Home VHS: Omega Department S3 E2"] = { key = "RM_1204d0ff-27b5-4f98-a0d5-4a77a0bb2f3f", id = "9796fc1d-5602-4413-9a9a-846f3a4b00f1" },
    ["Home VHS: Omega Department ghost town"] = { key = "RM_57f9e46a-7f7b-45be-8fea-2554718e2723", id = "42229010-855b-40a6-b9a0-be9d0f02925f" },
    ["Home VHS: One Eighty (darts)"] = { key = "RM_4f26d07e-907e-43d8-a3d8-20efa9bc2612", id = "75f556df-888a-4fad-9524-c7351a65ec5b" },
    ["Home VHS: Ooh, Shut That Door! S7E5"] = { key = "RM_4e176590-8416-4f06-a6f0-eb51aaec5f0c", id = "47058bd4-a7ff-4472-ad00-93972d18ea5b" },
    ["Home VHS: Our Wedding 19.1.88"] = { key = "RM_55563ce0-92e5-49cf-9761-36565fc9df57", id = "d620fd0a-d70c-43e5-9017-d7617b642fd0" },
    ["Home VHS: Playing with Bruce"] = { key = "RM_21dd813c-bd40-4318-984d-ddf1e730a602", id = "9401186f-f19c-452d-a753-819c58c0d529" },
    ["Home VHS: Preparing a Funeral (What Really Happens)"] = { key = "RM_3df75a26-3289-410b-a913-9a956ffe9181", id = "e502259c-f1ea-418c-b407-0e52849a6110" },
    ["Home VHS: QUIZ SHOWS"] = { key = "RM_f1870b4d-54e0-4f56-a302-f11883c55a35", id = "879430cc-34e5-452f-b905-42a9b40e66b7" },
    ["Home VHS: Quentin's 16th"] = { key = "RM_f540e928-a9fc-4fad-9800-511f2b49179a", id = "9dd008c0-ed51-411b-a3e5-c3b10bd4ff66" },
    ["Home VHS: RMFA"] = { key = "RM_d51d8130-1b4a-4154-9c19-c519a3165c98", id = "14fca23a-86ca-44b3-8342-264791175421" },
    ["Home VHS: Rangers v. Honey Bears 5.8.92"] = { key = "RM_3ed92f1e-0528-4e34-a612-c808aabc50dc", id = "cfe80cda-e58c-4129-9732-421b8f5317a3" },
    ["Home VHS: Rangers v. Hurricanes 8.12.92"] = { key = "RM_428354b7-724a-450b-ad97-a781847cd241", id = "6c75473d-2de5-4438-a17d-5a9ca4cc6da7" },
    ["Home VHS: Rangers v. Mothballs 12.8.90"] = { key = "RM_306e4aeb-3464-4127-b232-257c2d074ae4", id = "da6d1396-0e8d-4587-ac01-6343bd408706" },
    ["Home VHS: Reverend Quigley"] = { key = "RM_bbbdf73d-447d-432a-beb0-4ae928ab5f95", id = "47d28904-d6d0-47a5-81b9-3c2cb819cc9a" },
    ["Home VHS: Riverside Classic '92"] = { key = "RM_cf82ecde-a418-464b-bcfb-e09b874a4b26", id = "83134f2e-d17c-4dac-80ed-db9487327614" },
    ["Home VHS: Riverside vs West Point footie"] = { key = "RM_e7b0ff5e-b3ae-4bbe-b8f9-a8f9e73a1a16", id = "e4afaa47-795e-4124-9cf4-770a8045e6dd" },
    ["Home VHS: Roger's VHS"] = { key = "RM_e48e4e48-2b89-408b-9a58-9b508c21d36a", id = "9354e364-698c-428c-a7ea-b38de6bf61fb" },
    ["Home VHS: ST 4"] = { key = "RM_f3e3f4b9-3e52-43a8-9838-901b241b724e", id = "cda6e1e8-92ba-4f46-a500-b3b32180c3bf" },
    ["Home VHS: Sandy Perry"] = { key = "RM_8695c1c3-1956-424e-b75c-beaeb02520e1", id = "8cb5271e-368a-4676-bfc2-64687167f1a1" },
    ["Home VHS: School recital"] = { key = "RM_6e98bb27-f65d-4039-9408-9e90ff34a659", id = "872b1ecd-60fa-4994-b770-0020c2ddba54" },
    ["Home VHS: Secrets of Spiffo's Special Sauce"] = { key = "RM_a3ec6fe4-a219-4244-8a60-1074f5a51a24", id = "fad2c5af-1968-43d5-aa35-ab8fa6555f22" },
    ["Home VHS: Shows"] = { key = "RM_7db264e3-146a-4d7e-b734-3a89357cb31e", id = "ec6b7830-297c-486d-a0e9-1a48ece936c1" },
    ["Home VHS: Soaps Tape"] = { key = "RM_592ef549-cf74-4f89-8fdd-7d5c6085074b", id = "27d9ab7b-ab9a-464a-b392-ca0e451fa7d8" },
    ["Home VHS: Spiffo World June 1992"] = { key = "RM_731eb09e-1f08-498c-bd2f-87b1a6788b8e", id = "a3167c3e-6f13-4b2a-8414-8eb4d4201556" },
    ["Home VHS: Sunday Night Late 12/20/92"] = { key = "RM_c7a212c6-7e90-403f-a0e9-4b1c58976f76", id = "7694cea7-b7dd-4c55-a1fb-7ec03c6223c0" },
    ["Home VHS: Sunset Drive"] = { key = "RM_5fde86b9-858f-42ed-87b1-26a71d8efa21", id = "626e33bb-7fab-4c22-a803-14027f36e916" },
    ["Home VHS: TDTOE"] = { key = "RM_8461f86c-0b9d-4db0-b0e7-90681929acef", id = "f2906e97-2690-47e3-a44b-0a33c8438240" },
    ["Home VHS: TV repair"] = { key = "RM_7662d4e3-6899-4a05-aa1b-d6b6463b30fd", id = "c23539e8-c5eb-4f58-850f-18522250c470" },
    ["Home VHS: Tailoring 101"] = { key = "RM_9e8595e6-bb55-40da-a11b-fcd33012e302", id = "af941537-39ac-42fb-8c7a-ed346ded282e" },
    ["Home VHS: Tempest"] = { key = "RM_b3f1e728-167c-4142-9075-f2e149db9a78", id = "24e06bf8-5bd5-417e-8727-13f26da706c5" },
    ["Home VHS: The Signs of Satanism"] = { key = "RM_b38ece86-2649-4f4d-b0c3-55383b891d4f", id = "7feb80e4-48f6-4ec6-8e17-844c9107695c" },
    ["Home VHS: Tracy & Polly 8th Bday (Cute!)"] = { key = "RM_b89b9b3e-afa0-49d9-9876-ce4e01d1bbef", id = "c915eb17-87d3-416a-9906-9228eae1aa92" },
    ["Home VHS: Tree Planting Guide"] = { key = "RM_25539628-fba8-4f1c-8ae8-e86eaa7975c5", id = "db7deaf2-ddbe-42c8-8fd3-9725d8fdeff3" },
    ["Home VHS: Trends in Commodities"] = { key = "RM_ff91d226-1aa7-4feb-aad6-9a14b40d0020", id = "a5b3ba72-99ab-4813-8dcb-aa269d2e8f84" },
    ["Home VHS: Up with the Joneses"] = { key = "RM_80d7bbd6-bfbb-457a-bbe7-f91dbedd440a", id = "c7b841fa-89dd-453d-a3f2-e0846a230a70" },
    ["Home VHS: Washington High DO NOT TOUCH"] = { key = "RM_f6b49d28-78e8-42d8-95e8-ac6e7beed853", id = "c1d3824b-0e65-4315-90ba-6b8faa4f823f" },
    ["Home VHS: Wedding video!!!!"] = { key = "RM_33887d75-b833-4430-be8a-a37f6aeb7773", id = "a97a0024-144f-4c24-b414-cf77f3d49159" },
    ["Home VHS: Will/Ana Wedding"] = { key = "RM_f732623e-1c59-4205-b411-385b3323fa7c", id = "dee45fa2-71a0-44fc-8696-6d325237f4fd" },
    ["Home VHS: XYZ's with Abe E. Seez!"] = { key = "RM_1b43e117-8c20-4fe0-aadf-7c5883642d14", id = "2b27a1eb-c3e3-42ad-9da5-a077789ca019" },
    ["Home VHS: Xmas '91"] = { key = "RM_2a452e57-bef2-4b05-9f84-b8f62929a7ac", id = "afb8c0f4-884a-4ef7-8321-d518242dbea1" },
    ["Home VHS: Xmas Play"] = { key = "RM_7deb22b5-105b-4bb1-be7b-c39b3ca04562", id = "8903add4-d1a8-4be8-a5f3-c96b2467b6c3" },
    ["Home VHS: beach summer 91"] = { key = "RM_c8bd962b-9cc2-4161-a07a-2f2dfdfba90a", id = "33ecc070-9725-4459-9f14-1e0d609dd59b" },
    ["Home VHS: conspiracy crap???"] = { key = "RM_dd968007-6a08-41b3-8055-45d5932180c6", id = "2221f0f4-4937-4c35-81b3-6267c8b47bcf" },
    ["Home VHS: foxes doc"] = { key = "RM_66cdd6f9-2e4a-49b1-a987-be647013378b", id = "0b953c0d-04cc-4dda-b3c1-5317ff899bec" },
    ["Home VHS: horse race"] = { key = "RM_9574ab21-2b35-4d84-9d2a-ce59962e1979", id = "afa6734b-6fc8-443d-806e-2e21d6feb860" },
    ["Home VHS: molly june 30"] = { key = "RM_842709ef-4323-4bfb-9e3d-831d71396057", id = "a0d8bbf2-50ae-4e9e-b314-abd8214d8182" },
    ["Home VHS: moocows"] = { key = "RM_ce0412c6-a0b8-4f13-a582-70e47e688cb2", id = "18a00063-b838-4aaa-8991-7acc16554a08" },
    ["Home VHS: muldraugh v west point soccer"] = { key = "RM_b4af00c6-6964-4ede-81a9-35ddce491000", id = "88bbe9fa-dc06-4891-beb4-de538bbdee3e" },
    ["Home VHS: no 9"] = { key = "RM_e0b3e6f9-df90-4f92-943b-87b8827a3d86", id = "fe4ede3c-a153-4e46-aebe-9681d14fe196" },
    ["Home VHS: nof vid"] = { key = "RM_22bc8229-f470-4158-8743-81f92b6deccc", id = "1c6745f6-70b8-49e8-9087-b1bbb9263985" },
    ["Home VHS: our world #9"] = { key = "RM_dc86a46b-0669-4c26-832e-abca85bb12d8", id = "2f44d58f-f8dc-498f-9890-cf1eeb1bbd62" },
    ["Home VHS: stock cars"] = { key = "RM_0ef25267-ebdc-4a9f-9d70-8e57ea391dfb", id = "8904b5c7-86f6-4b49-a163-cf37d4421895" },
    ["VHS: A Day on the Farm"] = { key = "RM_ae2d9265-69d8-45a0-b077-5d5486dbc225", id = "fa0cd1c6-3846-4652-8be6-bb1f8c2b176c" },
    ["VHS: A Stitch in Time"] = { key = "RM_23a5a9b2-a5d6-42c3-8022-e7f356d26d20", id = "066ed71a-1803-4143-8151-3d6461a19e79" },
    ["VHS: Ace Pilot"] = { key = "RM_37779b42-4de8-4dd6-b49f-6fb820a39232", id = "037fc8e4-9cac-4817-a4ae-4972c405b68c" },
    ["VHS: Adefope Fencing Special"] = { key = "RM_5d6e7512-d8ec-4c97-beeb-d16944976eba", id = "89d33c66-7071-4b82-859f-2062bfe8db19" },
    ["VHS: Albert Wellen QC S2.01"] = { key = "RM_f369383a-ebf1-49bd-8b5f-b8d8c6f3c2b7", id = "d8779c82-0cff-423d-944f-16c4f468a556" },
    ["VHS: Albert Wellen QC S2.02"] = { key = "RM_84bd1196-e7b0-4324-ab58-47520d39bde1", id = "4467d917-1e90-4901-8531-e148f1fc40c7" },
    ["VHS: Albert Wellen QC S2.03"] = { key = "RM_8cfb9911-3545-4507-b8e4-c07e2dec491b", id = "23c075cf-bd66-4bfd-9b6f-b94e4a063055" },
    ["VHS: Albert Wellen QC S2.04"] = { key = "RM_2f4543d1-1cbd-48e8-b589-73c7ed427a0e", id = "ce2d2ae4-b097-49ac-952e-f34fd18d6d86" },
    ["VHS: Albert Wellen QC S2.05"] = { key = "RM_742b5ec0-d481-4bdd-ae78-24d0f6cc9122", id = "53015c80-6096-4c1c-adef-e6da20db518e" },
    ["VHS: All Over Again"] = { key = "RM_602b3c06-31b5-4061-8028-9b5d82e4304b", id = "d46ebbd8-2eb1-48c5-b18c-71d61febd36c" },
    ["VHS: Ballincoolin S1.01"] = { key = "RM_cc91f6b3-d71c-455a-834c-a955d0e1aeb7", id = "f3e24301-7b24-4daf-ab00-e9502d8dfb22" },
    ["VHS: Ballincoolin S1.02"] = { key = "RM_3be3b991-ac24-4737-8cd6-8ae151a1f088", id = "1a5d1e8a-67a0-4526-a216-92641fe98009" },
    ["VHS: Ballincoolin S1.03"] = { key = "RM_c0f066f6-fa69-4b13-828a-35c2a05f5203", id = "b2575483-a742-46b3-939a-6f3690ecb8a0" },
    ["VHS: Ballincoolin S1.04"] = { key = "RM_3c25fa09-2394-415f-99a1-329403e5dc97", id = "0ee453da-77c9-4ce3-a0c8-2d9d981be645" },
    ["VHS: Ballincoolin S1.05"] = { key = "RM_beacd1dd-a48c-4b4f-832a-ad51620555e0", id = "8812702d-9d7e-46e3-a8d7-3a580b5fb107" },
    ["VHS: Better Fishing With Jason Master"] = { key = "RM_4adc559b-4265-496d-b3dc-83f84d2cc3a1", id = "c7d905cf-3fe7-44e6-89a9-5d501bc73944" },
    ["VHS: Blood in the Hood"] = { key = "RM_198c2769-f047-498e-b065-169309dcb613", id = "53c7fa63-ec5d-40de-8875-a0f474ef49a6" },
    ["VHS: Breaking Points"] = { key = "RM_d1f4ceb4-9189-4a5b-8a18-57bbb30a1e67", id = "929a2ae1-a7f1-4fe5-9b4e-7779a4483091" },
    ["VHS: Carzone E1"] = { key = "RM_0d184031-e8ad-430f-804e-0e1456beddd3", id = "07b0cd73-7563-4699-9fb4-99316a0fc0bd" },
    ["VHS: Carzone E2"] = { key = "RM_7ad44eea-b249-4f7f-af50-37c224c4c0ea", id = "7b192b30-ea36-4395-a5e4-ac2d825d3b91" },
    ["VHS: Carzone E3"] = { key = "RM_5db54a52-03f8-4832-aff2-dbd94f7f49c4", id = "313fa630-d448-44ab-b1f0-7cff1d1db830" },
    ["VHS: Combat Wound Management"] = { key = "RM_add97be9-fcd5-4970-92ca-cd1f3b3fa4cf", id = "4653d39e-2fcf-49c2-9b51-0ab992fa123c" },
    ["VHS: Controlling Nasty Crop Pests and Diseases"] = { key = "RM_32996011-3abf-4f95-ae32-2d66752e73fa", id = "4cd4e3d3-c7ad-4848-875d-dd86d946bd45" },
    ["VHS: Cosa Nostra"] = { key = "RM_68708156-443b-4a18-b825-0b6a1492bb99", id = "05f702e8-3c94-4cb4-a93e-b07f88bb5b17" },
    ["VHS: CyberKiller 2"] = { key = "RM_7dd0f9ca-16ad-4a92-add3-1f271101609a", id = "d7715bdb-f363-47cb-8c04-6a156906fcfc" },
    ["VHS: Dark Agent"] = { key = "RM_562697c8-9b01-4c26-b5c7-d1820a30e95a", id = "9a18b23e-e597-449e-adbd-81dacae59b93" },
    ["VHS: Dead Wrong"] = { key = "RM_5db5be4f-5035-40c2-8333-30b398a7fe3f", id = "31a726b7-0ee6-408b-8599-95c80aa8a6c5" },
    ["VHS: Dead Wrong S2.01"] = { key = "RM_a5f20ba8-358d-4343-87c8-6e10d9ead1c4", id = "932853dc-0a71-4671-bf48-c5bfd126f367" },
    ["VHS: Dead Wrong S2.02"] = { key = "RM_8325e8b1-81b2-4a90-96e4-5f1c7ad4f669", id = "8b07e425-fe72-44b5-8635-db6ab6128bb7" },
    ["VHS: Dead Wrong S2.03"] = { key = "RM_94e2230f-0a39-4ea0-be80-1ce9caccac04", id = "145c607e-0358-4a20-8d6b-49278af92272" },
    ["VHS: Dead Wrong S2.04"] = { key = "RM_ced75718-ca65-4f5d-a6d2-31982ea125d5", id = "38cc7ba3-a100-475d-83a3-9c17525c1dd7" },
    ["VHS: Dead Wrong S2.05"] = { key = "RM_88d9a134-9eba-40f1-96eb-d811f9dc22e7", id = "26d31e43-e3a0-4758-95e9-afdd6d90e013" },
    ["VHS: Dime Diamonds"] = { key = "RM_7c548082-42b4-49ef-8415-e09436251249", id = "25df99f3-2866-498e-8016-9b005df1d250" },
    ["VHS: Dog Goblin II"] = { key = "RM_7b57e2c3-94e3-4ead-b465-dd318eed18dd", id = "526534f0-0bcd-4cca-a30c-5bc37c359fbe" },
    ["VHS: Dog Goblin III"] = { key = "RM_8395801f-a069-4425-879d-f2aa3d862d41", id = "092a6643-cc78-4b99-bd8f-deb68814078d" },
    ["VHS: Dog Goblin IV"] = { key = "RM_a838ac71-0eb0-403c-a583-71d2aa9a9661", id = "77facb85-3606-460c-ac75-f82a31ce25f1" },
    ["VHS: Dying Strike"] = { key = "RM_f4a52d0b-a933-4ea9-aaae-b83f4955e936", id = "01940222-8880-4757-be51-9b919bfc0f5c" },
    ["VHS: Eagle Down"] = { key = "RM_afe6aa5c-2d03-44f4-84b0-860d226d5b7e", id = "c6224369-5973-4ec9-817c-76d2aa07f553" },
    ["VHS: Emergency First Aid"] = { key = "RM_37a45068-9ff8-4b30-b4ab-7b5ec547fdff", id = "955bf539-6b8b-4dea-9fde-7bfaf3b31983" },
    ["VHS: Exposure Survival E1"] = { key = "RM_a34efdfd-8769-4602-9fea-b6125793c69c", id = "ccfd97d7-6b57-432c-bca7-f9a271f8012f" },
    ["VHS: Exposure Survival E2"] = { key = "RM_497bac8e-614f-4304-bc75-7b313a8fbb61", id = "6f1be5b5-d871-4ebf-bc44-2657f7c89bb5" },
    ["VHS: Exposure Survival E3"] = { key = "RM_7da44577-f37e-4501-9c05-45d6057765d8", id = "7402fb83-b5b3-4b08-99f9-82bc67f4572b" },
    ["VHS: Exposure Survival E4"] = { key = "RM_cc93005d-ab9d-473e-964d-7becaea44c1a", id = "a628a723-ac78-4bcb-927a-f84ad8c6c286" },
    ["VHS: Exposure Survival E5"] = { key = "RM_81c44aae-9d19-48b6-8bed-0bacc0377558", id = "1123df57-5e9b-4d61-88f1-7561949132e3" },
    ["VHS: Exposure Survival E6"] = { key = "RM_c2c86c3a-5630-4749-971a-474079d14cd1", id = "75928dcd-c613-4a1e-afb5-20c4c671b835" },
    ["VHS: Exposure Survival E7"] = { key = "RM_98d4f152-995c-4b08-9a07-630608eabf02", id = "2dcd687b-ac76-4b33-b0b7-79ddfba2feb4" },
    ["VHS: Exposure Survival E8"] = { key = "RM_b46f1ed1-81a2-453c-8ec5-dfea779c9aa5", id = "f74df7fc-20ae-4600-b2d2-f504d9355440" },
    ["VHS: Fred and Ali's Radical Journey"] = { key = "RM_be7dd9c6-9f32-427e-86eb-30194dc0fd15", id = "473bb1b2-3fd0-4d4b-8e8f-42d3bd01b929" },
    ["VHS: From Ore to Store"] = { key = "RM_dd42d72c-63c6-4e57-b16b-11cdc5eba9b0", id = "200e0912-8bfc-4d16-bd0b-8c63a7893773" },
    ["VHS: Ghoul Stoppers"] = { key = "RM_cab50ea8-a979-4488-b39c-46ac1f0cc0fe", id = "be51ed1d-e0dd-4836-8a18-7273f1545fc6" },
    ["VHS: Global Warrior"] = { key = "RM_9538bba8-b976-47a5-b31b-c7a7a61a31bd", id = "0bac9338-28c4-4a72-94fe-9d47cf956f7b" },
    ["VHS: Growing Fruit and Veg at Home 1"] = { key = "RM_68e705de-edd5-42a1-baaf-c7dd8a37355f", id = "1a22a4b3-156b-4474-a455-8d6c066e5a21" },
    ["VHS: Growing Fruit and Veg at Home 2"] = { key = "RM_bd2eb6d9-0367-47f3-a498-b4f6b044ebb0", id = "a7cd7482-cc83-4097-9ce9-c14eb745014d" },
    ["VHS: Growing Herbs at Home"] = { key = "RM_05d53e8d-ed73-4e3a-9f1c-cfff8e869617", id = "1c687700-baf6-4901-83e7-11038b7292a9" },
    ["VHS: Home Invaders 2"] = { key = "RM_8fd94922-b49e-41c3-9287-cc7aa8cbe38f", id = "d778665f-21b1-475e-a530-7233c95c2d0f" },
    ["VHS: Home Welding Guide"] = { key = "RM_015375a7-3761-4721-95e0-2a9be69ea306", id = "c1a3d275-4b61-4b29-94cd-2a87b183f5e8" },
    ["VHS: How Electricity Works"] = { key = "RM_88a98a51-34b0-4dcf-a75a-4fed3b6a0f24", id = "9f33c7f2-2af6-4d44-a9bc-630ee8310a2f" },
    ["VHS: Knapping: The Ancient Art"] = { key = "RM_eabed711-b083-458f-9778-c3a95965e502", id = "c3d6c81d-a141-49ce-9127-79180cf23c2c" },
    ["VHS: Knox Gun Owners Club's Guide to Guns"] = { key = "RM_e17b3497-1e70-4ca8-9d17-721cd6e36d8a", id = "729fc45b-5f9c-46b1-8cb6-d4978b050068" },
    ["VHS: Lives Taken"] = { key = "RM_6a9a8a45-dd0e-4070-9fdb-9b6478439fd5", id = "9822e2c7-b5c2-4600-bf2c-3c1543e6fa70" },
    ["VHS: Loveheart"] = { key = "RM_2feed722-ac0c-450c-9eb4-a0f51b606082", id = "d544e324-b554-42e2-a36e-de7e09b32a2c" },
    ["VHS: Making Sushi at Home"] = { key = "RM_dd860b97-22c4-4b5b-a21f-cf712fd875c0", id = "988e8c5a-93b4-456f-be54-4638c5dc7812" },
    ["VHS: Man on the Run"] = { key = "RM_952fabe1-d6dd-4544-9449-17b24e33a99c", id = "e50928ac-f472-43d9-bae0-2c27e3187567" },
    ["VHS: Marriage License"] = { key = "RM_fe939e58-ff08-4d6a-8372-d7e463625e22", id = "4d2ed157-ca09-47aa-bde5-8acb4db6bf5b" },
    ["VHS: Molly Brown"] = { key = "RM_19988fe9-9b55-4f2d-b7aa-08e3d4012a8e", id = "d3b8c97d-d3a7-4268-88bc-7e4a6bf24d6e" },
    ["VHS: Mother's Boy"] = { key = "RM_40782a01-f9b9-4dd1-ac33-1e17567b0a5c", id = "9ec23879-13eb-4b6a-ab44-e9038952104f" },
    ["VHS: Operation Fort Knox"] = { key = "RM_acf1af82-baa7-4d7f-8fd1-6157e5f9b9d8", id = "e311d6ae-9271-40fc-be4b-fba27317d5fc" },
    ["VHS: Paris in the Rain"] = { key = "RM_563bdf40-b31b-43f9-aed5-bcaca683e776", id = "9fd2da4a-9130-4fac-a49e-8811b8968939" },
    ["VHS: Pleistocene Land"] = { key = "RM_a21b42d2-1a71-4cd4-8506-26e135818586", id = "ab77e300-a0be-4c54-a514-50d44b543489" },
    ["VHS: Pottery for Anyone"] = { key = "RM_b995c51e-3a31-49cc-ad6d-d0b6628a61e9", id = "7e395694-9830-4066-8709-bf285677937d" },
    ["VHS: Return of the Nightporter"] = { key = "RM_dd8e5a36-f247-4679-9808-923ec93f873f", id = "17596597-5bae-4814-927c-c8673b7739af" },
    ["VHS: Rosewood Medical First Aid"] = { key = "RM_9faa0b1e-9f5a-4e3f-b11c-d26f3b45e6c9", id = "0cd1fbcb-1ea6-4edc-aeb6-f0a81eff6c5e" },
    ["VHS: Satin and Silk"] = { key = "RM_887b79cf-cd40-4d19-99e4-f7da96410a68", id = "1d57ab8f-61e9-4bb1-9d6f-d3d9d1146ea1" },
    ["VHS: Simon's Fitness Club E1"] = { key = "RM_6fc3511f-a073-4f36-a51f-df98e0c68f8f", id = "3297434d-f2b0-47cf-b00c-038a937ddce5" },
    ["VHS: Simon's Fitness Club E2"] = { key = "RM_b7b9ad13-d45d-4cbc-9ffc-61937a11c55c", id = "f87aee3b-2749-4c76-a1be-471c8a9229b3" },
    ["VHS: Simon's Fitness Club E3"] = { key = "RM_446e7d53-565c-4b2b-a0de-188851661481", id = "d27e7cd9-537e-4c5c-aabc-c37a7abbb214" },
    ["VHS: Simon's Fitness Club E4"] = { key = "RM_296d5978-af87-4e25-b165-3a5e47db0a18", id = "ebd9a190-456a-4ffe-b9f5-eeaedca68661" },
    ["VHS: Simon's Fitness Club E5"] = { key = "RM_6fe1edd7-1891-4ce6-9287-0c3f200eeda1", id = "98406d57-3f55-4f36-afc4-b78554acc0aa" },
    ["VHS: Slow Descent"] = { key = "RM_002fec46-caa9-4b42-962e-e7a99e76fde9", id = "254ce9f9-2f49-497c-8914-c64f28bf8bce" },
    ["VHS: Sordid Client"] = { key = "RM_f8ec6e64-66d1-4151-92d9-329cd4fc51f1", id = "1ef8dff0-952f-49db-9312-2e363764160e" },
    ["VHS: Space Crew S3.01"] = { key = "RM_0db2e334-8a63-4766-aaf6-6ab2070f1569", id = "a3189d19-73db-41f8-8865-ef478eebd58a" },
    ["VHS: Space Crew S3.02"] = { key = "RM_dfb2cb58-7302-45e7-9622-0b49cf28587c", id = "30ef3e9e-6270-441c-acbb-77191dbe073b" },
    ["VHS: Space Crew S3.03"] = { key = "RM_861dfc5c-a29f-4064-b910-399f4fe96c16", id = "074d0c6d-f387-4472-b41b-fe73ce2132da" },
    ["VHS: Space Crew S3.04"] = { key = "RM_7ccea845-b467-42bb-a0fc-37cc2b500fe3", id = "4a0838f5-b881-4c94-9dfa-66b655870395" },
    ["VHS: Space Crew S3.05"] = { key = "RM_a0060377-0738-4f6b-98ed-04714ce7bf9b", id = "e34b5a15-f058-495f-b16e-482c704d3b52" },
    ["VHS: Squad Down"] = { key = "RM_42a397cf-ee08-467a-b492-a11798781ead", id = "0454442e-ce08-4d01-bba5-6a8822bf86d1" },
    ["VHS: Strange Little Men"] = { key = "RM_24ca71c7-bde5-4697-85ca-53a24a3602ba", id = "be64169e-3ed9-4cf8-90fa-b36283f9c2eb" },
    ["VHS: Strangely True S2.01"] = { key = "RM_f1df2202-f042-4874-bc1e-c5408b9bbd72", id = "9b8500f2-2288-4497-b85a-eacbda615a03" },
    ["VHS: Strangely True S2.02"] = { key = "RM_e1dbc609-dca8-4b26-9b42-cf782f486865", id = "4b60b0ce-0ee2-4d4b-b31e-c6cfd0b8bd01" },
    ["VHS: Strangely True S2.03"] = { key = "RM_88113755-4c98-44bc-9ff2-4e339f60de20", id = "7e713c4c-5ae5-4c16-89ff-6ff5191401b3" },
    ["VHS: Strangely True S2.04"] = { key = "RM_324e8b68-2152-456e-92c1-a146c0514e92", id = "8e792270-84c1-4fc3-b4b8-2a500c522347" },
    ["VHS: Strangely True S2.05"] = { key = "RM_5f9f6755-8ad8-4285-b31d-6e5a27bf5754", id = "1f13efd4-42db-4889-9695-9b74d39dcdf7" },
    ["VHS: Survival Instinct"] = { key = "RM_53678152-20f5-4a59-b3f5-57a3da5dbf5e", id = "9fcadfea-5b3b-4c72-ac30-d03839a3e86d" },
    ["VHS: Tangier"] = { key = "RM_99d9ce47-c385-43ab-beaf-ced4c14069c6", id = "7bdb6cb5-1d76-4928-a784-d0ec97a98fd3" },
    ["VHS: The Cook Show E1"] = { key = "RM_21ff5f9e-4b9f-419a-a6eb-5ccb63ccaa4e", id = "e6fd44a9-1774-4204-ab45-9b316301aa2b" },
    ["VHS: The Cook Show E2"] = { key = "RM_08265ea3-f212-46ca-a1c8-467d50460ce6", id = "a754fdaf-5bac-40cd-9a69-da90e8a0cac7" },
    ["VHS: The Cook Show E3"] = { key = "RM_d9acbdfd-ba72-4aff-93f9-0930845371a9", id = "7933a371-a8a6-4c31-8886-7a97d89f2c7e" },
    ["VHS: The Cook Show E4"] = { key = "RM_89bb626a-ac81-4dd7-bb60-aa8838601ce5", id = "4cc3b806-4630-4dfc-a935-efa700fbd7fb" },
    ["VHS: The Cook Show E5"] = { key = "RM_a7182576-fb24-4f6d-abac-6c215f2ad68e", id = "2695eb00-ee79-4b39-833a-1023a28ce397" },
    ["VHS: The Cook Show E6"] = { key = "RM_7dd28b0c-ea7c-4e61-affa-86106091b90c", id = "01b3d832-602c-4566-b8d6-c2b74a4a0b00" },
    ["VHS: The Cook Show E7"] = { key = "RM_e6a52f32-648b-4ad7-a7c5-05950798bdaf", id = "2c2a052d-097c-4507-85f4-7fda90f3e3d1" },
    ["VHS: The Crying of the Foxes"] = { key = "RM_f48e1489-e08f-401f-8fef-e055c607e7ae", id = "d006671e-9d60-4634-8cda-27a28abbc164" },
    ["VHS: The Danger in Your Bed"] = { key = "RM_b759e0f6-e7a3-4529-a716-f616f4f68fc6", id = "462ca6e0-fd5e-4bf9-9748-12b3480ece26" },
    ["VHS: The Dog Goblin"] = { key = "RM_6847deee-b5f1-45ef-a3e1-d6f7f2971f58", id = "21411665-0ce7-4200-83a1-43ae2e6cbbb3" },
    ["VHS: The Janitor"] = { key = "RM_652f4b35-fe6f-4357-9fda-3f204abef922", id = "75c5a4a9-4e4b-4825-9db7-a371899e58b1" },
    ["VHS: The Magical Woodland E1"] = { key = "RM_0207f622-e3e0-4c8e-a31c-7c32d6ba857f", id = "05f9056b-914e-4810-9a6a-9267249e9bcf" },
    ["VHS: The Magical Woodland E2"] = { key = "RM_c65f0a5d-acf9-43a8-ab66-199e6cf01986", id = "03885118-50f5-4b05-b586-07d512a40cbe" },
    ["VHS: The Magical Woodland E3"] = { key = "RM_a9e91671-01ca-424d-af33-7ec80e00c8b8", id = "b5a52c62-47f7-4715-9665-24e6826d88e0" },
    ["VHS: The Magical Woodland E4"] = { key = "RM_0571904d-fd02-4707-b5f0-ca98b3147833", id = "fd334e37-e3db-43b7-afd8-010f4e9042f9" },
    ["VHS: The Magical Woodland E5"] = { key = "RM_efd5cbb2-e371-489c-bc13-ea895355f52b", id = "38580dcf-3da0-469a-b35f-57c2720de3b1" },
    ["VHS: The Moderators S2.01"] = { key = "RM_2c8a0e3b-1ca1-426f-abda-61a373f61467", id = "a2ed359c-9462-4159-9aba-10e859ae71bb" },
    ["VHS: The Moderators S2.02"] = { key = "RM_a5a6821d-a290-40d3-949d-2c2832fd4c94", id = "3a6e9627-47fd-40d5-b7ff-f0d9ff78f4ff" },
    ["VHS: The Moderators S2.03"] = { key = "RM_586a3767-f78a-4c71-bdef-d941658f0516", id = "22b33878-8089-4bc7-81c0-c0825ba0d85e" },
    ["VHS: The Moderators S2.04"] = { key = "RM_ca0c7abf-fae0-4d16-849f-8115f81ad36e", id = "c79ef837-974d-448e-9e0c-9e563cac847f" },
    ["VHS: The Moderators S2.05"] = { key = "RM_e166576b-f654-499e-bc0b-13dbe7c272ae", id = "255cccad-36c7-435d-b01e-cf9d7811382e" },
    ["VHS: The Omega Department S3.01"] = { key = "RM_68a7cacc-6db4-452f-997a-4dc58cdafb94", id = "26437711-f5e5-47a7-b958-438e3202449a" },
    ["VHS: The Omega Department S3.02"] = { key = "RM_fd783144-9963-45bd-ac6d-77c6fe63ec76", id = "c30b6008-84c5-413f-836c-ae2f6a0f70b1" },
    ["VHS: The Omega Department S3.03"] = { key = "RM_72c671c4-c5ed-42a3-bae7-490c195facf2", id = "8b5aafc8-16ad-4a41-8be8-6ca094adb5af" },
    ["VHS: The Omega Department S3.04"] = { key = "RM_8a8b20c4-7a0e-416e-98fe-d53f13ef06fe", id = "ac791ef2-40b8-421c-984b-d8b3258b5833" },
    ["VHS: The Omega Department S3.05"] = { key = "RM_0916e23e-af1f-4934-9a5e-566273ad37a8", id = "35991256-3806-4d78-a06d-b71c516d193f" },
    ["VHS: The Omega Department S5.01"] = { key = "RM_69744b85-8d01-4f1d-9bc2-b588c6342e3b", id = "b6777358-7f94-4104-8c3e-9175dc77faf9" },
    ["VHS: The Omega Department S5.02"] = { key = "RM_9b0ae8e1-a956-4ab4-a14c-47f83de25dbd", id = "23e9dec5-8183-46dc-9f3f-5c5bda49f4ba" },
    ["VHS: The Omega Department S5.03"] = { key = "RM_ac57c893-eb87-4e41-b980-1e13bbcbddfc", id = "bd31c750-cb0b-4e80-98e7-4bb71a386d1a" },
    ["VHS: The Omega Department S5.04"] = { key = "RM_2ab035c6-3e51-4968-93b8-55f74fde3d79", id = "6f03e034-4fac-460e-ace6-e86c4e34e791" },
    ["VHS: The Omega Department S5.05"] = { key = "RM_e8bec953-069f-403d-ad48-ba760ec3a2ad", id = "68b564ed-0f80-4f79-a799-67c11797bac6" },
    ["VHS: The Petting Zoo"] = { key = "RM_e7d3b48b-4a50-48a7-a406-1397ebb5182a", id = "b4830b9a-341e-4f2e-b6f6-87aaaaf99d00" },
    ["VHS: The Thompsons S3.01"] = { key = "RM_3ebe59dc-dfa7-490e-ab4c-89aecde89662", id = "4638a251-4bbe-4d91-a555-2e46eb790f8c" },
    ["VHS: The Thompsons S3.02"] = { key = "RM_2885ad75-de54-452d-a5d0-dfbfb8b1e5b2", id = "cddde004-4ee4-48dc-8454-83123ad8d534" },
    ["VHS: The Thompsons S3.03"] = { key = "RM_4e49e943-7fc5-4597-a12b-eabc5a157b50", id = "2f5f43fd-8d17-4ef0-ba60-dd4b7591c512" },
    ["VHS: The Thompsons S3.04"] = { key = "RM_b495c815-4d94-4316-b148-e6120b0720ff", id = "cc884f89-a56d-4d8a-9e75-24c417c14276" },
    ["VHS: The Thompsons S3.05"] = { key = "RM_d82119eb-93ac-4669-81a9-9e6832ea2726", id = "a84da6ea-c350-4304-8746-a84acc059d10" },
    ["VHS: Three Deaths and a Divorce"] = { key = "RM_5783a64b-a9da-4533-9702-c3edae544087", id = "fc734b68-487c-46fa-8b73-ddb1450366e0" },
    ["VHS: Timbergap Manor"] = { key = "RM_af82dc80-6f4b-43f3-9236-6f5f48c7a142", id = "eab285a7-1fd2-4748-9911-0dacfa7b9a40" },
    ["VHS: Tired in Toronto"] = { key = "RM_3e25ec58-81d6-4ccf-a0f2-a3bbca717be7", id = "9953e7f7-396c-4400-82d7-0fc24fbfe0b7" },
    ["VHS: Train Bomb"] = { key = "RM_124c8e97-532f-4dd7-919a-e664914e0634", id = "8c204a6e-f1a2-4dd5-a91a-7358acb0d677" },
    ["VHS: War Front"] = { key = "RM_1fb4c62f-a02d-4d44-a692-fd3c7d500ceb", id = "5a504f00-584b-4330-9752-b213784097c7" },
    ["VHS: Washington High S5.01"] = { key = "RM_905213c7-761f-4026-9ab4-93da949b2ba9", id = "d8644aea-9694-4234-b40f-a0d780c644e9" },
    ["VHS: Washington High S5.02"] = { key = "RM_5d7bfbc2-a233-491b-8554-0ee162f4b23c", id = "3633446b-54f4-463b-9305-45d9c0876d36" },
    ["VHS: Washington High S5.03"] = { key = "RM_c86e8126-9e8f-4703-b0fa-9645594b8629", id = "c36c34f8-4c6c-4bec-852c-120c20ca9984" },
    ["VHS: Washington High S5.04"] = { key = "RM_e861dbeb-5d76-4031-843f-f71eb0a75eb4", id = "47d9170a-fe9d-42f6-8a20-def16f3955b7" },
    ["VHS: Washington High S5.05"] = { key = "RM_c293f6cf-3f28-401b-b1f6-ca3b6b4e48e3", id = "b9d78079-738f-4304-906e-8c4d5a5a1f25" },
    ["VHS: Woodcraft E1"] = { key = "RM_65319278-26d8-4433-a447-04f8dd0c79c0", id = "dedd4e83-6e3b-4f4f-9c9b-72a5ed08969d" },
    ["VHS: Woodcraft E2"] = { key = "RM_095acdbc-c4ef-44a1-aad4-aec98a88cbf8", id = "c2d01da8-8e04-4889-8676-bb633e98df2d" },
    ["VHS: Woodcraft E3"] = { key = "RM_36e51b7a-e72a-491b-b81e-7feb2e9b3392", id = "3e9c5cf0-bf40-40eb-bcd7-4fd6c5ae58ca" },
    ["VHS: Woodcraft E4"] = { key = "RM_d7b24844-74a7-4095-bfad-83a99c299673", id = "0627a89a-a32b-4e80-9926-815aa9d22b2b" },
    ["VHS: Woodcraft E5"] = { key = "RM_76f3676c-493f-478e-b228-1dc7c1f0e0af", id = "2bf49f71-0d46-43aa-bbfd-f311e5bda9b2" },
    ["VHS: Woodcraft E6"] = { key = "RM_e111eb34-3621-483a-8c69-01dc20a0d1f5", id = "968591cd-d4aa-4ef1-9632-7771a1f5b9ab" },
    ["VHS: Woodcraft E7"] = { key = "RM_8df2f07b-4088-45dc-b674-01b73f247512", id = "01dedfea-62eb-4ae6-a4bc-5e629b7ba54b" },
    ["VHS: Working Clay at Home"] = { key = "RM_d9a8fc81-28a6-4ecc-b508-2429559c82d6", id = "dccc28f4-fc37-4d74-928d-9f7d1bdf4e3f" },
    ["VHS: You Are Dead"] = { key = "RM_3f323df1-dfe8-48a1-9df6-92bc6887057a", id = "620997ad-5f62-4498-b589-8bcd412a7cc1" },
    ["VHS: Z-Squad S2.01"] = { key = "RM_0305a32f-a000-4bc1-9183-a7773b0fa443", id = "b68b207a-026e-4af2-9227-38277df51e41" },
    ["VHS: Z-Squad S2.02"] = { key = "RM_070e8851-c263-4ecb-b872-5266a7c035ff", id = "4255a86b-d9f7-45e3-bf9f-060c8a35858d" },
    ["VHS: Z-Squad S2.03"] = { key = "RM_fa201bfc-03a0-4766-b4e1-4153324ec657", id = "4f3f30d6-df77-4e85-b1cb-4ca7e67addd9" },
    ["VHS: Z-Squad S2.04"] = { key = "RM_610aa9e0-098e-4e64-a35b-4eca97972fff", id = "72f5baec-e382-48ca-817a-594c619d35c8" },
    ["VHS: Z-Squad S2.05"] = { key = "RM_fde7f7e8-6847-481b-8997-234461266708", id = "ac4302bc-c9c1-433a-a8cd-4609d0bde968" },
}
-- <AUTO-GEN:MEDIA_NAME_MAP END>

local function shouldRunClientRepair()
    return not (isServer() and not isClient())
end

local function isMediaScriptItem(item)
    local scriptItem = item and item:getScriptItem()
    local cat = scriptItem and scriptItem:getRecordedMediaCat()
    return cat ~= nil and cat ~= ""
end

local function fixRecordedMediaName(item)
    if not item or not item.getMediaData then return 0 end
    -- index 有效：vanilla load 已用現行翻譯重刷，不需處理
    if item:getMediaData() ~= nil then return 0 end
    -- 只處理 script 定義帶 MediaCategory 的媒體類物品（vanilla 慣用判別法）
    if not isMediaScriptItem(item) then return 0 end
    -- 不動玩家/第三方 MOD 自訂名稱
    if item.isCustomName and item:isCustomName() then return 0 end

    local currentName = item:getName()
    local entry = currentName and RecordedMediaNameFlx.EN_TO_MEDIA[currentName]
    if not entry then return 0 end

    if not isClient() then
        -- SP（單機）：重新連結媒體資料（恢復功能；名稱由 Java 端重寫為現行翻譯）。
        -- guid 查無（烘焙表過期）時保留英文名與反查資格，待 gen-media-map 再生後修復；
        -- 若此時改名會永久失去反查鍵，關閉未來重連結的機會
        local recordedMedia = getZomboidRadio() and getZomboidRadio():getRecordedMedia()
        local mediaData = recordedMedia and recordedMedia:getMediaData(entry.id)
        if not mediaData then return 0 end
        item:setRecordedMediaData(mediaData)
        return 1
    end

    -- MP client（含 co-op host）：僅顯示層改名（client 端不得用本地 registry 重連結）
    local newName = getText(entry.key)
    if not newName or newName == "" or newName == entry.key or newName == currentName then
        return 0
    end
    item:setName(newName)
    return 1
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
                fixed = fixed + fixRecordedMediaName(item)

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
        print(TAG .. " [RecordedMediaName] Fixed orphaned media item names: " .. tostring(fixed))
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
