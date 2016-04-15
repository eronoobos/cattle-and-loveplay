function widget:GetInfo()
	return {
		name	= "Cattle and Loveplay: Sand Build Command Helper",
		desc	= "shows where not to build",
		author  = "zoggop",
		date 	= "February 2012",
		license	= "whatever",
		layer 	= 0,
		enabled	= true
	}
end

local restrictSand = true
local isNotValid

local wormConfig = VFS.Include('wormconfig/wormconfig.lua')
local sandType = wormConfig.sandType

local bx, by, bz
local mouseX, mouseY
local lastCamState
local lastCmdID
local lastFacing
local myBadFeet
local worldDisplayList = 0
local screenDisplayList = 0
local myFont

local spGetGroundInfo = Spring.GetGroundInfo
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spGetMapOptions = Spring.GetMapOptions
local spGetCameraState = Spring.GetCameraState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetMouseState = Spring.GetMouseState
local spGetBuildFacing = Spring.GetBuildFacing
local spGetActiveCommand = Spring.GetActiveCommand
local spSendLuaGaiaMsg = Spring.SendLuaGaiaMsg
local spPos2BuildPos = Spring.Pos2BuildPos
local spEcho = Spring.Echo

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glColor = gl.Color
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glLoadFont = gl.LoadFont
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glDepthTest = gl.DepthTest

local GL_TRIANGLE_STRIP = GL.TRIANGLE_STRIP

function passIsNotValid(uDefID)
   isNotValid[uDefID] = true
--   spEcho(uDefID, 'received by widget')
end

local function doTriangle(x1, y1, z1, x2, y2, z2, x3, y3, z3)
	glVertex(x1, y1, z1)
    glVertex(x2, y2, z2)
    glVertex(x3, y3, z3)
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
	local badFeet = {}
	for tx = xmin, xmax, 16 do
		for tz = zmin, zmax, 16 do
			local groundType = spGetGroundInfo(tx, tz)
			if groundType then
				if sandType[groundType] then
					local fx, fz = tx, tz
					if tx == xmax then fx = tx - 16 end
					if tz == zmax then fz = tz - 16 end
					badFeet[#badFeet+1] = {x = fx, z = fz}
				end
			end
		end
	end
	if #badFeet > 0 then return badFeet end
	return false
end

local function DrawBuildWarning()
	local x, y, z = bx, by, bz
			
	glDepthTest(false)
	glPushMatrix()
		
	glColor(1, 0, 0, 1)
	for i = 1, #myBadFeet do
		local foot = myBadFeet[i]
		glBeginEnd(GL_TRIANGLE_STRIP, doTriangle, foot.x, y, foot.z, foot.x+16, y, foot.z, foot.x+16, y, foot.z+16)
		glBeginEnd(GL_TRIANGLE_STRIP, doTriangle, foot.x, y, foot.z, foot.x, y, foot.z+16, foot.x+16, y, foot.z+16)
	end
	glColor(1, 1, 1, 0.5)

	glPopMatrix()
	glDepthTest(true)
end

local function DrawWarningText()
	local x1, y1 = spWorldToScreenCoords(myBadFeet[1].x, by, myBadFeet[1].z)
	local x2, y2 = spWorldToScreenCoords(myBadFeet[#myBadFeet].x, by, myBadFeet[#myBadFeet].z+16)
	local x = (x1 + x2) / 2
	glColor(1, 0, 0, 1.0)
	myFont:Print("CAUTION", x, y1+4, 20, "cdo")
	myFont:Print("CAUTION", x, y1+4, 20, "cd")
	myFont:Print("SAND", x, y2-4, 20, "cao")
	myFont:Print("SAND", x, y2-4, 20, "ca")
	glColor(1, 1, 1, 0.5)
end

local function CameraStatesMatch(stateA, stateB)
	if not stateA or not stateB then return end
	if #stateA ~= #stateB then return end
	for key, value in pairs(stateA) do
		if value ~= stateB[key] then return end
	end
	return true
end

function widget:Initialize()
	myFont = glLoadFont('LuaUI/Fonts/Orbitron Bold.ttf', 36, 4, 10)
	if spGetMapOptions().restrict_sand_building == "0" then
		restrictSand = false
	end
	if not restrictSand then
		spEcho("Restrict Building on Sand is not on. Sand Build Command Helper widget has been disabled.")
		widgetHandler:RemoveWidget()
	else
		isNotValid = {}
		widgetHandler:RegisterGlobal("passIsNotValid", passIsNotValid) --so that widget can receive isNotValid from sand_restrict gadget
		spSendLuaGaiaMsg('Sand Build Helper Widget Loaded')
	end
end 

-- function widget:MouseMove(mx, my, dx, dy, button)
function widget:Update(dt)
	if not restrictSand then return end
	local _, cmdID = spGetActiveCommand()
	if cmdID and isNotValid[-cmdID] then
		local mx, my = spGetMouseState()
		local facing = spGetBuildFacing()
		local camState = spGetCameraState()
		if mx ~= mouseX or my ~= mouseY or cmdID ~= lastCmdID or facing ~= lastFacing or not CameraStatesMatch(camState, lastCamState) then
			-- if not CameraStatesMatch(camState, lastCamState) then spEcho("cam states don't match") end
			mouseX, mouseY = mx, my
			lastCamState = camState
			lastCmdID = cmdID
			lastFacing = facing
			local _, pos = spTraceScreenRay(mx, my, true)
			-- spEcho("pos", mx, my, pos[1], pos[3])
			if not pos then return end
			local facing = spGetBuildFacing()
			local px, py, pz = spPos2BuildPos(-cmdID, pos[1], pos[2], pos[3], facing)
			local badFeet = footprintOnSand(px, pz, -cmdID, facing)
			if badFeet then
				-- spEcho("badfeet")
				myBadFeet = badFeet
				bx, by, bz = px, py, pz
				worldDisplayList = glCreateList(DrawBuildWarning)
				screenDisplayList = glCreateList(DrawWarningText)
			else
				glDeleteList(worldDisplayList)
				worldDisplayList = 0
				glDeleteList(screenDisplayList)
				screenDisplayList = 0
			end
		end
	else
		glDeleteList(worldDisplayList)
		worldDisplayList = 0
		glDeleteList(screenDisplayList)
		screenDisplayList = 0
	end
end

function widget:DrawWorldPreUnit()
	glCallList(worldDisplayList)
end

function widget:DrawScreen()
	glCallList(screenDisplayList)
end

function widget:Shutdown()
	glDeleteList(worldDisplayList)
	glDeleteList(screenDisplayList)
end

function widget:GameStart()
	
end