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
local randomAttacks = false --if true, then there is no worm sign, and a unit on the sand is picked at random to be eaten every evaluation cycle
local maxWorms = 1 -- how many worms can be in the game at once
local baseWormChance = 50 -- chance out of 100 that a worm will be spawned every wormEventFrequency seconds 
local wormEventFrequency = 30 -- time in seconds between potential worm event.
local baseWormDuration = 45
local wormSpeed = 1.0 -- how much the worm's vector is multiplied by to produce a position each game frame
local wormSensingRange = 1500 -- the range within which a unit will add to a worm's "anger" (i.e. will keep the worm from leaving)
local wormEatMex = false -- will worms eat metal extractors?

-- non mapoption config
local wormSignFrequency = 15 -- average time in seconds between worm signs (varies + or - 50%)
local sandType = "Sand" -- the ground type that worm spawns in
local wormEmergeUnitName = "sworm" -- what unit the worms emerge and attack as
local rippleHeight = 1.5 -- height of ripples that worm makes in the sand
local bulgeHeight = 1.5
local bulgeSizeV = 5
local bulgeSizeP = 4
local bulgeSize = 7
local bulgeScale = 8
local attackDelay = 12 -- delay between worm attacks
local cellSize = 64 -- for wormReDir
local evalFrequency = 200 -- game frames between evaluation of units on sand
local signEvalFrequency = 12 -- game frames between parts of a wormsign volley (lower value means more lightning strikes per sign)
local wormRange = 150 -- range within which worm will attack


-- storage variables

local areWorms = true -- will be set to false if the map option sand_worms is off
local sandUnits = {} -- sandUnits[unitID] = true are on sand
local numSandUnits = 0
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
local angerTimeGain = evalFrequency / 35 -- there are 30 game frames per second, so dividing this by something more makes the worm eventually die even if it has a constant supply of targets
local evalNewVector = math.floor(16 / wormSpeed)
local rippled = {} -- stores references to rippleMap nodes that are actively under transformation
local rippleMap = {}-- stores locations of sand that has been raised by worm to lower it
local bulgeProfile = {}
local bulgeStamp = {}
--local bulgeScaleHalf = bulgeScale / 2
local bulgeX = { 1, 1, -1, -1 }
local bulgeZ = { 1, -1, -1, 1 }

--sounds
local sndQuakeA = "sounds/deep_tremor.wav"
local sndQuakeB = "sounds/low_quake.wav"
local sndQuakeC = "sounds/rumble_9sec.wav"
local sndQuakeD = "sounds/rumble_11sec.wav"
local sndLightningA = "sounds/Lightning-02.wav"
local sndLightningB = "sounds/Lightning-03.wav"
local sndLightningC = "sounds/Lightning-01.wav"
local sndLightningD = "sounds/thunder_strike.wav"
local sndLightningE = "sounds/thunder_strike2.wav"
local sndShortRumble = "sounds/rumble_short.wav"
local sndShortTremor = "sounds/subwoof_short.wav"
local sndElectricSpark = "sounds/electric_spark.wav"
local sndElectricLadder = "sounds/electric_ladder.wav"
local sndElectricRasp = "sounds/electric_rasp.wav"
local sndElectricFizzle = "sounds/electric_fizzle.wav"
local sndSandExplosion = "sounds/sand_explosion.wav"
local shortQuakeSnds = { sndShortRumble, sndShortTremor }
local quakeSnds = { sndQuakeA, sndQuakeB, sndQuakeC, sndQuakeD }
local lightningSnds = { sndLightningA, sndLightningB, sndLightningC, sndLightningD, sndLightningE }
local electricSnds = { sndElectricSpark, sndElectricLadder, sndElectricFizzle }


-- functions

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
		local cost = math.floor( uDef.metalCost + (uDef.energyCost / 50) )
		local fract = (cost - lowest) / range
		fract = fract ^ middle
		vals[uDefID] = math.floor( wormSensingRange * 0.67 * fract )
		if uDef.extractsMetal > 0 then
			vals[uDefID] = -math.floor(wormSensingRange * 0.2)
		end
		if uDef.canHover then
			vals[uDefID] = -math.floor(wormSensingRange * 0.3)
		end
