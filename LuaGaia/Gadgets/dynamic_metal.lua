function gadget:GetInfo()
	return {
		name      = "Dynamic Metal Map Multilayout 1.0",
		desc      = "Dynamic Metal Map sets metal spots according to map option selected. Layout is loaded from mapconfig/metal_layouts/metal_layout_[option].lua where [option] is the value of the metal map option.",
		author    = "zoggop, original gadget by Cheesecan",
		date      = "Feburary 28, 2014",
		license   = "LGPL",
		layer     = 0,
		enabled   = true  --  loaded by default?
	}
end

local pixelCoords = {
	[1] = { 0, 0 },
	[2] = { 0, 1 },
	[3] = { 0, -1 },
	[4] = { 1, 0 },
	[5] = { -1, 0 },
	[6] = { 1, 1 },
	[7] = { -1, 1 },
	[8] = { 1, -1 },
	[9] = { -1, -1 },
	[10] = { 2, 0 },
	[11] = { -2, 0 },
	[12] = { 0, 2 },
	[13] = { 0, -2 },
}

local function ClearMetalSquare(x, z, size)
	local halfSize = math.ceil(size / 2)
	for ix = x-halfSize, x+halfSize do
		for iz = z-halfSize, z+halfSize do
			Spring.SetMetalAmount(ix, iz, 0)
		end
	end
end

local mm

if (not gadgetHandler:IsSyncedCode()) then
  return false
end

if (Spring.GetGameFrame() >= 1) then
  return false
end

-- which metal spot layout to load based on map option
local layout = "normal"
local options = Spring.GetMapOptions()
if options ~= nil then
	if options.metal ~= nil then
		layout = options.metal
	end
end
local layoutFile = "mapconfig/metal_layouts/metal_layout_" .. layout .. ".lua"

if VFS.FileExists(layoutFile) then
	mm = VFS.Include(layoutFile)
	Spring.Echo("Parsing " .. layoutFile)
else
	Spring.Echo("missing " .. layoutFile .. " - you will probably become out of sync")
end

if (mm and #mm.spots > 0) then
	for i = 1, #mm.spots do
		local x = math.ceil(mm.spots[i].x/16)-1
		local z = math.ceil(mm.spots[i].z/16)-1
		local metal = mm.spots[i].metal
		local pixels = 5
		if metal <= 1 then
			pixels = 5
		elseif metal <= 2 then
			pixels = 9
		else
			pixels = 13
		end
		local mAmount = (1000 / pixels) * metal

		if(x == nil or z == nil) then
			Spring.Echo("FATAL ERROR: x or y was nil for index " .. i)
		end
		
		ClearMetalSquare(x, z, 8)
		for p = 1, pixels do
			Spring.SetMetalAmount(x + pixelCoords[p][1], z + pixelCoords[p][2], mAmount)
		end
	end
	
	Spring.Echo("Dynamic metal gadget was succesfully loaded (synced)")
else 
	Spring.Echo("content of " .. layoutFile .. " is illegal - you will probably become out of sync")
end

return false --unload
