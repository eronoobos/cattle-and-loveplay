local center = piece "center"
local sWormSeg1 = piece "sWormSeg1"
local sWormSeg2 = piece "sWormSeg2"
local sWormSeg3 = piece "sWormSeg3"
local sWormSeg4 = piece "sWormSeg4"
local sWormMout1 = piece "sWormMout1"
local sWormMout2 = piece "sWormMout2"
local sWormMout3 = piece "sWormMout3"
local foodmagnet = piece "foodmagnet"

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

local function MuchDirt(unitx, unity, unitz, dirtnum, sleepbetween, randradius)
	randradius = randradius or 25
	for i=1,dirtnum do
		randX=math.random(-randradius,randradius)
		randZ=math.random(-randradius,randradius)
		Spring.SpawnCEG("sworm_dirt",unitx+randX,unity,unitz+randZ,0,1,0,50,0)
		if sleepbetween then Sleep(sleepbetween) end
	end
end

local function Swallow(doomedByDist)
	if not doomedByDist then return end
	local diesFirstID, diesSecondID
	local dieIDs = {}
	local pushAway = {}
	for dist, uID in pairsByKeys(doomedByDist) do
		if not diesFirstID then
			diesFirstID = uID
			table.insert(dieIDs, uID)
		elseif not diesSecondID then
			diesSecondID = uID
			table.insert(dieIDs, uID)
		else
			table.insert(pushAway, uID)
		end
	end
	if not diesFirstID then return end

	local uDefID = Spring.GetUnitDefID(diesFirstID)
	if not uDefID then return end
	if not UnitDefs then return end
	local uDef = UnitDefs[uDefID]
	if not uDef then return end
	local unitx,unity,unitz = Spring.GetUnitBasePosition(unitID)
	-- Spring.Echo("init", Spring.GetUnitBasePosition(diesFirstID))

	Spring.PlaySoundFile("WmStampede",1.5,unitx,unity,unitz)

	MuchDirt(unitx, unity, unitz, 5, 50)
	Jaws(80, 0.5) --opens Mouth
	MuchDirt(unitx, unity, unitz, 5)

	Spring.MoveCtrl.Enable(diesFirstID)

	-- AttachUnit(foodmagnet, diesFirstID)
	MuchDirt(unitx, unity, unitz, 11, 100)
	Move(center,y_axis,150,30)-- the whole thing is wheighting tons of tons, so propelling itself out of the sand, slows it down

	-- move the second unit into the mouth
	if diesSecondID then
		Spring.MoveCtrl.Enable(diesSecondID)
		local secx, secy, secz = Spring.GetUnitBasePosition(diesSecondID)
		local distx = secx - unitx
		local distz = secz - unitz
		local dist = math.sqrt(distx*distx + distz*distz)
		if dist > 10 then
			Spring.MoveCtrl.SetVelocity(diesSecondID, -distx/100, 0, -distz/100)
			Spring.MoveCtrl.SetRotationVelocity(diesSecondID, 0, math.random()*0.1-0.05, 0)
		end
	end

	-- push the rest away from the mouth
	for _, uID in pairs(pushAway) do
		local secx, secy, secz = Spring.GetUnitBasePosition(uID)
		if secx then
			local distx = secx - unitx
			local distz = secz - unitz
			local angle = mAtan2(distz, distx)
			local tx, tz = CirclePos(unitx, unitz, 65, angle)
			local vx = tx - secx
			local vz = tz - secz
			Spring.AddUnitImpulse(uID, vx/30, 1.5, vz/30)
		end
	end

	MuchDirt(unitx, unity, unitz, 11, 100)
	Spring.PlaySoundFile("WmRoar2",1.0,unitx,unity,unitz)
	Sleep(200)
	Spring.PlaySoundFile("WmRoar1",1.0,unitx,unity,unitz)
	Sleep(200)
	Spring.PlaySoundFile("WmRoar3",1.0,unitx,unity,unitz)
	Sleep(600)

	local unitHeight = uDef.height
	local unitMass = uDef.mass
	local unitHealth, unitMaxHealth = Spring.GetUnitHealth(diesFirstID)
	-- Move(foodmagnet,y_axis,-50 - unitHeight, 11) -- expecting unit to be attached to foodmagnet from this point towards
	Move(center,y_axis,75, 11)
	MuchDirt(unitx, unity, unitz, 10, 10)
	WaitForMove(center,y_axis)
	Jaws(55, 12)
	MuchDirt(unitx, unity, unitz, 4)
	-- Spring.MoveCtrl.SetVelocity(diesFirstID, 0, 2, 0)
	-- Spring.MoveCtrl.SetRotationVelocity(diesFirstID, math.random(2)-1, math.random(2)-1, math.random(2)-1)
	Sleep(100)
	MuchDirt(unitx, unity, unitz, 4)
	for _, diesID in pairs(dieIDs) do
		Spring.SetUnitHealth(diesID, unitMaxHealth*0.1)
		Spring.MoveCtrl.Disable(diesID)
		Spring.AddUnitImpulse(diesID, 0, 5, 0)
		Spring.SetUnitRotation(diesID, math.random(40)-20, math.random(40)-20, math.random(40)-20)
	end
	Sleep(200)
	Jaws(80, 1)
	MuchDirt(unitx, unity, unitz, 10, 200)
	Jaws(25, 15)
	Sleep(100)
	Spring.DestroyUnit (diesFirstID, true)
	if diesSecondID then Spring.DestroyUnit (diesSecondID, true) end
	Sleep(200)
	Jaws(11, 0.05)
	Move(center,y_axis,25, 7)

	-- if (Spring.ValidUnitID (diesFirstID)) then -- this assures, that the unit in the mouth is alive until the very last moment
			-- Spring.Echo("death", Spring.GetUnitBasePosition(diesFirstID))
	      -- Spring.DestroyUnit (diesFirstID,false,true) --this destroys the unit without wreckage. Knorke teached me that. If you want to know something, ask him. Its helpfull AND entertaining, to be his pupil.
	-- end

	while true == Spring.UnitScript.IsInMove(center, y_axis) do --spawns cegs and turns the 4fth segmet
		MuchDirt(unitx, unity, unitz, 1, 100, 15)
	end

	WaitForMove(center,y_axis)
	Spring.PlaySoundFile("WmSandExplosion",2.0,unitx,unity,unitz)
	Move(center,y_axis,0, 4)

	while true == Spring.UnitScript.IsInMove(center, y_axis) do --spawns cegs and turns the 4fth segmet until the Worm is underground 
		MuchDirt(unitx, unity, unitz, 1, 200, 10)
	end
end

function script.Create()
	Turn(center,y_axis,math.rad(math.random(1,360)),50) -- start in a random rotation
	Spin(center,y_axis,0.03,1) -- worm rotates slowly
	local x,y,z = Spring.GetUnitPosition(unitID)
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
					-- if #unitsToSwallow == 2 then break end
				end
			end
			if numToSwallow > 0 then Swallow(unitsToSwallow) end
		end
	end
	Spring.DestroyUnit(unitID, false, true)
end