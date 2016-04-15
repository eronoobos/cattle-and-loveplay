local wormConfig = {
	sandType = { ["Sand"] = true }, -- the ground type that worm spawns in
	wormEmergeUnitNames = { 
		["sworm1"] = 1,
		["sworm2"] = 2,
		["sworm3"] = 3,
		["sworm4"] = 4, },
	wormUnderUnitName = "underworm", -- unit name for unit that moves around with the worm underground
	wormTriggerUnitName = "wormtrigger", -- unit name that when spawned deletes itself and spawns a worm
}

return wormConfig