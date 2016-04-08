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
local sandType = { ["Sand"] = true }
local maxSlope = 0.25
local buildSpacing = 16

-- these default values are changed in gadget:Initialize()
local aiPresent = false
local restrictSand = true
local sinkWrecks = true

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

local spGetGroundInfo = Spring.GetGroundInfo
local tInsert = table.insert

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
		if not ignore and (uDef.extractsMetal == 0) and (uDef.maxAcc < 0.01) then --if it's not a metal extractor and does not move, it is not valid
		  if string.find(uDef.tooltip, " Mine") == nil then --if it's a mine, it is valid
			isNotValid[uDefID] = true
			SendToUnsynced("passIsNotValid", uDefID)
--			Spring.Echo(uDefID, 'sent from gadget')
			if aiPresent then
			  elmoMaxSize[uDefID] = math.max(uDef.xsize, uDef.zsize) * 8
			  elmoMaxSize[uDefID] = elmoMaxSize[uDefID] - (elmoMaxSize[uDefID] % 32) + 32
			end
		  end
		end
	  end
	
	
	  sinkCount = math.random(10, 20)
	  sinkUnit = {} -- stores which units to sink between UnitCreated() and UnitFinished() so that units can be better evaluated in UnitCreated()
	  sunkHeight = {} -- stores which units to sink (key) to what height (value)
	  sinkRadius = {} -- stores the footprint radius of the unit being sunk, for deforming terrain
	end
	
	if sinkWrecks then
--		fSunkHeight = {} -- would use this if *actually* sinking wrecks were possible
		fSinkSpeed = {}
		fSinkCount = math.random(20, 40)
	end
end

local function loadReDir()
	if not VFS.FileExists('data/redirect_sizes.lua') or not VFS.FileExists('data/build_redirect_matrix.u8') then
		Sping.Echo("no redirect matrix files exist")
		return
	end
	local reDirSizes = VFS.Include('data/redirect_sizes.lua')
--	Spring.Echo("reDir size", reDirSizes[1])
	local reDirRead = VFS.LoadFile('data/build_redirect_matrix.u8')
	local reDirTable = VFS.UnpackU8(reDirRead, 1, reDirSizes[1])
