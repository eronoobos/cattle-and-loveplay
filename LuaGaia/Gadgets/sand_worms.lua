function gadget:GetInfo()
  return {
    name      = "Cattle and Loveplay: Sand Worms",
    desc      = "Handles sand worms.",
    author    = "eronoobos",
    date      = "April 2016",
    license   = "whatever",
    layer     = -3,
    enabled   = true
   }
end

-- configuration variables

-- options that will be set by map options
local wormSpeed = 1.0 -- how much the worm's vector is multiplied by to produce a position each game frame. slightly randomized for each worm (+/- 10%)
local wormEatMex = false -- will worms eat metal extractors?
local wormEatCommander = false -- will worms eat commanders?
local wormAggression = 5 -- translates into movementPerWormAnger and unitsPerWormAnger

-- config modified later by map options
local movementPerWormAnger = 100000 / wormAggression -- how much total movement (sum x+y distance plus metal cost per eval frequency of each unit) makes up 1 wormAnger
local unitsPerWormAnger = 500 / wormAggression

-- non mapoption config
local sandType = { ["Sand"] = true } -- the ground type that worm spawns in
local wormEmergeUnitNames = { 
	["sworm1"] = 1,
	["sworm2"] = 2,
	["sworm3"] = 3,
	["sworm4"] = 4, }
local wormUnderUnitName = "underworm" -- unit name for unit that moves around with the worm underground
local wormTriggerUnitName = "wormtrigger" -- unit name that when spawned deletes itself and spawns a worm
local wormSpeedLowerBias = 10 -- percentage below wormSpeed that an individual worm's speed can be. lowers with high wormAnger
local wormSpeedUpperBias = 10 -- percentage above wormSpeed that an individual worm's speed can be
local boxSize = 1024 -- for finding occupied areas to spawn worms near
local wormSpawnDistance = 1000 -- how far away from occupied area to spawn worm
local biteHeight = 32 -- how high above ground in elmos will the worm target and eat units
local baseWormDuration = 90 -- how long will a worm chase something to eat before giving up
local wormChaseTimeMod = 2 -- how much to multiply the as-the-crow-flies estimated time of arrival at target. modified by wormAnger
local distancePerValue = 2000 -- how value converts to distance, to decide between close vs valuable targets
local mexValue = -200 -- negative value = inaccuracy of targetting
local hoverValue = -300 -- negative value = inaccuracy of targetting
local commanderValue = -100 -- negative value = inaccuracy of targetting
local wormSignFrequency = 20 -- average time in seconds between worm signs (varies + or - 50%)
local rippleNumMin = 5
local rippleNumMax = 10
local bulgeSize = 7
local bulgeScale = 8
local attackDelay = 22 -- delay between worm attacks
local cellSize = 64 -- for wormReDir
local evalFrequency = 150 -- game frames between evaluation of units on sand
local signEvalFrequency = 12 -- game frames between parts of a wormsign volley (lower value means more lightning strikes per sign)
local attackEvalFrequency = 30 -- game frames between attacking units in range of worm under sand