--		Spring.Echo(uDef.name, uDef.humanName, uDef.tooltip, vals[uDefID], cost, uDef.metalCost, uDef.energyCost, uDef.mass, fract)
	end
	return vals
end

local function createBulgeProfile(vSize, pSize)
	Spring.Echo("creating bulge profile")
	for v=1,vSize do
		local vh = (1-((v/vSize)^3))
		bulgeProfile[v] = {}
		for p=1,pSize do
			local ph = vh * (1-((p/pSize)^3))
			bulgeProfile[v][p] = ph
			Spring.Echo(v, p, ph)
		end
	end
end

local function createBulgeStamp(size, scale)
	Spring.Echo("creating bulge stamp")
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
			Spring.Echo(x, z, h, d, dx, dz, dix, diz)
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
	local units = Spring.GetAllUnits()
	local num = 0
	local bestDist = {}
	for wID, w in pairs(worm) do
		bestDist[wID] = 9999
	end
	-- for debugging
	for uID, b in pairs(sandUnits) do
--		SendToUnsynced("passSandUnit", uID, nil) --uncomment this for debug info (along with line farther down)
	end
	sandUnits = {}
	local alreadyAngered = {}
	for k, uID in pairs(units) do
		--if unit enters sand, add it to the sand unit table, if it exits, remove it
		if not isEmergedWorm[uID] then
			local ux, uy, uz = Spring.GetUnitBasePosition(uID)
			local groundType, _ = Spring.GetGroundInfo(ux, uz)
			local groundHeight = Spring.GetGroundHeight(ux, uz) 
			if groundType == sandType and uy < groundHeight + 32 then
				local uDefID = Spring.GetUnitDefID(uID)
				local uDef = UnitDefs[uDefID]
				if not wormEatMex and (uDef.extractsMetal > 0) then
					-- don't target mexes if mapoption says no
				else
					sandUnits[uID] = true
					num = num + 1
					local uval = sandUnitValues[uDefID]
	--				SendToUnsynced("passSandUnit", uID, uval)
	--				Spring.Echo("sending", uID, uval)
					for wID, w in pairs(worm) do
						local x = w.x
						local z = w.z
						local distx = math.abs(ux - x)
						local distz = math.abs(uz - z)
						local dist = math.sqrt((distx*distx) + (distz*distz))
						if dist - uval < wormSensingRange then
		--					Spring.Echo(wID, "sensed unit", uID, "at", ux, uz)
							if not alreadyAngered[wID] then
								worm[wID].endSecond = worm[wID].endSecond + angerTimeGain 
								alreadyAngered[wID] = true
							end
							if dist - uval < bestDist[wID] then
								worm[wID].tx = ux
								worm[wID].tz = uz
								if uval < 0 then
									local j = -uval
									local jx = (math.random() * j * 2) - j
									local jz = (math.random() * j * 2) - j
									local tx, tz = nearestSand(worm[wID].tx + jx, worm[wID].tz + jz)
									worm[wID].tx = tx
									worm[wID].tz = tz
								end
								bestDist[wID] = dist - uval
							end
						end
					end
				end
			end
		end
	end
	return num
end

local function signLightning(x, y, z)
	local xrand = (2*math.random()) - 1
	local zrand = (2*math.random()) - 1
	local lx = 0
	local lz = 0
	for ly=0,2000,1.5 do
		Spring.SpawnCEG("WORMSIGN_LIGHTNING",x+lx,y+ly,z+lz,0,1,0,2,0)
		if ly % 48 == 0 then
			xrand = (2*math.random()) - 1
			zrand = (2*math.random()) - 1
		end
		lx = lx + xrand
		lz = lz + zrand
	end
	Spring.SpawnCEG("WORMSIGN_FLASH",x,y,z,0,1,0,2,0)
end

