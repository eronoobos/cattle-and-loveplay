local center = piece "center"
local sWormSeg1 = piece "sWormSeg1"
local sWormSeg2 = piece "sWormSeg2"
local sWormSeg3 = piece "sWormSeg3"
local sWormSeg4 = piece "sWormSeg4"
local sWormMout1 = piece "sWormMout1"
local sWormMout2 = piece "sWormMout2"
local sWormMout3 = piece "sWormMout3"
local foodmagnet = piece "foodmagnet"

-- set based on unit definition in script.Create()
local uDef
local modelHeight = 75
local modelRadius = 36
local maxMealSize = 36
local doomRadius = 65

local sqrtThree = math.sqrt(3)

local mAtan2 = math.atan2
local mCos = math.cos
local mSin = math.sin
local mRandom = math.random
local mCeil = math.ceil
local mFloor = math.floor

local function pairsByKeys (t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

local function AngleXYXY(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  return mAtan2(dy, dx), dx, dy
end

local function CirclePos(cx, cy, dist, angle)
  angle = angle or mRandom() * twicePi
  local x = cx + dist * mCos(angle)
  local y = cy + dist * mSin(angle)
  return x, y
end

-- local AttachUnit = Spring.UnitScript.AttachUnit

local function AttachUnit(pieceNum, passengerID)
	Spring.UnitAttach(unitID, passengerID, pieceNum)
end

local function SetWormColVols()
	local flap = modelHeight * 0.67
	local flapOff = (modelHeight*0.1)
	local thick = modelHeight * 0.067
	local cylRad = modelRadius * 2
	local cylHei = modelHeight * 0.867
	Spring.SetUnitPieceCollisionVolumeData(unitID, sWormMout2, true, thick, flap, flap, -flapOff, thick, 0, 2)
	Spring.SetUnitPieceCollisionVolumeData(unitID, sWormMout1, true, flap, flap, thick, 0, thick, -flapOff, 2)
	Spring.SetUnitPieceCollisionVolumeData(unitID, sWormMout3, true, flap, flap, thick, 0, thick, flapOff, 2)
	Spring.SetUnitPieceCollisionVolumeData(unitID, sWormSeg1, true, cylRad, cylHei, cylRad, 0, 0, 0, 1, 1)
	Spring.SetUnitPieceCollisionVolumeData(unitID, foodmagnet, false, 1, 1, 1, 0, 0, 0, 1, 1)
	-- ( number unitID, number pieceIndex, boolean enable, number scaleX, number scaleY, number sca
end

local function Jaws(degree, speed)
	local longSide = math.rad( (degree / 2) * sqrtThree )
	local shortSide = math.rad( degree / 2 )
	local longSpeed = math.rad( (speed / 2) * sqrtThree )
	local shortSpeed = math.rad( speed / 2 )
	Turn(sWormMout2, z_axis, math.rad(degree), math.rad(speed))
	Turn(sWormMout1, x_axis, -longSide, longSpeed)
	Turn(sWormMout1, z_axis, -shortSide, shortSpeed)
	Turn(sWormMout3, x_axis, longSide, longSpeed)
	Turn(sWormMout3, z_axis, -shortSide, shortSpeed)
end

local function MuchDirt(x, y, z, dirtnum, sleepbetween, randradius)
	randradius = randradius or modelRadius*0.75
	for i=1,dirtnum do
		randX=math.random(-randradius,randradius)
		randZ=math.random(-randradius,randradius)
		Spring.SpawnCEG("sworm_dirt",x+randX,y,z+randZ,0,1,0,50,0)
		if sleepbetween then Sleep(sleepbetween) end
	end
end

local function ComeToMe(uID, x, y, z)
	local ux, uy, uz = Spring.GetUnitBasePosition(uID)
	if not ux then return end
	local distx = ux - x
	local disty = uy - (y + math.ceil(modelHeight*0.05))
	local distz = uz - z
	Spring.MoveCtrl.Enable(uID)
	-- Spring.AddUnitImpulse(uID, -distx/10, 0.01, -distz/10)
	-- Spring.Echo(distx, distz)
	Spring.Echo(uy, y, disty)
	Spring.MoveCtrl.SetVelocity(uID, -distx/100, -disty/100, -distz/100)
	Spring.MoveCtrl.SetRotationVelocity(uID, 0, math.random()*0.03-0.015, 0)
end

local function ToyWith(uID)
	Spring.AddUnitImpulse(uID, math.random()*0.2-0.1, 1, math.random()*0.2-0.1)
	-- Spring.SetUnitRotation(uID, 0, math.random(8)-4, 0)
end

local function GetUnitDef(uID)
	local uDefID = Spring.GetUnitDefID(uID)
	if not uDefID then return end
	return UnitDefs[uDefID]
end

local function Swallow(doomedByDist)
	if not doomedByDist then return end
	local mealIDs = {}
	local mealDefsByID = {}
	local awayIDs = {}
	local mealSize = 0
	for dist, uID in pairsByKeys(doomedByDist) do
		local awayWithYou = true
		if mealSize < maxMealSize then
			local uDef = GetUnitDef(uID)
			if uDef then
				local uSize = math.ceil(uDef.radius)
				-- local uSize = mCeil(uDef.height * uDef.radius)
				Spring.Echo(uSize)
				local newMealSize = mealSize + uSize
				if newMealSize <= maxMealSize then
					table.insert(mealIDs, uID)
					mealDefsByID[uID] = uDef
					mealSize = newMealSize
					awayWithYou = false
				end
			end
		end
		if awayWithYou then
			table.insert(awayIDs, uID)
		end
	end
	if #mealIDs == 0 then return end
	local x,y,z = Spring.GetUnitBasePosition(unitID)

	for _, uID in pairs(mealIDs) do
		ComeToMe(uID, x, y, z)
	end

	-- push the rest away from the mouth
	for _, uID in pairs(awayIDs) do
		local ux, uy, uz = Spring.GetUnitBasePosition(uID)
		if ux then
			local angle = AngleXYXY(x, z, ux, uz)
			local tx, tz = CirclePos(x, z, 65, angle)
			local vx = tx - ux
			local vz = tz - uz
			Spring.AddUnitImpulse(uID, vx/10, 0.25, vz/10)
		end
	end

	-- WaitForMove(center,y_axis)
	Jaws(80, 10)
	Move(center, y_axis, modelHeight, mFloor(modelHeight*0.15))
	Spring.PlaySoundFile("WmRoar2",1.0,x,y,z)
	Sleep(200)
	Spring.PlaySoundFile("WmRoar1",1.0,x,y,z)
	Sleep(200)

	-- Sleep(600)

	-- Move(foodmagnet,y_axis,-50 - unitHeight, 11) -- expecting unit to be attached to foodmagnet from this point towards
	-- Move(center, y_axis, modelHeight, mFloor(modelHeight*0.15))
	MuchDirt(x, y, z, 10, 10)
	WaitForMove(center,y_axis)
	local mostPieces = 0
	local piecesByID = {}
	for _, uID in pairs(mealIDs) do
		local pieces = Spring.GetUnitPieceList(uID)
		if mostPieces < #pieces then mostPieces = #pieces end
		piecesByID[uID] = pieces
		Spring.MoveCtrl.SetVelocity(uID, 0, 0, 0)
		Spring.MoveCtrl.SetRotationVelocity(uID, 0, 0, 0)
		-- Spring.MoveCtrl.Disable(uID)
	end
	-- Spring.Echo(mostPieces)
	for p = 1, mostPieces do
		Jaws(20, 900)
		Spring.PlaySoundFile("WmRoar3",1.0,x,y,z)
		MuchDirt(x, y, z, 4)
		-- Spring.MoveCtrl.SetVelocity(diesFirstID, 0, 2, 0)
		-- Spring.MoveCtrl.SetRotationVelocity(diesFirstID, math.random(2)-1, math.random(2)-1, math.random(2)-1)
		Sleep(50)
		MuchDirt(x, y, z, 4)
		local ate = false
		for _, uID in pairs(mealIDs) do
			-- Spring.MoveCtrl.Disable(uID)
			local uHealth, uMaxHealth = Spring.GetUnitHealth(uID)
			if uHealth then
				Spring.SetUnitHealth(uID, uHealth / 2)
				local pieces = piecesByID[uID]
				if #pieces > 0 then
					local pieceNumber = 0
					pieceNumber = math.random(#pieces)
					table.remove(pieces, pieceNumber)
					-- local exploType = SFX.FALL + SFX.NO_HEATCLOUD
					local exploType = SFX.SHATTER + SFX.NO_HEATCLOUD
					if #pieces == 0 then
						exploType = SFX.SHATTER
					end
					Spring.UnitScript.CallAsUnit(uID, Explode, pieceNumber, exploType)
					if #pieces == 0 then
						Spring.PlaySoundFile("WmCrush1",1.0,x,y,z)
						Sleep(50)
						Spring.PlaySoundFile("WmExplode3",1.0,x,y,z)
						Spring.DestroyUnit(uID, false, true)
						ate = true
					else
						Spring.PlaySoundFile("WmCrush1",1.0,x,y,z)
						Sleep(50)
						Spring.PlaySoundFile("WmExplode2",1.0,x,y,z)
						Spring.UnitScript.CallAsUnit(uID, Hide, pieceNumber)
					end
				end
			end
		end
		if not ate then
			MuchDirt(x, y, z, 4, 200)
			Jaws(80, 60)
		end
		MuchDirt(x, y, z, 5, 200)
	end
	Jaws(15, 2)
	MuchDirt(x, y, z, 10, 200)
end

function script.Create()
	uDef = GetUnitDef(unitID)
	modelHeight = uDef.height
	modelRadius = uDef.radius
	maxMealSize = math.ceil(uDef.radius) * 0.888
	-- maxMealSize = mCeil(0.6 * (uDef.height * uDef.radius))
	doomRadius = mFloor(modelRadius * 1.8)
	Spring.Echo("sworm created", modelHeight, modelRadius, maxMealSize, doomRadius)
	SetWormColVols()
	local x,y,z = Spring.GetUnitPosition(unitID)

	Turn(center,y_axis,math.rad(math.random(1,360)),180) -- start in a random rotation
	Spin(center,y_axis,0.03,1) -- worm rotates slowly
	Spring.PlaySoundFile("WmStampede",1.5,x,y,z)
	MuchDirt(x, y, z, 5, 50)
	-- Move(center,y_axis,20,30)
	-- WaitForMove(center,y_axis)
	Jaws(80, 70) --opens Mouth
	Move(center, y_axis, modelHeight*0.5, modelHeight*0.45)
	MuchDirt(x, y, z, 3)
	MuchDirt(x, y, z, 10, 100)
	-- Move(center, y_axis, modelHeight*2, mFloor(modelHeight*0.4))
	-- WaitForMove(center, y_axis)
	-- Spring.Echo("swallow now")
	if (x and y and z) then
		local nearunits = Spring.GetUnitsInSphere(x,y,z, doomRadius)
		if nearunits then
			local unitsToSwallow = {}
			local numToSwallow = 0
			for _, nearunitid in ipairs (nearunits) do
				if (nearunitid~=unitID) then
					local dist = Spring.GetUnitSeparation(unitID, nearunitid, true)
					unitsToSwallow[mCeil(dist)] = nearunitid
					numToSwallow = numToSwallow + 1
				end
			end
			if numToSwallow > 0 then Swallow(unitsToSwallow) end
		end
	end
	Sleep(200)
	Jaws(9, 1)
	Move(center, y_axis, modelHeight/3, mFloor(modelHeight*0.1))
	-- if (Spring.ValidUnitID (diesFirstID)) then -- this assures, that the unit in the mouth is alive until the very last moment
			-- Spring.Echo("death", Spring.GetUnitBasePosition(diesFirstID))
	      -- Spring.DestroyUnit (diesFirstID,false,true) --this destroys the unit without wreckage. Knorke teached me that. If you want to know something, ask him. Its helpfull AND entertaining, to be his pupil.
	-- end
	while true == Spring.UnitScript.IsInMove(center, y_axis) do --spawns cegs and turns the 4fth segmet
		MuchDirt(x, y, z, 1, 100, modelRadius*0.5)
	end
	WaitForMove(center,y_axis)
	Spring.PlaySoundFile("WmSandExplosion",2.0,x,y,z)
	Move(center, y_axis, 0, mCeil(modelHeight*0.05))
	while true == Spring.UnitScript.IsInMove(center, y_axis) do --spawns cegs and turns the 4fth segmet until the Worm is underground 
		MuchDirt(x, y, z, 1, 200, modelRadius*0.25)
	end
	Spring.DestroyUnit(unitID, false, true)
end