-- storage variables
local killMeNow = {} -- units to be killed on a particular frame (to avoid recursion)
local inedibleDefIDs = {} -- units worms should not eat
local astar = {} -- for later inclusion of the astar module
local excludeUnits = {}
local newRipples = {}
local oldStamps = {}
local wormSizes = {}
local largestSandUnitSize = 0
local wormChance = 0.1 -- chance out of 1 that a worm appears. changes with worm anger.
local wormEventFrequency = 55 -- time in seconds between potential worm event. changes with worm anger.
local wormBellyLimit = 3 -- changes with wormAnger
local halfBoxSize = boxSize / 2
local occupiedBoxes = {}
local maxWorms = 1 -- how many worms can be in the game at once (changes with wormAnger)
local wormAnger = 0.1 -- non integer form of above (changed by wormTargetting)
local nextPotentialEvent = 0 -- when the next worm event is. see wormTargetting() and Initialize()m
local areWorms = true -- will be set to false if the map option sand_worms is off
local sandUnits = {} -- sandUnits[unitID] = true are on sand
local sandUnitPosition = {}
local numSandUnits = 0
local totalSandMovement = 0
local sandUnitValues = {} -- sandUnitValues[unitDefID] = value (the amount it attracts the worm
local worm = {}
local signFreqMin = wormSignFrequency / 2 -- the minimum pause between worm signs
local signFreqMax = wormSignFrequency + signFreqMin -- maximum pause between worm signs
local gaiaTeam -- which team is gaia? (set in Initialize())
local wormReDir -- precalculated 2d matrix of where to shunt the worm if it tries to move onto rock
local isEmergedWorm = {} -- is unitID an emerged attacking worm?
local halfCellSize = cellSize / 2
local sizeX = Game.mapSizeX 
local sizeZ = Game.mapSizeZ
local rippled = {} -- stores references to rippleMap nodes that are actively under transformation
local rippleMap = {}-- stores locations of sand that has been raised by worm to lower it

--sounds, see gamedata/sounds.lua
local quakeSnds = { "WmQuake1", "WmQuake2", "WmQuake3", "WmQuake4" }
local lightningSnds = { "WmLightning1", "WmLightning2", "WmLightning3", "WmLightning4", "WmLightning5" }
local thunderSnds = { "WmThunder1", "WmThunder2", "WmThunder3", "WmThunder4", "WmThunder5" }

-- localized functions
local mAtan2 = math.atan2
local mRandom = math.random
local mAbs = math.abs
local mCos = math.cos
local mSin = math.sin
local pi = math.pi
local twicePi = math.pi * 2
local halfPi = math.pi / 2
local quarterPi = math.pi / 4
local mMax = math.max
local mMin = math.min
local mCeil = math.ceil
local mFloor = math.floor
local mSqrt = math.sqrt
local tInsert = table.insert
local tRemove = table.remove

-- localized Spring functions
local spEcho = Spring.Echo
local spGetGroundInfo = Spring.GetGroundInfo
local spGetGroundHeight = Spring.GetGroundHeight
local spGetUnitDefID = Spring.GetUnitDefID
local spSetUnitPosition = Spring.SetUnitPosition
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitBasePosition = Spring.GetUnitBasePosition
local spSetUnitVelocity = Spring.SetUnitVelocity
local spGetUnitVelocity = Spring.GetUnitVelocity
local spSpawnCEG = Spring.SpawnCEG
local spDestroyUnit = Spring.DestroyUnit
local spCreateUnit = Spring.CreateUnit
local spSpawnProjectile = Spring.SpawnProjectile
local spAddHeightMap = Spring.AddHeightMap
local spGetGameSeconds = Spring.GetGameSeconds
local spPlaySoundFile = Spring.PlaySoundFile
local spGetGameFrame = Spring.GetGameFrame
local spMarkerAddPoint = Spring.MarkerAddPoint
local spGetAllUnits = Spring.GetAllUnits
local spSetProjectilePosition = Spring.SetProjectilePosition
local spSetProjectileTarget = Spring.SetProjectileTarget
local spGetUnitHealth = Spring.GetUnitHealth
local spSetUnitHealth = Spring.SetUnitHealth
local spAdjustHeightMap = Spring.AdjustHeightMap
local spGetUnitTeam = Spring.GetUnitTeam
local spGetMapOptions = Spring.GetMapOptions
local spGetTeamUnits = Spring.GetTeamUnits
local spGetLocalAllyTeamID = Spring.GetLocalAllyTeamID
local spSetUnitCollisionVolumeData = Spring.SetUnitCollisionVolumeData
local spSetUnitRadiusAndHeight = Spring.SetUnitRadiusAndHeight
local spIsPosInAirLos = Spring.IsPosInAirLos
local spIsPosInRadar = Spring.IsPosInRadar
local spSetHeightMapFunc = Spring.SetHeightMapFunc
local spGetAllyTeamList = Spring.GetAllyTeamList
local spGetGaiaTeamID = Spring.GetGaiaTeamID
local spSetUnitStealth = Spring.SetUnitStealth
local spSetUnitCloak = Spring.SetUnitCloak
local spGetUnitsInSphere = Spring.GetUnitsInSphere
local spGetSpectatingState = Spring.GetSpectatingState
local spGiveOrderToUnit = Spring.GiveOrderToUnit

-- localizations that must be set in Initialize
local spMoveCtrlEnable
local spMoveCtrlSetVelocity
local spMoveCtrlSetPosition

-- functions

local function DistanceXZ(x1, z1, x2, z2)
	return mSqrt( (x2-x1)^2 + (z2-z1)^2 )
end

-- y is not random, but zero
local function randomXYZ()
	return mRandom(sizeX), 0, mRandom(sizeZ)
end

local function AngleAdd(angle1, angle2)
  return (angle1 + angle2) % twicePi
end

local function AngleXYXY(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  return mAtan2(dy, dx), dx, dy
end

local function AngleDist(angle1, angle2)
  -- return ((angle1 + pi - angle2) % twicePi) - pi
  -- angle = 180 - abs(abs(a1 - a2) - 180); 
  local a = angle2 - angle1
  if a > pi then
  	a = a - twicePi
  elseif a < -pi then
  	a = a + twicePi
  end
  return a
end

function meanAngle (angleList)
	local sumSin, sumCos = 0, 0
	for i, angle in pairs(angleList) do
		sumSin = sumSin + mSin(angle)
		sumCos = sumCos + mCos(angle)
	end
	return mAtan2(sumSin, sumCos)
end

local function CirclePos(cx, cy, dist, angle)
  angle = angle or mRandom() * twicePi
  local x = cx + dist * mCos(angle)
  local y = cy + dist * mSin(angle)
  return x, y
end

local function DistanceSq(x1, y1, x2, y2)
  local dx = mAbs(x2 - x1)
  local dy = mAbs(y2 - y1)
  return (dx*dx) + (dy*dy)
end

local function loadWormReDir()
	if not VFS.FileExists('data/sand_worm_redirect_size.lua') or not VFS.FileExists('data/sand_worm_redirect_matrix.u8') then
		return
	end
	local reDirSize = VFS.Include('data/sand_worm_redirect_size.lua')
	local reDirRead = VFS.LoadFile('data/sand_worm_redirect_matrix.u8')
	local reDirTable = VFS.UnpackU8(reDirRead, 1, reDirSize)
	local reDir = {}
	for i=1, reDirSize, 4 do
		local cx = reDirTable[i] * cellSize
		local cz = reDirTable[i+1] * cellSize
		local bx = reDirTable[i+2] * cellSize
		local bz = reDirTable[i+3] * cellSize
--		spEcho(cx, cz, bx, bz)
		if reDir[cx] == nil then reDir[cx] = {} end
		reDir[cx][cz] = { bx, bz }
	end
	return reDir
end

local function getWormPathGraph(nodeSize)
	local halfNodeSize = nodeSize / 2
	local testSize = 16
	local graph = {}
	local id = 1
	for cx = 0, sizeX-nodeSize, nodeSize do
		local x = cx + halfNodeSize
		for cz = 0, sizeZ-nodeSize, nodeSize do
			local z = cz + halfNodeSize
			local sand = true
			for tx = cx, cx+nodeSize, testSize do
				for tz = cz, cz+nodeSize, testSize do
					local groundType = spGetGroundInfo(tx, tz)
					if not sandType[groundType] then
						sand = false
						break
					end
				end
				if not sand then break end
			end
			if sand then
				local node = { x = x, y = z, id = id}
				id = id + 1
				tInsert(graph, node)
				-- spMarkerAddPoint(x, 100, z, nodeSize)
			end
		end
	end
	return graph
end

local function getSandUnitValues()
	local vals = {}
	local inedible = {}
	local highest = 0
	local lowest = 999999
	local sum = 0
	local num = 0
	for uDefID, uDef in pairs(UnitDefs) do
		local cost = mFloor( uDef.metalCost + (uDef.energyCost / 50) )
		if cost > highest then
			highest = cost
		end
		if cost < lowest then
			lowest = cost
		end
		sum = sum + cost
		num = num + 1
	end
	local range = highest - lowest
	local average = sum / num
	local middle = (average - lowest) / range
	middle = middle ^ 0.3
	-- spEcho(highest, lowest, range, average, middle)
	for uDefID, uDef in pairs(UnitDefs) do
		if wormEmergeUnitNames[uDef.name] then
			inedible[uDefID] = true
		elseif uDef.name == wormUnderUnitName then
			inedible[uDefID] = true
		elseif uDef.name == wormTriggerUnitName then
			inedible[uDefID] = true
		elseif uDef.showPlayerName then --string.find(string.lower(uDef.humanName), "commander") then
			-- spEcho(uDef.name, uDef.humanName, "is commander")
			vals[uDefID] = commanderValue
			if not wormEatCommander then
				inedible[uDefID] = true
			end
		elseif uDef.extractsMetal > 0 then
			vals[uDefID] = mexValue
			if not wormEatMex then
				inedible[uDefID] = true
			end
		elseif uDef.moveDef and uDef.moveDef.family == "hover" then
			vals[uDefID] = hoverValue
		else
			local cost = mFloor( uDef.metalCost + (uDef.energyCost / 50) )
			local fract = (cost - lowest) / range
			fract = fract ^ middle
			vals[uDefID] = mFloor(distancePerValue * fract)
		end
--		spEcho(uDef.name, uDef.humanName, uDef.tooltip, vals[uDefID], cost, uDef.metalCost, uDef.energyCost, uDef.mass, fract)
	end
	return vals, inedible
end

local function createFullBulgeStamp(size)
	local stamp = {}
	for xi=-size,size do
		local x = xi * 8
		local dx = mAbs(xi) / size
		for zi=-size,size do
			local z = zi * 8
			local dz = mAbs(zi) / size
			local d = mSqrt((dx^2) + (dz^2))
			local h
			if d > 1 then
				h = 0
			else
				h = 1-(d^3)
			end
			tInsert(stamp, { x = x, z = z, h = h })
		end
	end
	return stamp
end

local function createRippleExpansionMap()
	local emap = {}
	emap = {
		{x = -8, z = -8, h = 0.71}, {x = 0, z = -8, h = 1}, {x = 8, z = -8, h = 0.71},
		{x = -8, z = 0, h = 1},								{x = 8, z = 0, h = 1},
		{x = -8, z = 8, h = 0.71}, {x = 0, z = 8, h = 1}, {x = 8, z = 8, h = 0.71}
	}
	return emap
end

local function mapClampX(x)
	return mMax(mMin(x, sizeX), 0)
end

local function mapClampZ(z)
	return mMax(mMin(z, sizeZ), 0)
end

local function mapClampXZ(x, z)
	return mapClampX(x), mapClampZ(z)
end

local function nodeHere(x, z, graph, nodeSize)
	x, z = mapClampXZ(x, z)
	local nx = (x - (x % nodeSize)) + mCeil(nodeSize/2)
	local nz = (z - (z % nodeSize)) + mCeil(nodeSize/2)
	local node = astar.find_node(nx, nz, graph) or astar.nearest_node(nx, nz, graph)
	-- spEcho(x, z, nx, nz, nodeSize, mCeil(nodeSize/2), node)
	return node
end

local function nearestSand(x, z)
	local groundType, _ = spGetGroundInfo(x, z)
	if sandType[groundType] then return x, z end
	if wormReDir then
		-- also clamps to map bounds
		local cx = mMax(mMin(x, sizeX-halfCellSize), halfCellSize)
		local cz = mMax(mMin(z, sizeZ-halfCellSize), halfCellSize)
		cx = cx - (cx % cellSize)
		cz = cz - (cz % cellSize)
		if wormReDir[cx] then
			if wormReDir[cx][cz] then
				return wormReDir[cx][cz][1]+halfCellSize, wormReDir[cx][cz][2]+halfCellSize
			end
		end
	end
	local node = astar.nearest_node(x, z, wormSizes[1].wormGraph)
	return node.x, node.y
end

local function nearestRock(x, z, minDist, maxDist)
	minDist = minDist or 16
	maxDist = maxDist or 224
	x, z = mapClampXZ(x, z)
	if not sandType[spGetGroundInfo(x,z)] then return x, z end
	-- search for rock
	local ax, az, aa
	for dist = minDist, maxDist, 16 do
		for a = 0, twicePi, quarterPi do
			local sx, sz = CirclePos(x, z, dist, a)
			if not sandType[spGetGroundInfo(sx,sz)] then
				if not ax then
					ax, az, aa = sx, sz, a
				elseif mAbs(AngleDist(a, aa)) > halfPi*1.5 then
					return ax, az, sx, sz
				end
			end
		end
	end
	if ax then return ax, az end
	return x, z
end

local function edibleUnit(emergedUnitID, uID)
	-- spEcho(UnitDefs[spGetUnitDefID(uID)].name)
	local wID = isEmergedWorm[emergedUnitID]
	-- spEcho("excludeUnits?", excludeUnits[uID])
	if excludeUnits[uID] and excludeUnits[uID] ~= wID then return end
	if wID then
		local w = worm[wID]
		if w then
			-- spEcho("badTargets?", w.size.badTargets[uID])
			if w.size.badTargets[uID] then return end
		end
	end
	local uDefID = spGetUnitDefID(uID)
	if not uDefID then return end
	-- spEcho("inedibleDefIDs?", inedibleDefIDs[uDefID])
	if inedibleDefIDs[uDefID] then return end
	local ux, uy, uz = spGetUnitPosition(uID)
	if not sandType[spGetGroundInfo(ux,uz)] then return end
	if uy - spGetGroundHeight(ux,uz) > biteHeight then return end
	return true
end

local function inWormMouth(x, z)
	for uID, wID in pairs(isEmergedWorm) do
		local w = worm[wID]
		if w then
			local d = DistanceXZ(x, z, w.x, w.z)
			if d < w.size.radius then
				return w
			end
		end
	end
end

local function getWormSizes(sizesByUnitName)
	local sizes = {}
	for unitName, s in pairs(sizesByUnitName) do
		local uDef = UnitDefNames[unitName]
		local bulgeStamp = createFullBulgeStamp(mCeil(uDef.radius / 8))
		local nodeSize = math.ceil(uDef.radius * 2.1)
		local wormGraph = getWormPathGraph(nodeSize)
		local nodeDist = 1+ (2 * (nodeSize^2))
		local valid_node_func = function ( node, neighbor ) 
			if astar.distance( node.x, node.y, neighbor.x, neighbor.y) < nodeDist then
				return true
			end
			return false
		end
		local size = { radius = uDef.radius, diameter = uDef.radius * 2, maxMealSize = mCeil(uDef.radius * 0.888), bulgeStamp = bulgeStamp, rippleHeight = uDef.radius / 20, bulgeHeight = uDef.radius / 120, unitName = unitName, badTargets = {}, wormGraph = wormGraph, valid_node_func = valid_node_func, nodeSize = nodeSize }
		sizes[s] = size
	end
	return sizes
end

local function occupyBox(uSize, ux, uz, dx, dz)
	local insideBox = false
	for ib, box in pairs(occupiedBoxes) do
		if ux > box.xmin and ux < box.xmax and uz > box.zmin and uz < box.zmax then
			box.count = box.count + 1
			if uSize > box.largestUnitSize then box.largestUnitSize = uSize end
			box.dxSum = box.dxSum + dx
			box.dzSum = box.dzSum + dz
			insideBox = true
			break
		end
	end
	if not insideBox then
		local box = { 
			x = ux,
			z = uz,
			xmin = mapClampX(ux - halfBoxSize),
			xmax = mapClampX(ux + halfBoxSize), 
			zmin = mapClampZ(uz - halfBoxSize),
			zmax = mapClampZ(uz + halfBoxSize),
			count = 1,
			largestUnitSize = uSize,
			dxSum = dx,
			dzSum = dz,
		}
		tInsert(occupiedBoxes, box)
	end
end

local function giveTargetToWorms(uID, uSize, uval, ux, uz, dx, dz)
	for wID, w in pairs(worm) do
		if not w.emergedID and not w.size.badTargets[uID] and uSize <= w.size.maxMealSize then
			local x = w.x
			local z = w.z
			local distx = mAbs(ux - x)
			local distz = mAbs(uz - z)
			local dist = mSqrt((distx*distx) + (distz*distz))
			-- local velx, vely, velz, velLength = spGetUnitVelocity(uID)
			-- spEcho(velx, vely, velz, velLength)
			local velx = dx / evalFrequency
			local velz = dz / evalFrequency
			-- velx = (velx + pvelx) / 2
			-- velz = (velz + pvelz) / 2
			local velmult = dist/w.speed
			local farx = ux + (velx * velmult)
			local farz = uz + (velz * velmult)
			local fardist = mSqrt(DistanceSq(w.x, w.z, farx, farz))
			--	spEcho(wID, "sensed unit", uID, "at", ux, uz)
			if fardist - uval < (w.bestDist or 999999) then
				w.bestDist = fardist - uval
				w.targetUnitID = uID
				w.targetUnitData = { ux = ux, uz = uz, uval = uval, dist = dist, velx = velx, velz = velz, velmult = velmult }
			end
		end
	end
end

local function wormTargetting()
	local second = spGetGameSeconds()
	local units = spGetAllUnits()
	local num = 0
	--uncomment the following loop for debug info (along with line farther down)
	-- for uID, b in pairs(sandUnits) down
		-- SendToUnsynced("passSandUnit", uID, nil)
	-- end
	-- do not target units near feeding worms
	excludeUnits = {}
	for uID, wID in pairs(isEmergedWorm) do
		local w = worm[wID]
		if w then
			local y = spGetGroundHeight(w.x, w.z)
			local nearUnits = spGetUnitsInSphere(w.x, y, w.z, w.range*3)
			for _, nuID in pairs(nearUnits) do
				excludeUnits[nuID] = wID
			end
		end
	end
	for wID, w in pairs(worm) do
		w.bestDist = nil
	end
	totalMovement = 0
	sandUnits = {}
	occupiedBoxes = {}
	largestSandUnitSize = 0
	for k, uID in pairs(units) do
		--if unit enters sand, add it to the sand unit table, if it exits, remove it
		if not isEmergedWorm[uID] then
			local ux, uy, uz = spGetUnitBasePosition(uID)
			local groundType, _ = spGetGroundInfo(ux, uz)
			local groundHeight = spGetGroundHeight(ux, uz) 
			if sandType[groundType] and uy < groundHeight + biteHeight then
				local uDefID = spGetUnitDefID(uID)
				if not inedibleDefIDs[uDefID] then
					local uDef = UnitDefs[uDefID]
					local uval = sandUnitValues[uDefID]
					-- local uSize = mCeil(uDef.height * uDef.radius)
					local uSize = mCeil(uDef.radius)
					if uSize > largestSandUnitSize then largestSandUnitSize = uSize end
					local dx, dz = 0, 0
					if sandUnitPosition[uID] then
						-- add how much the unit has moved since last evaluation to total movement sum
						dx = ux - sandUnitPosition[uID].x
						dz = uz - sandUnitPosition[uID].z
						local adx, adz = mAbs(dx), mAbs(dz)
						if adx > 0 or adz > 0 then
							totalMovement = totalMovement + adx + adz + uDef.metalCost
						end
					end
					sandUnitPosition[uID] = {x = ux, z = uz}
					sandUnits[uID] = true
					num = num + 1
					occupyBox(uSize, ux, uz, dx, dz) -- sort into non-grid boxes of units
					if not excludeUnits[uID] then giveTargetToWorms(uID, uSize, uval, ux, uz, dx, dz) end
	--				SendToUnsynced("passSandUnit", uID, uval)
				end
			else
				sandUnitPosition[uID] = nil
			end
		end
	end
	-- perform vector calcs on best worm targets
	for wID, w in pairs(worm) do
		if w.targetUnitData then
			local u = w.targetUnitData
			if u.uval < 0 then
				-- for negative values (hovers, mexes, and commanders)
				-- target badly, like a radar blip
				local j = -u.uval
				local jx = (mRandom() * j * 2) - j
				local jz = (mRandom() * j * 2) - j
				w.tx, w.tz = nearestSand(u.ux + jx, u.uz + jz)
			else
				local veltestmult = u.velmult / 2
				local testx = u.ux + (u.velx * veltestmult)
				local testz = u.uz + (u.velz * veltestmult)
				local testa = AngleXYXY(w.x, w.z, testx, testz)
				local cura = AngleXYXY(w.x, w.z, u.ux, u.uz)
				local adist = AngleDist(cura, testa)
				-- spEcho(cura, testa, adist)
				if mAbs(adist) > halfPi then
					w.tx, w.tz = u.ux, u.uz
					-- spEcho("adist above halfpi, using ux, uz")
				elseif mAbs(adist) > quarterPi then
					local fortyFive = quarterPi
					if adist < 0 then fortyFive = -quarterPi end
					local newa = AngleAdd(cura, fortyFive)
					w.tx, w.tz = CirclePos(w.x, w.z, u.dist, AngleAdd(cura, fortyFive))
					-- spEcho("adist above quarterpi", fortyFive, newa)
				else
					w.tx, w.tz = CirclePos(w.x, w.z, u.dist, testa)
					-- spEcho("adist below quarterpi, using testa")
				end
				-- w.tx, w.tz = u.ux, u.uz
			end
		end
	end
	return num, mCeil(totalMovement)
end

local function signLightning(x, z)
	local y = spGetGroundHeight(x, z)
	local lx = 0
	local lz = 0
	local weaponDefID = WeaponDefNames["wormlightning"].id
	for ly=0,2000,48 do
		local xrand = (2*mRandom()) - 1
		local zrand = (2*mRandom()) - 1
		local dx = xrand * 48
		local dz = zrand * 48
		local projectileID = spSpawnProjectile(weaponDefID, {["pos"] = {x+lx, y+ly, z+lz}, ["end"] = {x+lx+dx, y+ly+48, z+lz+dz}, ttl = 15, team = gaiaTeam, maxRange = 49, startAlpha = 1, endAlpha = 1, })
		-- spSetProjectilePosition(projectileID, x+lx, y+ly, z+lz)
		spSetProjectileTarget(projectileID, x+lx+dx, y+ly+48, z+lz+dz)
		lx = lx + dx
		lz = lz + dz
	end
	spSpawnCEG("WORMSIGN_FLASH",x,y,z,0,1,0,2,0)
end


local function signArcLightning(x, z, arcLength, heightDivisor, segLength, lightningCeg, flashCeg)
	arcLength = arcLength or 48
	heightDivisor = heightDivisor or 1
	segLength = segLength or 16
	lightningCeg = lightningCeg or "WORMSIGN_LIGHTNING_SMALL"
	flashCeg = flashCeg or "WORMSIGN_FLASH_SMALL"
	local y = spGetGroundHeight(x, z)
	local xrand = (2*mRandom()) - 1
	local zrand = (2*mRandom()) - 1
	local ly = 0
	local lx = 0
	local lz = 0
	local i = 0
	local gh = y+arcLength
	repeat
		ly =  arcLength * ((0.25-(((i/arcLength)-0.5)^2)) / heightDivisor)
		local cx = x+lx
		local cy = y+ly
		local cz = z+lz
		spSpawnCEG(lightningCeg,cx,cy,cz,0,1,0,2,0)
		if i % segLength == 0 then
			xrand = (2*mRandom()) - 1
			zrand = (2*mRandom()) - 1
			gh = spGetGroundHeight(cx,cz)
		end
		lx = lx + xrand
		lz = lz + zrand
		i = i + 1
	until cy < gh
	spSpawnCEG(flashCeg,x,y,z,0,1,0,2,0)
	spSpawnCEG(flashCeg,x+lx-xrand,y+ly,z+lz-zrand,0,1,0,2,0)
end

local function wormBigSign(w)
	local sx = w.x
	local sz = w.z
	-- signLightning(sx, sz)
	local minArc = mCeil(w.size.radius * 8)
	local maxArc = mCeil(w.size.radius * 10)
	signArcLightning( sx, sz, mRandom(minArc,maxArc), 1+mRandom(), 32, "WORMSIGN_LIGHTNING", "WORMSIGN_FLASH" )
	local snd = thunderSnds[mRandom(#thunderSnds)]
	spPlaySoundFile(snd,0.5,sx,sy,sz)
end

local function wormMediumSign(w)
	if not w then return end
	local sx, sz = CirclePos(w.x, w.z, w.size.radius)
	local num = mRandom(1,2)
	local minArc = mCeil(w.size.radius * 3)
	local maxArc = mCeil(w.size.radius * 6)
	for n=1,num do
		signArcLightning( sx, sz, mRandom(minArc,maxArc), mRandom(1,3), 24 )
	end
	local snd = lightningSnds[mRandom(#lightningSnds)]
	spPlaySoundFile(snd,0.1,sx,sy,sz)
end

local function wormLittleSign(w, sx, sz)
	if not w and not sx then return end
	sx = sx or w.x
	sz = sz or w.z
	local num = mRandom(1,2)
	local minArc, maxArc
	if w then
		minArc = mCeil(w.size.radius / 1.5)
		maxArc = mCeil(w.size.radius * 2.5)
	else
		minArc = 24
		maxArc = 96
	end
	for n=1,num do
		signArcLightning( sx, sz, mRandom(minArc, maxArc), mRandom(2,5) )
	end
	local snd = lightningSnds[mRandom(#lightningSnds)]
	spPlaySoundFile(snd,0.1,sx,sy,sz)
end

local function initializeRippleMap()
	for rx = 0, sizeX/8 do
		rippleMap[rx] = {}
		for rz = 0, sizeZ/8 do
			rippleMap[rx][rz] = 0
		end
	end
end

local function addRipple(x, z, hmod)
	if hmod > 0.1 then
		local rx = mFloor(x / 8)
		local rz = mFloor(z / 8)
		if not rippleMap[rx] then
			-- spEcho("bad rx in ripplemap", rx)
			return
		end
		if not rippleMap[rx][rz] then
			-- spEcho("bad rz in ripplemap", rz)
			return
		end
		-- if rippleMap[rx][rz] == 0 then
			tInsert(newRipples, {rx, rz, hmod})
		-- end
		-- rippleMap[rx][rz] = rippleMap[rx][rz] + hmod
		-- x = rx * 8
		-- z = rz * 8
		-- spAdjustHeightMap(x, z, x+8, z+8, hmod)
	end
end

local function signStampRipple(w, mult, lightning)
	local x, z = w.x, w.z
	local bulgeStamp = w.size.bulgeStamp
	local rippleHeight = w.size.rippleHeight
	local hmodBase = rippleHeight*mult
	if hmodBase > 0.1 then
		x = x - (x % 8)
		z = z - (z % 8)
		local lmult
		if lightning then lmult = mult / 65 end
		local num = mRandom(rippleNumMin,rippleNumMax)
		-- local num = 8
		for n=1,num do
			stamp = bulgeStamp[mRandom(1,#bulgeStamp)]
			local bx, bz, bh = stamp.x, stamp.z, stamp.h
			if bh > 0 then
				local sx = x + bx
				local sz = z + bz
				local gt, _ = spGetGroundInfo(sx, sz)
				if sandType[gt] then
					local hmod = bh * hmodBase
					addRipple(sx, sz, hmod)
					if lightning then
						if mRandom() < (0.001 + lmult) then
							wormLittleSign(w, sx, sz)
						end
					end
				end
			end
		end
	end
end

local function writeNewRipples()
	if #newRipples == 0 then return end
	spSetHeightMapFunc(function()
		for id, vals in pairs(newRipples) do
			local rx = vals[1]
			local rz = vals[2]
			local x = rx * 8
			local z = rz * 8
			local hmod = vals[3]
			spAddHeightMap(x, z, hmod)
			if rippleMap[rx][rz] == 0 then
				tInsert(rippled, {rx, rz})
			end
			rippleMap[rx][rz] = rippleMap[rx][rz] + hmod
		end
	end)
	newRipples = {}
end

local function signUnRippleExpand()
--	local numripples = #rippled
--	if numripples > 0 then spEcho(#rippled) end
	spSetHeightMapFunc(function()
		for id = #rippled, 1, -1 do
			local vals = rippled[id]
			local rx = vals[1]
			local rz = vals[2]
			local x = rx * 8
			local z = rz * 8
			local hmod = rippleMap[rx][rz]
			if hmod >= 0.2 then
				local hsub = hmod / 2
				spAddHeightMap(x, z, -hsub)
				rippleMap[rx][rz] = hsub
				local i = mRandom(1,8)
				local ex = x + rippleExpand[i].x
				local ez = z + rippleExpand[i].z
				local eh = hsub * rippleExpand[i].h
				addRipple(ex, ez, eh)
			else
				spAddHeightMap(x, z, -hmod)
				rippleMap[rx][rz] = 0
				tRemove(rippled, id)
			end
		end
	end)
end

local function signStamp(w)
	local x, z, bh = w.x, w.z, w.size.bulgeHeight*0.1 + w.size.bulgeHeight*mRandom()
	x, z = CirclePos(x, z, w.size.radius*0.1)
	spSetHeightMapFunc(function()
		for _, stamp in pairs(w.size.bulgeStamp) do
			local sx, sz = x+stamp.x, z+stamp.z
			local gt, _ = spGetGroundInfo(sx, sz)
			if sandType[gt] then
				spAddHeightMap(x+stamp.x, z+stamp.z, stamp.h*bh)
			end
		end
	end)
	local gf = spGetGameFrame()
	tInsert(oldStamps, {x = x, z = z, bulgeHeight = bh, stamp = w.size.bulgeStamp, endFrame = gf + 12, halfFrame = gf + 6 })
end

local function clearOldStamps()
	local gf = spGetGameFrame()
	spSetHeightMapFunc(function()
		for i = #oldStamps, 1, -1 do
			local old = oldStamps[i]
			local x, z, bh = old.x, old.z, old.bulgeHeight
			if gf >= old.endFrame then
				for _, stamp in pairs(old.stamp) do
					local sx, sz = x+stamp.x, z+stamp.z
					local gt, _ = spGetGroundInfo(sx, sz)
					if sandType[gt] then
						spAddHeightMap(x+stamp.x, z+stamp.z, -(stamp.h*bh)/2)
					end
				end
				tRemove(oldStamps, i)
			elseif not old.halved and gf >= old.halfFrame then
				for _, stamp in pairs(old.stamp) do
					local sx, sz = x+stamp.x, z+stamp.z
					local gt, _ = spGetGroundInfo(sx, sz)
					if sandType[gt] then
						spAddHeightMap(x+stamp.x, z+stamp.z, -(stamp.h*bh)/2)
					end
				end
				old.halved = true
			end
		end
	end)
end

local function normalizeVector(vx, vz)
	local dist = mSqrt( (vx^2) + (vz^2) )
	if dist == 0 then return vx, vz end
	vx = vx / dist
	vz = vz / dist
	return vx, vz
end

local function wormMoveUnderUnit(w)
	if not w.underUnitID then return end
	spSetUnitPosition(w.underUnitID, w.x, w.z)
	if w.vx then
		-- spSetUnitVelocity(w.underUnitID, w.vx, 0, w.vz)
		spMoveCtrlSetVelocity(w.underUnitID, w.vx, 0, w.vz)
	end
end

local function wormDirect(w)
	if w.emergedID then return end
	if not w.tx then
		-- spEcho("no target, using random target")
		w.tx, w.tz = nearestSand(mRandom(halfCellSize, sizeX-halfCellSize), mRandom(halfCellSize, sizeZ-halfCellSize))
	end
	local x = w.x
	local z = w.z
	local tx = w.tx
	local tz = w.tz
	local r = w.size.radius
	if not (tx < x + r and tx > x - r and tz < z + r and tz > z - r) then
		-- not near the target yet
		if not w.path or (w.xPathed ~= tx and w.zPathed ~= tz) then
			-- need a new path
			local graph = w.size.wormGraph
			local startNode = nodeHere(x, z, graph, w.size.nodeSize) or w.targetNode
			if startNode then
				local goalNode = nodeHere(tx, tz, graph, w.size.nodeSize)
				if goalNode and startNode ~= goalNode then
					w.path = astar.path(startNode, goalNode, graph, false, w.size.valid_node_func)
					if w.path then
						if not w.path[2] then
							w.pathStep = 1
						else
							w.pathStep = 2
						end
						w.targetNode = w.path[w.pathStep]
						w.xPathed, w.zPathed = tx, tz
						w.clearShot = true
						if #w.path > 2 then
							for i = 2, #w.path-1 do
								local node = w.path[i]
								if node and #node.neighbors < 8 then
									-- spEcho("path has rocks")
									w.clearShot = false
									break
								end
							end
						end
					end
				end
			end
		end 
		if w.targetNode and not w.clearShot then
			-- have a path and it's not clear of rocks
			local nx, nz = w.targetNode.x, w.targetNode.y
			if nx < x + r and nx > x - r and nz < z + r and nz > z - r and w.pathStep < #w.path then
				-- we're at the targetNode and it's not the last node
				w.pathStep = w.pathStep + 1
				w.targetNode = w.path[w.pathStep]
				-- spEcho("going to next node", w.pathStep, tx, tz)
			else
				-- still need to get to the targetNode
				tx, tz = w.targetNode.x, w.targetNode.y
			end
		end
	end
	local distx = tx - x
	local distz = tz - z
	w.vx, w.vz = normalizeVector(distx, distz)
end

local function passWormSign(x, z)
	local allyList = spGetAllyTeamList()
	local y = spGetGroundHeight(x, z)
	for k, aID in pairs(allyList) do
		local inRadar = spIsPosInRadar(x, y, z, aID)
		local inLos = spIsPosInAirLos(x, y, z, aID)
		if inRadar or inLos then
			SendToUnsynced("passSign", aID, x, y, z, inLos)
		end
	end
	SendToUnsynced("passSpectatorSign", x, y, z)
end

local function wormSpawn(x, z)
	local w = { 1 }
	local id = 0
	repeat
		id = id + 1
		w = worm[id]
	until not w
	if id <= maxWorms then
		local box
		if x and z then
			-- we're all fine here, have position to spawn at
		elseif #occupiedBoxes > 0 then
			local highestDist = 0
			local highestBox
			for _, b in pairs(occupiedBoxes) do
				local lowestDist
				for _, w in pairs(worm) do
					local dist = DistanceSq(b.x, b.z, w.x, w.z)
					if not lowestDist or dist < lowestDist then
						lowestDist = dist
					end
				end
				if lowestDist and lowestDist > highestDist then
					highestDist = lowestDist
					highestBox = b
				end
			end
			box = highestBox or occupiedBoxes[mRandom(#occupiedBoxes)]
			local movementAngle = mAtan2(box.dzSum, box.dxSum)
			x, z = CirclePos(box.x, box.z, wormSpawnDistance, movementAngle)
		else
			x, _, z = randomXYZ()
		end
		local spawnX, spawnZ = nearestSand(x, z)
		local wID = id
		local speed = wormSpeed + (mRandom(-wormSpeedLowerBias, wormSpeedUpperBias) / 100)
		local size = 1
		for s, sizeParams in ipairs(wormSizes) do
			local largest = largestSandUnitSize
			if box then largest = box.largestUnitSize end
			if sizeParams.maxMealSize >= largest then
				size = s
				break
			end
		end
		-- spEcho(largestSandUnitSize, box.largestUnitSize, wormSizes[size].maxMealSize, size)
		local uDef = UnitDefNames[wormSizes[size].unitName]
		local range = mCeil(((speed * attackEvalFrequency) / 2) + (uDef.radius * 1.4))
		local second = spGetGameSeconds()
		local frame = spGetGameFrame()
		local w = { 
			x = spawnX, z = spawnZ,
			endSecond = second + baseWormDuration,
			signSecond = second + mRandom(signFreqMin, signFreqMax),
			nextAttackEval = frame + attackEvalFrequency,
			bellyCount = 0,
			speed = speed,
			range = range,
			size = wormSizes[size],
			underUnitID = spCreateUnit(wormUnderUnitName, spawnX, spGetGroundHeight(spawnX, spawnZ), spawnZ, 0, gaiaTeam),
		}
		-- spSetUnitRadiusAndHeight(w.underUnitID, mCeil(w.size.radius*0.8), mCeil(w.size.radius*0.1))
		Spring.SetUnitMaxHealth(w.underUnitID, uDef.health)
		spMoveCtrlEnable(w.underUnitID)
		-- spSetUnitCollisionVolumeData( w.underUnitID,
		-- 	w.size.diameter, w.size.radius, w.size.diameter,
		-- 	0, w.size.radius*0.5, 0,
		-- 	2, 1, 1 )
		if box then
			-- go straight for it before first eval cycle
			w.tx, w.tz = box.x, box.z
		end
		worm[wID] = w
		wormBigSign(w)
		-- spEcho(speed, range)
		-- passWormSign(spawnX, spawnZ)
	end
end

local function wormDie(wID)
	local w = worm[wID]
	if w then
		if w.underUnitID then
			killMeNow[w.underUnitID] = spGetGameFrame() + 1
		end
	end
	worm[wID] = nil
	nextPotentialEvent = nextPotentialEvent + wormEventFrequency
--	SendToUnsynced("passWorm", wID, nil)
end

local function wormAttack(targetID, wID)
	local w = worm[wID]
	local awayFromRock = w.size.radius * 1 * 1.6
	local x, y, z = spGetUnitPosition(targetID)
	local rockx, rockz, rockbx, rockbz = nearestRock(x, z)
	if rockbx then
		local rbdx, rbdz = x - rockbx, z - rockbz -- reverse distance, to get angle from rock to unit
		local rockbdist = mSqrt((rbdx*rbdx)+(rbdz*rbdz))
		if rockbdist < w.size.radius then
			-- not enough room to attack, ignore target for 15 seconds
			w.size.badTargets[targetID] = spGetGameSeconds() + 15
			return
		elseif rockbdist < awayFromRock then
			rockx = (rockx + rockbx) / 2
			rockz = (rockz + rockbz) / 2
		end
	end
	local rockdist, rdx, rdz = 0, 0, 0
	if rockx ~= x then
		rdx, rdz = x - rockx, z - rockz -- reverse distance, to get angle from rock to unit
		rockdist = mSqrt((rdx*rdx)+(rdz*rdz))
	end
	-- emerge worm far enough from rock
	-- spMarkerAddPoint(x, 100, z, "sand")
	-- spMarkerAddPoint(rockx, 100, rockz, "rock")
	-- spEcho("attack!", x, z, rockx, rockz, rdx, rdz, rockdist, awayFromRock)
	if rockdist > 0 and rockdist < awayFromRock then
		local rockangle = mAtan2(rdz, rdx)
		x, z = CirclePos(rockx, rockz, awayFromRock, rockangle)
		-- spMarkerAddPoint(x, 100, z, "new")
		y = spGetGroundHeight(x, z)
	end
	local unitTeam = spGetUnitTeam(targetID)
	local attackerID = spCreateUnit(w.size.unitName, x, y, z, 0, gaiaTeam, false)
	if w.underUnitID then
		-- hide underworm
		spMoveCtrlSetPosition(w.underUnitID, w.x, -5000, w.z)
	end
	isEmergedWorm[attackerID] = wID
	w.emergedID = attackerID
	w.x, w.z = x, z
	w.vx, w.vz = 0, 0
end

local function doWormMovementAndRipple(gf, second)
	for wID, w in pairs(worm) do
		if w.vx and not w.emergedID then
			w.x = mapClampX(w.x + (w.vx*w.speed))
			w.z = mapClampZ(w.z + (w.vz*w.speed))
			-- Spring.Echo(w.x, w.z)
			-- SendToUnsynced("passWorm", wID, w.x, w.z, w.vx, w.vz, w.vx, w.vz, w.tx, w.tz, w.signSecond, w.endSecond ) --uncomment this to show the worms positions, vectors, and targets real time (uses gui_worm_debug.lua)
		end
		-- if not w.emergedID then
			-- signStamp(w)
		-- end
		local rippleMult = nil
		if second > w.signSecond-4 and second < w.signSecond+3 then -- and not w.emergedID then
			-- if it's one second before or after worm sign second, ripple sand
			lightning = mRandom() < 0.4
			rippleMult = 1 / (1 + mAbs(second - w.signSecond))
		elseif w.vx and not w.emergedID then
			-- when moving, always ripple sand a little with occasional ground lightning
			lightning = mRandom() < 0.3
			rippleMult = 0.2
		end
		if rippleMult then
			signStampRipple(w, rippleMult, lightning)
			if mRandom() < rippleMult * 0.2 then
				local cegx = mapClampX(w.x + mRandom(w.size.diameter) - w.size.radius)
				local cegz = mapClampZ(w.z + mRandom(w.size.diameter) - w.size.radius)
				local groundType, _ = spGetGroundInfo(cegx, cegz)
				if sandType[groundType] then
					local cegy = spGetGroundHeight(cegx, cegz)
					spSpawnCEG("sworm_dust",cegx,cegy,cegz,0,1,0,30,0)
				end
			end
		end
		if w.emergedID and mRandom() < 0.01 then
			wormMediumSign(w)
		end
	end
end

local function evalCycle(gf, second)
	if gf % evalFrequency ~= 0 then return end
	-- reset bad targets
	for s, size in pairs(wormSizes) do
		for uID, endSecond in pairs(size.badTargets) do
			if second >= endSecond then
				size.badTargets[uID] = nil
			end
		end
	end

	-- handle deaths
	for wID, w in pairs(worm) do
		if second >= w.endSecond then
			wormDie(wID)
		end
	end
	
	-- do targetting of units on sand
	numSandUnits, totalSandMovement = wormTargetting()

	-- calculate worm anger & dependent variables
	wormAnger = ((numSandUnits + 1) / unitsPerWormAnger) + ((totalSandMovement + 1) / movementPerWormAnger)
	maxWorms = mMin(3, mCeil(wormAnger))
	wormBellyLimit = mMin(9, mCeil(1 + mSqrt(wormAnger * 21)))
	wormSpeedLowerBias = mMax(0, 10 - mFloor(wormAnger * 4))
	wormChance = mMin(1, 0.5 + mSqrt(wormAnger / 12))
	if wormAnger > 2 then
		wormEventFrequency = 5
	else
		wormEventFrequency = 5 + (0.55 * ((wormAnger - 3) ^ 4))
	end
	wormEventFrequency = mMin(60, mMax(5, mCeil(wormEventFrequency)))
	-- spEcho(maxWorms, wormBellyLimit, wormSpeedLowerBias, wormChance, wormEventFrequency, wormAnger, numSandUnits, totalSandMovement, unitsPerWormAnger, movementPerWormAnger, wormAggression)
	-- spawn worms
	if numSandUnits > 0 and second >= nextPotentialEvent then
--			spEcho("potential worm event...")
		if mRandom() < wormChance then
			wormSpawn()
		end
		nextPotentialEvent = second + wormEventFrequency
	end
end

local function doWormAttacks(gf, second)
	if numSandUnits == 0 then return end
	local alreadyAttacked = {}
	for wID, w in pairs(worm) do
		if not w.emergedID and gf >= w.nextAttackEval then
			w.nextAttackEval = gf + attackEvalFrequency
			local wx = w.x
			local wz = w.z
			local wy = spGetGroundHeight(wx, wz)
			local unitsNearWorm = spGetUnitsInSphere(wx, wy, wz, w.range)
			local bestVal = -99999
			local bestID
			for k, uID in pairs(unitsNearWorm) do
				local uDefID = spGetUnitDefID(uID)
				local uDef = UnitDefs[uDefID]
				if wormEmergeUnitNames[uDef.name] then
					-- do not attack units near other emerged worms
					bestID = nil
					break
				elseif not inedibleDefIDs[uDefID] and not alreadyAttacked[uID] and (excludeUnits[uID] == wID or not excludeUnits[uID]) and not w.size.badTargets[uID] then
					local uSize = mCeil(uDef.radius)
					if uSize <= w.size.maxMealSize then
						local x, y, z = spGetUnitPosition(uID)
						local groundType, _ = spGetGroundInfo(x, z)
						if sandType[groundType] then
							local uval = sandUnitValues[uDefID]
							if uval > bestVal then
								bestID = uID
								bestVal = uval
							end
						end
					end
				end
			end
			if bestID then
				w.signSecond = second + 1 -- for ground ripples
				wormAttack(bestID, wID)
				-- if (Script.UnitScript('getWorm')) then
			 --        Script.LuaUI.myevent(666)
			 --   end
				alreadyAttacked[bestID] = true
			end
		end
	end
end


-- synced
if gadgetHandler:IsSyncedCode() then

function gadget:Initialize()
	spMoveCtrlEnable = Spring.MoveCtrl.Enable
	spMoveCtrlSetVelocity = Spring.MoveCtrl.SetVelocity
	spMoveCtrlSetPosition = Spring.MoveCtrl.SetPosition
	GG.wormEdibleUnit = edibleUnit
	local mapOptions = spGetMapOptions()
	if mapOptions then
		if mapOptions.sand_worms == "0" then
			areWorms = false
		end
		if mapOptions.sworm_aggression then wormAggression = tonumber(mapOptions.sworm_aggression) end
		movementPerWormAnger = 100000 / wormAggression
		if mapOptions.sworm_worm_speed then wormSpeed = tonumber(mapOptions.sworm_worm_speed) end
		if mapOptions.sworm_eat_mex == "1" then wormEatMex = true end
		if mapOptions.sworm_eat_commander == "1" then wormEatCommander = true end
		-- SendToUnsynced("passWormInit", evalFrequency, wormSpeed, 65) -- uncomment for showing worm positions with debug widget
	end
	if not areWorms then
		spEcho("Sand worms are not enabled. Sand worm gadget disabled.")
		gadgetHandler:RemoveGadget()
		return
	end
	sandUnitValues, inedibleDefIDs = getSandUnitValues()
	gaiaTeam = spGetGaiaTeamID()
	wormReDir = loadWormReDir()
	astar = VFS.Include('a-star-lua/a-star.lua')
	wormSizes = getWormSizes(wormEmergeUnitNames)
	rippleExpand = createRippleExpansionMap()
	initializeRippleMap()
	nextPotentialEvent = spGetGameSeconds() + wormEventFrequency
	-- clear leftover worm units
	local units = spGetTeamUnits(gaiaTeam)
	for _, uID in pairs(units) do
		local uDefID = spGetUnitDefID(uID)
		local uDef = UnitDefs[uDefID]
		if uDef.name == wormUnderUnitName or wormEmergeUnitNames[uDef.name] then
			spDestroyUnit(uID, false, true)
		end
	end
end

function gadget:GameStart()
	spEcho("sand worm aggression", wormAggression)
	spEcho("sand worm base speed", wormSpeed)
	spEcho("sand worms eat mex?", wormEatMex)
	spEcho("sand worms eat commander?", wormEatCommander)
end

function gadget:GameFrame(gf)
	if not areWorms then return end
	
	local second = spGetGameSeconds()

	for uID, frame in pairs(killMeNow) do
		if gf >= frame then
			spDestroyUnit(uID, false, true)
			killMeNow[uID] = nil
		end
	end	

	if gf % 4 == 0 then
		signUnRippleExpand()
		-- clearOldStamps()
	end

	doWormMovementAndRipple(gf, second) -- worm movement and ground ripple
	writeNewRipples()

	evalCycle(gf, second) -- unit evaluation cycle

	-- calculate vectors and paths
	if gf % 30 == 0 then
		for wID, w in pairs(worm) do
			wormDirect(w)
			wormMoveUnderUnit(w) -- catch up worm under unit to current worm position
		end
	end

	doWormAttacks(gf, second) -- do worm attacks
	
	-- do worm sign lightning and pass wormsign markers to widget
	if gf % signEvalFrequency == 0 then
		for wID, w in pairs(worm) do
			if not w.emergedID then
				-- wormBigSign(w)
				if not w.hasSigned and second >= w.signSecond then
					wormBigSign(w)
					-- passWormSign(w.x, w.z)
					w.hasSigned = true
				end
				if not w.hasQuaked and second > w.signSecond - 4 then
					local y = spGetGroundHeight(w.x, w.z)
					local snd = quakeSnds[mRandom(#quakeSnds)]
					spPlaySoundFile(snd,1.5,w.x,y,w.z)
					w.hasQuaked = true
				end
				if second > w.signSecond + 3 then
					w.signSecond = second + mRandom(signFreqMin, signFreqMax)
					w.hasQuaked = false
					w.hasSigned = false
				end
			end
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	local uDef = UnitDefs[unitDefID]
	if uDef.name == "wormtrigger" then
		local x, y, z = spGetUnitPosition(unitID)
		wormSpawn(x, z) -- to make testing easier
		spDestroyUnit(unitID, false, true)
	end
	-- spEcho(uDef.name, mCeil(uDef.radius), mCeil(uDef.height), mCeil(uDef.radius * uDef.height), mCeil(uDef.radius + uDef.height))
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if unitDefID == UnitDefNames[wormUnderUnitName].id then
		-- spEcho("worm under unit killed")
		for wID, w in pairs(worm) do
			if w.underUnitID == unitID then
				-- spEcho("worm killed")
				w.underUnitID = nil
				wormDie(wID)
				break
			end
		end
		return
	end

	-- remove from units on sand table
	if sandUnits[unitID] then
		sandUnits[unitID] = nil
		sandUnitPosition[unitID] = nil
		numSandUnits = numSandUnits - 1
--		SendToUnsynced("passSandUnit", uID, nil)
	end

	-- remove from emerged worms to allow worm to attack again
	local wID = isEmergedWorm[unitID]
	if wID then
		local w = worm[wID]
		isEmergedWorm[unitID] = nil
		if w then
			w.emergedID = nil
			if attackerID or w.bellyCount >= wormBellyLimit then
				-- worms that have been killed by an attacker die
				-- worms that have eaten too much must take some time to rest & digest
				wormDie(wID)
			else
				-- worm appatite whetted
				w.tx, w.tz = nil, nil
				w.endSecond = spGetGameSeconds() + baseWormDuration
				if w.underUnit then
					spSetUnitHealth(w.underUnitID, spGetUnitHealth(unitID))
					spMoveCtrlSetPosition(w.underUnitID, w.x, spGetGroundHeight(w.x, w.z), w.z)
				end
				wormDirect(w)
			end
		end
	else
		local ux, uy, uz = spGetUnitPosition(unitID)
		local w = inWormMouth(ux, uz)
		if w then
			-- spEcho("unit died in my belly")
			w.bellyCount = w.bellyCount + 1
		end
	end
end


end
-- end synced


-- unsynced
if not gadgetHandler:IsSyncedCode() then

	local function initToLuaUI(_, evalFreq, speed, range)
	  if (Script.LuaUI('passWormInit')) then
		Script.LuaUI.passWormInit(evalFreq, speed, range)
	  end
	end

	local function wormToLuaUI(_, wID, x, z, vx, vz, nvx, nvz, tx, tz, signSecond, endSecond)
	  if (Script.LuaUI('passWorm')) then
		Script.LuaUI.passWorm(wID, x, z, vx, vz, nvx, nvz, tx, tz, signSecond, endSecond)
	  end
	end
	
	local function sandUnitToLuaUI(_, uID, uval)
--		spEcho("unsynced", uID, uval)
	  if (Script.LuaUI('passSandUnit')) then
--	  	spEcho("to send", uID, uval)
		Script.LuaUI.passSandUnit(uID, uval)
	  end
	end
	
	local function signToLuaUI(_, allyID, x, y, z, los)
		local myAlly = spGetLocalAllyTeamID()
		if myAlly == allyID and (Script.LuaUI('passSign')) then
			Script.LuaUI.passSign(x, y, z, los)
		end
	end
	
	local function specSignToLuaUI(_, x, y, z)
		if spGetSpectatingState() then
			Script.LuaUI.passSign(x, y, z, true)
		end
	end

	function gadget:Initialize()
	  gadgetHandler:AddSyncAction('passWormInit', initToLuaUI)
	  gadgetHandler:AddSyncAction('passWorm', wormToLuaUI)
	  gadgetHandler:AddSyncAction('passSandUnit', sandUnitToLuaUI)
	  gadgetHandler:AddSyncAction('passSign', signToLuaUI)
	  gadgetHandler:AddSyncAction('passSpectatorSign', specSignToLuaUI)
	end
	
end