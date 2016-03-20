function widget:GetInfo()
	return {
		name	= "Cattle and Loveplay: Sand Worm Debug Visualizations",
		desc	= "visualizes debug sand worm information",
		author  = "zoggop",
		date 	= "February 2012",
		license	= "whatever",
		layer 	= 0,
		enabled	= true
	}
end

local evalFrequency = 150
local wormRange = 65 -- range within which worm will attack
local wormSpeed = 1.0 -- how much the worm's vector is multiplied by to produce a position each game frame

local areWorms = true
local worm
local uvals

function widget:Initialize()
	if Spring.GetMapOptions().sand_worms == "0" then
		areWorms = false
	end
	if not areWorms then
		Spring.Echo("Sand worms are not enabled. Sand Worm Helper widget has been disabled.")
		widgetHandler:RemoveWidget()
	else
		worm = {}
		uvals = {}
		widgetHandler:RegisterGlobal("passWormInit", passWormInit) -- get config data from gadget
		widgetHandler:RegisterGlobal("passWorm", passWorm) --so that widget can receive worm information from the gadget
		widgetHandler:RegisterGlobal("passSandUnit", passSandUnit)
	end
end 

function passWormInit(evalFreq, speed, range)
	evalFrequency = evalFreq
	wormSpeed = speed
	wormRange = range
end

function passWorm(wID, x, z, vx, vz, nvx, nvz, tx, tz, signSecond, endSecond)
	if x then
		worm[wID] = { x = x, z = z, vx = vx, vz = vz, nvx = nvx, nvz = nvz, tx = tx, tz = tz, signSecond = signSecond, endSecond = endSecond }
	else
		worm[wID] = nil
	end
end

function passSandUnit(uID, uval)
--	Spring.Echo(uID, uval)
	if uID then
		if uval then
			uvals[uID] = uval
		else
			uvals[uID] = nil
		end
	end
end

local function DoLine(x1, y1, z1, x2, y2, z2)
    gl.Vertex(x1, y1, z1)
    gl.Vertex(x2, y2, z2)
end

function widget:DrawWorld()
	if not areWorms then return end
	gl.DepthTest(false)
	gl.PushMatrix()
	gl.LineWidth(4)

	for wID, w in pairs(worm) do
		if w then
			local y = Spring.GetGroundHeight(w.x, w.z)
			if w.tx then
				local ty = Spring.GetGroundHeight(w.tx, w.tz)
				gl.Color(1, 0, 0, 1)
				gl.DrawGroundCircle(w.tx, ty, w.tz, 16, 16)
				gl.LineWidth(1)
				gl.BeginEnd(GL.LINE_STRIP, DoLine, w.x, y, w.z, w.tx, ty, w.tz)
			end
			gl.LineWidth(2)
			gl.DrawGroundCircle(w.x, y, w.z, wormRange, 16)
			gl.Color(1, 0.5, 0, 1)
			gl.LineWidth(2)
			gl.Color(1, 0.9, 0.1, 1)
			gl.DrawGroundCircle(w.x, y, w.z, 32, 16)
			if w.vx then
				gl.Color(1.0, 0.0, 0.0, 1)
				local vtx = w.x + (w.vx * evalFrequency * wormSpeed)
				local vtz = w.z + (w.vz * evalFrequency * wormSpeed)
				local vty = Spring.GetGroundHeight(vtx, vtz)
				gl.BeginEnd(GL.LINE_STRIP, DoLine, w.x, y, w.z, vtx, vty, vtz)
				if w.nvx then
					gl.Color(1.0, 0.5, 0.0, 1)
					local nvtx = w.x + (w.nvx * evalFrequency * wormSpeed)
					local nvtz = w.z + (w.nvz * evalFrequency * wormSpeed)
					local nvty = Spring.GetGroundHeight(nvtx, nvtz)
					gl.BeginEnd(GL.LINE_STRIP, DoLine, w.x, y, w.z, nvtx, nvty, nvtz)
				end
			end
		end
	end
	
	for uID, uval in pairs(uvals) do
		if uval and Spring.ValidUnitID(uID) then
			local x, y, z = Spring.GetUnitPosition(uID)
			if x and y and z then
				gl.LineWidth(1)
				gl.Color(1, 0, 0, 1)
				if uval < 0 then gl.Color(0, 0, 1, 1) end
				gl.DrawGroundCircle(x, y, z, math.abs(uval), 16)
			end
		end
	end
	
	for wID, w in pairs(worm) do
		if w then
			if w.endSecond and w.signSecond then
				gl.DepthTest(false)
				gl.PushMatrix()
				local y = Spring.GetGroundHeight(w.x, w.z)
				gl.Translate(w.x, y, w.z)
				gl.Billboard()
				local second = Spring.GetGameSeconds()
				local statString = tostring(wID) .. ' : ' .. tostring(math.floor(w.endSecond - second) .. ' , ' .. tostring(math.floor(w.signSecond - second)))
				gl.Text(statString, 0, 0, 16, "cdo")
				gl.Text(statString, 0, 0, 16, "cd")
				gl.PopMatrix()
				gl.DepthTest(true)
			end
		end
	end

	gl.LineWidth(1)
	gl.Color(1, 1, 1, 0.5)
	gl.PopMatrix()
	gl.DepthTest(true)
end