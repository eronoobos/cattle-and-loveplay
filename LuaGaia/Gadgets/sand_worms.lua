function gadget:GetInfo()
  return {
    name      = "Cattle and Loveplay: Sand Worms",
    desc      = "Handles sand worms.",
    author    = "zoggop",
    date      = "February 2012",
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
local wormUnits = { 
	["sworm1"] = 1,
	["sworm2"] = 2,
	["sworm3"] = 3,
	["sworm4"] = 4, }
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
local sandType = "Sand" -- the ground type that worm spawns in
local wormEmergeUnitName = "sworm" -- what unit the worms emerge and attack as
local rippleNumMin = 5
local rippleNumMax = 10
local rippleHeight = 1.5 -- height of ripples that worm makes in the sand
local bulgeHeight = 1.5
local bulgeSize = 7
local bulgeScale = 8
local attackDelay = 22 -- delay between worm attacks
local cellSize = 64 -- for wormReDir
local evalFrequency = 150 -- game frames between evaluation of units on sand
local signEvalFrequency = 12 -- game frames between parts of a wormsign volley (lower value means more lightning strikes per sign)
local attackEvalFrequency = 30 -- game frames between attacking units in range of worm under sand

-- storage variables
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
local worm = {} -- x, z, tx, tz, vx, vz, nvx, nvz, signSecond, lastAttackSecond, endSecond, favoredSide
local signFreqMin = wormSignFrequency / 2 -- the minimum pause between worm signs
local signFreqMax = wormSignFrequency + signFreqMin -- maximum pause between worm signs
local gaiaTeam -- which team is gaia? (set in Initialize())
local wormReDir = {} -- precalculated 2d matrix of where to shunt the worm if it tries to move onto rockf
local isEmergedWorm = {} -- is unitID an emerged attacking worm?
local halfCellSize = cellSize / 2
local sizeX = Game.mapSizeX 
local sizeZ = Game.mapSizeZ
local rippled = {} -- stores references to rippleMap nodes that are actively under transformation
local rippleMap = {}-- stores locations of sand that has been raised by worm to lower it
local bulgeStamp = {}
--local bulgeScaleHalf = bulgeScale / 2
local bulgeX = { 1, 1, -1, -1 }
local bulgeZ = { 1, -1, -1, 1 }

--sounds, see gamedata/sounds.lua
local quakeSnds = { "WmQuake1", "WmQuake2", "WmQuake3", "WmQuake4" }
local lightningSnds = { "WmLightning1", "WmLightning2", "WmLightning3", "WmLightning4", "WmLightning5" }
local thunderSnds = { "WmThunder1", "WmThunder2", "WmThunder3", "WmThunder4", "WmThunder5" }

-- renamed functions
local mAtan2 = math.atan2
local mRandom = math.random
local mAbs = math.abs
local mCos = math.cos
local mSin = math.sin
local pi = math.pi
local twicePi = math.pi * 2
local halfPi = math.pi / 2
local quarterPi = math.pi / 4


-- functions

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
	local reDirSize = VFS.Include('data/sand_worm_redirect_size.lua')
	local reDirRead = VFS.LoadFile('data/sand_worm_redirect_matrix.u8')
	local reDirTable = VFS.UnpackU8(reDirRead, 1, reDirSize)
	local reDir = {}
	for i=1, reDirSize, 4 do
		local cx = reDirTable[i] * cellSize
		local cz = reDirTable[i+1] * cellSize
		local bx = reDirTable[i+2] * cellSize
		local bz = reDirTable[i+3] * cellSize
--		Spring.Echo(cx, cz, bx, bz)
		if reDir[cx] == nil then reDir[cx] = {} end
		reDir[cx][cz] = { bx, bz }
	end
	return reDir
end

local function getWormSizes(sizesByUnitName)
	local sizes = {}
	for unitName, s in pairs(sizesByUnitName) do
		local uDef = UnitDefNames[unitName]
		local size = { maxUnitSize = math.ceil(uDef.radius * 0.888), unitName = unitName }
		sizes[s] = size
	end
	return sizes
end

local function getSandUnitValues()
	local vals = {}
	local highest = 0
	local lowest = 999999
	local sum = 0
	local num = 0
	for uDefID, uDef in pairs(UnitDefs) do
		local cost = math.floor( uDef.metalCost + (uDef.energyCost / 50) )
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
	Spring.Echo(highest, lowest, range, average, middle)
	for uDefID, uDef in pairs(UnitDefs) do
		if uDef.extractsMetal > 0 then
			vals[uDefID] = mexValue
		elseif uDef.canHover then
			vals[uDefID] = hoverValue
		elseif string.find(string.lower(uDef.name), "commander") then
			vals[uDefID] = commanderValue
		else
			local cost = math.floor( uDef.metalCost + (uDef.energyCost / 50) )
			local fract = (cost - lowest) / range
			fract = fract ^ middle
			vals[uDefID] = math.floor(distancePerValue * fract)
		end
--		Spring.Echo(uDef.name, uDef.humanName, uDef.tooltip, vals[uDefID], cost, uDef.metalCost, uDef.energyCost, uDef.mass, fract)
	end
	return vals
end

local function createBulgeStamp(size, scale)
	-- Spring.Echo("creating bulge stamp")
	local stamp = {}
	local i = 1
	for xi=1,size do
		local x = (xi-1) * scale
		local dix = xi - 1
		local dx = dix / (size-1)
		for zi=1,size do
			local diz = zi - 1
			local dz = diz / (size-1)
			local d = math.sqrt((dx^2) + (dz^2))
			local h
			if d > 1 then
				h = 0
			else
				h = 1-(d^3)
			end
			local z = (zi-1) * scale
			stamp[i] = { x = x, z = z, h = h }
			i = i + 1
			-- Spring.Echo(x, z, h, d, dx, dz, dix, diz)
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
	return math.max(math.min(x, sizeX), 0)
end

local function mapClampZ(z)
	return math.max(math.min(z, sizeZ), 0)
end

local function mapClampXZ(x, z)
	return mapClampX(x), mapClampZ(z)
end

local function nearestSand(ix, iz)
	-- also clamps to map bounds
	local x = math.max(math.min(ix, sizeX-halfCellSize), halfCellSize)
	local z = math.max(math.min(iz, sizeZ-halfCellSize), halfCellSize)
	local groundType, _ = Spring.GetGroundInfo(x, z)
	if groundType == sandType then
		return x, z
	else
		local cx = x - (x % cellSize)
		local cz = z - (z % cellSize)
		if wormReDir[cx] then
			if wormReDir[cx][cz] then
				return wormReDir[cx][cz][1]+halfCellSize, wormReDir[cx][cz][2]+halfCellSize
			else
				return x, z
			end
		else
			return x, z
		end
	end
end

local function wormTargetting()
	local second = Spring.GetGameSeconds()
	local units = Spring.GetAllUnits()
	local num = 0
	local bestDist = {}
	for wID, w in pairs(worm) do
		bestDist[wID] = nil
	end
	-- for debugging
	-- for uID, b in pairs(sandUnits) do
--		SendToUnsynced("passSandUnit", uID, nil) --uncomment this for debug info (along with line farther down)
	-- end
	totalMovement = 0
	sandUnits = {}
	occupiedBoxes = {}
	largestSandUnitSize = 0
	for k, uID in pairs(units) do
		--if unit enters sand, add it to the sand unit table, if it exits, remove it
		if not isEmergedWorm[uID] then
			local ux, uy, uz = Spring.GetUnitBasePosition(uID)
			local groundType, _ = Spring.GetGroundInfo(ux, uz)
			local groundHeight = Spring.GetGroundHeight(ux, uz) 
			if groundType == sandType and uy < groundHeight + biteHeight then
				local uDefID = Spring.GetUnitDefID(uID)
				local uDef = UnitDefs[uDefID]
				local uval = sandUnitValues[uDefID]
				if not wormEatMex and uval == mexValue then
					-- don't target mexes if mapoption says no
				elseif not wormEatCommander and uval == commanderValue then
					-- don't target commanders if mapoption says no
				else
					-- local uSize = math.ceil(uDef.height * uDef.radius)
					local uSize = math.ceil(uDef.radius)
					if uSize > largestSandUnitSize then largestSandUnitSize = uSize end
					local dx, dz = 0, 0
					if sandUnitPosition[uID] then
						-- add how much the unit has moved since last evaluation to total movement sum
						dx = ux - sandUnitPosition[uID].x
						dz = uz - sandUnitPosition[uID].z
						local adx, adz = math.abs(dx), math.abs(dz)
						if adx > 0 or adz > 0 then
							totalMovement = totalMovement + adx + adz + uDef.metalCost
						end
					end
					sandUnitPosition[uID] = {x = ux, z = uz}
					sandUnits[uID] = true
					num = num + 1
					-- sort into non-grid boxes of units
					local insideBox = false
					for ib, box in pairs(occupiedBoxes) do
						if ux > box.xmin and ux < box.xmax and uz > box.zmin and uz < box.zmax then
							box.count = box.count + 1
							if uSize > box.largestUnitSize then box.largestUnitSize = uSize end
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
						}
						table.insert(occupiedBoxes, box)
					end
	--				SendToUnsynced("passSandUnit", uID, uval)
	--				Spring.Echo("sending", uID, uval)
					for wID, w in pairs(worm) do
						if uSize <= wormSizes[w.size].maxUnitSize then
							local x = w.x
							local z = w.z
							local distx = math.abs(ux - x)
							local distz = math.abs(uz - z)
							local dist = math.sqrt((distx*distx) + (distz*distz))
							local velx, vely, velz, velLength = Spring.GetUnitVelocity(uID)
							-- Spring.Echo(velx, vely, velz, velLength)
							local pvelx = dx / evalFrequency
							local pvelz = dz / evalFrequency
							velx = (velx + pvelx) / 2
							velz = (velz + pvelz) / 2
							local velmult = dist/w.speed
							local farx = ux + (velx * velmult)
							local farz = uz + (velz * velmult)
							local fardist = math.sqrt(DistanceSq(w.x, w.z, farx, farz))
		--					Spring.Echo(wID, "sensed unit", uID, "at", ux, uz)
							if fardist - uval < (bestDist[wID] or 999999) then
								if uval < 0 then
									-- for negative values (mexes and hovers)
									-- target badly, like a radar blip
									local j = -uval
									local jx = (mRandom() * j * 2) - j
									local jz = (mRandom() * j * 2) - j
									w.tx, w.tz = nearestSand(ux + jx, uz + jz)
								else
									local veltestmult = velmult / 1.5
									local testx = ux + (velx * veltestmult)
									local testz = uz + (velz * veltestmult)
									local testa = AngleXYXY(w.x, w.z, testx, testz)
									local cura = AngleXYXY(w.x, w.z, ux, uz)
									local adist = AngleDist(cura, testa)
									-- Spring.Echo(cura, testa, adist)
									if math.abs(adist) > halfPi then
										w.tx, w.tz = ux, uz
										-- Spring.Echo("adist above halfpi, using ux, uz")
									elseif math.abs(adist) > quarterPi then
										local fortyFive = quarterPi
										if adist < 0 then fortyFive = -quarterPi end
										local newa = AngleAdd(cura, fortyFive)
										w.tx, w.tz = CirclePos(w.x, w.z, dist, AngleAdd(cura, fortyFive))
										-- Spring.Echo("adist above quarterpi", fortyFive, newa)
									else
										w.tx, w.tz = CirclePos(w.x, w.z, dist, testa)
										-- Spring.Echo("adist below quarterpi, using testa")
									end
								end
								bestDist[wID] = fardist - uval
								-- if w.fresh then
								if w.targetUnitID ~= uID then
									-- give enough time to get to the worm's new target
									-- local eta = math.ceil((w.speed / 30) * fardist * wormChaseTimeMod) + 20
									-- w.endSecond = second + eta
									w.fresh = false
								end
								w.targetUnitID = uID
							end
						end
					end
				end
			else
				sandUnitPosition[uID] = nil
			end
		end
	end
	return num, math.ceil(totalMovement)
