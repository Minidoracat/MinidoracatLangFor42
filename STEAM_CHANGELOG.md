[h1][B42]Chinese translation For 42 by Minidoracat 如一漢化組 42.20.2-1.18.1[/h1]
[i]2026-08-11[/i]

[h3]🔧 Fixed[/h3]
[list]
[*] [b]路易斯維爾地圖 39 個地標鍵誤刪回滾（GitHub issue #2）[/b]。玩家回報世界地圖多處直接顯示裸 key（MapLabel_LouisvilleTrainStation、MapLabel_IroquoisPark 等）。根因：4e9ce58（隨 1.15.1 上線）的死鍵清理以「官方 EN 有無」判死鍵，把 worldmap-annotations.lua 以 addUntranslatedText 引用的 56 個 MapLabel_* 鍵中的 39 個 POI 鍵誤判為死鍵刪除——這批鍵官方 EN 亦無（官方 MapLabel.json 僅 14 個城鎮鍵），引擎查無鍵時 fallback 無值可退、直接畫裸 key；且 MapLabel_Flx.lua 本就會移除官方原文字標籤，缺鍵時連英文都不剩。POI 地標絕大多數（31/39）僅在 zoom 13.5–16.5 帶渲染，街名層級的近距檢視踩不到，故發版驗證未抓到——上線當日玩家即於 Steam 留言回報、翌日提交 issue 截圖。修法：整檔還原 4e9ce58~1 的 CH/CN MapLabel.json（倖存 17 鍵清理前後值零異動，無潤色損失），56 鍵與 annotations 引用逐鍵對齊、零缺零餘。還原時順修 5 組舊值缺陷（雙邊 review 抓出，皆有同實體既有定譯佐證）：CN IrvingtonSpeedway「欧文顿Speedway赛道」→「欧文顿赛车场」（英文殘留，對齊 CH）；CH/CN FossoilField「福索球場」→「[b]福索石油[/b]球場」（Fossoil＝福索石油，全庫定譯）；CardinalPlaza「主教廣場」→「[b]紅雀[/b]廣場」（對齊 Print_Media_CardinalPlaza_title，Cardinal 為紅雀非主教）；LouisvilleBruiserFactory「布魯瑟[b]棒球[/b]工廠」→「布魯瑟工廠」（該廠產品是球棒，對齊 Print_Media_LouisvilleBruiser_title）；PSDelilah「迪莉婭號[b]水上餐廳[/b]」→「迪莉婭號[b]蒸汽船[/b]」（PS＝Paddle Steamer，對齊 Print_Media_Delilah_title）。
[/list]

[h3]✨ Added[/h3]
[list]
[*] [b]verify_mod.py 檢查 12「地圖註記鍵覆蓋」[/b]：掃 media/maps/ 下各 worldmap-annotations.lua 的 addUntranslatedText 引用，逐語系與該語系 MapLabel.json 比對——引擎按鍵前綴路由到 per-file map（Translator.getTextInternal：MapLabel_ 只查 MapLabel.json 填的表，跨 mod 同檔名合併、不跨檔名），鍵搬錯檔照樣裸 key，故不能拿全 json 鍵聯集當存在判準。除缺鍵外亦驗[b]譯值有效性[/b]（空值／非字串／值等於鍵名都等同缺譯），另備兩道自失明防護：擷取數與呼叫數交叉比對（掃描 regex 失配即 FAIL）、非 MapLabel_ 前綴引用即 FAIL（該類鍵會被 MapLabel_Flx.lua 過濾靜默刪除）。鑑別力已驗證：對修復前狀態跑出 CH/CN 各 39 筆缺鍵 FAIL（exit 1），修復後全數 PASS。死鍵稽核紀錄 scripts/dead_keys_audit_42.20.2.json 同步回填（39 鍵 delete→keep_alive、存活判定 method 補掃 annotations 引用）。
[/list]
