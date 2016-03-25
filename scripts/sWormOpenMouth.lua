local center = piece "center"
local sWormSeg1 = piece "sWormSeg1"
local sWormSeg2 = piece "sWormSeg2"
local sWormSeg3 = piece "sWormSeg3"
local sWormSeg4 = piece "sWormSeg4"
local sWormMout0 = piece "sWormMout0"
local sWormMout1 = piece "sWormMout1"
local sWormMout2 = piece "sWormMout2"
local sWormMout3 = piece "sWormMout3"
local foodmagnet = piece "foodmagnet"

-- local AttachUnit = Spring.UnitScript.AttachUnit

local function AttachUnit(pieceNum, passengerID)
	Spring.UnitAttach(unitID, passengerID, pieceNum)
end

local DropUnit = Spring.UnitScript.DropUnit

local sndRoarA = "sounds/reverse_scream.wav"
local sndRoarB = "sounds/cobra.wav"
local sndRoarC = "sounds/wtf_roar.wav"
local sndSandExplosion = "sounds/sand_explosion.wav"
local sndQuakeA = "sounds/deep_tremor.wav"
local sndQuakeB = "sounds/low_quake.wav"
local sndQuakeC = "sounds/rumble_9sec.wav"
local sndQuakeD = "sounds/rumble_11sec.wav"
local quakeSnds = { sndQuakeA, sndQuakeB, sndQuakeC, sndQuakeD }

function script.Create()

Spring.SetUnitPieceCollisionVolumeData(unitID, sWormMout0, true, 5, 35, 35, 7, 20, 0, 2)
Spring.SetUnitPieceCollisionVolumeData(unitID, sWormMout2, true, 5, 35, 35, -7, 20, 0, 2)
Spring.SetUnitPieceCollisionVolumeData(unitID, sWormMout1, true, 35, 35, 5, 0, 20, -7, 2)
Spring.SetUnitPieceCollisionVolumeData(unitID, sWormMout3, true, 35, 35, 5, 0, 20, 7, 2)
Spring.SetUnitPieceCollisionVolumeData(unitID, sWormSeg1, true, 70, 60, 70, 0, 0, 0, 1, 1)
-- ( number unitID, number pieceIndex, boolean enable, number scaleX, number scaleY, number scaleZ, number offsetX, number offsetY, number offsetZ [, number volumeType [, number primaryAxis]] )

--move the worm into the position underground and close mouth
Move(center,y_axis,-50,0) --Moves the worm underground Instantanously
closeMouth()
Spin(center,y_axis,0.03,1) -- worm rotates slowly

local x,y,z = Spring.GetUnitPosition (unitID)

if (x and y and z) then
	local nearunits=Spring.GetUnitsInSphere  (x,y,z, 32) or "nothing"
	if (nearunits~="nothing") then		
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

function closeMouth()
Turn(sWormMout0,z_axis,math.rad(50),10)
Turn(sWormMout2,z_axis,math.rad(-50),10)
Turn(sWormMout1,x_axis,math.rad(50),10)
Turn(sWormMout3,x_axis,math.rad(-50),10)
end

function closeMouthHalf()
Turn(sWormMout0,z_axis,math.rad(25),5)
Turn(sWormMout2,z_axis,math.rad(-25),5)
Turn(sWormMout1,x_axis,math.rad(25),5)
Turn(sWormMout3,x_axis,math.rad(-25),5)
end

function openMouthSlow()
Turn(sWormMout0,z_axis,math.rad(0),0.12)
Turn(sWormMout2,z_axis,math.rad(0),0.12)
Turn(sWormMout1,x_axis,math.rad(0),0.12)
Turn(sWormMout3,x_axis,math.rad(0),0.12)
end

function openMouth()
Turn(sWormMout0,z_axis,math.rad(0),0.5)
Turn(sWormMout2,z_axis,math.rad(0),0.5)
Turn(sWormMout1,x_axis,math.rad(0),0.5)
Turn(sWormMout3,x_axis,math.rad(0),0.5)
end

local function WaitForMouth()
	WaitForTurn(sWormMout0, z_axis)
	WaitForTurn(sWormMout2, z_axis)
	WaitForTurn(sWormMout1, x_axis)
	WaitForTurn(sWormMout3, x_axis)
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

function swallow(idUnitToBeSwallowed)

local unitx,unity,unitz=Spring.GetUnitBasePosition(unitID)
-- Spring.Echo("init", Spring.GetUnitBasePosition(idUnitToBeSwallowed))

Spring.PlaySoundFile(sndSandExplosion,15.0,unitx,unity,unitz)
Spring.PlaySoundFile(sndRoarA,5.0,unitx,unity,unitz)

