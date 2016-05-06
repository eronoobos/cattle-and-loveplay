-- unsynced
if not gadgetHandler:IsSyncedCode() then

local spAddMapLight = Spring.AddMapLight
local spAddModelLight = Spring.AddModelLight


	function gadget:GetInfo()
        return {
			name    = "gfx_worm_lightning_lights.lua",
			desc    = "dynamic lighting for worm lightning",
			author  = "eronoobos",
			date    = "May, 2016",
			license = "whatever",
			enabled = true,
		}
	end

	local function addLightningLight(x, y, z, radius, color)
		color = color or {1.0, 1.0, 1.0}
		local lightParams = {
			position = {x, y, z},
			-- direction = {dx, dy, dz},
			-- ambientColor = {0, 0, 0},
			diffuseColor = color,
			specularColor = {color[1]*0.25, color[2]*0.25, color[3]*0.25},
			-- intensityWeight = {ambientWeight, diffuseWeight, specularWeight},
			-- per-frame decay of ambientColor (spread over TTL frames)
			-- ambientDecayRate = {ambientRedDecay, ambientGreenDecay, ambientBlueDecay},
			-- per-frame decay of diffuseColor (spread over TTL frames)
			-- diffuseDecayRate = {diffuseRedDecay, diffuseGreenDecay, diffuseBlueDecay},
			-- per-frame decay of specularColor (spread over TTL frames)
			-- specularDecayRate = {specularRedDecay, specularGreenDecay, specularBlueDecay},
			-- *DecayType = 0.0 -> interpret *DecayRate values as linear, else as exponential
			-- decayFunctionType = {ambientDecayType, diffuseDecayType, specularDecayType},
			radius = radius,
			-- fov = number degrees,
			ttl = 2,
			priority = 20,
			ignoreLOS = false,
		}
		spAddMapLight(lightParams)
		spAddModelLight(lightParams)
	end

	function gadget:Initialize()
	  gadgetHandler:RegisterGlobal('wormLightningLight', addLightningLight)
	end
	

end