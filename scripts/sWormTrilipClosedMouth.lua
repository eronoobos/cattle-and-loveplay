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

local function swallow(idUnitToBeSwallowed)
	local uDefID = Spring.GetUnitDefID(idUnitToBeSwallowed)
	if not uDefID then return end
	if not UnitDefs then return end
	local uDef = UnitDefs[uDefID]
	if not uDef then return end
	local unitx,unity,unitz=Spring.GetUnitBasePosition(unitID)
	-- Spring.Echo("init", Spring.GetUnitBasePosition(idUnitToBeSwallowed))

	Spring.PlaySoundFile("WmStampede",1.5,unitx,unity,unitz)

	MuchDirt(unitx, unity, unitz, 5, 50)
	Jaws(70, 0.5) --opens Mouth
	MuchDirt(unitx, unity, unitz, 5)

	Spring.MoveCtrl.Enable(idUnitToBeSwallowed)
	-- Spring.MoveCtrl.SetTrackSlope(idUnitToBeSwallowed, false)
	Spring.MoveCtrl.SetGroundOffset(idUnitToBeSwallowed, 80)
	-- AttachUnit(foodmagnet, idUnitToBeSwallowed)
	MuchDirt(unitx, unity, unitz, 11, 100)
	Move(center,y_axis,150,30)-- the whole thing is wheighting tons of tons, so propelling itself out of the sand, slows it down

	MuchDirt(unitx, unity, unitz, 11, 100)
	Spring.PlaySoundFile("WmRoar2",1.0,unitx,unity,unitz)
	Sleep(200)
	Spring.PlaySoundFile("WmRoar1",1.0,unitx,unity,unitz)
	Sleep(200)
	Spring.PlaySoundFile("WmRoar3",1.0,unitx,unity,unitz)
	Sleep(600)

	local unitHeight = uDef.height
	local unitMass = uDef.mass
	local unitHealth, unitMaxHealth = Spring.GetUnitHealth(idUnitToBeSwallowed)
	Move(foodmagnet,y_axis,-50 - unitHeight, 11) -- expecting unit to be attached to foodmagnet from this point towards
	Move(center,y_axis,75, 11)
	MuchDirt(unitx, unity, unitz, 10, 10)
	WaitForMove(center,y_axis)
	Jaws(55, 12)
	MuchDirt(unitx, unity, unitz, 4)
	-- Spring.MoveCtrl.SetVelocity(idUnitToBeSwallowed, 0, 2, 0)
	-- Spring.MoveCtrl.SetRotationVelocity(idUnitToBeSwallowed, math.random(2)-1, math.random(2)-1, math.random(2)-1)
	Sleep(100)
	MuchDirt(unitx, unity, unitz, 4)
	-- Spring.SetUnitHealth(idUnitToBeSwallowed, unitMaxHealth*0.1)
	Spring.MoveCtrl.Disable(idUnitToBeSwallowed)
	Spring.AddUnitImpulse(idUnitToBeSwallowed, 0, 5, 0)
	Spring.SetUnitRotation(idUnitToBeSwallowed, math.random(40)-20, math.random(40)-20, math.random(40)-20)
	Sleep(200)
	Jaws(70, 1)
	MuchDirt(unitx, unity, unitz, 10, 200)
	Jaws(25, 15)
	Sleep(100)
	Spring.DestroyUnit (idUnitToBeSwallowed, true)
	Sleep(200)
	Jaws(8, 0.05)
	Move(center,y_axis,25, 7)

	-- if (Spring.ValidUnitID (idUnitToBeSwallowed)) then -- this assures, that the unit in the mouth is alive until the very last moment
			-- Spring.Echo("death", Spring.GetUnitBasePosition(idUnitToBeSwallowed))
	      -- Spring.DestroyUnit (idUnitToBeSwallowed,false,true) --this destroys the unit without wreckage. Knorke teached me that. If you want to know something, ask him. Its helpfull AND entertaining, to be his pupil.
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
		local nearunits = Spring.GetUnitsInSphere(x,y,z, 32)
		if nearunits then		
			for _, nearunitid in ipairs (nearunits) do
				if (nearunitid~=unitID) then
					swallow(nearunitid)
					break
				end
			end
		end
	end
	Spring.DestroyUnit(unitID, false, true)
end