MuchDirt(unitx, unity, unitz, 5)
Spring.SpawnCEG("sworm_dirt",unitx,unity,unitz,0,1,0,50,0) -- spawns some dirt and dustclouds (dirt is stolen like fire from the gods of mods - yep its smoths)
MuchDirt(unitx, unity, unitz, 5, 50)
openMouth() --opens Mouth
MuchDirt(unitx, unity, unitz, 7)

Spring.PlaySoundFile(sndRoarB,5.0,unitx,unity,unitz)
Spring.PlaySoundFile(sndRoarC,4.0,unitx,unity,unitz)

Spring.MoveCtrl.Enable(idUnitToBeSwallowed)
-- Spring.MoveCtrl.SetTrackSlope(idUnitToBeSwallowed, false)
Spring.MoveCtrl.SetGroundOffset(idUnitToBeSwallowed, 80)
-- AttachUnit(foodmagnet, idUnitToBeSwallowed)
MuchDirt(unitx, unity, unitz, 11, 100)
Spring.Echo("attached", Spring.GetUnitBasePosition(idUnitToBeSwallowed))
Move(center,y_axis,80,16)-- the whole thing is wheighting tons of tons, so propelling itself out of the sand, slows it down

MuchDirt(unitx, unity, unitz, 11, 100)

Sleep(1000)--we give the mouth some time so it is allready half opened when the worm breaks through the sand.

Spring.PlaySoundFile(sndRoarB,3.0,unitx,unity,unitz)
Spring.PlaySoundFile(quakeSnds[math.random(1,4)],15.0,unitx,unity,unitz)

local uDefID = Spring.GetUnitDefID(idUnitToBeSwallowed)
local unitHeight = UnitDefs[uDefID].height
local unitMass = UnitDefs[uDefID].mass
local unitHealth, unitMaxHealth = Spring.GetUnitHealth(idUnitToBeSwallowed)
Spring.Echo(unitMass, unitHealth, unitMaxHealth)

Move(foodmagnet,y_axis,-50 - unitHeight, 11) -- expecting unit to be attached to foodmagnet from this point towards
Move(center,y_axis,5, 11)
MuchDirt(unitx, unity, unitz, 10, 10)
WaitForMove(center,y_axis)
-- WaitForMouth()
closeMouthHalf()
MuchDirt(unitx, unity, unitz, 6)
-- Spring.MoveCtrl.SetVelocity(idUnitToBeSwallowed, 0, 2, 0)
-- Spring.MoveCtrl.SetRotationVelocity(idUnitToBeSwallowed, math.random(2)-1, math.random(2)-1, math.random(2)-1)
-- WaitForMouth()
Sleep(50)
Spring.MoveCtrl.Disable(idUnitToBeSwallowed)
Spring.AddUnitImpulse(idUnitToBeSwallowed, 0, 5, 0)
Spring.SetUnitHealth(idUnitToBeSwallowed, unitMaxHealth*0.1)
Spring.SetUnitRotation(idUnitToBeSwallowed, math.random(30)-15, math.random(30)-15, math.random(30)-15)
openMouth()
Sleep(4000)
-- Spring.DestroyUnit(idUnitToBeSwallowed)
MuchDirt(unitx, unity, unitz, 6)
-- WaitForMouth()
MuchDirt(unitx, unity, unitz, 5)
closeMouth()
Spring.DestroyUnit (idUnitToBeSwallowed, true)
Move(center,y_axis,-40, 7)
-- WaitForMouth()

-- if (Spring.ValidUnitID (idUnitToBeSwallowed)) then -- this assures, that the unit in the mouth is alive until the very last moment
		-- Spring.Echo("death", Spring.GetUnitBasePosition(idUnitToBeSwallowed))
      -- Spring.DestroyUnit (idUnitToBeSwallowed,false,true) --this destroys the unit without wreckage. Knorke teached me that. If you want to know something, ask him. Its helpfull AND entertaining, to be his pupil.
-- end

while(true==Spring.UnitScript.IsInMove(center, y_axis)) do --spawns cegs and turns the 4fth segmet
	MuchDirt(unitx, unity, unitz, 1, 300)
end

WaitForMove(center,y_axis)
Move(center,y_axis,-50, 4)

Spring.PlaySoundFile(sndSandExplosion,12.0,unitx,unity,unitz)

while(true==Spring.UnitScript.IsInMove(center, y_axis)) do --spawns cegs and turns the 4fth segmet until the Worm is underground 
randX=math.random(-25,25)
randZ=math.random(-25,25)
Spring.SpawnCEG("sworm_dirt",unitx+randX,unity,unitz+randZ,0,1,0,50,0)
Sleep(250)
end

end

function Killed()
	
				
					
						
						
						
						
					
  

end

function script.StartMoving()


		
		
		
end

function script.StopMoving()


	
end
