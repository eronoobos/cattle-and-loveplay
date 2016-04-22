function gadget:GetInfo()
  return {
    name      = "Cattle and Loveplay: Sand Restrictor",
    desc      = "Restricts building creation on Sand terrain type by sinking invalid units, redirect AI build commands from sand to rock, and 'sinks' wrecks on the sand by reducing their health slowly.",
    author    = "zoggop",
    date      = "February 2012",
    license   = "whatever",
    layer     = -3,
    enabled   = true
   }
end

local cellSize = 64
local halfCellSize = cellSize / 2
local sizeX = Game.mapSizeX 
local sizeZ = Game.mapSizeZ
local maxSlope = 0.25
local buildSpacing = 16

local wormConfig = VFS.Include('wormconfig/wormconfig.lua')
local sandType = wormConfig.sandType

-- these default values are changed in gadget:Initialize()
local aiPresent = false
local restrictSand = true
local sinkWrecks = false

-- for AI command redirection
local reDir
local reReDir
local elmoMaxSize
local isOccupied 
local occupyThis
local unitOccupies
local unitOccupiesNodes = {}
local buildNodeSizes = {}
local buildGraphs = {}

-- doInit() will set this to a list of unit def IDs that can't be built on sand    
local isNotValid = {}

local sinkCount = 0
local sunkHeight = {}
local sinkRadius = {}
local sinkUnit = {}

local fSinkCount = 0
local fSinkSpeed = {}
--local fSunkHeight --not needed unless wrecks actually sinking is possible

local astar

local strFind = string.find
local mRandom = math.random
local mMax = math.max

local spGetGroundInfo = Spring.GetGroundInfo
local spEcho = Spring.Echo
local spGetGroundHeight = Spring.GetGroundHeight
local spTestBuildOrder = Spring.TestBuildOrder
local spGetGroundNormal = Spring.GetGroundNormal
local spGetUnitPosition = Spring.GetUnitPosition
local spMarkerAddPoint = Spring.MarkerAddPoint
local spRemoveBuildingDecal = Spring.RemoveBuildingDecal
local spGetMapOptions = Spring.GetMapOptions
local spGetTeamList = Spring.GetTeamList
local spGetTeamInfo = Spring.GetTeamInfo
local spGetGameFrame = Spring.GetGameFrame
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitHealth = Spring.GetUnitHealth
local spAddUnitDamage = Spring.AddUnitDamage
local spDestroyUnit = Spring.DestroyUnit
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetFeatureHealth = Spring.GetFeatureHealth
local spSetFeaturePosition = Spring.SetFeaturePosition
local spSetFeatureHealth = Spring.SetFeatureHealth
local spDestroyFeature = Spring.DestroyFeature
local spGetUnitBuildFacing = Spring.GetUnitBuildFacing
local spGetGaiaTeamID = Spring.GetGaiaTeamID
local spGetFeatureDefID = Spring.GetFeatureDefID

-- local functions

local function doInit()
	if restrictSand then
	  isNotValid = {}
	  for uDefID, uDef in pairs(UnitDefs) do
	  	local ignore = false
		local customParams = uDef.customParams
		if (customParams) then
		  if customParams.ignoreplacementrestriction then
		  	ignore=true
		  end
		end
		if not ignore and (uDef.extractsMetal == 0) and (uDef.maxAcc < 0.01) and not uDef.needGeo and not strFind(uDef.tooltip, " Mine") then --if it's not a metal extractor and does not move, it is not valid
			isNotValid[uDefID] = true
			SendToUnsynced("passIsNotValid", uDefID)
	--			spEcho(uDefID, 'sent from gadget')
			if aiPresent then
			  elmoMaxSize[uDefID] = mMax(uDef.xsize, uDef.zsize) * 8
			  elmoMaxSize[uDefID] = elmoMaxSize[uDefID] - (elmoMaxSize[uDefID] % 32) + 32
			end
		  end
	  end
	
	
	  sinkCount = mRandom(10, 20)
	  sinkUnit = {} -- stores which units to sink between UnitCreated() and UnitFinished() so that units can be better evaluated in UnitCreated()
	  sunkHeight = {} -- stores which units to sink (key) to what height (value)
	  sinkRadius = {} -- stores the footprint radius of the unit being sunk, for deforming terrain
	end
	
	if sinkWrecks then
--		fSunkHeight = {} -- would use this if *actually* sinking wrecks were possible
		fSinkSpeed = {}
		fSinkCount = mRandom(20, 40)
	end
end