local function signArcLightning(x, y, z, arcHeight, squishDiv)
	local sub = math.sqrt(arcHeight)
	local div = sub / 2
	local xrand = (2*math.random()) - 1
	local zrand = (2*math.random()) - 1
	local lx = 0
	local lz = 0
	local ly = 0
	local i = 0
	local gh = y+arcHeight
	repeat
		ly = ( arcHeight-(((i/div)-sub)^2) ) / squishDiv
		local cx = x+lx
		local cy = y+ly
		local cz = z+lz
		Spring.SpawnCEG("WORMSIGN_LIGHTNING_SMALL",cx,cy,cz,0,1,0,2,0)
		if i % 24 == 0 then
			xrand = (2*math.random()) - 1
			zrand = (2*math.random()) - 1
		end
		if i % 8 == 0 then
			gh = Spring.GetGroundHeight(x+lx,z+lz)
		end
		lx = lx + xrand
		lz = lz + zrand
		i = i + 1
	until cy < gh
	Spring.SpawnCEG("WORMSIGN_FLASH_SMALL",x,y,z,0,1,0,2,0)
	Spring.SpawnCEG("WORMSIGN_FLASH_SMALL",lx,ly,lz,0,1,0,2,0)
end

local function wormBigSign(wID)
	local sx = worm[wID].x
	local sz = worm[wID].z
	local sy = Spring.GetGroundHeight(sx, sz)
	signLightning(sx, sy, sz)
	local snd = lightningSnds[math.random(1,5)]
	Spring.PlaySoundFile(snd,9.0,sx,sy,sz)
end