end

local function signLightning(x, y, z)
	local xrand = (2*mRandom()) - 1
	local zrand = (2*mRandom()) - 1
	local lx = 0
	local lz = 0
	for ly=0,2000,1.5 do
		Spring.SpawnCEG("WORMSIGN_LIGHTNING",x+lx,y+ly,z+lz,0,1,0,2,0)
		if ly % 48 == 0 then
			xrand = (2*mRandom()) - 1
			zrand = (2*mRandom()) - 1
		end
		lx = lx + xrand
		lz = lz + zrand
	end
	Spring.SpawnCEG("WORMSIGN_FLASH",x,y,z,0,1,0,2,0)
end

local function signArcLightning(x, y, z, arcLength, lengthPerHeight, segLength, flashCeg)
	segLength = segLength or 24
	flashCeg = flashCeg or "WORMSIGN_FLASH_SMALL"
	local sub = math.sqrt(arcLength)
	local div = sub / 2
	local xrand = (2*mRandom()) - 1
	local zrand = (2*mRandom()) - 1
	local lx = 0
	local lz = 0
	local ly = 0
	local i = 0
	local gh = y+arcLength
	repeat
		ly = ( arcLength-(((i/div)-sub)^2) ) / lengthPerHeight
		local cx = x+lx
		local cy = y+ly
		local cz = z+lz
		Spring.SpawnCEG("WORMSIGN_LIGHTNING_SMALL",cx,cy,cz,0,1,0,2,0)
		if i % segLength == 0 then
			xrand = (2*mRandom()) - 1
			zrand = (2*mRandom()) - 1
			gh = Spring.GetGroundHeight(cx,cz)
		end
		-- if i % 8 == 0 then
			-- gh = Spring.GetGroundHeight(x+lx,z+lz)
		-- end
		lx = lx + xrand
		lz = lz + zrand
		i = i + 1
	until cy < gh
	Spring.SpawnCEG(flashCeg,x,y,z,0,1,0,2,0)
	Spring.SpawnCEG(flashCeg,lx,ly,lz,0,1,0,2,0)
