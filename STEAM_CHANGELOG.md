[h1][B42]Chinese translation For 42 by Minidoracat 如一漢化組 42.20.2-1.18.0[/h1]
[i]2026-08-10[/i]

[h3]✨ Added[/h3]
[list]
[*] [b]演化食譜句式名固化英文修復（登記簿 A29，新增 EvolvedRecipeName_Flx.lua）[/b]。玩家回報冰箱裡的鍋菜叫 Game and Fish Roast with Soy Sauce (新鮮, 已烹飪)——外層狀態字是中文、內層菜名整串英文。
[list]
[*] [b]不是硬編碼[/b]。官方 ISAddItemInRecipe.lua 的 checkName 本身正確使用 getText（ContextMenu_FoodType_* ＋ ContextMenu_EvolvedRecipe_* ＋ RecipeName／RecipeNameNew 模板）組名；問題在組完之後 setName：InventoryItem.save 在 name != originalName 時把[b]成品字串整串[/b]序列化（flag 8），load 原樣讀回不重譯。語言在「做菜當下」被烘死，MP dedicated server（EN）煮的菜就永遠是英文。外層「(新鮮, 已烹飪)」仍是中文，是因為那由 Food.getName() 每次即時組——這個混血正是烘死的特徵。
[*] [b]修法不做句式反查[/b]：Food 的 extraItems／spices 存的是 fullType 字串列表（跨語言不變，且各自過 save/load），ScriptManager 可由 resultItem 反查所屬食譜，兩者湊齊即可[b]以本機語言原樣重跑官方 checkName[/b]——結果與本機新煮的逐字一致，零反查表、零 generator、第三方 MOD 的食材與食譜自動涵蓋。這也解除了 A20 條尾原記的「演化食譜句式名刻意不處理（需句式反查、誤傷風險高）」。
[*] [b]⚠️ 最大的坑是官方的 dirtyUI[/b]：checkName 三個出口有兩個[b]無條件[/b]呼叫 ISInventoryPage.dirtyUI()，而 dirtyUI → refreshBackpacks() → triggerEvent("OnRefreshInventoryWindowContainers", …, "end")——正是本修補掛勾的事件之一。不擋就是無限遞迴，且逐物品觸發整組背包 UI 重建。故以 runRepair 包住每一輪：重入旗標擋第二層、整批期間把 dirtyUI 換成 no-op、只有真的改過名字才補呼叫一次真的（且補呼叫必須在旗標仍生效時進行，否則終止性只能仰賴官方函式的冪等性）。
[*] [b]索引鍵是 fullType，不是 bare type[/b]。中途曾依 EvolvedRecipe.isResultItem 的 bare-type 比對改成 bare type，被 codex 端 review 以反例駁回：決定「哪個食譜適用於這個物品」的[b]權威[/b]路徑是 RecipeManager.getEvolvedRecipe 的 baseItem.getFullType().equals(recipe.resultItem)，用 bare type 會讓 SomeMod.PanFriedVegetables2 誤配到 vanilla 食譜、把第三方物品改名。已改回並補測試，教訓寫進 A29 升版 SOP。
[*] [b]同 resultItem 時比最終顯示字串，相同才合併、不同就整個跳過[/b]（初版是 first-wins，等於主動把玩家的菜改成另一道菜的名字）。判準必須是 getText("ContextMenu_EvolvedRecipe_" .. getUntranslatedName()) 而非 key 本身——實機 log 抓到拿 key 比會把 vanilla [b]唯二[/b]的一對多（Base.BucketOfSoup ← SoupBucket/SoupBucket2、Base.BucketOfStew ← StewBucket/StewBucket2，key 不同但譯文都是「燉湯」「燉菜」）整組誤判成不可判，桶裝湯／桶裝燉菜等於完全沒被涵蓋。vanilla 63 個 evolvedrecipe／61 個相異 resultItem；[b]基準須掃全 media/scripts[/b]，只看 evolvedrecipes.txt 會漏掉 fishing 的 AddBaitToChum 而少算成 62／60。
[*] [b]所有失效路徑都留 console 訊號[/b]（checkName 缺失／拋錯、dirtyUI 缺失、索引為空各一次性告警；正常啟動印 Repair path active (N ...)）——A20 曾自 276c3c5 起靜靜失效數月，這是同型防護。
[*] 回歸測試 scripts/test_evolved_recipe_name.lua（57 案，[b]載入 vanilla 真實 checkName[/b] 跑重算；找不到 vanilla 時 exit 2 而非綠燈）。鑑別力以 mutation testing 量化，當時 15 個變異體殺 12，存活的 3 個都是測試盲點且已補上斷言。
[/list]
[/list]

