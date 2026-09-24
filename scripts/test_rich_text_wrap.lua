-- ISRichTextPanel_Flx 長串中文換行回歸（issue #3：VHS 封底文字超出框外）
-- 用法：在 repo 根目錄執行 `lua scripts/test_rich_text_wrap.lua`
local CHAR_W = 16 -- 假字寬：每個 UTF-8 字元 16px
local function width(s) local n = 0; for _ in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do n = n + 1 end; return n * CHAR_W end
function getTextManager() return {
	MeasureStringX = function(_, _, s) return width(s) end,
	getFontFromEnum = function() return { getLineHeight = function() return 18 end } end,
} end
function string.trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function string.contains(s, p) return s:find(p, 1, true) ~= nil end
ISRichTextPanel = {}
dofile("MOD/MinidoracatLangFor42/Contents/mods/MinidoracatLangFor42/42/media/lua/client/ISUI/ISRichTextPanel_Flx.lua")

local function paginate(text, w)
	local p = setmetatable({ text = text, width = w, marginLeft = 20, marginRight = 20, marginTop = 0, marginBottom = 0,
		maxLines = 0, defaultFont = 1, replaceKeyNames = function(_, t) return t end, setScrollHeight = function() end },
		{ __index = ISRichTextPanel })
	p:paginate()
	return p
end

local fails = 0
local function check(name, cond) if not cond then fails = fails + 1; print("FAIL " .. name) else print("PASS " .. name) end end

-- ISMediaInfo 的 richText 寬 360 → 可用 320
local vhs = "杰基·米兰一直想成为一名罪犯, 现在他的梦想实现了. 但是, 在老板保利·巴齐尼的命令下, 杰基和他的兄弟乔一起实施的抢劫案出了问题, 杰基发现自己不得不做出一个严峻的选择 - 他的地位, 还是他自己的兄弟. 1989 年, 被评级为 R."
local p = paginate(vhs, 360)
local all, over = {}, false
for i, l in ipairs(p.lines) do
	if (p.lineX[i] or 0) + width(l) > 320 then over = true end
	all[#all + 1] = l
end
check("VHS 封底每行不超過行寬", not over)
check("切行不遺失文字", table.concat(all):gsub("%s", "") == vhs:gsub("%s", ""))

p = paginate("hello world foo", 360)
check("英文短句不受影響", #p.lines == 1 and p.lines[1] == "hello world foo")

if fails > 0 then os.exit(1) end
