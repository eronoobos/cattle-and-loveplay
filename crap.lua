	underworm = {
		movementClass = "UNDERSAND",
		maxVelocity = 1.0,
		acceleration = 1.0,
		turnRate = 100,
		turnInPlace = false,
		waterline = -150,
		crushResistance = 99999,
		blocking = false,
		buildPic = "sworm.png",
		canMove = true,
		description = "I'd like to be under the sand, in a sand worm's garden.",
		footprintX = 1,
		footprintZ = 1,
		iconType = "sworm",
		levelGround = false,
		maxDamage = 9999,
		name = "Sand Worm",
		objectName = "swormOpenMouth-180_50out-r45.s3o",
		script = [[nullscript.lua]],
		-- stealth = true,
		-- canCloak =  true,
		-- initCloaked = true,
		customParams = {
 			ignoreplacementrestriction = true,
		},
	},


local moveDatas = {
	UNDERSAND = {
		speedmodclass = 3,
		crushstrength = 0,
		footprintx = 1,
		footprintz = 1,
		maxslope = 90,
		maxwaterslope = 90,
		minwaterdepth = -9999,
		avoidmobilesonpath = false,
	},
}

--------------------------------------------------------------------------------
-- Final processing / array format
--------------------------------------------------------------------------------
local defs = {}

for moveName, moveData in pairs(moveDatas) do
	moveData.name = moveName
	defs[#defs + 1] = moveData
end

return defs
