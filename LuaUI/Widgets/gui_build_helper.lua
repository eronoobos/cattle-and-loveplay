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
local myfont

function passIsNotValid(uDefID)
   isNotValid[uDefID] = true
--   Spring.Echo(uDefID, 'received by widget')
end

local function DoLine(x1, y1, z1, x2, y2, z2)
    gl.Vertex(x1, y1, z1)
    gl.Vertex(x2, y2, z2)
end

local function DoTriangle(x1, y1, z1, x2, y2, z2, x3, y3, z3)
	gl.Vertex(x1, y1, z1)
    gl.Vertex(x2, y2, z2)
    gl.Vertex(x3, y3, z3)
end

local function footprintOnSand(x, z, unitDefID, facing)
	-- if sandType[Spring.GetGroundInfo(x,z)] then return true end
	local uDef = UnitDefs[unitDefID]
	if not uDef then return end
	local halfFootprintX = uDef.xsize * 4
	local halfFootprintZ = uDef.zsize * 4
	if facing % 2 ~= 0 then
		local hfpz = halfFootprintZ+0
		halfFootprintZ = halfFootprintX
		halfFootprintX = hfpz
	end
	-- Spring.Echo(uDef.xsize, uDef.zsize, halfFootprintX, halfFootprintZ)
	local xmin = x - halfFootprintX
	local xmax = x + halfFootprintX
	local zmin = z - halfFootprintZ
	local zmax = z + halfFootprintZ
	-- Spring.MarkerAddPoint(xmin, 100, zmin, "min")
	-- Spring.MarkerAddPoint(xmax, 100, zmax, "max")
	local badFeet = {}
	for tx = xmin, xmax, 16 do
		for tz = zmin, zmax, 16 do
			local groundType = Spring.GetGroundInfo(tx, tz)
			if groundType then
				if sandType[groundType] then
					local fx, fz = tx, tz
					if tx == xmax then fx = tx - 16 end
					if tz == zmax then fz = tz - 16 end
					table.insert(badFeet, {x = fx, z = fz} )
				end
			end
		end
	end
	if #badFeet > 0 then return badFeet end
	return false
end

local function DrawBuildWarning()
	local x, y, z = bx, by, bz
			
	gl.DepthTest(false)
	gl.PushMatrix()
		
	gl.Color(1, 0, 0, 1)
	for _, foot in pairs(myBadFeet) do
		gl.BeginEnd(GL.TRIANGLE_STRIP, DoTriangle, foot.x, y, foot.z, foot.x+16, y, foot.z, foot.x+16, y, foot.z+16)
		gl.BeginEnd(GL.TRIANGLE_STRIP, DoTriangle, foot.x, y, foot.z, foot.x, y, foot.z+16, foot.x+16, y, foot.z+16)
	end
	gl.Color(1, 1, 1, 0.5)

	gl.PopMatrix()
	gl.DepthTest(true)
end

local function DrawWarningText()
	local x1, y1 = Spring.WorldToScreenCoords(myBadFeet[1].x, by, myBadFeet[1].z)
	local x2, y2 = Spring.WorldToScreenCoords(myBadFeet[#myBadFeet].x, by, myBadFeet[#myBadFeet].z+16)
	local x = (x1 + x2) / 2
	gl.Color(1, 0, 0, 1.0)
	myFont:Print("CAUTION", x, y1+4, 20, "cdo")
	myFont:Print("CAUTION", x, y1+4, 20, "cd")
	myFont:Print("SAND", x, y2-4, 20, "cao")
	myFont:Print("SAND", x, y2-4, 20, "ca")
	gl.Color(1, 1, 1, 0.5)
end

local function CameraStatesMatch(stateA, stateB)
	if not stateA or not stateB then return end
	if #stateA ~= #stateB then return end
	for key, value in pairs(stateA) do
		if value ~= stateB[key] then return end
	end
	return true
end

-- function widget:IsAbove(x, y)
	-- because otherwise widget:MouseMove never gets called?
	-- return true
-- end

function widget:Initialize()
	myFont = gl.LoadFont("LuaUI/Fonts/Orbitron Bold.ttf", 72, 12)
	if Spring.GetMapOptions().restrict_sand_building == "0" then
		restrictSand = false
	end
	if not restrictSand then
		Spring.Echo("Restrict Building on Sand is not on. Sand Build Command Helper widget has been disabled.")
		widgetHandler:RemoveWidget()
	else
		isNotValid = {}
		widgetHandler:RegisterGlobal("passIsNotValid", passIsNotValid) --so that widget can receive isNotValid from sand_restrict gadget
		Spring.SendLuaGaiaMsg('Sand Build Helper Widget Loaded')
	end
end 

-- function widget:MouseMove(mx, my, dx, dy, button)
function widget:Update(dt)
	if not restrictSand then return end
	local _, cmdID = Spring.GetActiveCommand()
	if cmdID and isNotValid[-cmdID] then
		local mx, my = Spring.GetMouseState()
		local facing = Spring.GetBuildFacing()
		local camState = Spring.GetCameraState()
		if mx ~= mouseX or my ~= mouseY or cmdID ~= lastCmdID or facing ~= lastFacing or not CameraStatesMatch(camState, lastCamState) then
			-- if not CameraStatesMatch(camState, lastCamState) then Spring.Echo("cam states don't match") end
			mouseX, mouseY = mx, my
			lastCamState = camState
			lastCmdID = cmdID
			lastFacing = facing
			local _, pos = Spring.TraceScreenRay(mx, my, true)
			-- Spring.Echo("pos", mx, my, pos[1], pos[3])
			if not pos then return end
			local facing = Spring.GetBuildFacing()
			local px, py, pz = Spring.Pos2BuildPos(-cmdID, pos[1], pos[2], pos[3], facing)
			local badFeet = footprintOnSand(px, pz, -cmdID, facing)
			if badFeet then
				-- Spring.Echo("badfeet")
				myBadFeet = badFeet
				bx, by, bz = px, py, pz
				worldDisplayList = gl.CreateList(DrawBuildWarning)
				screenDisplayList = gl.CreateList(DrawWarningText)
			else
				gl.DeleteList(worldDisplayList)
				worldDisplayList = 0
				gl.DeleteList(screenDisplayList)
				screenDisplayList = 0
			end
		end
	else
		gl.DeleteList(worldDisplayList)
		worldDisplayList = 0
		gl.DeleteList(screenDisplayList)
		screenDisplayList = 0
	end
end

function widget:DrawWorldPreUnit()
	gl.CallList(worldDisplayList)
end

function widget:DrawScreen()
	gl.CallList(screenDisplayList)
end

function widget:Shutdown()
	gl.DeleteList(worldDisplayList)
	gl.DeleteList(screenDisplayList)
end

function widget:GameStart()
	
end