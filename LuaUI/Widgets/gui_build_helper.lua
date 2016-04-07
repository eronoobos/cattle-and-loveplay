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

function widget:DrawWorld()
  if not restrictSand then return end
	local _, cmdID = Spring.GetActiveCommand()
	if cmdID and isNotValid[-cmdID] then
--		Spring.Echo("command")
		local mx, my = Spring.GetMouseState()
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if not pos then return end
		local px = pos[1]
		local py = pos[2]
		local pz = pos[3]
		local groundType, _ = Spring.GetGroundInfo(px, pz)
		if groundType == "Sand" then
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
				
			gl.LineWidth(10*(600 / camHeight))
			gl.Color(1, 0, 0, 0.5)
			gl.BeginEnd(GL.LINE_STRIP, DoLine, x-frad, y, z-frad, x+frad, y, z+frad)
			gl.BeginEnd(GL.LINE_STRIP, DoLine, x+frad, y, z-frad, x-frad, y, z+frad)
			gl.DrawGroundCircle(x, y, z, frad, 16)
			gl.LineWidth(1.0)
			gl.Translate(x, y, z)
			gl.Billboard()
			gl.Color(1, 0, 0, 1.0)
			gl.Text("CAUTION", 0, frad+8, 14, "cd")
			gl.Text("SAND", 0, -(frad+8), 14, "ca")
			gl.Color(1, 1, 1, 0.5)
	
			gl.DepthTest(true)
		end
	end
end