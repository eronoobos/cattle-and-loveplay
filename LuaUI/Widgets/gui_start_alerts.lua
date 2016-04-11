function widget:GetInfo()
	return {
		name	= "Cattle and Loveplay: Start Alerts",
		desc	= "displays map option alerts before the game starts",
		author  = "zoggop",
		date 	= "February 2012",
		license	= "whatever",
		layer 	= 0,
		enabled	= true
	}
end

local gameStarted = false

local restrictSand = true
local sinkWrecks = false
local areWorms = true

local startDelay = 1 -- how many frames to keep alert
local sandType = { ["Sand"] = true }
local sandGraph
local sandNodeSize = 256
local sandNodeDist = ((sandNodeSize / 2)^2 * 2)
local astar

local sandTitle
local sandWarning

local alertCounter
local myHeaderFont
local myFont
local sizeX = Game.mapSizeX 
local sizeZ = Game.mapSizeZ
local sandyStarts = {}
local startsChanged = 1

local screenDisplayList = 0

local alertHeight = 250

local spGetGroundInfo = Spring.GetGroundInfo
local tInsert = table.insert

local function getSandGraph(nodeSize)
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

local function DoLine(x1, y1, z1, x2, y2, z2)
    gl.Vertex(x1, y1, z1)
    gl.Vertex(x2, y2, z2)
end

local function nearestNodeScreenCoords(sx, sy, nodes, nodeDist)
	local _, pos = Spring.TraceScreenRay(sx, sy, true)
	if pos then
		local node = astar.nearest_node(pos[1], pos[3], nodes, nodeDist)
		if node then
			local nsx, nsy = Spring.WorldToScreenCoords(node.x, Spring.GetGroundHeight(node.x, node.y), node.y)
			return nsx, nsy
		end
	end
end

local function cameraStatesMatch(stateA, stateB)
	if not stateA or not stateB then return end
	if #stateA ~= #stateB then return end
	for key, value in pairs(stateA) do
		if value ~= stateB[key] then return end
	end
	return true
end

local function drawLandMarker(r, g, b, a, x1, y1, x2, y2, x3)
	for n=5, 4, -1 do
		if n == 5 then
			gl.LineWidth(4)
			gl.Color(0, 0, 0, a)
		else
			gl.LineWidth(2)
			gl.Color(r, g, b, a)
		end
		if x3 then
			gl.BeginEnd(GL.LINE_STRIP, DoLine, x1, y1, 0, x3, y1, 0)
			gl.BeginEnd(GL.LINE_STRIP, DoLine, x3, y1, 0, x3, y2, 0)
			gl.BeginEnd(GL.LINE_STRIP, DoLine, x3, y2, 0, x2, y2, 0)
		else
			gl.BeginEnd(GL.LINE_STRIP, DoLine, x1, y1, 0, x2, y1, 0)
			gl.BeginEnd(GL.LINE_STRIP, DoLine, x2, y1, 0, x2, y2, 0)
		end
		gl.Rect(x2-n, y2-n, x2+n, y2+n)
	end
end

local function drawAlerts(viewX, viewY, sx, sy, alertX, alertSlide, alertOpacity, sandyStarts)
	gl.Color(1, 0.9, 0.5, 1)
	myFont:Print(sandTitle, alertX, viewY*0.3, 36, "rvno")
	myFont:Print(sandTitle, alertX, viewY*0.3, 36, "rvn")
	myFont:Print(sandWarning, alertX, viewY*0.26, 16, "rvo")
	myFont:Print(sandWarning, alertX, viewY*0.26, 16, "rv")
	if sx then
		if sx > viewX*0.65 then
			drawLandMarker(1.0, 0.9, 0.5, alertOpacity, viewX*0.61*alertSlide, viewY*0.3, sx, sy)
		else
			drawLandMarker(1.0, 0.9, 0.5, alertOpacity, viewX*0.61*alertSlide, viewY*0.3, sx, sy, viewX*0.63)
		end
	end
	gl.Color(1, 0, 0, 1)
	gl.LineWidth(4)
	for _, start in pairs(sandyStarts) do
		local scrX, scrY = Spring.WorldToScreenCoords(start.x,start.y,start.z)
		-- gl.BeginEnd(GL.LINE_STRIP, DoLine, start.x-48, start.y-48, 0, start.x+48, start.y-48, 0)
		-- gl.BeginEnd(GL.LINE_STRIP, DoLine, start.x+48, start.y-48, 0, start.x+48, start.y+48, 0)
		-- gl.BeginEnd(GL.LINE_STRIP, DoLine, start.x+48, start.y+48, 0, start.x-48, start.y+48, 0)
		-- gl.BeginEnd(GL.LINE_STRIP, DoLine, start.x-48, start.y+48, 0, start.x-48, start.y-48, 0)
		myFont:Print("CAUTION", scrX, scrY+30, 20, "cdo")
		myFont:Print("CAUTION", scrX, scrY+30, 20, "cd")
		myFont:Print("SAND", scrX, scrY-30, 20, "cao")
		myFont:Print("SAND", scrX, scrY-30, 20, "ca")
	end
	gl.Color(1, 1, 1, 0.5)
