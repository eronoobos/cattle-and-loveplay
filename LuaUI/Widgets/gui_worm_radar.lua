function widget:GetInfo()
	return {
		name	= "Cattle and Loveplay: Sand Worm Radar",
		desc	= "marks sand worm sign",
		author  = "zoggop",
		date 	= "February 2012",
		license	= "whatever",
		layer 	= 0,
		enabled	= true
	}
end

-- config
local areWorms = true
local signDuration = 5 -- how long in seconds each sign lasts on screen
local flashDuration = 1/6 -- seconds per flash
local hornPeriod = 0.5 -- seconds per alarm horn
local hornNumber = 3 -- number of horns per alarm

local alertTex = "luaui/images/sworm_alert.png"
local arrowHoriTex = "luaui/images/sworm_arrow_hori.png"
local arrowVertTex = "luaui/images/sworm_arrow_Vert.png"
local arrowDiagTex = "luaui/images/sworm_arrow_diag.png"
local targetTex = "luaui/images/sworm_target.png"

local sndSignAlarm = "sounds/sign_alarm.wav"

local arrowSize = 64
local alertSize = 64
local minimapAlertSize = 20
local minimapTargetSize = 150
local alertToBottom = 0.143

local maxSignBreak = 60 -- above this number of seconds between signs and it's treated as a new sign
local maxSignDistanceBreak = 1000 -- above this number of elmos between signs and it's treated as a new sign

-- storage
local sign = {}
local lastSign = { x = 0, z = 0, time = 0 }
local alertColor = 1
local alertColors = {
	{ r = 1, g = 0, b = 1, a = 1 }, 
	{ r = 1, g = 0, b = 1, a = 0 }, 
	{ r = 1, g = 0.25, b = 0, a = 1 }, 
	{ r = 1, g = 0.25, b = 0, a = 0 } 
}
local arrowSizeHalf = arrowSize / 2
local alertSizeHalf = alertSize / 2
local minimapAlertSizeHalf = minimapAlertSize / 2
local minimapTargetSizeHalf = minimapTargetSize / 2
local alertSizeToBottom = alertToBottom * alertSize
local lastFlash = 0
local signDurationHalf = signDuration / 2
local targetDirs = { {x=1,y=1}, {x=1,y=-1}, {x=-1,y=1}, {x=-1,y=-1} }
local targetDir = 1
local lastHorn = 0


-- local functions

function passSign(x, y, z, los)
	-- finding an empty sign array id
	local s = { 1 }
	local id = 0
	repeat
		id = id + 1
		s = sign[id]
	until not s
	-- determining if this sign is "new"
	local new = false
	local xdistance = math.abs(x - lastSign.x)
	local zdistance = math.abs(z - lastSign.z)
	local distance = math.sqrt((xdistance^2) + (zdistance^2))
	local timebetween = Spring.GetGameSeconds() - lastSign.time
--	Spring.Echo("new? ", distance, timebetween)
	if (distance > maxSignDistanceBreak) or (timebetween > maxSignBreak) then
		new = true
		hornCount = 0
	end
	-- writing sign to sign array
	sign[id] = { x = x, y = y, z = z, los = los, d = signDuration + Spring.GetGameSeconds(), new = new }
	-- storing this sign's location and time
	lastSign = { x = x, z = z, time = Spring.GetGameSeconds() }
	targetDir = targetDir + 1
	if targetDir > 4 then targetDir = 1 end
end

function dirOffScreen(x, y, viewX, viewY)
	local invX = 0
	local invY = 0
	if x > viewX then
		invX = -1
	elseif x < 0 then
		invX = 1
	end
	if y > viewY then
		invY = -1
	elseif y < 0 then
		invY = 1
	end
	local offX = math.min( math.max(x, 0), viewX )
	local offY = math.min( math.max(y, 0), viewY )
	return offX, offY, invX, invY
end

local function drawArrow(x, y, invX, invY)
	local x1, y1, x2, y2, x3, y3, x4, y4
	if not (invX == 0) and not (invY == 0) then
		gl.Texture(arrowDiagTex)
	end
	if invX == 0 then
		gl.Texture(arrowVertTex)
		x1 = x - arrowSizeHalf
		x2 = x + arrowSizeHalf
	else
		x1 = x
		x2 = x + (invX*arrowSize)
	end
	if invY == 0 then
		gl.Texture(arrowHoriTex)
		y1 = y - arrowSizeHalf
		y2 = y + arrowSizeHalf
	else
		y1 = y
		y2 = y + (invY*arrowSize)
	end
	gl.TexRect(x1, y1, x2, y2)
	return x1, y1, x2, y2
