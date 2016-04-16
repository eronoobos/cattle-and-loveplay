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

local wormConfig = VFS.Include('wormconfig/wormconfig.lua')
local sandType = wormConfig.sandType

local startDelay = 1 -- how many frames to keep alert
local sandGraph
local sandNodeSize = 256
local sandNodeDist = ((sandNodeSize / 2)^2 * 2)
local astar

local alertR, alertG, alertB = 1.0, 0.63, 0.33

local sandTitle
local sandWarning

local alertCounter
local nodeX, nodeY, nodeZ
local myFont
local myBodyFont
local sizeX = Game.mapSizeX 
local sizeZ = Game.mapSizeZ

local screenDisplayList = 0

local alertHeight = 250

local spGetGroundInfo = Spring.GetGroundInfo
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spGetGroundHeight = Spring.GetGroundHeight
local spGetMapOptions = Spring.GetMapOptions
local spGetCameraState = Spring.GetCameraState
local spGetViewGeometry = Spring.GetViewGeometry
local spGetTeamList = Spring.GetTeamList
local spGetTeamStartPosition = Spring.GetTeamStartPosition
local spTraceScreenRay = Spring.TraceScreenRay
local spEcho = Spring.Echo

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glRect = gl.Rect
local glLoadFont = gl.LoadFont

local GL_LINE_STRIP = GL.LINE_STRIP

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
				graph[id] = node
				id = id + 1
			end
		end
	end
	return graph
end

local function doLine2d(x1, y1, x2, y2)
    glVertex(x1, y1)
    glVertex(x2, y2)
end

local function nearestNodeAtScreenCoords(sx, sy, nodes, nodeDist)
	local _, pos = spTraceScreenRay(sx, sy, true)
	if pos then
		local node = astar.nearest_node(pos[1], pos[3], nodes, nodeDist)
		if node then
			return node.x, spGetGroundHeight(node.x, node.y), node.y
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
	for n=5, 3, -2 do
		if n == 5 then
			glLineWidth(6)
			glColor(0, 0, 0, a)
			glBeginEnd(GL_LINE_STRIP, doLine2d, x2, y1, x2+2, y1)
		else
			glLineWidth(2)
			glColor(r, g, b, a)
		end
		if x3 then
			glBeginEnd(GL_LINE_STRIP, doLine2d, x1, y1, x3, y1)
			glBeginEnd(GL_LINE_STRIP, doLine2d, x3, y1, x3, y2)
			glBeginEnd(GL_LINE_STRIP, doLine2d, x3, y2, x2, y2)
		else
			glBeginEnd(GL_LINE_STRIP, doLine2d, x1, y1, x2, y1)
			glBeginEnd(GL_LINE_STRIP, doLine2d, x2, y1, x2, y2)
		end
		glRect(x2-n, y2-n, x2+n, y2+n)
	end
end

local function drawStartPosCaution(scrX,scrY)
	myFont:Begin()
	myFont:SetTextColor(1.0, 0.0, 0.0, 1.0)
	myFont:Print("CAUTION", scrX, scrY+30, 20, "cdo")
	myFont:Print("SAND", scrX, scrY-30, 20, "cao")
	myFont:End()
end

local function drawAlerts(viewX, viewY, sx, sy, alertX, alertSlide, alertOpacity)
	glColor(1, 1, 1, 1)
	myFont:Begin()
	myFont:SetTextColor(alertR, alertG, alertB, alertOpacity)
	myFont:Print(sandTitle, alertX, viewY*0.4, 36, "rvo")
	myFont:End()
	myBodyFont:Begin()
	myBodyFont:SetTextColor(alertR, alertG, alertB, alertOpacity)
	myBodyFont:Print(sandWarning, alertX, viewY*0.36, 16, "rvo")
	myBodyFont:End()
	if sx then
		if sx > viewX*0.65 then
			drawLandMarker(alertR, alertG, alertB, alertOpacity, viewX*0.61*alertSlide, viewY*0.4, sx, sy)
		else
			drawLandMarker(alertR, alertG, alertB, alertOpacity, viewX*0.61*alertSlide, viewY*0.4, sx, sy, viewX*0.63)
		end
	end
	glColor(1, 1, 1, 0.5)