end

local function wormBigSign(wID)
	local sx = worm[wID].x
	local sz = worm[wID].z
	local sy = Spring.GetGroundHeight(sx, sz)
	signLightning(sx, sy, sz)
	-- signArcLightning( sx, sy, sz, mRandom(1500,2000), mRandom(5,10), 100, "WORMSIGN_FLASH" )
	local snd = thunderSnds[mRandom(#thunderSnds)]
	Spring.PlaySoundFile(snd,1.0,sx,sy,sz)
end

local function wormMediumSign(wID, randRadius)
	randRadius = randRadius or 30
	local w = worm[wID]
	if not w then return end
	local sx = w.x + mRandom(-randRadius,randRadius)
	local sz = w.z + mRandom(-randRadius,randRadius)
	local sy = Spring.GetGroundHeight(sx, sz)
	local num = mRandom(1,2)
	for n=1,num do
		signArcLightning( sx, sy, sz, mRandom(96,256), mRandom(4,10), 32 )
	end
	local snd = lightningSnds[mRandom(#lightningSnds)]
	Spring.PlaySoundFile(snd,0.33,sx,sy,sz)
end

local function wormLittleSign(wID, sx, sy, sz)
	local w = worm[wID]
	if not w and not sx then return end
	sx = sx or w.x
	sz = sz or w.z
	sy = sy or Spring.GetGroundHeight(sx, sz)
	local num = mRandom(1,2)
	for n=1,num do
		signArcLightning( sx, sy, sz, mRandom(24,96), mRandom(3,10) )
	end
	local snd = lightningSnds[mRandom(#lightningSnds)]
	Spring.PlaySoundFile(snd,0.25,sx,sy,sz)
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
		local rx = math.floor(x / 8)
		local rz = math.floor(z / 8)
		if not rippleMap[rx] then
			-- Spring.Echo("bad rx in ripplemap", rx)
			return
		end
		if not rippleMap[rx][rz] then
			-- Spring.Echo("bad rz in ripplemap", rz)
			return
		end
		if rippleMap[rx][rz] == 0 then table.insert(rippled, {rx, rz}) end
		rippleMap[rx][rz] = rippleMap[rx][rz] + hmod
		x = rx * 8
		z = rz * 8
		Spring.AdjustHeightMap(x, z, x+8, z+8, hmod)
	end
end

local function signStampRipple(x, z, mult, lightning)
	local hmodBase = bulgeHeight*mult
	if hmodBase > 0.1 then
		x = x - (x % 8)
		z = z - (z % 8)
		local lmult
		if lightning then lmult = mult / 65 end
		local num = mRandom(rippleNumMin,rippleNumMax)
		-- local num = 8
		for n=1,num do
			stamp = bulgeStamp[mRandom(1,#bulgeStamp)]
			local bh = stamp.h
			if bh > 0 then
				local bx = stamp.x
				local bz = stamp.z
				local hmod = bh * hmodBase
				local d = mRandom(1,4)
				local sx = x + (bulgeX[d]*bx)
				local sz = z + (bulgeZ[d]*bz)
				local gt, _ = Spring.GetGroundInfo(sx, sz)
				if gt == sandType then
					addRipple(sx, sz, hmod)
					if lightning then
						if mRandom() < (0.001 + lmult) then
							local y = Spring.GetGroundHeight(sx, sz)
							wormLittleSign(nil, sx, y, sz)
						end
					end
				end
			end
		end
	end
end

local function signUnRippleExpand()
--	local numripples = #rippled
--	if numripples > 0 then Spring.Echo(#rippled) end
	for id, vals in pairs(rippled) do
		local rx = vals[1]
		local rz = vals[2]
		local x = rx * 8
		local z = rz * 8
		local hmod = rippleMap[rx][rz]
		if hmod > 0.2 then
			local hsub = hmod / 2
			Spring.AdjustHeightMap(x, z, x+8, z+8, -hsub)
			rippleMap[rx][rz] = hsub
			local i = mRandom(1,8)
			local ex = x + rippleExpand[i].x
			local ez = z + rippleExpand[i].z
			local eh = hsub * rippleExpand[i].h
			addRipple(ex, ez, eh)
		elseif hmod > 0.1 then
			Spring.AdjustHeightMap(x, z, x+8, z+8, -0.1)
			rippleMap[rx][rz] = hmod - 0.1
		else
			Spring.AdjustHeightMap(x, z, x+8, z+8, -hmod)
			rippleMap[rx][rz] = 0
			table.remove(rippled, id)
		end
	end
end

local function normalizeVector(vx, vz)
	local dist = math.sqrt( (vx^2) + (vz^2) )
	vx = vx / dist
	vz = vz / dist
	return vx, vz
end

local function dynamicAvoidRockVector(wID)
	local w = worm[wID]
	local x, z, vx, vz = w.x, w.z, w.vx, w.vz
	local evalDist = math.ceil(evalFrequency * w.speed)
	local blockDist = -1
	for far=16, evalDist, 16 do
		local nx = x + (vx*far)
		local nz = z + (vz*far)
		local groundType, _ = Spring.GetGroundInfo(nx, nz)
		if groundType ~= sandType or nx > sizeX or nz > sizeZ or nx < 0 or nz < 0  then
			blockDist = far
			break
		end
	end
	if blockDist == -1 then
		return vx, vz
	else
		-- two perpendicular vectors
		local pvx = { -vz, vz }
		local pvz = { vx, -vx }
		local sandMult = { 2, 2 }
		local vStart = 1
		local vEnd = 2
		if w.favoredSide then
			vStart = w.favoredSide
			vEnd = w.favoredSide
		end
		for v=vStart, vEnd do
			for m=0.1, 1, 0.1 do
				local mr = 1 - m
				local mvx = (mr * vx) + (m * pvx[v])
				local mvz = (mr * vz) + (m * pvz[v])
				local tx = x + (mvx*blockDist)
				local tz = z + (mvz*blockDist)
				local gt, _ = Spring.GetGroundInfo(tx, tz)
				if gt == sandType then
					sandMult[v] = m
					break
				end
			end
		end
		local noMultMult = false
		local vBest = 1
		if sandMult[2] < sandMult[1] then
			vBest = 2
		elseif sandMult[1] == 2 and sandMult[2] == 2 then
			vx = -vx
			vz = -vz
			local revSandMult = { -1, -1 }
			local vStart = 1
			local vEnd = 2
			if w.favoredSide then
				vStart = w.favoredSide
				vEnd = w.favoredSide
			end
			for v=vStart, vEnd do
				for m=1, 0.1, -0.1 do
					local mr = 1 - m
					local mvx = (mr * vx) + (m * pvx[v])
					local mvz = (mr * vz) + (m * pvz[v])
					local tx = x + (mvx*blockDist)
					local tz = z + (mvz*blockDist)
					local gt, _ = Spring.GetGroundInfo(tx, tz)
					if gt == sandType then
						revSandMult[v] = m
						break
					end
				end
			end
			if revSandMult[2] > revSandMult[1] then
				vBest = 2
			end
			sandMult = revSandMult
			noMultMult = true
		end
		if w.favoredSide then vBest = w.favoredSide end
		local multMult = 1 - ((blockDist-16) / evalDist)
		if noMultMult then
			multMult = 1
		end
		local vMult = sandMult[vBest] * multMult
		local vMultRemain = 1 - vMult
		local nvx = (vMultRemain * vx) + (vMult * pvx[vBest])
		local nvz = (vMultRemain * vz) + (vMult * pvz[vBest])
		if noMultMult then
			w.vx = nvx
			w.vz = nvz
		end
		if not w.favoredSide then w.favoredSide = vBest end
		return normalizeVector(nvx, nvz)
	end
end

local function wormDirect(wID)
	local x = worm[wID].x
	local z = worm[wID].z
	if not worm[wID].tx then
--		Spring.Echo(wID, "no target. using random vector")
		worm[wID].vx = 1 - (2*mRandom())
		worm[wID].vz = 1 - (2*mRandom())
		return
	end
	local tx = worm[wID].tx
	local tz = worm[wID].tz
	if tx < x + 32 and tx > x - 32 and tz < z + 32 and tz > z - 32 then
--		Spring.Echo(wID, "target near position. using random vector and removing target")
		worm[wID].vx = 1 - (2*mRandom())
		worm[wID].vz = 1 - (2*mRandom())
		worm[wID].tx = nil
		worm[wID].tz = nil
		return
	end
--	Spring.Echo(wID, "calculating vector")
	local distx = tx - x
	local distz = tz - z
	local vx, vz = normalizeVector(distx, distz)
	worm[wID].vx = vx
	worm[wID].vz = vz
--	Spring.MarkerAddPoint(tx, 100, tz, wID)
--	Spring.MarkerErasePosition(tx, 100, tz)
end

local function passWormSign(x, z)
	local allyList = Spring.GetAllyTeamList()
	local y = Spring.GetGroundHeight(x, z)
	for k, aID in pairs(allyList) do
		local inRadar = Spring.IsPosInRadar(x, y, z, aID)
		local inLos = Spring.IsPosInAirLos(x, y, z, aID)
		if inRadar or inLos then
			SendToUnsynced("passSign", aID, x, y, z, inLos)
		end
	end
	SendToUnsynced("passSpectatorSign", x, y, z)
end

local function wormSpawn()
	local w = { 1 }
	local id = 0
	repeat
		id = id + 1
		w = worm[id]
	until not w
	if id <= maxWorms then
		local x, y, z, box
		if #occupiedBoxes > 0 then
			box = occupiedBoxes[mRandom(#occupiedBoxes)]
			x, z = CirclePos(box.x, box.z, wormSpawnDistance)
		else
			x, y, z = randomXYZ()
		end
		local spawnX, spawnZ = nearestSand(x, z)
		local wID = id
		local speed = wormSpeed + (mRandom(-wormSpeedLowerBias, wormSpeedUpperBias) / 100)
		local size = 1
		for s, sizeParams in ipairs(wormSizes) do
			local largest = largestSandUnitSize
			if box then largest = box.largestUnitSize end
			if sizeParams.maxUnitSize >= largest then
				size = s
				break
			end
		end
		Spring.Echo(largestSandUnitSize, box.largestUnitSize, wormSizes[size].maxUnitSize, size)
		local uDef = UnitDefNames[wormSizes[size].unitName]
		local range = math.ceil(((speed * attackEvalFrequency) / 2) + (uDef.radius * 1.4))
		worm[wID] = { x = spawnX, z = spawnZ, endSecond = math.floor(Spring.GetGameSeconds() + baseWormDuration), signSecond = Spring.GetGameSeconds() + mRandom(signFreqMin, signFreqMax), lastAttackSecond = 0, vx = nil, vz = nil, tx = nil, tz = nil, hasQuaked = false, fresh = true, bellyCount = 0, speed = speed, range = range, size = size }
		wormBigSign(wID)
		-- Spring.Echo(speed, range)
		passWormSign(spawnX, spawnZ)
	end
end

local function wormDie(wID)
--	Spring.Echo(wID, "died")
	worm[wID] = nil
	nextPotentialEvent = nextPotentialEvent + wormEventFrequency
--	SendToUnsynced("passWorm", wID, nil)
end

local function wormAttack(targetID, wID)
	local w = worm[wID]
	local x, y, z = Spring.GetUnitPosition(targetID)
--	Spring.MarkerAddPoint(x, y, z, "attack!")
--	Spring.MarkerErasePosition(x, y, z)
	local unitTeam = Spring.GetUnitTeam(targetID)
	local attackerID = Spring.CreateUnit(wormSizes[w.size].unitName, x, y, z, 0, gaiaTeam, false)
	isEmergedWorm[attackerID] = wID
	w.emergedID = attackerID
	w.x, w.z = x, z
end


-- synced
if gadgetHandler:IsSyncedCode() then

function gadget:Initialize()
	local mapOptions = Spring.GetMapOptions()
	if mapOptions then
		if mapOptions.sand_worms == "0" then
			areWorms = false
		end
		if mapOptions.sworm_aggression then wormAggression = tonumber(mapOptions.sworm_aggression) end
		movementPerWormAnger = 100000 / wormAggression
		if mapOptions.sworm_worm_speed then wormSpeed = tonumber(mapOptions.sworm_worm_speed) end
		if mapOptions.sworm_eat_mex == "1" then wormEatMex = true end
		if mapOptions.sworm_eat_commander == "1" then wormEatCommander = true end
		SendToUnsynced("passWormInit", evalFrequency, wormSpeed, 65) -- uncomment for showing worm positions with debug widget
	end
	if not areWorms then
		Spring.Echo("Sand worms are not enabled. Sand worm gadget disabled.")
		gadgetHandler:RemoveGadget()
		return
	end
	wormSizes = getWormSizes(wormUnits)
	sandUnitValues = getSandUnitValues()
	gaiaTeam = Spring.GetGaiaTeamID()
	wormReDir = loadWormReDir()
	bulgeStamp = createBulgeStamp(bulgeSize, bulgeScale)
	rippleExpand = createRippleExpansionMap()
	initializeRippleMap()
	nextPotentialEvent = Spring.GetGameSeconds() + wormEventFrequency
end

function gadget:GameStart()
	Spring.Echo("sand worm aggression", wormAggression)
	Spring.Echo("sand worm base speed", wormSpeed)
	Spring.Echo("sand worms eat mex?", wormEatMex)
	Spring.Echo("sand worms eat commander?", wormEatCommander)
end

function gadget:GameFrame(gf)
	if not areWorms then return end
	
	local second = Spring.GetGameSeconds()
	
	-- worm movement and ripple sign
	if gf % 4 == 0 then signUnRippleExpand() end
	for wID, w in pairs(worm) do
		if w.vx and not w.emergedID then
			w.nvx, w.nvz = dynamicAvoidRockVector(wID)
			w.x = math.max(math.min(w.x + (w.nvx*w.speed), sizeX), 0)
			w.z = math.max(math.min(w.z + (w.nvz*w.speed), sizeZ), 0)
			-- SendToUnsynced("passWorm", wID, w.x, w.z, w.vx, w.vz, w.nvx, w.nvz, w.tx, w.tz, w.signSecond, w.endSecond ) --uncomment this to show the worms positions, vectors, and targets real time (uses gui_worm_debug.lua)
		end
		local rippleMult = nil
		if second > w.signSecond-4 and second < w.signSecond+3 then -- and not w.emergedID then
			-- if it's one second before or after worm sign second, ripple sand
			if not worm[wID].hasQuaked then
				local y = Spring.GetGroundHeight(w.x, w.z)
				local snd = quakeSnds[mRandom(#quakeSnds)]
				Spring.PlaySoundFile(snd,1.0,w.x,y,w.z)
				w.hasQuaked = true
			end
			lightning = mRandom() < 0.4
			rippleMult = 1 / (1 + math.abs(second - w.signSecond))
		elseif w.vx and not w.emergedID then
			-- when moving, always ripple sand a little with occasional ground lightning
			lightning = mRandom() < 0.3
			rippleMult = 0.2
		end
		if rippleMult then
			signStampRipple(w.x, w.z, rippleMult, lightning)
			if mRandom() < rippleMult * 0.1 then
				local cegx = mapClampX(w.x + mRandom(60) - 30)
				local cegz = mapClampZ(w.z + mRandom(60) - 30)
				local cegy = Spring.GetGroundHeight(cegx, cegz) + 5
				Spring.SpawnCEG("sworm_dust",cegx,cegy,cegz,0,1,0,30,0)
			end
		end
		if w.emergedID and mRandom() < 0.01 then
			wormMediumSign(wID)
		end
	end
	
	-- evaluation cycle
	if gf % evalFrequency == 0 then
	
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
		maxWorms = math.min(3, math.ceil(wormAnger))
		wormBellyLimit = math.min(9, math.ceil(1 + math.sqrt(wormAnger * 21)))
		wormSpeedLowerBias = math.max(0, 10 - math.floor(wormAnger * 4))
		wormChance = math.min(1, 0.5 + math.sqrt(wormAnger / 12))
		if wormAnger > 2 then
			wormEventFrequency = 5
		else
			wormEventFrequency = 5 + (0.55 * ((wormAnger - 3) ^ 4))
		end
		wormEventFrequency = math.min(60, math.max(5, math.ceil(wormEventFrequency)))
		-- Spring.Echo(maxWorms, wormBellyLimit, wormSpeedLowerBias, wormChance, wormEventFrequency, wormAnger, numSandUnits, totalSandMovement, unitsPerWormAnger, movementPerWormAnger, wormAggression)
		-- spawn worms
		if numSandUnits > 0 and second >= nextPotentialEvent then
--			Spring.Echo("potential worm event...")
			if mRandom() < wormChance then
				wormSpawn()
			end
			nextPotentialEvent = second + wormEventFrequency
		end
		
		-- calculate vectors
		for wID, w in pairs(worm) do
			if not w.tx then
				-- if no target then make a random target
				local tx, tz = nearestSand(mRandom(halfCellSize, sizeX-halfCellSize), mRandom(halfCellSize, sizeZ-halfCellSize))
				worm[wID].tx = tx
				worm[wID].tz = tz
			end
			wormDirect(wID)
		end
	end

	if gf % attackEvalFrequency == 0 and numSandUnits > 0 then
		-- do worm attacks on units that are within range
		local alreadyAttacked = {}
		for wID, w in pairs(worm) do
			if not w.emergedID then
				local wx = w.x
				local wz = w.z
				local wy = Spring.GetGroundHeight(wx, wz)
				local unitsNearWorm = Spring.GetUnitsInSphere(wx, wy, wz, w.range)
				local bestVal = -99999
				local bestID
				for k, uID in pairs(unitsNearWorm) do
					if not alreadyAttacked[uID] then
						local uDefID = Spring.GetUnitDefID(uID)
						local uDef = UnitDefs[uDefID]
						if not wormUnits[uDef.name] then
							local uSize = math.ceil(uDef.radius)
							if uSize <= wormSizes[w.size].maxUnitSize then
								local x, y, z = Spring.GetUnitPosition(uID)
								local groundType, _ = Spring.GetGroundInfo(x, z)
								if groundType == sandType and sandUnits[uID] then
									local uDefID = Spring.GetUnitDefID(uID)
									local uval = sandUnitValues[uDefID]
									if uval > bestVal then
										bestID = uID
										bestVal = uval
									end
								end
							end
						end
					end
				end
				if bestID then
					w.signSecond = second + 1 -- for ground ripples
					wormAttack(bestID, wID)
					w.lastAttackSecond = second
					alreadyAttacked[bestID] = true
					w.bellyCount = w.bellyCount + 1
					-- Spring.Echo(w.bellyCount, wormBellyLimit, w.endSecond)
				end
			end
		end
	end
	
	-- do worm sign lightning and pass wormsign markers to widget
	if gf % signEvalFrequency == 0 then
--		Spring.Echo("doing wormsigns at", secondInt, second)
		for wID, w in pairs(worm) do
			local timeToSign = w.signSecond
--			Spring.Echo(wID, secondToSign, secondInt, timeToSign, second)
			if second > timeToSign-3 and second < timeToSign+2 and not w.emergedID then
				-- local dice = mRandom()
				-- if dice > 0.95 then
				if not w.hasSigned and second >= timeToSign then
--					Spring.Echo(wID, "doing lightning sign")
					wormBigSign(wID)
					passWormSign(w.x, w.z)
					w.hasSigned = true
				end
			end
			if second > timeToSign+3 then
				w.signSecond = second + mRandom(signFreqMin, signFreqMax)
				w.hasQuaked = false
				w.hasSigned = false
			end
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	local uDef = UnitDefs[unitDefID]
	Spring.Echo(uDef.name, math.ceil(uDef.radius), math.ceil(uDef.height), math.ceil(uDef.radius * uDef.height), math.ceil(uDef.radius + uDef.height))
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
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
			if w.bellyCount >= wormBellyLimit then
				-- worms that have eaten too much must take some time to rest & digest
				wormDie(wID)
			else
				-- worm appatite whetted
				w.endSecond = Spring.GetGameSeconds() + baseWormDuration
			end
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
--		Spring.Echo("unsynced", uID, uval)
	  if (Script.LuaUI('passSandUnit')) then
--	  	Spring.Echo("to send", uID, uval)
		Script.LuaUI.passSandUnit(uID, uval)
	  end
	end
	
	local function signToLuaUI(_, allyID, x, y, z, los)
		local myAlly = Spring.GetLocalAllyTeamID()
		if myAlly == allyID and (Script.LuaUI('passSign')) then
			Script.LuaUI.passSign(x, y, z, los)
		end
	end
	
	local function specSignToLuaUI(_, x, y, z)
		if Spring.GetSpectatingState() then
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