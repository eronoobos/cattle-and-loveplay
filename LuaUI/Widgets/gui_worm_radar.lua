function widget:GetInfo()
	return {
		name	= "Cattle and Loveplay: Sand Worm Radar",
		desc	= "marks sand worm sign",
		author  = "zoggop",
		date 	= "February 2012",
		license	= "whatever",
		layer 	= -12,
		enabled	= true
	}
end

-- config
local areWorms = true
local alertDuration = 5 -- how long in seconds each sign lasts on screen
local flashDuration = 5 -- frames per flash

local wormConfig = VFS.Include('wormconfig/wormconfig.lua')
local wormEmergeUnitNames = wormConfig.wormEmergeUnitNames
local wormUnderUnitName = wormConfig.wormUnderUnitName
local underwormDefID = UnitDefNames[wormUnderUnitName].id

local signTex = "icons/underworm.png"
local attackTex = "icons/sworm.png"
local arrowHoriTex = "luaui/images/sworm_arrow_hori.png"
local arrowVertTex = "luaui/images/sworm_arrow_Vert.png"
local arrowDiagTex = "luaui/images/sworm_arrow_diag.png"

local arrowSize = 64
local arrowIconSize = 48
local targetGap = 0.05
local timeBetweenAttacks = 60 -- in seconds

local sizeX = Game.mapSizeX 
local sizeZ = Game.mapSizeZ

-- storage
local wormEmergeUnitDefIDs = {}
local wormAlerts = {}
local seenWorms = {}
local alertColor = 1
local alertColors = {
	{ r = 1, g = 0, b = 1, a = 1 }, 
	{ r = 1, g = 0, b = 1, a = 0 }, 
	{ r = 1, g = 0.25, b = 0, a = 1 }, 
	{ r = 1, g = 0.25, b = 0, a = 0 } 
}
local arrowSizeHalf = arrowSize / 2
local arrowIconSizeHalf = arrowIconSize / 2
local nextFlash = 0
local nextAttackAlert = 0

local mSqrt = math.sqrt
local tInsert = table.insert

local Spring.

-- local functions

local function normalizeVector(...)
	local dist = 0
	local arg = {...}
	for _, a in pairs(arg) do
		dist = dist + (a^2)
	end
	dist = mSqrt(dist)
	if dist == 0 then return ..., 0 end
	local v = {}
	for _, a in pairs(arg) do
		tInsert(v, a/dist)
	end
	tInsert(v, dist)
	return unpack(v)
end

local function DoLine2D(x1, y1, x2, y2)
    gl.Vertex(x1, y1)
    gl.Vertex(x2, y2)
end

local function DoTriangle2D(x1, y1, x2, y2, x3, y3)
    gl.Vertex(x1, y1)
    gl.Vertex(x2, y2)
    gl.Vertex(x3, y3)
end

local function drawArrow(x, y, viewX, viewY)
	local centerX, centerY = viewX/2, viewY/2
	local dx, dy = x-centerX, y-centerY
	local vx, vy, dist = normalizeVector(dx, dy)
	local x1 = math.min( math.max(x, 0), viewX )
	local y1 = math.min( math.max(y, 0), viewY )
	local backX, backY = x1-(vx*arrowSize), y1-(vy*arrowSize)
	local x2, y2 = backX+(vy*arrowSizeHalf), backY-(vx*arrowSizeHalf)
	local x3, y3 = backX-(vy*arrowSizeHalf), backY+(vx*arrowSizeHalf)
	gl.BeginEnd(GL.TRIANGLE_STRIP, DoTriangle2D, x1, y1, x2, y2, x3, y3)
	local cx = (x1 + x2 + x3) / 3
	local cy = (y1 + y2 + y3) / 3
	return cx-arrowIconSizeHalf, cy-arrowIconSizeHalf, cx+arrowIconSizeHalf, cy+arrowIconSizeHalf
end

local function seeUnit(unitID)
	local unitDefID = Spring.GetUnitDefID(unitID)
	-- Spring.Echo(unitDefID, underwormDefID)
	if unitDefID ~= underwormDefID then return end
	if not seenWorms[unitID] then
		seenWorms[unitID] = Spring.GetGameSeconds()
		local ux, uy, uz = Spring.GetUnitPosition(unitID)
		table.insert(wormAlerts, {unitID = unitID, endSecond = Spring.GetGameSeconds()+alertDuration, x=ux, y=uy, z=uz})
	end
end


-- callins

