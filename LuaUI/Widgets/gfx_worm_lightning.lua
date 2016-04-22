function widget:GetInfo()
	return {
		name	= "Cattle and Loveplay: Worm Lightning FX",
		desc	= "does worm lightning effects",
		author  = "eronoobos",
		date 	= "April 2016",
		license	= "whatever",
		layer 	= 0,
		enabled	= true
	}
end

local timelineElementDuration = 0.075 -- in seconds
local timelineMinSize = 3
local timelineMaxSize = 12
local connectProbability = 0.25
local flashTex = "bitmaps/sworm_lightning_glow.png"
local flashSizeMult = 6

local strikes = {}

local lastX1, lastZ1, lastX2, lastZ2

local tRemove = table.remove
local mAtan2 = math.atan2
local mSin = math.sin
local mCos = math.cos
local mRandom = math.random
local mMin = math.min
local mMax = math.max
local mSqrt = math.sqrt
local mAbs = math.abs
local mDeg = math.deg
local mCeil = math.ceil

local pi = math.pi
local twicePi = math.pi * 2
local halfPi = math.pi / 2
local thirdPi = math.pi / 3
local twoThirdsPi = thirdPi * 2
local quarterPi = math.pi / 4
local eighthPi = math.pi / 8

local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local spGetGroundHeight = Spring.GetGroundHeight
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spIsAABBInView = Spring.IsAABBInView
local spIsSphereInView = Spring.IsSphereInView
local spGetLocalTeamID = Spring.GetLocalTeamID
local spGetTeamRulesParam = Spring.GetTeamRulesParam

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glColor = gl.Color
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glDepthTest = gl.DepthTest
local glLineWidth = gl.LineWidth
local glTexRect = gl.TexRect
local glTexture = gl.Texture
local glBlending = gl.Blending
local glBillboard = gl.Billboard
local glTranslate = gl.Translate
local glNormal = gl.Normal
local glRotate = gl.Rotate
local glTexCoord = gl.TexCoord

local GL_LINE_STRIP = GL.LINE_STRIP
local GL_TRIANGLE_STRIP = GL.TRIANGLE_STRIP
local GL_POINTS = GL.POINTS
local GL_TRIANGLE_FAN = GL.TRIANGLE_FAN

-- simple duplicate, does not handle nesting
local function tDuplicate(sourceTable)
	local duplicate = {}
	for k, v in pairs(sourceTable) do
		duplicate[k] = v
	end
	return duplicate
end

local function normalizeVector2d(vx, vy)
	if vx == 0 and vy == 0 then return 0, 0 end
	local dist = mSqrt(vx*vx + vy*vy)
	return vx/dist, vy/dist, dist
end

local function normalizeVector3d(vx, vy, vz)
	if vx == 0 and vy == 0 and vz == 0 then return 0, 0, 0 end
	local dist = mSqrt(vx*vx + vy*vy + vz*vz)
	return vx/dist, vy/dist, vz/dist, dist
end

local function perpendicularVector2d(vx, vz)
	if mRandom(1,2) == 1 then
		return -vz, vx
	else
		return vz, -vx
	end 
end

local function AngleAdd(angle1, angle2)
  return (angle1 + angle2) % twicePi
end

local function CirclePos(cx, cy, dist, angle)
  angle = angle or mRandom() * twicePi
  local x = cx + dist * mCos(angle)
  local y = cy + dist * mSin(angle)
  return x, y
end

local triCylPos = {}
local triCylRot = twicePi / 3
for i = 0, 3 do
	local a = i * triCylRot
	local x, z = CirclePos(0, 0, 1, a)
	triCylPos[i] = {x=x, z=z}
end
local triCylRadiusPos = {}

local function doLine3d(x1, y1, z1, x2, y2, z2)
    glVertex(x1, y1, z1)
    glVertex(x2, y2, z2)
end

local function doPoints2d(x, y)
	glVertex(x, y)
end

local function getTriCylPos(r, i)
	if triCylRadiusPos[r] then return triCylRadiusPos[r][i].x, triCylRadiusPos[r][i].z, triCylPos[i].x, triCylPos[i].z end
	triCylRadiusPos[r] = {}
	for i = 0, 3 do
		local p = triCylPos[i]
		local x, z = p.x*r, p.z*r
		triCylRadiusPos[r][i] = {x=x, z=z}
	end
	return triCylRadiusPos[r][i].x, triCylRadiusPos[r][i].z, triCylPos[i].x, triCylPos[i].z
end

local function doTriCylinder(r, h)
	-- for i = 1, 3 do
	-- 	local x, z = getTriCylPos(r, i)
	-- 	glVertex(x, 0, z)
	-- end
	-- local coords = { 0, 0.5, 1, 0}
	for i = 0, 3 do
		local x, z, px, pz = getTriCylPos(r, i)
		-- glNormal(px, 1, pz)
		-- glTexCoord(coords[i+1], 0)
		glVertex(x, 0, z)
		-- glTexCoord(coords[i+1], 1)
		glVertex(x, h, z)
	end
	-- for i = 1, 3 do
	-- 	local x, z = getTriCylPos(r, i)
	-- 	glVertex(x, h, z)
	-- end