local function wormLittleSign(wID, sx, sy, sz)
	if not sx or not sy or not sx then
		sx = worm[wID].x
		sz = worm[wID].z
		sy = Spring.GetGroundHeight(sx, sz)
	end
	local num = math.random(1,2)
	for n=1,num do
		signArcLightning( sx, sy, sz, math.random(24,96), 3+math.random(0,7) )
	end
	local snd = electricSnds[math.random(1,3)]
	Spring.PlaySoundFile(snd,0.75,sx,sy,sz)
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
		x = rx * 8
		z = rz * 8
		if rippleMap[rx][rz] == 0 then table.insert(rippled, {rx, rz}) end
		rippleMap[rx][rz] = rippleMap[rx][rz] + hmod
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
		local num = math.random(5,10)
		for n=1,num do
			stamp = bulgeStamp[math.random(1,#bulgeStamp)]
			local bh = stamp.h
			if bh > 0 then
				local bx = stamp.x
				local bz = stamp.z
				local hmod = bh * hmodBase
				local d = math.random(1,4)
				local sx = x + (bulgeX[d]*bx)
				local sz = z + (bulgeZ[d]*bz)
				local gt, _ = Spring.GetGroundInfo(sx, sz)
				if gt == sandType then
					addRipple(sx, sz, hmod)
					if lightning then
						if math.random() < (0.001 + lmult) then
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
			local i = math.random(1,8)
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
	local x = worm[wID].x
	local z = worm[wID].z
	local vx = worm[wID].vx
	local vz = worm[wID].vz
	local blockDist = -1
	for far=16, evalFrequency*wormSpeed, 16 do
		local nx = x + (vx*far)
		local nz = z + (vz*far)
		local groundType, _ = Spring.GetGroundInfo(nx, nz)
		if groundType ~= sandType or nx > sizeX or nz > sizeZ or nx < 0 or nz < 0  then
			blockDist = far
			break
		end
	end
	if blockDist == -1 then
--		wormFavoredSide[wID] = nil
		return vx, vz
	else
		-- two perpendicular vectors
		local pvx = { -vz, vz }
		local pvz = { vx, -vx }
		local sandMult = { 2, 2 }
		local vStart = 1
		local vEnd = 2
		if worm[wID].favoredSide then
			vStart = worm[wID].favoredSide
			vEnd = worm[wID].favoredSide
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
			if worm[wID].favoredSide then
				vStart = worm[wID].favoredSide
				vEnd = worm[wID].favoredSide
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
		if worm[wID].favoredSide then vBest = worm[wID].favoredSide end
		local multMult = 1 - ((blockDist-16) / (evalFrequency*wormSpeed))
		if noMultMult then
			multMult = 1
		end
		local vMult = sandMult[vBest] * multMult
		local vMultRemain = 1 - vMult
		local nvx = (vMultRemain * vx) + (vMult * pvx[vBest])
		local nvz = (vMultRemain * vz) + (vMult * pvz[vBest])
		if noMultMult then
			worm[wID].vx = nvx
			worm[wID].vz = nvz
		end
		if not worm[wID].favoredSide then worm[wID].favoredSide = vBest end
		return normalizeVector(nvx, nvz)
	end
end

local function wormDirect(wID)
	local x = worm[wID].x
	local z = worm[wID].z
	if not worm[wID].tx then
--		Spring.Echo(wID, "no target. using random vector")
		worm[wID].vx = 1 - (2*math.random())
		worm[wID].vz = 1 - (2*math.random())
		return
	end
	local tx = worm[wID].tx
	local tz = worm[wID].tz
	if tx < x + 32 and tx > x - 32 and tz < z + 32 and tz > z - 32 then
--		Spring.Echo(wID, "target near position. using random vector and removing target")
		worm[wID].vx = 1 - (2*math.random())
		worm[wID].vz = 1 - (2*math.random())
		worm[wID].tx = nil
		worm[wID].tz = nil
		return
	end
--	Spring.Echo(wID, "calculating vector")
	local distx = tx - x
	local distz = tz - z
	local vx, vz = normalizeVector(distx, distz)
--	local nx = x + (vx*wormSpeed*evalFrequency)
--	local nz = z + (vz*wormSpeed*evalFrequency)
--	vx, vz = avoidRockVector(x, z, nx, nz, vx, vz)
	worm[wID].vx = vx
	worm[wID].vz = vz
--	Spring.MarkerAddPoint(tx, 100, tz, wID)
--	Spring.MarkerErasePosition(tx, 100, tz)
end

local function randomSandUnit()
	local which = math.random(numSandUnits)
	local i = 1
	local targetID
	for id, b in pairs(sandUnits) do
		if i == which then targetID = id end
		i = i + 1
	end
	return targetID
end

local function wormSpawn()
	local w = { 1 }
	local id = 0
	repeat
		id = id + 1
		w = worm[id]
	until not w
	if id <= maxWorms then
		local uID = randomSandUnit()
		local x, y, z = Spring.GetUnitPosition(uID)
		local rvx, rvz = normalizeVector( (math.random()*2)-1, (math.random()*2)-1 )
		local away = wormSensingRange * 0.5
		local spawnX, spawnZ = nearestSand( x+(rvx*away), z+(rvz*away) )
--		local spawnX, spawnZ = nearestSand(math.random(halfCellSize, sizeX-halfCellSize), math.random(halfCellSize, sizeZ-halfCellSize))
		local wID = id
		worm[wID] = { x = spawnX, z = spawnZ, endSecond = math.floor(Spring.GetGameSeconds() + baseWormDuration), signSecond = Spring.GetGameSeconds() + math.random(signFreqMin, signFreqMax), lastAttackSecond = 0, vx = nil, vz = nil, tx = nil, tz = nil, hasQuaked = false}
		wormBigSign(wID)
	end
end

local function wormDie(wID)
--	Spring.Echo(wID, "died")
	worm[wID] = nil
--	SendToUnsynced("passWorm", wID, nil)
end

local function wormAttack(targetID)
	local x, y, z = Spring.GetUnitPosition(targetID)
--	Spring.MarkerAddPoint(x, y, z, "attack!")
--	Spring.MarkerErasePosition(x, y, z)
	local unitTeam = Spring.GetUnitTeam(targetID)
	local attackerID = Spring.CreateUnit(wormEmergeUnitName, x, y, z, 0, gaiaTeam, false)
	isEmergedWorm[attackerID] = true
end


-- callins

function gadget:Initialize()
	local mapOptions = Spring.GetMapOptions()
	if mapOptions then
		if mapOptions.sand_worms == "0" then
			areWorms = false
		end
		if mapOptions.sworm_random_attacks == "1" then
			randomAttacks = true
		end
		if mapOptions.sworm_max_worms then maxWorms = tonumber(mapOptions.sworm_max_worms) end
		if mapOptions.sworm_base_worm_chance then baseWormChance = tonumber(mapOptions.sworm_base_worm_chance) end
		if mapOptions.sworm_worm_event_frequency then wormEventFrequency = tonumber(mapOptions.sworm_worm_event_frequency) end
		if mapOptions.sworm_base_worm_duration then baseWormDuration = tonumber(mapOptions.sworm_base_worm_duration) end
		if mapOptions.sworm_worm_speed then wormSpeed = tonumber(mapOptions.sworm_worm_speed) end
		if mapOptions.sworm_worm_sensing_range then wormSensingRange = tonumber(mapOptions.sworm_worm_sensing_range) end
		wormRange = ((wormSpeed * evalFrequency) / 2) + 50
		if mapOptions.sworm_eat_mex == "1" then wormEatMex = true end
	end
	if not areWorms then
		Spring.Echo("Sand worms are not enabled. Sand worm gadget disabled.")
		return
	end
	sandUnitValues = getSandUnitValues()
	gaiaTeam = Spring.GetGaiaTeamID()
	wormReDir = loadWormReDir()
--	createBulgeProfile(bulgeSizeV, bulgeSizeP)
	bulgeStamp = createBulgeStamp(bulgeSize, bulgeScale)
	rippleExpand = createRippleExpansionMap()
	initializeRippleMap()
end

function gadget:GameFrame(gf)
	if not areWorms then return end
	
	local second = Spring.GetGameSeconds()
	
	-- worm movement and ripple sign
	if gf % 4 == 0 then signUnRippleExpand() end
	for wID, w in pairs(worm) do
		if w.vx and second > w.lastAttackSecond+attackDelay then
			local x = w.x
			local z = w.z
			local vx = w.vx
			local vz = w.vz
			local nvx, nvz
	--		if gf % evalNewVector == 0 or not wormNewVector[wID] then
				nvx, nvz = dynamicAvoidRockVector(wID)
				worm[wID].nvx = nvx
				worm[wID].nvz = nvz
	--		else
	--			nvx = wormNewVector[wID][1]
	--			nvz = wormNewVector[wID][2]
	--		end
			local xnew = math.max(math.min(x + (nvx*wormSpeed), sizeX), 0)
			local znew = math.max(math.min(z + (nvz*wormSpeed), sizeZ), 0)
			worm[wID].x = xnew
			worm[wID].z = znew
			local rad = 24
			local hmod = 2
			-- if it's one second before or after worm sign second, ripple sand
			if second > w.signSecond-4 and second < w.signSecond+3 and second > w.lastAttackSecond+attackDelay then
				if not worm[wID].hasQuaked then
					local y = Spring.GetGroundHeight(x, z)
					local snd = quakeSnds[math.random(1,4)]
					Spring.PlaySoundFile(snd,16.0,x,y,z)
					worm[wID].hasQuaked = true
				end
				local mult = 1 / (1 + math.abs(second - w.signSecond))
				local lightning = false
				if math.random() < 0.33 then lightning = true end
--				signStampRipple(math.max(math.min(x - (nvx*wormSpeed*64), sizeX), 0), math.max(math.min(z - (nvz*wormSpeed*40), sizeZ), 0), mult*0.5, lightning)
				signStampRipple(xnew, znew, mult, lightning)
--				signStampRipple(math.max(math.min(x + (nvx*wormSpeed*32), sizeX), 0), math.max(math.min(z + (nvz*wormSpeed*40), sizeZ), 0), mult*0.75, lightning)
			end	
--			SendToUnsynced("passWorm", wID, xnew, znew, vx, vz, nvx, nvz, w.tx, w.tz, w.signSecond, w.endSecond ) --uncomment this to show the worms positions, vectors, and targets real time (uses gui_worm_debug.lua)
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
		numSandUnits = wormTargetting()
		
		-- spawn worms
		if second % wormEventFrequency == 0 and numSandUnits > 0 then
--			Spring.Echo("potential worm event...")
			if math.random(0, 100) < baseWormChance + numSandUnits then
				if randomAttacks then
--					Spring.Echo("worm attack!")
					local which = randomSandUnit()
					wormAttack(targetID)
				else
					wormSpawn()
--					Spring.Echo("worm spawned!")
				end
			end
		end
		
		-- calculate vectors
		for wID, w in pairs(worm) do
			if not w.tx then
				-- if no target then make a random target
				local tx, tz = nearestSand(math.random(halfCellSize, sizeX-halfCellSize), math.random(halfCellSize, sizeZ-halfCellSize))
				worm[wID].tx = tx
				worm[wID].tz = tz
			end
			wormDirect(wID)
		end

		-- do worm attacks on units that are within range
		local alreadyAttacked = {}
		for wID, w in pairs(worm) do
			if (second > w.lastAttackSecond + attackDelay) and (numSandUnits > 0) then 
				local wx = w.x
				local wz = w.z
				local wy = Spring.GetGroundHeight(wx, wz)
				local unitsNearWorm = Spring.GetUnitsInSphere(wx, wy, wz, wormRange)
				local bestVal = -9999
				local bestID
				for k, uID in pairs(unitsNearWorm) do
					if not isEmergedWorm[uID] then
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
				if bestID and not alreadyAttacked[bestID] then
					wormAttack(bestID)
					worm[wID].lastAttackSecond = second
					alreadyAttacked[bestID] = true
				end
			end
		end
	
	-- do worm sign lightning and pass wormsign markers to widget
	elseif gf % signEvalFrequency == 0 then
--		Spring.Echo("doing wormsigns at", secondInt, second)
		for wID, w in pairs(worm) do
			local timeToSign = w.signSecond
--			Spring.Echo(wID, secondToSign, secondInt, timeToSign, second)
			if second > timeToSign-3 and second < timeToSign+2 and second > w.lastAttackSecond+attackDelay then
				local dice = math.random()
				if dice > 0.95 then
--				Spring.Echo(wID, "doing lightning sign")
					wormBigSign(wID)
				end
			end
			if second > timeToSign+3 then
				local allyList = Spring.GetAllyTeamList()
				local signX = w.x
				local signZ = w.z
				local signY = Spring.GetGroundHeight(signX, signZ)
				for k, aID in pairs(allyList) do

					local inRadar = Spring.IsPosInRadar(signX, signY, signZ, aID)
					local inLos = Spring.IsPosInLos(signX, signY, signZ, aID)
					if inRadar or inLos then
						SendToUnsynced("passSign", aID, signX, signY, signZ, inLos)
					end
				end
				SendToUnsynced("passSpectatorSign", signX, signY, signZ)
				worm[wID].signSecond = Spring.GetGameSeconds() + math.random(signFreqMin, signFreqMax)
				worm[wID].hasQuaked = false
			end
		end
	end
	
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)

	-- remove from units on sand table
	if sandUnits[unitID] then
		sandUnits[unitID] = nil
		numSandUnits = numSandUnits - 1
--		SendToUnsynced("passSandUnit", uID, nil)
	end
	
	-- remove from emerged worms to clear table
	if isEmergedWorm[unitID] then
		isEmergedWorm[unitID] = nil
	end
	
end


-- unsynced

if not gadgetHandler:IsSyncedCode() then
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
	  gadgetHandler:AddSyncAction('passWorm', wormToLuaUI)
	  gadgetHandler:AddSyncAction('passSandUnit', sandUnitToLuaUI)
	  gadgetHandler:AddSyncAction('passSign', signToLuaUI)
	  gadgetHandler:AddSyncAction('passSpectatorSign', specSignToLuaUI)
	end
end