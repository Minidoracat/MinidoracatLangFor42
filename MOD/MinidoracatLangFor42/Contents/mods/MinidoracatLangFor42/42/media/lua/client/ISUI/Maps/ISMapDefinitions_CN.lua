local _initDirectoryStreetData = MapUtils.initDirectoryStreetData

function MapUtils.initDirectoryStreetData(mapUI, directory)
	local startIndex, endIndex = string.find(directory, "Muldraugh, KY");
	if startIndex ~= nil then
		return;
	end
	local startIndex, endIndex = string.find(directory, "muldraugh, ky");
	if startIndex ~= nil then
		return;
	end

	_initDirectoryStreetData(mapUI, directory)
end

-- As 1 --
-- Skip Muldraugh to load the street data in Riverside.