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

local sandType = { ["Sand"] = true }

function widget:Initialize()
	if Spring.GetMapOptions().restrict_sand_building == "0" then
		restrictSand = false
	end
	if not restrictSand then
		Spring.Echo("Restrict Building on Sand is not on. Sand Build Command Helper widget has been disabled.")
		widgetHandler:RemoveWidget()
	else
		isNotValid = {}
		widgetHandler:RegisterGlobal("passIsNotValid", passIsNotValid) --so that widget can receive isNotValid from sand_restrict gadget
	end
end 

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
	local xmax = x + halfFootprintX - 8
	local zmin = z - halfFootprintZ
	local zmax = z + halfFootprintZ - 8
	-- Spring.MarkerAddPoint(xmin, 100, zmin, "min")
	-- Spring.MarkerAddPoint(xmax, 100, zmax, "max")
	local badFeet = {}
	for tx = xmin, xmax, 16 do
		for tz = zmin, zmax, 16 do
			local groundType = Spring.GetGroundInfo(tx, tz)
			if groundType then
				if sandType[groundType] then
					table.insert(badFeet, {x = tx, z = tz} )
				end
			end
		end
	end
	if #badFeet > 0 then return badFeet end
	return false
end

function widget:DrawWorld()
  if not restrictSand then return end
	local _, cmdID = Spring.GetActiveCommand()
	if cmdID and isNotValid[-cmdID] then
--		Spring.Echo("command")
		local mx, my = Spring.GetMouseState()
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if not pos then return end
		local facing = Spring.GetBuildFacing()
		local px, py, pz = Spring.Pos2BuildPos(-cmdID, pos[1], pos[2], pos[3], facing)
		local badFeet = footprintOnSand(px, pz, -cmdID, facing)
		if badFeet then
			local size = math.max(UnitDefs[-cmdID].xsize, UnitDefs[-cmdID].zsize) * 8
--			local fx = (UnitDefs[-cmdID].xsize * 8) / 2
--			local fz = (UnitDefs[-cmdID].zsize * 8) / 2
			local frad = (size / 2) + 7
			local x = px
			local z = pz
			local y = py
			
			local camHeight = Spring.GetCameraState().height
			if not camHeight then camHeight = 600 end 
			
			gl.DepthTest(false)
			gl.PushMatrix()
				
			gl.Color(1, 0, 0, 1)
			-- gl.LineWidth(2*(600 / camHeight))
			for _, foot in pairs(badFeet) do
				gl.BeginEnd(GL.TRIANGLE_STRIP, DoTriangle, foot.x, y, foot.z, foot.x+16, y, foot.z, foot.x+16, y, foot.z+16)
				gl.BeginEnd(GL.TRIANGLE_STRIP, DoTriangle, foot.x, y, foot.z, foot.x, y, foot.z+16, foot.x+16, y, foot.z+16)
			end
			-- gl.LineWidth(10*(600 / camHeight))
			-- gl.BeginEnd(GL.LINE_STRIP, DoLine, x-frad, y, z-frad, x+frad, y, z+frad)
			-- gl.BeginEnd(GL.LINE_STRIP, DoLine, x+frad, y, z-frad, x-frad, y, z+frad)
			-- gl.DrawGroundCircle(x, y, z, frad, 16)
			gl.LineWidth(1.0)
			gl.Translate(x, y, z)
			gl.Billboard()
			gl.Color(1, 0, 0, 1.0)
			gl.Text("CAUTION", 0, frad+8, 14, "cd")
			gl.Text("SAND", 0, -(frad+8), 14, "ca")
			gl.Color(1, 1, 1, 0.5)
	
			gl.PopMatrix()
			gl.DepthTest(true)
		end
	end
end