[h3]🔧 Fixed[/h3]
[list]
[*] [b]ContextMenu_EvolvedRecipe_* 七個鍵（CH/CN 各 7）[/b]。A29 把這組鍵的曝光面從「本機現煮」擴大到「所有 MP 食物」，順帶清掉既有問題：
[list]
[*] RecipeNameNew 由「%1 %2 [b]和[/b] %3」改為「配」——%3 是調味料，而 _and（並列連接詞）也是「和」，撞在一起會出現「野味 和 魚 燒烤 和 醬油」的歧義。（註：官方 CH 的 _with 是「與」，「配」是我方既有譯文，升版對照官方時勿誤判。）
[*] [b]5 個選單動詞句改名詞[/b]（官方 CH 原文照抄的問題，官方 EN 本來就全是名詞）：AddBaitToChum「向散餌中新增釣餌」→「散餌」、三個 Bagel「準備百吉餅…」→「貝果／罌粟籽貝果／芝麻貝果」（CN 沿用「百吉饼」系）、Oatmeal「碗 (燕麥片)」→「碗 (燕麥粥)」。這組鍵是[b]雙角色[/b]——也是右鍵選單標題，非 isResultItem 時外層還包「製作 %1」，所以原本顯示的是「[b]製作準備[/b]百吉餅」；改名詞對兩個角色都是淨改善。
[*] Stir fry Griddle Pan「烤菜」→「炒菜」，與同 EN 值（Stir-fry）的 Stir fry／Stir fry Forged 統一。
[/list]
[/list]

[h3]📝 Notes[/h3]
[list]
[*] [b]更正 A20 一句既有的錯誤斷言[/b]：「演化食譜句式名不等於單一 EN 原名，天然不受影響」與事實不符——35 個演化食譜 EN 名有 [b]21 個逐字等於某物品 EN 名[/b]（Pizza／Burger／Roast／Sandwich…），checkName 的 collapsed 分支（食材類型 > 3）會 setName(裸食譜名)，一直命中 A20 第一分支。不會 flip-flop（雙方都只匹配英文形態，一輪收斂），現由 A29 接手。
[*] [b]雙邊 review[/b]：Claude 端跑 base／architecture／tests／errors／comments 五個 lane，codex 端獨立跑 review-plus。三個真 bug 分別由不同來源抓到——dirtyUI 無限遞迴是自查、重入旗標空窗是 base review＋errors lens 獨立實測、索引鍵用錯層級是 codex 推翻 Claude lane 的結論。tests lens 另做 mutation testing 量化鑑別力，architect 抓到「本修補放大了翻譯鍵曝光面」這個沒人想到的外部影響。
[*] [b]遊戲內實測抓到一個離線測試抓不到的 bug[/b]：發布前跑 SP＋MP 實機，console 出現 ambiguous resultItem, skipped: Base.BucketOfSoup, Base.BucketOfStew——消歧判準原本比的是食譜 key，而 vanilla 唯二的一對多正好是 key 不同、譯文相同，於是唯一需要合併的兩組反被整組跳過。改比最終顯示字串後修正，測試也補上「key 不同但譯文相同」的案例（原測資是「key 相同」，天然測不到）。其餘實測結果：Repair path active (61 evolved recipes indexed) 與腳本掃描的 61 個相異 resultItem 吻合；dedicated server log 零筆 EvolvedRecipeName，驗證 server 端正確跳過；client 全程無本 MOD 相關 Lua 錯誤。
[*] [b]log 中其餘 1464 筆 ERROR/WARN 皆非本 MOD[/b]：1242 筆 ImportedSkeleton.collectBoneFrames（vanilla 骨架）、36 筆 AdvancedAnimator.visitFileFailed（PZ 對每個 MOD 掃 AnimSets／actiongroups，所有 MOD 皆有）、4 筆 FluidContainerScript.load 的 Sanitizing container name 'Fuel Pump'（即 A26 已補鍵的那件事）、Build_AnvilStone 缺圖（vanilla 只有 .fbx 無 UI 圖示，本 MOD 未碰）、Recipe Piano missing UiConfigScript、tiledef=LCtiles 9476（第三方地圖 MOD）。
[*] [b]顯示層治標的機制上限仍在[/b]：server 那份資料永遠是生成端語言，「重建→再修」是常態（同 A1）。
[*] versionMin 維持 42.20.1。
[/list]
