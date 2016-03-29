local center = piece "center"
local sWormSeg1 = piece "sWormSeg1"
local sWormSeg2 = piece "sWormSeg2"
local sWormSeg3 = piece "sWormSeg3"
local sWormSeg4 = piece "sWormSeg4"
local sWormMout1 = piece "sWormMout1"
local sWormMout2 = piece "sWormMout2"
local sWormMout3 = piece "sWormMout3"
local foodmagnet = piece "foodmagnet"

local maxMealSize = 32

local sqrtThree = math.sqrt(3)

local mAtan2 = math.atan2
local mCos = math.cos
local mSin = math.sin
local mRandom = math.random

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
	Spring.SetUnitPieceCollisionVolumeData(unitID, sWormMout2, true, 5, 50, 50, -7, 5, 0, 2)
	Spring.SetUnitPieceCollisionVolumeData(unitID, sWormMout1, true, 50, 50, 5, 0, 5, -7, 2)
	Spring.SetUnitPieceCollisionVolumeData(unitID, sWormMout3, true, 50, 50, 5, 0, 5, 7, 2)
	Spring.SetUnitPieceCollisionVolumeData(unitID, sWormSeg1, true, 70, 65, 70, 0, 0, 0, 1, 1)
	Spring.SetUnitPieceCollisionVolumeData(unitID, foodmagnet, false, 70, 65, 70, 0, 0, 0, 1, 1)
	-- ( number unitID, number pieceIndex, boolean enable, number scaleX, number scaleY, number sca
end

local function Jaws(degree, speed)
	local longSide = math.rad( (degree / 2) * sqrtThree )
	local shortSide = math.rad( degree / 2 )
	local longSpeed = (speed / 2) * sqrtThree
	local shortSpeed = speed / 2
	Turn(sWormMout2, z_axis, math.rad(degree), speed)
	Turn(sWormMout1, x_axis, -longSide, longSpeed)
	Turn(sWormMout1, z_axis, -shortSide, shortSpeed)
	Turn(sWormMout3, x_axis, longSide, longSpeed)
	Turn(sWormMout3, z_axis, -shortSide, shortSpeed)
end

local function MuchDirt(x, y, z, dirtnum, sleepbetween, randradius)
	randradius = randradius or 25
	for i=1,dirtnum do
		randX=math.random(-randradius,randradius)
		randZ=math.random(-randradius,randradius)
		Spring.SpawnCEG("sworm_dirt",x+randX,y,z+randZ,0,1,0,50,0)
		if sleepbetween then Sleep(sleepbetween) end
	end
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
				local uSize = uDef.xsize * uDef.zsize
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
		local ux, uy, uz = Spring.GetUnitBasePosition(uID)
		local distx = ux - x
		local distz = uz - z
		Spring.MoveCtrl.Enable(uID)
		-- Spring.AddUnitImpulse(uID, -distx/10, 0.01, -distz/10)
		-- Spring.Echo(distx, distz)
		Spring.MoveCtrl.SetVelocity(uID, -distx/100, 0, -distz/100)
		Spring.MoveCtrl.SetRotationVelocity(uID, 0, math.random()*0.1-0.05, 0)
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

	Sleep(600)

	-- Move(foodmagnet,y_axis,-50 - unitHeight, 11) -- expecting unit to be attached to foodmagnet from this point towards
	Move(center,y_axis,75, 11)
	MuchDirt(x, y, z, 10, 10)
	WaitForMove(center,y_axis)
	local mostPieces = 0
	local piecesByID = {}
	for _, uID in pairs(mealIDs) do
		local pieces = Spring.GetUnitPieceList(uID)
		if mostPieces < #pieces then mostPieces = #pieces end
		piecesByID[uID] = pieces
		Spring.MoveCtrl.Disable(uID)
	end
	Spring.Echo(mostPieces)
	local healthInc = 0.9 / mostPieces
	for p = 1, mostPieces do
		Jaws(30, 12)
		Spring.PlaySoundFile("WmRoar3",1.0,x,y,z)
		MuchDirt(x, y, z, 4)
		-- Spring.MoveCtrl.SetVelocity(diesFirstID, 0, 2, 0)
		-- Spring.MoveCtrl.SetRotationVelocity(diesFirstID, math.random(2)-1, math.random(2)-1, math.random(2)-1)
		Sleep(50)
		MuchDirt(x, y, z, 4)
		local maxHealthByID = {}
		local giveHealth = healthInc * ((mostPieces-p)+1)
		for _, uID in pairs(mealIDs) do
			-- local uDef = mealDefsByID[uID]
			-- local uMass = uDef.mass
			local uHealth, uMaxHealth = Spring.GetUnitHealth(uID)
			maxHealthByID[uID] = uMaxHealth
			Spring.SetUnitHealth(uID, uMaxHealth * giveHealth)
			if #mealIDs == 1 then
				Spring.AddUnitImpulse(uID, 0.01, 4, 0.01)
			else
				Spring.AddUnitImpulse(uID, 0.01, 1, 0.01)
			end
			local pieces = piecesByID[uID]
			if #pieces > 0 then
				local pieceNumber = 0
				pieceNumber = math.random(#pieces)
				Spring.Echo(pieceNumber, table.remove(pieces, pieceNumber))
				-- local exploType = SFX.FALL + SFX.NO_HEATCLOUD
				local exploType = SFX.SHATTER + SFX.NO_HEATCLOUD
				if #pieces == 0 then
					exploType = SFX.SHATTER
				end
				Spring.UnitScript.CallAsUnit(uID, Explode, pieceNumber, exploType)
				if #pieces == 0 then
					Spring.PlaySoundFile("WmCrush2",1.0,x,y,z)
					Spring.DestroyUnit(uID, false, true)
				else
					Spring.PlaySoundFile("WmCrush1",1.0,x,y,z)
					Spring.UnitScript.CallAsUnit(uID, Hide, pieceNumber)
				end
			end
		end
		MuchDirt(x, y, z, 4, 200)
		Jaws(80, 1)
		MuchDirt(x, y, z, 5, 200)
	end
	Jaws(25, 3)
	MuchDirt(x, y, z, 10, 200)
end

function script.Create()
	SetWormColVols()
	local x,y,z = Spring.GetUnitPosition(unitID)
	Turn(center,y_axis,math.rad(math.random(1,360)),50) -- start in a random rotation
	Spin(center,y_axis,0.03,1) -- worm rotates slowly
	Spring.PlaySoundFile("WmStampede",1.5,x,y,z)
	MuchDirt(x, y, z, 5, 50)
	-- Move(center,y_axis,20,30)
	-- WaitForMove(center,y_axis)
	Jaws(80, 0.5) --opens Mouth
	MuchDirt(x, y, z, 5)
	MuchDirt(x, y, z, 11, 100)
	Move(center,y_axis,150,30)-- the whole thing is wheighting tons of tons, so propelling itself out of the sand, slows it down
	MuchDirt(x, y, z, 11, 100)
	Spring.PlaySoundFile("WmRoar2",1.0,x,y,z)
	Sleep(200)
	Spring.PlaySoundFile("WmRoar1",1.0,x,y,z)
	Sleep(200)
	if (x and y and z) then
		local nearunits = Spring.GetUnitsInSphere(x,y,z, 60)
		if nearunits then
			local unitsToSwallow = {}
			local numToSwallow = 0
			for _, nearunitid in ipairs (nearunits) do
				if (nearunitid~=unitID) then
					local dist = Spring.GetUnitSeparation(unitID, nearunitid, true)
					unitsToSwallow[math.ceil(dist)] = nearunitid
					numToSwallow = numToSwallow + 1
				end
			end
			if numToSwallow > 0 then Swallow(unitsToSwallow) end
		end
	end
	Sleep(200)
	Jaws(11, 0.05)
	Move(center,y_axis,25, 7)
	-- if (Spring.ValidUnitID (diesFirstID)) then -- this assures, that the unit in the mouth is alive until the very last moment
			-- Spring.Echo("death", Spring.GetUnitBasePosition(diesFirstID))
	      -- Spring.DestroyUnit (diesFirstID,false,true) --this destroys the unit without wreckage. Knorke teached me that. If you want to know something, ask him. Its helpfull AND entertaining, to be his pupil.
	-- end
	while true == Spring.UnitScript.IsInMove(center, y_axis) do --spawns cegs and turns the 4fth segmet
		MuchDirt(x, y, z, 1, 100, 15)
	end
	WaitForMove(center,y_axis)
	Spring.PlaySoundFile("WmSandExplosion",2.0,x,y,z)
	Move(center,y_axis,0, 4)
	while true == Spring.UnitScript.IsInMove(center, y_axis) do --spawns cegs and turns the 4fth segmet until the Worm is underground 
		MuchDirt(x, y, z, 1, 200, 10)
	end
	Spring.DestroyUnit(unitID, false, true)
end