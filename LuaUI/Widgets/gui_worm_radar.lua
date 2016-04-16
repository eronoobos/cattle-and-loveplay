function widget:GetInfo()
	return {
		name	= "Cattle and Loveplay: Sand Worm Radar",
		desc	= "marks sand worm signs",
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
local flashDuration = 0.2 -- seconds per flash

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
local secondsBetweenAttackAlerts = 60

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
	{ r = 1, g = 0.5, b = 0, a = 1 }, 
	{ r = 1, g = 0.5, b = 0, a = 0 },
}


local arrowSizeHalf = arrowSize / 2
local arrowIconSizeHalf = arrowIconSize / 2
local lastFlash
local lastAttackAlert

local mSqrt = math.sqrt
local mAbs = math.abs
local mAtan2 = math.atan2
local mRad = math.rad
local mDeg = math.deg
local pi = math.pi
local halfPi = pi / 2

local cornerAngle = pi / 6
local corners = {
	{ min=0, max=cornerAngle, flip=1, yTop=1 },
	{ min=pi-cornerAngle, max=pi, yTop=1 },
	{ min=-cornerAngle, max=0, yBottom=1 },
	{ min=-pi, max=cornerAngle-pi, flip=1, yBottom=1 },
	{ min=-halfPi, max=cornerAngle-halfPi, flip=1, xTop=1 },
	{ min=-halfPi-cornerAngle, max=-halfPi, xBottom=1 },
	{ min=halfPi-cornerAngle, max=halfPi, xTop=1 },
	{ min=halfPi, max=halfPi+cornerAngle, flip=1, xBottom=1 },
}

local tInsert = table.insert
local tRemove = table.remove

local spIsSphereInView = Spring.IsSphereInView
local spIsUnitInView = Spring.IsUnitInView
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetMapOptions = Spring.GetMapOptions
local spGetViewGeometry = Spring.GetViewGeometry
local spGetUnitsInSphere = Spring.GetUnitsInSphere
local spAddUnitIcon = Spring.AddUnitIcon
local spSetUnitDefIcon = Spring.SetUnitDefIcon
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spEcho = Spring.Echo
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers

local glTexture = gl.Texture
local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glTexRect = gl.TexRect

local GL_LINE_STRIP = GL.LINE_STRIP
local GL_TRIANGLE_STRIP = GL.TRIANGLE_STRIP

-- local functions

local function normalizeVector2d(vx, vy)
	if vx == 0 and vy == 0 then return 0, 0 end
	local dist = mSqrt(vx*vx + vy*vy)
	return vx/dist, vy/dist, dist
end

local function doLine2d(x1, y1, x2, y2)
    glVertex(x1, y1)
    glVertex(x2, y2)
end

local function doTriangle2d(x1, y1, x2, y2, x3, y3)
    glVertex(x1, y1)
    glVertex(x2, y2)
    glVertex(x3, y3)
end

local function drawArrow(x, y, viewX, viewY)
	local centerX, centerY = viewX/2, viewY/2
	local dx, dy = x-centerX, y-centerY
	local vx, vy = normalizeVector2d(dx, dy)
	-- Spring.Echo(vx, vy, mDeg(mAtan2(vy, vx)), mAtan2(vy, vx))
	local zeroX, zeroY = 0, 0
	local angle = mAtan2(vy, vx)
	for i = 1, #corners do
		local c = corners[i]
		if angle > c.min and angle < c.max then
			local need = (angle-c.min) /  cornerAngle
			if c.flip then need = 1 - need end
			local space = need * arrowSizeHalf
			if c.xTop then
				viewX = viewX - space
			elseif c.xBottom then
				zeroX = zeroX + space
			elseif c.yTop then
				viewY = viewY - space
			elseif c.yBottom then
				zeroY = zeroY + space
			end
		end
	end
	if x > viewX then x1 = viewX elseif x < zeroX then x1 = zeroX else x1 = x end
	if y > viewY then y1 = viewY elseif y < zeroY then y1 = zeroY else y1 = y end
	local backX, backY = x1-(vx*arrowSize), y1-(vy*arrowSize)
	local x2, y2 = backX+(vy*arrowSizeHalf), backY-(vx*arrowSizeHalf)
	local x3, y3 = backX-(vy*arrowSizeHalf), backY+(vx*arrowSizeHalf)
	glBeginEnd(GL_TRIANGLE_STRIP, doTriangle2d, x1, y1, x2, y2, x3, y3)
	local cx = (x1 + x2 + x3) / 3
	local cy = (y1 + y2 + y3) / 3
	return cx-arrowIconSizeHalf, cy-arrowIconSizeHalf, cx+arrowIconSizeHalf, cy+arrowIconSizeHalf
end