end


-- callins

function widget:Initialize()
	local mapOptions = spGetMapOptions()
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
		spEcho("No map options have been enabled. Start Alerts widget has been disbled.")
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
		myFont = glLoadFont('LuaUI/Fonts/Orbitron Bold.ttf', 36, 4, 10)
		myBodyFont = glLoadFont('LuaUI/Fonts/Orbitron Bold.ttf', 16, 4, 5)
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
	local camState = spGetCameraState()
	local camsMatch =  cameraStatesMatch(camState, lastCamState)
	if lastAlertCounter == 0 and alertCounter == 0 and nodeX and camsMatch then
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
	local viewX, viewY, posX, posY = spGetViewGeometry()
	local centerX = (viewX / 2)
	local centerY = (viewY / 2)	
	local alertX = viewX*0.6*alertSlide
	local sx, sy
	if nodeX then
		sx, sy = spWorldToScreenCoords(nodeX, nodeY, nodeZ)
		if sx > viewX or sx < 0 or sy > viewY or sy < 0 then nodeX, nodeY, nodeZ = nil, nil, nil end
	end
	if not camsMatch or not nodeX then
		nodeX, nodeY, nodeZ = nearestNodeAtScreenCoords(viewX*0.8, viewY*0.5, sandGraph, sandNodeDist)
		if nodeX then
			sx, sy = spWorldToScreenCoords(nodeX, nodeY, nodeZ)
			if sx > viewX or sx < 0 or sy > viewY or sy < 0 then nodeX, nodeY, nodeZ = nil, nil, nil end
		else
			nodeX, nodeY, nodeZ = nearestNodeAtScreenCoords(viewX*0.4, viewY*0.5, sandGraph, sandNodeDist)
			if nodeX then
				sx, sy = spWorldToScreenCoords(nodeX, nodeY, nodeZ)
				if sx > viewX or sx < 0 or sy > viewY or sy < 0 then nodeX, nodeY, nodeZ = nil, nil, nil end
			else
				nodeX, nodeY, nodeZ = nearestNodeAtScreenCoords(viewX*0.5, viewY*0.2, sandGraph, sandNodeDist)
				if nodeX then
					sx, sy = spWorldToScreenCoords(nodeX, nodeY, nodeZ)
					if sx > viewX or sx < 0 or sy > viewY or sy < 0 then nodeX, nodeY, nodeZ = nil, nil, nil end
				else
					nodeX, nodeY, nodeZ = nearestNodeAtScreenCoords(viewX*0.5, viewY*0.8, sandGraph, sandNodeDist)
					if nodeX then
						sx, sy = spWorldToScreenCoords(nodeX, nodeY, nodeZ)
						if sx > viewX or sx < 0 or sy > viewY or sy < 0 then nodeX, nodeY, nodeZ = nil, nil, nil end
					end
				end
			end
		end
	end
	if not nodeX then sx, sy = nil, nil end
	screenDisplayList = glCreateList(drawAlerts, viewX, viewY, sx, sy, alertX, alertSlide, alertOpacity, sandyStarts)
	lastCamState = camState
	lastAlertCounter = alertCounter
end

function widget:DrawScreen()
	if (restrictSand or areWorms) and not gameStarted then
		glColor(1, 0, 0, 1)
		local teamList = spGetTeamList()
		for i = 1, #teamList do
			local t = teamList[i]
			local x,y,z = spGetTeamStartPosition(t)
			if x and x > 0 and z > 0 then
				local groundType, _ = spGetGroundInfo(x, z)
				if sandType[groundType] then
					local scrX, scrY = spWorldToScreenCoords(x,y,z)
					drawStartPosCaution(scrX,scrY)
				end
			end
		end
		glColor(1, 1, 1, 0.5)
	end
	glCallList(screenDisplayList)
end

function widget:GameFrame(f)
	if f > startDelay and not gameStarted then
		gameStarted = true
		alertCounter = 80
	end
end

function widget:Shutdown()
	glDeleteList(screenDisplayList)
end