function widget:Initialize()
	local mapOptions = Spring.GetMapOptions()
	if mapOptions then
		if Spring.GetMapOptions().sand_worms == "0" then
			areWorms = false
		end
	end
	if not areWorms then
		Spring.Echo("Sand worms are not enabled. Sand Worm Radar widget has been disabled.")
		widgetHandler:RemoveWidget()
	else
		Spring.AddUnitIcon('sworm', 'icons/sworm.png', 1.25, 1.0, true)
		Spring.AddUnitIcon('underworm', 'icons/underworm.png', 2.5, 1.0, false)
		Spring.SetUnitDefIcon(UnitDefNames.sworm1.id, 'sworm')
		Spring.SetUnitDefIcon(UnitDefNames.sworm2.id, 'sworm')
		Spring.SetUnitDefIcon(UnitDefNames.sworm3.id, 'sworm')
		Spring.SetUnitDefIcon(UnitDefNames.sworm4.id, 'sworm')
		Spring.SetUnitDefIcon(UnitDefNames.underworm.id, 'underworm')
	end
	for name, _ in pairs(wormEmergeUnitNames) do
		wormEmergeUnitDefIDs[UnitDefNames[name].id] = true
	end
end

function widget:UnitEnteredRadar(unitID, unitTeam, allyTeam, unitDefID)
	seeUnit(unitID)
end

function widget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
	seeUnit(unitID)
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	local second = Spring.GetGameSeconds()
	if second > nextAttackAlert then
		local ux, uy, uz = Spring.GetUnitPosition(unitID)
		local nearUnits = Spring.GetUnitsInSphere(ux, uy, uz, 150)
		for _, uID in pairs(nearUnits) do
			local unitDefID = Spring.GetUnitDefID(uID)
			if wormEmergeUnitDefIDs[unitDefID] then
				table.insert(wormAlerts, {endSecond = second+alertDuration, attack = true, x=ux, y=uy, z=uz})
				nextAttackAlert = second + timeBetweenAttacks
				break
			end
		end
	end
end

function widget:GameFrame(frame)
	if #seenWorms == 0 and #wormAlerts == 0 then return end
	local second = Spring.GetGameSeconds()
	for unitID, seen in pairs(seenWorms) do
		if second > seen + 300 then
			seenWorms[unitID] = nil
		end
	end
	for i = #wormAlerts, 1, -1 do
		local alert = wormAlerts[i]
		if second > alert.endSecond then
			table.remove(wormAlerts, i)
		elseif alert.unitID then
			alert.x, alert.y, alert.z = Spring.GetUnitPosition(alert.unitID)
			if not alert.x then
				table.remove(wormAlerts, i)
			end
		end
	end
	if frame >= nextFlash then
		alertColor = alertColor + 1
		if alertColor > 4 then alertColor = 1 end
		nextFlash = frame + flashDuration
	end
end

function widget:DrawScreen()
	if #wormAlerts == 0 then return end
	local viewX, viewY, posX, posY = Spring.GetViewGeometry()
	local ac = alertColors[alertColor]
	for _, alert in pairs(wormAlerts) do
		local visible
		if alert.unitID and Spring.IsUnitInView(alert.unitID) then
			visible = true 
		elseif Spring.IsSphereInView(alert.x, alert.y, alert.z, 50) then
			visible = true
		end
		if not visible then
			-- draw arrow at edge of screen if the worm is out of the viewport
			local ux, uy, uz = alert.x, alert.y, alert.z
			local x, y = Spring.WorldToScreenCoords(ux, uy, uz)
			gl.Color(ac.r, ac.g, ac.b, ac.a)
			local x1, y1, x2, y2 = drawArrow(x, y, viewX, viewY)
			gl.Color(1, 1, 1, ac.a)
			if alert.attack then
				gl.Texture(attackTex)
			else
				gl.Texture(signTex)
			end
			gl.TexRect(x1, y1, x2, y2)
		end
	end
	gl.Color(1, 1, 1, 0.5)
end

function widget:DrawInMiniMap(sx, sz)
	if #wormAlerts == 0 then return end
	local ac = alertColors[alertColor]
	for _, alert in pairs(wormAlerts) do
		local ux, uy, uz = alert.x, alert.y, alert.z
		local xr = ux/sizeX
		local yr = 1 - uz/sizeZ
		local x = xr*sx
		local y = yr*sz
		local gapX = targetGap * sx
		local gapY = targetGap * sz
		gl.Color(ac.r, ac.g, ac.b, ac.a)
		gl.LineWidth(2)
		gl.BeginEnd(GL.LINE_STRIP, DoLine2D, 0, y, x-gapX, y)
		gl.BeginEnd(GL.LINE_STRIP, DoLine2D, x+gapX, y, sx, y)
		gl.BeginEnd(GL.LINE_STRIP, DoLine2D, x, 0, x, y-gapY)
		gl.BeginEnd(GL.LINE_STRIP, DoLine2D, x, y+gapY, x, sz)
		gl.Color(1, 1, 1, 0.5)
	end
end