end

local function DoLine(x1, y1, z1, x2, y2, z2)
    gl.Vertex(x1, y1, z1)
    gl.Vertex(x2, y2, z2)
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
		widgetHandler:RegisterGlobal("passSign", passSign) --so that widget can receive worm information from the gadget
		Spring.AddUnitIcon('sworm', 'icons/sworm.tga', 3, 1.0)
		Spring.SetUnitDefIcon(UnitDefNames.sworm.id, 'sworm')
	end
end 

function widget:DrawScreen()
	gl.PushMatrix()
	local second = Spring.GetGameSeconds()
	local viewX, viewY, posX, posY = Spring.GetViewGeometry()
	for id, s in pairs(sign) do
		local x, y, z = Spring.WorldToScreenCoords(s.x, s.y, s.z)
		local secondsLeft = s.d - second
		if (x > 0) and (x < viewX) and (y > 0) and (y < viewY) then
			-- draw osd sign if it's within the viewport
			local camx, camy, camz = Spring.GetCameraPosition()
			local cdx = math.abs(camx-s.x)
			local cdy = math.abs(camy-s.y)
			local cdz = math.abs(camz-s.z)
			local camdist = math.sqrt(cdx^2 + cdy^2 + cdz^2)
			if not s.los or (camdist > 5000) then -- only draw osd sign if it's in radar and not visual or if the camera is very far out
				gl.Color(alertColors[alertColor].r, alertColors[alertColor].g, alertColors[alertColor].b, alertColors[alertColor].a)
				gl.Texture(alertTex)
				gl.TexRect(x-alertSizeHalf, y-alertSizeToBottom, x+alertSizeHalf, y+alertSize-alertSizeToBottom)
			end
		else
			-- draw arrow at edge of screen if the sign is out of the viewport
			gl.Color(1, 0.9, 0.5, alertColors[alertColor].a)
			local x1, y1, x2, y2 = drawArrow( dirOffScreen(x, y, viewX, viewY) )
			if x1 > x2 then
				local xtemp = x2
				x2 = x1
				x1 = xtemp
			end
			if y1 > y2 then
				local ytemp = y2
				y2 = y1
				y1 = ytemp
			end
			gl.Color(alertColors[alertColor].r, alertColors[alertColor].g, alertColors[alertColor].b, alertColors[alertColor].a)
			gl.Texture(alertTex)
			gl.TexRect(x1, y1, x2, y2)
		end
		-- play one alarm horn if new and more than hornPeriod seconds later
		-- if s.new and (second > lastHorn + hornPeriod) and (hornCount < hornNumber)  then
		-- 	Spring.PlaySoundFile(sndSignAlarm, 0.1)
		-- 	lastHorn = second
		-- 	hornCount = hornCount + 1
		-- end
		-- remove sign if it's above duration
		if second > s.d then
			sign[id] = nil
		end
	end
	if second - lastFlash >= flashDuration then
		alertColor = alertColor + 1
		if alertColor > 4 then alertColor = 1 end
		lastFlash = second
	end
	gl.Color(1, 1, 1, 0.5)
	gl.PopMatrix()
end

function widget:DrawInMiniMap(sx, sz)
	local second = Spring.GetGameSeconds()
	for id, s in pairs(sign) do
		local xr = s.x/(Game.mapX*512)
		local yr = 1 - s.z/(Game.mapY*512)
		local x = xr*sx
		local y = yr*sz
		gl.Color(alertColors[alertColor].r, alertColors[alertColor].g, alertColors[alertColor].b, alertColors[alertColor].a)
		gl.Texture(alertTex)
		gl.TexRect( x-minimapAlertSizeHalf, y-minimapAlertSizeHalf, x+minimapAlertSizeHalf, y+minimapAlertSizeHalf )
		local secondsLeft = s.d - second
		if secondsLeft > signDuration - 1 then
			-- draw giant target if the sign is "new"
			if s.new then
				gl.Color(alertColors[alertColor].r, alertColors[alertColor].g, alertColors[alertColor].b, alertColors[alertColor].a)
				gl.Texture(targetTex)
				local t = targetDirs[targetDir]
				gl.TexRect( x+(minimapTargetSizeHalf*t.x), y+(minimapTargetSizeHalf*t.y), x+(minimapTargetSizeHalf*(-t.x)), y+(minimapTargetSizeHalf*(-t.y)))
			end
		end
		gl.Color(1, 1, 1, 0.5)
	end
end