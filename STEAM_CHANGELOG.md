[h1][B42]Chinese translation For 42 by Minidoracat 如一漢化組 42.22.2-1.35.2[/h1]
[i]2026-11-27[/i]

[b]English summary[/b]
[list]
[*] Fixed a rare case where the world map (opened with M) could open at a wrong position or zoom. No player has reported it, and normal play looks the same.
[/list]

[h3]🔧 Fixed[/h3]
[list]
[*] [b]打開大地圖時，地圖位置或縮放可能跑掉[/b]：本包會在打開大地圖時一起整理地圖上的地名標籤。按 M 開地圖時，遊戲只告訴這段程式「是哪位玩家」，沒給位置和縮放；這段程式卻還是把位置和縮放往下傳，少數情況下傳出去的是不相干的數字，地圖可能開在奇怪的位置或縮放。現在沒給的就不傳，地圖照遊戲原本的方式打開。目前沒有玩家回報過這個問題，平常看不出差別。
[/list]
