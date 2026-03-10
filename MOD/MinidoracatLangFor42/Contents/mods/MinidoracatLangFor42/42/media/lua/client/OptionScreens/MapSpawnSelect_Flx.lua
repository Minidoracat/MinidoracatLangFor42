require "ISUI/ISScrollingListBox"

local TAG = "[CatLangFor42]"

function MapSpawnSelect:_fillList()
	self.listbox:clear()
	WORLD_MAP = nil
	self.mapPanel:clear()
	local spawnSelectImagePyramid = nil

	self.sortedList = {};
	self.notSortedList = {};

	local regions = self:getSpawnRegions()
	if not regions then return end
	for _,v in ipairs(regions) do
		local info = getMapInfo(v.name)
		if info then
			local item = {};
			item.name = info.title or "NO TITLE";
			item.region = v;
			item.dir = v.name;
			item.desc = info.description or "NO DESCRIPTION";
			if info.spawnSelectImagePyramid then
				spawnSelectImagePyramid = info.spawnSelectImagePyramid -- only one is supported
			end
			item.zoomX = info.zoomX
			item.zoomY = info.zoomY
			item.zoomS = info.zoomS
			item.demoVideo = info.demoVideo
			self:checkSorted(item);
		else
			local item = {}
			item.name = v.name;
			item.region = v;
			item.dir = "";
			item.desc = "";
			item.worldimage = nil;
			self:checkSorted(item);
		end
	end

	if #self.listbox.items > 1 then
		local item = {}
		item.name = getText("UI_mapspawn_random");
		item.region = nil;
		item.dir = "";
		item.desc = "";
		item.worldimage = nil;
		table.insert(self.notSortedList, item);
	end

	-- Force override: use our Chinese map image pyramid from MOD directory
	-- The loop above may have picked up the vanilla Muldraugh .zip (English),
	-- so we ALWAYS override with our Chinese Riverside .zip
	local riversideInfo = getMapInfo("Riverside, KY")
	if riversideInfo and riversideInfo.dir then
		local chinesePyramid = riversideInfo.dir .. "/spawnSelectImagePyramid.zip"
		print(TAG .. " Chinese map pyramid: " .. chinesePyramid)
		spawnSelectImagePyramid = chinesePyramid
	else
		print(TAG .. " WARNING: Could not find Riverside, KY map info for Chinese pyramid")
	end

	if spawnSelectImagePyramid then
		self.mapPanel:setImagePyramid(spawnSelectImagePyramid)
	else
		print(TAG .. " WARNING: No image pyramid, falling back to initMapData")
		for _,v in ipairs(regions) do
			local info = getMapInfo(v.name)
			if info then
				self.mapPanel:initMapData('media/maps/'..v.name) -- FIXME: order of multiple maps matters
				for _,dir in ipairs(info.lots) do
					self.mapPanel:initMapData('media/maps/'..dir) -- FIXME: order of multiple maps matters
				end
			end
		end
	end

	-- list has been sorted with MapsOrder
	for i,v in ipairs(self.sortedList) do
		self.listbox:addItem(v.name, v);
	end

	for i,v in ipairs(self.notSortedList) do
		self.listbox:addItem(v.name, v);
	end

	self:hideOrShowSaveName()
	self:recalculateMapSize()

	if self.textEntry ~= nil and self.textEntry:getInternalText() == "" then
		local sdf = SimpleDateFormat.new("yyyy-MM-dd_HH-mm-ss", Locale.ENGLISH);
		self.textEntry:setText(sdf:format(Calendar.getInstance():getTime()));
	end

	self.mapPanel.shownInitialLocation = false
end

-- Apply override if CatLangFor42 is active
local modId = "CatLangFor42"
local mods = getActivatedMods()
if mods:contains(modId) or mods:contains("\\" .. modId) then
	print(TAG .. " MapSpawnSelect override activated (Chinese map image pyramid)")
	MapSpawnSelect.fillList = MapSpawnSelect._fillList;
else
	print(TAG .. " WARNING: MapSpawnSelect override NOT activated. Mod ID not found.")
	-- Fallback: apply anyway since this file only loads when MOD is active
	MapSpawnSelect.fillList = MapSpawnSelect._fillList;
end