local function loadReDir()
	if not VFS.FileExists('data/redirect_sizes.lua') or not VFS.FileExists('data/build_redirect_matrix.u8') then
		Spring.Echo("no redirect matrix files exist")
		return
	end
	local reDirSizes = VFS.Include('data/redirect_sizes.lua')
--	spEcho("reDir size", reDirSizes[1])
	local reDirRead = VFS.LoadFile('data/build_redirect_matrix.u8')
	local reDirTable = VFS.UnpackU8(reDirRead, 1, reDirSizes[1])
--	spEcho("reDirTable size", #reDirTable)
	local reDir = {}
	for i=1, reDirSizes[1], 6 do
		local minbox = reDirTable[i] * 32
		local cx = reDirTable[i+1] * cellSize
		local cz = reDirTable[i+2] * cellSize
		local bx = reDirTable[i+3] * cellSize
		local bz = reDirTable[i+4] * cellSize
		local face = reDirTable[i+5]
--		spEcho(minbox, cx, cz, bx, bz, face)
		if reDir[minbox] == nil then reDir[minbox] = {} end
		if reDir[minbox][cx] == nil then reDir[minbox][cx] = {} end
		reDir[minbox][cx][cz] = { bx, bz, face }
	end
	return reDir
end

local function loadReReDir()
	if not VFS.FileExists('data/redirect_sizes.lua') or not VFS.FileExists('data/redirect_redirect_matrix.u8') then
		Spring.Echo("no redirect redirect matrix files exist")
		return
	end
	local reDirSizes = VFS.Include('data/redirect_sizes.lua')
--	spEcho("reReDir size", reDirSizes[2])
	local reReDirRead = VFS.LoadFile('data/redirect_redirect_matrix.u8')
	local reReDirTable = VFS.UnpackU8(reReDirRead, 1, reDirSizes[2])
--	spEcho("reReDirTable size", #reReDirTable)
	local reReDir = {}
	for i=1, reDirSizes[2], 51 do
		local minbox = reReDirTable[i] * 32
		local cx = reReDirTable[i+1] * cellSize
		local cz = reReDirTable[i+2] * cellSize
		if reReDir[minbox] == nil then reReDir[minbox] = {} end
		if reReDir[minbox][cx] == nil then reReDir[minbox][cx] = {} end
		reReDir[minbox][cx][cz] = {}
		local adder = i+3
		for n=1, 16 do
			local npos = (n-1) * 3
			local bx = reReDirTable[adder+npos] * cellSize
			local bz = reReDirTable[adder+npos+1] * cellSize
			local face = reReDirTable[adder+npos+2]
			reReDir[minbox][cx][cz][n] = { bx, bz, face }
--			spEcho(minbox, cx, cz, n, bx, bz, face)
		end
	end
	return reReDir
end

local function redirectFromMatrix(bx, bz, uDefID)
	local cx = bx - (bx % cellSize)
	local cz = bz - (bz % cellSize)
	local elmos = elmoMaxSize[uDefID]
	if not elmos or not reDir[elmos] or not reDir[elmos][cx] or not reDir[elmos][cx][cz] then
		return
	end
	-- spEcho("reDir entry for ", elmos, cx, cz, " found")
	local bface = reDir[elmos][cx][cz][3]
	local rx = reDir[elmos][cx][cz][1]
	local rz = reDir[elmos][cx][cz][2]
	local x = rx + halfCellSize
	local z = rz + halfCellSize
	local y = spGetGroundHeight(x, z)
	local blocked = spTestBuildOrder(uDefID, x, y, z, bface)
	local spotFound = false
	if isOccupied[rx] == nil then isOccupied[rx] = {} end
	if not isOccupied[rx][rz] and blocked > 0 then
		--spEcho("spot not occupied")
		spotFound = true
	else
		-- spEcho("spot occupied")
		for i = 1, 16 do
			bface = reReDir[elmos][rx][rz][i][3]
			local rrx = reReDir[elmos][rx][rz][i][1]
			local rrz = reReDir[elmos][rx][rz][i][2]
			x = rrx + halfCellSize
			z = rrz + halfCellSize
			y = spGetGroundHeight(x, z)
			blocked = spTestBuildOrder(uDefID, x, y, z, bface)
			if isOccupied[rrx] == nil then isOccupied[rrx] = {} end
			if not isOccupied[rrx][rrz] and blocked > 0 then
				spotFound = true
				-- spEcho("new unoccupied spot found")
				break
			end
		end
	end
	if spotFound then
		return x, z, bface
	end
end

local function valid_node_func(node)
	return not node.occupied
end

local function getBuildGraph(nodeSize)
	local halfNodeSize = nodeSize / 2
	local testSize = 16
	local graph = {}
	local id = 1
	for cx = 0, sizeX-nodeSize, nodeSize do
		local x = cx + halfNodeSize
		for cz = 0, sizeZ-nodeSize, nodeSize do
			local z = cz + halfNodeSize
			local buildable = true
			for tx = cx, cx+nodeSize, testSize do
				for tz = cz, cz+nodeSize, testSize do
					local groundType = spGetGroundInfo(tx, tz)
					if sandType[groundType] then
						buildable = false
						break
					else
						local _, _, _, slope = spGetGroundNormal(tx, tz)
						if slope > maxSlope then
							buildable = false
							break
						end
					end
				end
				if not buildable then break end
			end
			if buildable then
				local node = { x = x, y = z, id = id}
				graph[id] = node
				id = id + 1
				-- spMarkerAddPoint(x, 100, z, nodeSize)
			end
		end
	end
	return graph
end

local function getBuildRedirect(bx, bz, uDefID)
	if reDir and reReDir then return redirectFromMatrix(bx, bz, uDefID) end
	local uDef = UnitDefs[uDefID]
	if not uDef then return end
	local uSize = (mMax(uDef.xsize, uDef.zsize) * 16) + buildSpacing
	uSize = uSize - (uSize % 32)
	-- Spring.Echo("looking for redirect for", uDef.name, uSize)
	local buildGraph = buildGraphs[uSize] or getBuildGraph(uSize)
	if not buildGraphs[uSize] then buildGraphs[uSize] = buildGraph end
	local buildNodeSize = buildNodeSizes[uSize] or ((uSize / 2)^2 * 2)
	if not buildNodeSizes[uSize] then buildNodeSizes[uSize] = buildNodeSize end
	local node = astar.nearest_node(bx, bz, buildGraph, buildNodeSize, valid_node_func)
	if node then
		-- Spring.Echo("got on-the-fly build redirect")
		return node.x, node.y, mRandom(1, 4)
	end
	-- Spring.Echo("no on-the-fly build redirect")
end

local function occupyReDirSpot(unitID, unitDefID)
	local x, y, z = spGetUnitPosition(unitID)
	cx = x - (x % cellSize)
	cz = z - (z % cellSize)
	isOccupied[cx][cz] = true
	unitOccupies[unitID] = { [0]={cx,cz} }
	if isFactory[unitDefID] then
		local dx = { [0]=0, [1]=1, [2]=0, [3]=-1 }
		local dz = { [0]=1, [1]=0, [2]=-1, [3]=0 }
		for d=cellSize, cellsize*3, cellSize do
			local ox
			local oz
			if dx[bface] == 0 then
				oz = cz + d*dz[bface]
				ox = cx
				isOccupied[ox-cellSize][oz] = true
				unitOccupies[unitID][#unitOccupies[unitID]+1] = {ox-cellSize, oz}
				isOccupied[ox][oz] = true
				unitOccupies[unitID][#unitOccupies[unitID]+1] = {ox, oz}
				isOccupied[ox+cellSize][oz] = true
				unitOccupies[unitID][#unitOccupies[unitID]+1] = {ox+cellSize, oz}
			elseif dz[bface] == 0 then
				ox = cx + d*dx[bface]
				oz = cz
				isOccupied[ox][oz-cellSize] = true
				unitOccupies[unitID][#unitOccupies[unitID]+1] = {ox, oz-cellSize}
				isOccupied[ox][oz] = true
				unitOccupies[unitID][#unitOccupies[unitID]+1] = {ox, oz}
				isOccupied[ox][oz+cellSize] = true
				unitOccupies[unitID][#unitOccupies[unitID]+1] = {ox, oz+cellSize}
			end
		end
	end
end

local function occupyBuildSpot(unitID, unitDefID)
	if reDir and reReDir then return occupyReDirSpot(unitID, unitDefID) end
	local x, y, z = spGetUnitPosition(unitID)
	unitOccupiesNodes[unitID] = {}
	for uSize, buildGraph in pairs(buildGraphs) do
		local node = astar.nearest_node(x, z, buildNodeSizes[uSize])
		if node then
			node.occupied = true
			unitOccupiesNodes[unitID][#unitOccupiesNodes[unitID]+1] = node
		end
	end
end

local function footprintOnSand(x, z, unitDefID, facing)
	-- if sandType[spGetGroundInfo(x,z)] then return true end
	local uDef = UnitDefs[unitDefID]
	if not uDef then return end
	local halfFootprintX = uDef.xsize * 4
	local halfFootprintZ = uDef.zsize * 4
	if facing % 2 ~= 0 then
		local hfpz = halfFootprintZ+0
		halfFootprintZ = halfFootprintX
		halfFootprintX = hfpz
	end
	-- spEcho(uDef.xsize, uDef.zsize, halfFootprintX, halfFootprintZ)
	local xmin = x - halfFootprintX
	local xmax = x + halfFootprintX
	local zmin = z - halfFootprintZ
	local zmax = z + halfFootprintZ
	-- spMarkerAddPoint(xmin, 100, zmin, "min")
	-- spMarkerAddPoint(xmax, 100, zmax, "max")
	-- local badFeet = {}
	for tx = xmin, xmax, 16 do
		for tz = zmin, zmax, 16 do
			local groundType = spGetGroundInfo(tx, tz)
			if groundType then
				if sandType[groundType] then
					-- badFeet[#badFeet+1] = {x = tx, z = tz}
					return true
				end
			end
		end
	end
	-- if #badFeet > 0 then return badFeet end
	return false
end

local function sinkThisUnit(unitID, unitDefID)
	local x, y, z = spGetUnitPosition(unitID)
	if not x then return end
	local groundHeight = spGetGroundHeight(x, z)
	local uDef = UnitDefs[unitDefID]
	if not uDef then return end
	local height = uDef.height
	sunkHeight[unitID] = math.floor(groundHeight - height)
	spRemoveBuildingDecal(unitID)
	Spring.MoveCtrl.Enable(unitID)
	Spring.MoveCtrl.SetTrackGround(unitID, false)
	Spring.MoveCtrl.SetVelocity(unitID, 0, -height/1500, 0)
	local xRot = (mRandom() - 0.5) / 1500
	local zRot = (mRandom() - 0.5) / 1500
	Spring.MoveCtrl.SetRotationVelocity(unitID, xRot, 0.00, zRot)
end

-- synced
if gadgetHandler:IsSyncedCode() then

function gadget:Initialize()
	astar = VFS.Include('a-star-lua/a-star.lua')
	local mapOptions = spGetMapOptions()
	if mapOptions then
		if mapOptions.restrict_sand_building == "0" then
			restrictSand = false
		end
		
		if mapOptions.sink_wrecks == "1" then
			sinkWrecks = true
		end
	end
	if not restrictSand and not sinkWrecks then
		spEcho("Sand build restriction and wreck sinking are disabled. Removing gadget.")
		gadgetHandler:RemoveGadget()
		return
	end
	
	if restrictSand then
		local teamList = spGetTeamList()
		for k = 1, #teamList do
			local tID = teamList[k]
			local teamInfo = { spGetTeamInfo(tID) }
			if teamInfo[4] then
				aiPresent = true
			end
		end
	end
	
	if aiPresent then
		spEcho("AI present. Attempting to load build redirection matrix...")
		reDir = loadReDir()
		reReDir = loadReReDir()
		if reDir and reReDir then
			spEcho("Build redirection matrices loaded successfully.")
		else
			spEcho("Could not load build redirection matrices. Using on the fly build redirection.")
		end
		isOccupied = {}
		occupyThis = {}
		unitOccupies = {}
		elmoMaxSize = {}
	else
		spEcho("No AI present. Build redirection matrix not loaded.")
	end

	-- so that if luarules is reloaded midgame (for testing) it won't break
	local fmd, fdd = spGetGameFrame()
	if fmd > 1 or fdd > 1 then doInit() end
end

function gadget:GameStart()
	doInit()
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag, synced)
	if aiPresent and restrictSand then
		local teamInfo = { spGetTeamInfo(unitTeam) }
		if teamInfo[4] and isNotValid[-cmdID] then
			if #cmdParams > 2 then
				local bx, bz = cmdParams[1], cmdParams[3]
				local groundType, _ = spGetGroundInfo(bx, bz)
				if footprintOnSand(bx, bz, -cmdID, cmdParams[4]) then
					local x, z, bface = getBuildRedirect(bx, bz, -cmdID)
					bface = bface or cmdParams[4]
					if x then
						occupyThis = { unitID, unitTeam, uDefID }
						spGiveOrderToUnit(unitID, cmdID, {x, spGetGroundHeight(x,z), z, bface}, cmdOpts)
						return false
					end
				end
			end
		end
	end
	return true
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
  if restrictSand then
    if sunkHeight[unitID] then
      sunkHeight[unitID] = nil
      sinkRadius[unitID] = nil
    end
    if sinkUnit[unitID] then
      sinkUnit[unitID] = nil
    end
    
    if aiPresent then
		if unitOccupies[unitID] then
		  for n = 1, #unitOccupies[unitID] do
		  	local xz = unitOccupies[unitID][n]
			local ox, oz = xz
			isOccupied[ox][oz] = false
		  end
		  unitOccupies[unitID] = nil
		end
		if unitOccupiesNodes[unitID] then
			for i = 1, #unitOccupiesNodes[unitID] do
				local node = unitOccupiesNodes[unitID][i]
				node.occupied = nil
			end
			unitOccupiesNodes[unitID] = nil
		end
    end
  end
end

function gadget:FeatureDestroyed(featureID, allyTeam)
	if sinkWrecks then
--		fSunkHeight[featureID] = nil
		fSinkSpeed[featureID] = nil
	end
end

function gadget:GameFrame(gf)

  if restrictSand then
    if sinkCount > 1 then
      sinkCount = sinkCount - 1
    else
      for uID, sh in pairs(sunkHeight) do
        local x, y, z = spGetUnitPosition(uID)
        if y > sh then
			local h, maxH, _ = spGetUnitHealth(uID)
			if h > maxH * 0.05 then
				spAddUnitDamage(uID, h * 0.03)
			end
        else
          sunkHeight[uID] = nil
          sinkRadius[uID] = nil
          spDestroyUnit(uID, false, true)
        end
      end
      sinkCount = mRandom(10, 20)
    end
  end
	
	if sinkWrecks then
		if fSinkCount > 1 then
			fSinkCount = fSinkCount - 1
		else
--			spEcho("feature sink frame")
			for fID, ss in pairs(fSinkSpeed) do
--				local x, y, z = spGetFeaturePosition(fID)
				local health = spGetFeatureHealth(fID)
				if health > 0 then
--					spEcho("sinking feature", fID, fSinkSpeed[fID], fSunkHeight[fID])
--					spSetFeaturePosition(fID, x, y-1, z, false)
					spSetFeatureHealth(fID, health-ss)
				else
--					fSunkHeight[fID] = nil
					fSinkSpeed[fID] = nil
					spDestroyFeature(fID)
				end
			end
			fSinkCount = mRandom(20, 40)
		end
	end
	
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
	if not restrictSand then return end
	local x, y, z = spGetUnitPosition(unitID)
	if x then
		if footprintOnSand(x, z, unitDefID, spGetUnitBuildFacing(unitID)) then
		-- local groundType, _ = spGetGroundInfo(x, z)
		-- if sandType[groundType] then
			if (not builderID) then return true end   --no builder -> morph or something like that
			if builderTeam == spGetGaiaTeamID() then return true end
			if isNotValid[unitDefID] then
				if UnitDefs[unitDefID].isFeature then
					spDestroyUnit(unitID, true, true)
				else
					sinkThisUnit(unitID, unitDefID)
					-- sinkUnit[unitID] = true
				end
				return false
			end
		end
	end
	if occupyThis == { builderID, teamID, unitDefID } then
		occupyBuildSpot(unitID, unitDefID, teamID, builderID)
		occupyThis = {}
	end
end

function gadget:FeatureCreated(featureID, allyTeam)
	if not sinkWrecks then return end
	local x, y, z = spGetFeaturePosition(featureID)
	if (x ~= nil) and (z ~= nil) then
		local groundType, _ = spGetGroundInfo(x, z)
		if sandType[groundType] then
			local fDefID = spGetFeatureDefID(featureID)
--			fSunkHeight[featureID] = y - FeatureDefs[fDefID].height
			fSinkSpeed[featureID] = FeatureDefs[fDefID].maxHealth / 45
--			spEcho("will sink", featureID, fSunkHeight[featureID], fSinkSpeed[featureID])
		end
	end
end

function gadget:RecvLuaMsg(msg, playerID)
	if msg == 'Sand Build Helper Widget Loaded' then
		for uDefID, valid in pairs(isNotValid) do
			SendToUnsynced("passIsNotValid", uDefID)
		end
	end
end

end
-- end synced


-- unsynced --
if not gadgetHandler:IsSyncedCode() then

	local function isNotValidToLuaUI(_,uDefID)
	  if (Script.LuaUI('passIsNotValid')) then
		Script.LuaUI.passIsNotValid(uDefID)
	  end
	end

	function gadget:Initialize()
	  gadgetHandler:AddSyncAction('passIsNotValid', isNotValidToLuaUI)      
	end

end