--	Spring.Echo("reDirTable size", #reDirTable)
	local reDir = {}
	for i=1, reDirSizes[1], 6 do
		local minbox = reDirTable[i] * 32
		local cx = reDirTable[i+1] * cellSize
		local cz = reDirTable[i+2] * cellSize
		local bx = reDirTable[i+3] * cellSize
		local bz = reDirTable[i+4] * cellSize
		local face = reDirTable[i+5]
--		Spring.Echo(minbox, cx, cz, bx, bz, face)
		if reDir[minbox] == nil then reDir[minbox] = {} end
		if reDir[minbox][cx] == nil then reDir[minbox][cx] = {} end
		reDir[minbox][cx][cz] = { bx, bz, face }
	end
	return reDir
end

local function loadReReDir()
	if not VFS.FileExists('data/redirect_sizes.lua') or not VFS.FileExists('data/redirect_redirect_matrix.u8') then
		Sping.Echo("no redirect redirect matrix files exist")
		return
	end
	local reDirSizes = VFS.Include('data/redirect_sizes.lua')
--	Spring.Echo("reReDir size", reDirSizes[2])
	local reReDirRead = VFS.LoadFile('data/redirect_redirect_matrix.u8')
	local reReDirTable = VFS.UnpackU8(reReDirRead, 1, reDirSizes[2])
--	Spring.Echo("reReDirTable size", #reReDirTable)
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
--			Spring.Echo(minbox, cx, cz, n, bx, bz, face)
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
	-- Spring.Echo("reDir entry for ", elmos, cx, cz, " found")
	local bface = reDir[elmos][cx][cz][3]
	local rx = reDir[elmos][cx][cz][1]
	local rz = reDir[elmos][cx][cz][2]
	local x = rx + halfCellSize
	local z = rz + halfCellSize
	local y = Spring.GetGroundHeight(x, z)
	local blocked = Spring.TestBuildOrder(uDefID, x, y, z, bface)
	local spotFound = false
	if isOccupied[rx] == nil then isOccupied[rx] = {} end
	if not isOccupied[rx][rz] and blocked > 0 then
		--Spring.Echo("spot not occupied")
		spotFound = true
	else
		-- Spring.Echo("spot occupied")
		for i = 1, 16 do
			bface = reReDir[elmos][rx][rz][i][3]
			local rrx = reReDir[elmos][rx][rz][i][1]
			local rrz = reReDir[elmos][rx][rz][i][2]
			x = rrx + halfCellSize
			z = rrz + halfCellSize
			y = Spring.GetGroundHeight(x, z)
			blocked = Spring.TestBuildOrder(uDefID, x, y, z, bface)
			if isOccupied[rrx] == nil then isOccupied[rrx] = {} end
			if not isOccupied[rrx][rrz] and blocked > 0 then
				spotFound = true
				-- Spring.Echo("new unoccupied spot found")
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
						local _, _, _, slope = Spring.GetGroundNormal(tx, tz)
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
				id = id + 1
				tInsert(graph, node)
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
	local uSize = ((math.max(uDef.xsize, uDef.zsize) * 16) + buildSpacing) % 32
	local buildGraph = buildGraphs[uSize] or getBuildGraph(uSize)
	if not buildGraphs[uSize] then buildGraphs[uSize] = buildGraph end
	local buildNodeSize = buildNodeSizes[uSize] or ((uSize / 2)^2 * 2)
	if not buildNodeSizes[uSize] then buildNodeSizes[uSize] = buildNodeSize end
	local node = astar.nearest_node(bx, bz, buildGraph, buildNodeSize, valid_node_func)
	if node then
		return node.x, node.y, math.random(1, 4)
	end
end

local function occupyReDirSpot(unitID, unitDefID)
	local x, y, z = Spring.GetUnitPosition(unitID)
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
				table.insert(unitOccupies[unitID], {ox-cellSize, oz})
				isOccupied[ox][oz] = true
				table.insert(unitOccupies[unitID], {ox, oz})
				isOccupied[ox+cellSize][oz] = true
				table.insert(unitOccupies[unitID], {ox+cellSize, oz})
			elseif dz[bface] == 0 then
				ox = cx + d*dx[bface]
				oz = cz
				isOccupied[ox][oz-cellSize] = true
				table.insert(unitOccupies[unitID], {ox, oz-cellSize})
				isOccupied[ox][oz] = true
				table.insert(unitOccupies[unitID], {ox, oz})
				isOccupied[ox][oz+cellSize] = true
				table.insert(unitOccupies[unitID], {ox, oz+cellSize})
			end
		end
	end
end

local function occupyBuildSpot(unitID, unitDefID)
	if reDir and reReDir then return occupyReDirSpot(unitID, unitDefID) end
	local x, y, z = Spring.GetUnitPosition(unitID)
	unitOccupiesNodes[unitID] = {}
	for uSize, buildGraph in pairs(buildGraphs) do
		local node = astar.nearest_node(x, z, buildNodeSizes[uSize])
		if node then
			node.occupied = true
			table.insert(unitOccupiesNodes[unitID], node)
		end
	end
end

-- synced
if gadgetHandler:IsSyncedCode() then

function gadget:Initialize()
	astar = VFS.Include('a-star-lua/a-star.lua')
	local mapOptions = Spring.GetMapOptions()
	if mapOptions then
		if mapOptions.restrict_sand_building == "0" then
			restrictSand = false
		end
		
		if mapOptions.sink_wrecks == "0" then
			sinkWrecks = false
		end
	end
	if not restrictSand and not sinkWrecks then
		Spring.Echo("Sand build restriction and wreck sinking are disabled. Removing gadget.")
		gadgetHandler:RemoveGadget()
		return
	end
	
	if restrictSand then
		local teamList = Spring.GetTeamList()
		for k, tID in pairs(teamList) do
			local teamInfo = { Spring.GetTeamInfo(tID) }
			if teamInfo[4] then
				aiPresent = true
			end
		end
	end
	
	if aiPresent then
		Spring.Echo("AI present. Loading build redirection matrix...")
		-- reDir = loadReDir()
		-- reReDir = loadReReDir()
		if not reDir or not reReDir then
			-- Spring.Echo("using on the fly build redirection")
		end
		isOccupied = {}
		occupyThis = {}
		unitOccupies = {}
		elmoMaxSize = {}
	else
		Spring.Echo("No AI present. Build redirection matrix not loaded.")
	end

	-- so that if luarules is reloaded midgame (for testing) it won't break
	local fmd, fdd = Spring.GetGameFrame()
	if fmd > 1 or fdd > 1 then doInit() end
end

function gadget:GameStart()
	doInit()
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag, synced)
	if aiPresent and restrictSand then
		local teamInfo = { Spring.GetTeamInfo(unitTeam) }
		if teamInfo[4] and isNotValid[-cmdID] then
			if #cmdParams > 2 then
				local bx, bz = cmdParams[1], cmdParams[3]
				local groundType, _ = Spring.GetGroundInfo(bx, bz)
				if sandType[groundType] then
					local x, z, bface = getBuildRedirect(bx, bz, -cmdID)
					if x then
						occupyThis = { unitID, unitTeam, uDefID }
						Spring.GiveOrderToUnit(unitID, cmdID, {x, Spring.GetGroundHeight(x,z), z, bface}, cmdOpts)
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
		if unitOccupies[unitID] ~= nil then
		  for n, xz in pairs(unitOccupies[unitID]) do
			local ox, oz = xz
			isOccupied[ox][oz] = false
		  end
		  unitOccupies[unitID] = nil
		end
		if unitOccupiesNodes[unitID] then
			for _, node in pairs(unitOccupiesNodes) do
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
        local x, y, z = Spring.GetUnitPosition(uID)
        if y > sh then
  --				local h, maxH, _ = Spring.GetUnitHealth(uID)
  --				if h > maxH / 20 then
  --					Spring.AddUnitDamage(uID, h / 30)
  --				end
          local x1 = x - sinkRadius[uID]
          local z1 = z - sinkRadius[uID]
          local x2 = x + sinkRadius[uID]
          local z2 = z + sinkRadius[uID]
          for rmod=32, 0, -8 do
            local hmod = (rmod - 16) * 0.001
            local jitterz = math.random(0, 32) - 16
            local jitterx = math.random(0, 32) - 16
            local ax, az = x1-rmod+jitterx, z1-rmod+jitterz
            if sandType[Spring.GetGroundInfo(ax,az)] then
            	local bx, bz = x1-rmod+jitterx, z1+rmod+jitterz
            	if sandType[Spring.GetGroundInfo(bx,bz)] then
            		local cx, cz = x1+rmod+jitterx, z1-rmod+jitterz
            		if sandType[Spring.GetGroundInfo(cx,cz)] then
            			local dx, dz = x1+rmod+jitterx, z1+rmod+jitterz
            			if sandType[Spring.GetGroundInfo(dx,dz)] then
            				Spring.AdjustHeightMap(ax, az, dx, dz, hmod)
            			end
            		end
            	end
            end
          end
        else
          sunkHeight[uID] = nil
          sinkRadius[uID] = nil
          Spring.DestroyUnit(uID, false, true)
        end
      end
      sinkCount = math.random(10, 20)
    end
  end
	
	if sinkWrecks then
		if fSinkCount > 1 then
			fSinkCount = fSinkCount - 1
		else
--			Spring.Echo("feature sink frame")
			for fID, ss in pairs(fSinkSpeed) do
--				local x, y, z = Spring.GetFeaturePosition(fID)
				local health = Spring.GetFeatureHealth(fID)
				if health > 0 then
--					Spring.Echo("sinking feature", fID, fSinkSpeed[fID], fSunkHeight[fID])
--					Spring.SetFeaturePosition(fID, x, y-1, z, false)
					Spring.SetFeatureHealth(fID, health-ss)
				else
--					fSunkHeight[fID] = nil
					fSinkSpeed[fID] = nil
					Spring.DestroyFeature(fID)
				end
			end
			fSinkCount = math.random(20, 40)
		end
	end
	
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
	if not restrictSand then return end
	local x, y, z = Spring.GetUnitPosition(unitID)
	if (x ~= nil) and (z ~= nil) then
		local groundType, _ = Spring.GetGroundInfo(x, z)
		if sandType[groundType] then
			if (not builderID) then return true end   --no builder -> morph or something like that
			if builderTeam == Spring.GetGaiaTeamID() then return true end
			if isNotValid[unitDefID] then
				if UnitDefs[unitDefID].isFeature then
					Spring.DestroyUnit(unitID, true, true)
				else
					sinkUnit[unitID] = true
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
	local x, y, z = Spring.GetFeaturePosition(featureID)
	if (x ~= nil) and (z ~= nil) then
		local groundType, _ = Spring.GetGroundInfo(x, z)
		if sandType[groundType] then
			local fDefID = Spring.GetFeatureDefID(featureID)
--			fSunkHeight[featureID] = y - FeatureDefs[fDefID].height
			fSinkSpeed[featureID] = FeatureDefs[fDefID].maxHealth / 45
--			Spring.Echo("will sink", featureID, fSunkHeight[featureID], fSinkSpeed[featureID])
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, teamID)
	if restrictSand and sinkUnit[unitID] then
          local x, y, z = Spring.GetUnitPosition(unitID)
          local groundHeight = Spring.GetGroundHeight(x, z)
          local height = UnitDefs[unitDefID].height
          sunkHeight[unitID] = math.floor(groundHeight - height)
          local size = math.max(UnitDefs[unitDefID].xsize * 7, UnitDefs[unitDefID].zsize * 7) --should be 8. it is 7 so that the deformations are a bit smaller than the building
          sinkRadius[unitID] = size / 2
          Spring.RemoveBuildingDecal(unitID)
          Spring.MoveCtrl.Enable(unitID)
          Spring.MoveCtrl.SetTrackGround(unitID, false)
          Spring.MoveCtrl.SetVelocity(unitID, 0, -height/1500, 0)
          local xRot = (math.random() - 0.5) / 1500
          local zRot = (math.random() - 0.5) / 1500
          Spring.MoveCtrl.SetRotationVelocity(unitID, xRot, 0.00, zRot)
          sinkUnit[unitID] = nil
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