local function seeUnit(unitID)
	local unitDefID = spGetUnitDefID(unitID)
	-- spEcho(unitDefID, underwormDefID)
	if unitDefID ~= underwormDefID then return end
	local cur = spGetTimer()
	if not seenWorms[unitID] then
		seenWorms[unitID] = cur
		local ux, uy, uz = spGetUnitPosition(unitID)
		wormAlerts[#wormAlerts+1] = {unitID = unitID, timer = cur, x=ux, y=uy, z=uz}
	end
end


-- callins

function widget:Initialize()
	local mapOptions = spGetMapOptions()
	if mapOptions then
		if spGetMapOptions().sand_worms == "0" then
			areWorms = false
		end
	end
	if not areWorms then
		spEcho("Sand worms are not enabled. Sand Worm Radar widget has been disabled.")
		widgetHandler:RemoveWidget()
	else
		spAddUnitIcon('sworm', 'icons/sworm.png', 1.25, 1.0, true)
		spAddUnitIcon('underworm', 'icons/underworm.png', 2.5, 1.0, false)
		spSetUnitDefIcon(UnitDefNames.sworm1.id, 'sworm')
		spSetUnitDefIcon(UnitDefNames.sworm2.id, 'sworm')
		spSetUnitDefIcon(UnitDefNames.sworm3.id, 'sworm')
		spSetUnitDefIcon(UnitDefNames.sworm4.id, 'sworm')
		spSetUnitDefIcon(UnitDefNames.underworm.id, 'underworm')
	end
	for name, _ in pairs(wormEmergeUnitNames) do
		wormEmergeUnitDefIDs[UnitDefNames[name].id] = true
	end
	local cur = spGetTimer()
	lastFlash = cur
	lastAttackAlert = cur
	-- wormAlerts[#wormAlerts+1] = {timer = cur, x=sizeX/2, y=100, z=sizeZ/2} -- for testing
end

function widget:UnitEnteredRadar(unitID, unitTeam, allyTeam, unitDefID)
	seeUnit(unitID)
end

function widget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
	seeUnit(unitID)
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	local cur = spGetTimer()
	local attackAlertAge = spDiffTimers(cur, lastAttackAlert)
	if attackAlertAge > secondsBetweenAttackAlerts then
		local ux, uy, uz = spGetUnitPosition(unitID)
		local nearUnits = spGetUnitsInSphere(ux, uy, uz, 150)
		if not nearUnits or #nearUnits == 0 then return end
		for i = 1, #nearUnits do
			local uID = nearUnits[i]
			local unitDefID = spGetUnitDefID(uID)
			if wormEmergeUnitDefIDs[unitDefID] then
				wormAlerts[#wormAlerts+1] = {timer = cur, attack = true, x=ux, y=uy, z=uz}
				lastAttackAlert = cur
				break
			end
		end
	end
end

function widget:GameFrame(frame)
	if #wormAlerts == 0 then return end
	for i = #wormAlerts, 1, -1 do
		local alert = wormAlerts[i]
		if alert.unitID then
			alert.x, alert.y, alert.z = spGetUnitPosition(alert.unitID)
			if not alert.x then
				tRemove(wormAlerts, i)
			end
		end
	end
end

function widget:Update(dt)
	if #seenWorms == 0 and #wormAlerts == 0 then return end
	local cur = spGetTimer()
	for unitID, seen in pairs(seenWorms) do
		local age = spDiffTimers(cur, seen)
		if age > 300 then
			seenWorms[unitID] = nil
		end
	end
	for i = #wormAlerts, 1, -1 do
		local alert = wormAlerts[i]
		local age = spDiffTimers(cur, alert.timer)
		if age > alertDuration then
			tRemove(wormAlerts, i)
		end
	end
	local flashAge = spDiffTimers(cur, lastFlash)
	if flashAge > flashDuration then
		alertColor = alertColor + 1
		if alertColor > #alertColors then alertColor = 1 end
		lastFlash = cur
	end
end

function widget:DrawScreen()
	if #wormAlerts == 0 then return end
	local viewX, viewY, posX, posY = spGetViewGeometry()
	local ac = alertColors[alertColor]
	for i = 1, #wormAlerts do
		local alert = wormAlerts[i]
		local visible
		if alert.unitID and spIsUnitInView(alert.unitID) then
			visible = true 
		elseif spIsSphereInView(alert.x, alert.y, alert.z, 50) then
			visible = true
		end
		if not visible then
			-- draw arrow at edge of screen if the worm is out of the viewport
			local ux, uy, uz = alert.x, alert.y, alert.z
			local x, y = spWorldToScreenCoords(ux, uy, uz)
			glColor(ac.r, ac.g, ac.b, ac.a)
			local x1, y1, x2, y2 = drawArrow(x, y, viewX, viewY)
			glColor(1, 1, 1, ac.a)
			if alert.attack then
				glTexture(attackTex)
			else
				glTexture(signTex)
			end
			glTexRect(x1, y1, x2, y2)
		end
	end
	glColor(1, 1, 1, 0.5)
end

function widget:DrawInMiniMap(sx, sz)
	if #wormAlerts == 0 then return end
	local ac = alertColors[alertColor]
	for i = 1, #wormAlerts do
		local alert = wormAlerts[i]
		local ux, uy, uz = alert.x, alert.y, alert.z
		local xr = ux/sizeX
		local yr = 1 - uz/sizeZ
		local x = xr*sx
		local y = yr*sz
		local gapX = targetGap * sx
		local gapY = targetGap * sz
		glColor(ac.r, ac.g, ac.b, ac.a)
		glLineWidth(2)
		glBeginEnd(GL_LINE_STRIP, doLine2d, 0, y, x-gapX, y)
		glBeginEnd(GL_LINE_STRIP, doLine2d, x+gapX, y, sx, y)
		glBeginEnd(GL_LINE_STRIP, doLine2d, x, 0, x, y-gapY)
		glBeginEnd(GL_LINE_STRIP, doLine2d, x, y+gapY, x, sz)
		glColor(1, 1, 1, 0.5)
	end
end