end


-- callins

function widget:Initialize()
	local mapOptions = Spring.GetMapOptions()
	if mapOptions then
		if mapOptions.restrict_sand_building == "0" then
			restrictSand = false
		end
		if mapOptions.sink_wrecks == "1" then
			sinkWrecks = true
		end
		if mapOptions.sand_worms == "0" then
			areWorms = false
		end
	end
	if not restrictSand and not sinkWrecks and not areWorms then
		Spring.Echo("No map options have been enabled. Start Alerts widget has been disbled.")
		widgetHandler:RemoveWidget()
	else
		if restrictSand and not sinkWrecks then
			sandTitle = "HAZARDOUS SAND"
			sandWarning = "Non-metal-extracting structures sink."
		elseif sinkWrecks and not restrictSand then
			sandTitle = "SAND"
			sandWarning = "Wrecks sink."
		elseif sinkWrecks and restrictSand then
			sandTitle = "HAZARDOUS SAND"
			sandWarning = "Non-metal-extracting structures & wrecks sink."
		end
		alertCounter = 50
		myFont = gl.LoadFont("LuaUI/Fonts/Orbitron Bold.ttf", 72, 12)
		if areWorms then
			sandTitle = "HAZARDOUS SAND"
			sandWarning = sandWarning .. " Worms eat units."
		end
		sandGraph = getSandGraph(sandNodeSize)
		astar = VFS.Include('a-star-lua/a-star.lua')
	end
	if Game.startPosType ~= 2 then
		startDelay = 300 -- display alert for 10 seconds if start positions are not chosen in-game
	end
end

function widget:Update(dt)
	if gameStarted and alertCounter == 0 then
		widgetHandler:RemoveWidget()
		return
	end
	if alertCounter > 0 then
		alertCounter = alertCounter - 1
	end
	local camState = Spring.GetCameraState()
	if lastAlertCounter == 0 and alertCounter == 0 and startsChanged == -1 and cameraStatesMatch(camState, lastCamState) then
		return
	end
	local alertOpacity = 1
	local alertSlide = 1
	if gameStarted then
		alertOpacity = alertCounter / 80
		alertSlide = alertCounter / 80
	else
		alertOpacity = (50 - alertCounter) / 50
		alertSlide = (50 - alertCounter) / 50
	end
	local viewX, viewY, posX, posY = Spring.GetViewGeometry()
	local centerX = (viewX / 2)
	local centerY = (viewY / 2)	
	local alertX = viewX*0.6*alertSlide
	local sx, sy = nearestNodeScreenCoords(viewX*0.8, viewY*0.5, sandGraph, sandNodeDist)
	if not sx then
		sx, sy = nearestNodeScreenCoords(viewX*0.4, viewY*0.5, sandGraph, sandNodeDist)
	end
	if startsChanged == 0 then
		sandyStarts = {}
		if (restrictSand or areWorms) and not gameStarted then
			for _,t in ipairs(Spring.GetTeamList()) do
				local x,y,z = Spring.GetTeamStartPosition(t)
				if x and x > 0 and z > 0 then
					local groundType, _ = Spring.GetGroundInfo(x, z)
					if sandType[groundType] then
						table.insert(sandyStarts, {x=x, y=y, z=z,})
					end
				end
			end
		end
	end
	screenDisplayList = gl.CreateList(drawAlerts, viewX, viewY, sx, sy, alertX, alertSlide, alertOpacity, sandyStarts)
	lastCamState = camState
	lastAlertCounter = alertCounter
	startsChanged = math.max(-1, startsChanged - 1)
end

function widget:MousePress(x, y, button)
	startsChanged = 1
end

function widget:DrawScreen()
	gl.CallList(screenDisplayList)
end

function widget:GameFrame(f)
	if f > startDelay and not gameStarted then
		gameStarted = true
		alertCounter = 80
	end
end