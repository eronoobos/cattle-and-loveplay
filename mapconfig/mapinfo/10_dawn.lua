--------------------------------------------------------------------------------------------------------
-- Night settings
--------------------------------------------------------------------------------------------------------

if (Spring.GetMapOptions().timeofday ~= "dawn") then
	return
end

local function Scale(tag, scale)
	local value = loadstring("return mapinfo." .. tag:lower())()
	assert(type(value) == "number")
	loadstring("mapinfo." .. tag:lower() .. " = " .. value * scale)()
end

local function ColorShift(tag, shift)
	local color = loadstring("return mapinfo." .. tag:lower())()
	assert(type(color) == "table")
	color[1] = color[1] * shift[1]
	color[2] = color[2] * shift[2]
	color[3] = color[3] * shift[3]
end

------------------------------------------------------------
-- Relative Settings

local redShift = {1.5, 1.5, 1.5}
local deepRedShift = {0.53, 0.53, 0.53}
local blueShift = {0.6, 0.6, 0.6}

ColorShift("lighting.groundambientcolor",  blueShift)
ColorShift("lighting.grounddiffusecolor",  redShift)
ColorShift("lighting.groundspecularcolor", redShift)
ColorShift("lighting.unitambientcolor",    blueShift)
ColorShift("lighting.unitdiffusecolor",    redShift)
ColorShift("lighting.unitspecularcolor",   redShift)
Scale("lighting.groundshadowdensity", 1.2)
Scale("lighting.unitshadowdensity",   1.2)

ColorShift("atmosphere.suncolor",   redShift)
ColorShift("atmosphere.cloudcolor", redShift)
ColorShift("atmosphere.skycolor",   redShift)
ColorShift("atmosphere.fogcolor",   redShift)
Scale("atmosphere.fogstart", 1.2)
Scale("atmosphere.fogend",   1.2)

ColorShift("water.planecolor",    deepRedShift)
ColorShift("water.surfaceColor",  redShift)
ColorShift("water.specularColor", redShift)
ColorShift("water.diffuseColor",  redShift)
Scale("water.surfaceAlpha", 0.75)
Scale("water.fresnelmax", 0.25)

------------------------------------------------------------
-- Absolute Settings

local cfg = {
	lighting = {
		sunDir              = {-1.5, 0.15, -1.5, 1e9},
	},
}


return cfg