end

local function getStrikeTimeline()
	local n = mRandom(timelineMinSize-1, timelineMaxSize-1)
	local elements = { 1.0 }
	for i = 1, n do
		local element = 0
		if mRandom() < connectProbability then
			element = 0.1 + (mRandom() * 0.4)
		end
		elements[#elements+1] = element
	end
	local timeline = {}
	for i = 1, n+1 do
		timeline[#timeline+1] = tRemove(elements, mRandom(#elements))
		-- timeline[#timeline+1] = 0
	end
	return timeline
end

local function drawSegment(x1, y1, z1, x2, y2, z2, r)
	glPushMatrix()
	-- glLineWidth(4)
	-- glColor(0, 0, 1, 1)
	-- glBeginEnd(GL_LINE_STRIP, doLine3d, x1, y1, z1, x2, y2, z2)
	glTranslate(x1, y1, z1)
	local dx, dy, dz = x2-x1, y2-y1, z2-z1
	local yAxisAngle = mDeg(mAtan2(-dz, dx))
	glRotate(yAxisAngle, 0, 1, 0)
	local distXZ = mSqrt(dx*dx + dz*dz)
	local zAxisAngle = mDeg(mAtan2(-distXZ, dy))
	glRotate(zAxisAngle, 0, 0, 1)
	local dist = mSqrt(dx*dx + dy*dy + dz*dz)
	glBeginEnd(GL_TRIANGLE_STRIP, doTriCylinder, r, dist+(r/2), 3)
	-- glLineWidth(2)
	-- glColor(1, 0, 0, 1)
	-- glBeginEnd(GL_LINE_STRIP, doLine3d, 0, 0, 0, 0, dist, 0)
	glPopMatrix()
end

local function drawLightning(segments, radius, trunkOnly)
	for i = 1, #segments do
		local seg = segments[i]
		if not trunkOnly or seg.branch == 1 then
			drawSegment(seg.init.x, seg.init.y, seg.init.z, seg.term.x, seg.term.y, seg.term.z, radius/seg.branch)
		end
	end
end

local function drawLightningFlash(x, y, z, size, color)
	glPushMatrix()
	glColor(color)
	glTexture(flashTex)
	glTranslate(x, y, z)
	glBillboard()
	glTexRect(-size, -size, size, size)
	glPopMatrix()
end

local function getLightningSegments(x1, z1, x2, z2, offsetMult, generationNum, branchProb, minOffsetMultXZ, minOffsetMultY)
	offsetMult = offsetMult or 0.4
	generationNum = generationNum or 5
	branchProb = branchProb or 0.2
	minOffsetMultXZ = minOffsetXZ or 0.05
	minOffsetMultY = minOffsetY or 0.1
	local y1, y2 = spGetGroundHeight(x1, z1), spGetGroundHeight(x2, z2)
	local ymin = mMin(y1, y2)
	local ymax = ymin
	local segmentList = { {init = {x=x1,y=y1,z=z1}, term = {x=x2,y=y2,z=z2}, branch = 1} }
	for g = 1, generationNum do
		local newSegmentList = {}
		for s = #segmentList, 1, -1 do
			local seg = tRemove(segmentList, s)
			local midX = (seg.init.x + seg.term.x) / 2
			local midY = (seg.init.y + seg.term.y) / 2
			local midZ = (seg.init.z + seg.term.z) / 2
			local vx, vz, dist = normalizeVector2d(seg.term.x-seg.init.x, seg.term.z-seg.init.z)
			local pvx, pvz = perpendicularVector2d(vx, vz)
			local offMax = dist * offsetMult
			local offsetXZ = mRandom(dist*minOffsetMultXZ, dist*offsetMult)
			midX, midZ = midX+(pvx*offsetXZ), midZ+(pvz*offsetXZ)
			midY = mMax( spGetGroundHeight(midX,midZ), midY+mRandom(dist*minOffsetMultY,offMax) )
			if midY > ymax then ymax = midY end
			local mid = {x=midX, y=midY, z=midZ}
			newSegmentList[#newSegmentList+1] = {init=seg.init, term=mid, branch=seg.branch}
			newSegmentList[#newSegmentList+1] = {init=mid, term=seg.term, branch=seg.branch}
			if mRandom() < branchProb then
				local angle = mAtan2(vz, vx)
				angle = AngleAdd(angle, (mRandom()*quarterPi)-eighthPi)
				local bx, bz = CirclePos(seg.init.x, seg.init.z, dist/2, angle)
				newSegmentList[#newSegmentList+1] = { init=seg.init, term={x=bx,y=seg.init.y,z=bz}, branch=seg.branch+1 }
			end
		end
		segmentList = newSegmentList
	end
	return segmentList, ymin, ymax
end

local function passWormLightning(x1, z1, x2, z2, offsetMult, generationNum, branchProb, minOffsetMultXZ, minOffsetMultY, thickness, glowThickness)
	if not x1 or not z1 or not x2 or not z2 then return end
	thickness = thickness or (0.75 + (mRandom() * 0.5)) -- actually radius
	glowThickness = glowThickness or (thickness * 3.5) -- actually radius
	if not generationNum then
		local dx, dz = x2-x1, z2-z1
		local dist = mSqrt(dx*dx + dz*dz)
		-- Spring.Echo(dist)
		if dist < 64 then
			generationNum = 4
		elseif dist < 128 then
			generationNum = 5
		elseif dist < 256 then
			generationNum = 6
		else
			generationNum = 7
		end
	end
	local segments, y1, y2 = getLightningSegments(x1, z1, x2, z2, offsetMult, generationNum, branchProb, minOffsetMultXZ, minOffsetMultY)
	local first = segments[1].init
	local last = segments[#segments].term
	local r = mRandom()
	local baseColor = { 0.5+(r*0.5), 0.0, 0.5+((1-r)*0.5), 1.0 }
	local coreColor = { baseColor[1], 0.5, baseColor[3], 0.1 }
	local glowColor = { baseColor[1], 0, baseColor[3], 0.01 }
	local flashColor = { baseColor[1], baseColor[2], baseColor[3], 0.5}
	local radius = mMax( mAbs(x2-x1), mAbs(y2-y1), mAbs(z2-z1) ) / 2
	local x, y, z = (x1+x2) / 2, (y1+y2) / 2, (z1+z2) / 2
	local flashSize = radius * flashSizeMult
	local strike = {
		-- baseColor = baseColor,
		trunkColor = glowColor,
		coreColor = coreColor,
		glowColor = glowColor,
		coreDisplayList = glCreateList(drawLightning, segments, thickness*0.67),
		trunkDisplayList = glCreateList(drawLightning, segments, thickness*1.33, true),
		glowDisplayList = glCreateList(drawLightning, segments, glowThickness),
		flashDisplayList = glCreateList(drawLightningFlash, x, y, z, flashSize, flashColor),
		timer = spGetTimer(),
		timeline = getStrikeTimeline(),
	}
	strikes[#strikes+1] = strike
end

function widget:GameFrame(gf)
	local myTeamID = spGetLocalTeamID()
	local x1 = spGetTeamRulesParam(myTeamID, "wormLightningX1")
	local z1 = spGetTeamRulesParam(myTeamID, "wormLightningZ1")
	local x2 = spGetTeamRulesParam(myTeamID, "wormLightningX2")
	local z2 = spGetTeamRulesParam(myTeamID, "wormLightningZ2")
	if x1 ~= lastX1 or z1 ~= lastZ1 or x2 ~= lastX2 or z2 ~= lastZ2 then
		passWormLightning(x1, z1, x2, z2)
	end
	lastX1, lastZ1, lastX2, lastZ2 = x1, z1, x2, z2
end

function widget:Update(dt)
	if #strikes == 0 then return end
	local cur = spGetTimer()
	for i = #strikes, 1, -1 do
		local s = strikes[i]
		local age = spDiffTimers(cur, s.timer)
		local timeSlot = mCeil(age / timelineElementDuration)
		if timeSlot == 0 then timeSlot = 1 end
		if timeSlot ~= s.timeSlot then
			if timeSlot > #s.timeline then
				glDeleteList(s.coreDisplayList)
				glDeleteList(s.trunkDisplayList)
				glDeleteList(s.glowDisplayList)
				glDeleteList(s.flashDisplayList)
				tRemove(strikes, i)
			else
				local element = s.timeline[timeSlot]
				-- Spring.Echo(age, timeSlot, element)
				if element == 1.0 then
					s.flash = true
					s.flashed = true
				else
					s.flash = false
				end
				s.glowColor[4] = element * 0.1
				s.coreColor[4] = element
				if s.flashed then
					s.trunkColor[4] = element * 0.1
					s.trunkColor[2] = element * 0.2
					s.coreColor[2] = element
				else
					s.coreColor[2] = 0
				end
				s.timeSlot = timeSlot
			end
		end
	end
end

function widget:DrawWorld()
	if #strikes == 0 then return end
	glDepthTest(true)
	-- glPushMatrix()
	glBlending("alpha_add")
	for i = 1, #strikes do
		local s = strikes[i]
		glColor(s.glowColor)
		glCallList(s.glowDisplayList)
		glColor(s.coreColor)
		glCallList(s.coreDisplayList)
		if s.flashed then
			glColor(s.trunkColor)
			glCallList(s.trunkDisplayList)
		end
	end
	-- glPopMatrix()
	glDepthTest(false)
	for i = 1, #strikes do
		local s = strikes[i]
		if s.flash then
			glCallList(s.flashDisplayList)
		end
	end
	glDepthTest(true)
	glBlending("reset")
	glColor(1, 1, 1, 0.5)
end

function widget:Shutdown()
	for i = #strikes, 1, -1 do
		local s = strikes[i]
		glDeleteList(s.coreDisplayList)
		glDeleteList(s.trunkDisplayList)
		glDeleteList(s.glowDisplayList)
		glDeleteList(s.flashDisplayList)
	end
end