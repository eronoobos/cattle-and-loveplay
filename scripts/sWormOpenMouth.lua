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

local AttachUnit = Spring.UnitScript.AttachUnit

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

function reset()
Turn( center,x_axis,math.rad(0),0)                              
Turn( sWormSeg1,x_axis,math.rad(0),0)                              
Turn( sWormSeg2,x_axis,math.rad(0),0)                              
Turn( sWormSeg3,x_axis,math.rad(0),0)                              
Turn( sWormSeg4,x_axis,math.rad(0),0)                            
Turn( sWormMout0,x_axis,math.rad(0),0)                              
Turn( sWormMout1,x_axis,math.rad(0),0)                              
Turn( sWormMout2,x_axis,math.rad(0),0)                             
Turn( sWormMout3,x_axis,math.rad(0),0)                             
Turn( foodmagnet,x_axis,math.rad(0),0)                            



Turn( center,y_axis,math.rad(0),0)                              
Turn( sWormSeg1,y_axis,math.rad(0),0)                              
Turn( sWormSeg2,y_axis,math.rad(0),0)                              
Turn( sWormSeg3,y_axis,math.rad(0),0)                              
Turn( sWormSeg4,y_axis,math.rad(0),0)                            
Turn( sWormMout0,y_axis,math.rad(0),0)                              
Turn( sWormMout1,y_axis,math.rad(0),0)                              
Turn( sWormMout2,y_axis,math.rad(0),0)                             
Turn( sWormMout3,y_axis,math.rad(0),0)                             
Turn( foodmagnet,y_axis,math.rad(0),0)                            




Turn( center,z_axis,math.rad(0),0)                              
Turn( sWormSeg1,z_axis,math.rad(0),0)                              
Turn( sWormSeg2,z_axis,math.rad(0),0)                              
Turn( sWormSeg3,z_axis,math.rad(0),0)                              
Turn( sWormSeg4,z_axis,math.rad(0),0)                            
Turn( sWormMout0,z_axis,math.rad(0),0)                              
Turn( sWormMout1,z_axis,math.rad(0),0)                              
Turn( sWormMout2,z_axis,math.rad(0),0)                             
Turn( sWormMout3,z_axis,math.rad(0),0)                             
Turn( foodmagnet,z_axis,math.rad(0),0)                            

end

function closeMouth()
Turn(sWormMout0,z_axis,math.rad(50),10)
Turn(sWormMout2,z_axis,math.rad(-50),10)
Turn(sWormMout1,x_axis,math.rad(50),10)
Turn(sWormMout3,x_axis,math.rad(-50),10)
end

function openMouth()
Turn(sWormMout0,z_axis,math.rad(0),2)
Turn(sWormMout2,z_axis,math.rad(0),2)
Turn(sWormMout1,x_axis,math.rad(0),2)
Turn(sWormMout3,x_axis,math.rad(0),2)
end

function swallow(idUnitToBeSwallowed)

local unitx,unity,unitz=Spring.GetUnitBasePosition(unitID)

Spring.PlaySoundFile(sndSandExplosion,15.0,unitx,unity,unitz)
Spring.PlaySoundFile(sndRoarA,5.0,unitx,unity,unitz)

Spring.SpawnCEG("sworm_dirt",unitx,unity,unitz,0,1,0,50,0) -- spawns some dirt and dustclouds (dirt is stolen like fire from the gods of mods - yep its smoths)
Sleep(250) --0,25 sec wait
openMouth() --opens Mouth

Spring.PlaySoundFile(sndRoarB,5.0,unitx,unity,unitz)
Spring.PlaySoundFile(sndRoarC,4.0,unitx,unity,unitz)

Spring.MoveCtrl.Enable(idUnitToBeSwallowed)
Spring.MoveCtrl.SetTrackGround(idUnitToBeSwallowed, false)
AttachUnit(foodmagnet, idUnitToBeSwallowed)

Move(center,y_axis,80, 16)-- the whole thing is wheighting tons of tons, so propelling itself out of the sand, slows it down
for i=1,11 do
	randX=math.random(-25,25)
	randZ=math.random(-25,25)
	Spring.SpawnCEG("sworm_dirt",unitx+randX,unity,unitz+randZ,0,1,0,50,0)
	Sleep(100)
end
--Sleep(1100)--we give the mouth some time so it is allready half opened when the worm breaks through the sand.

Spring.PlaySoundFile(sndRoarB,3.0,unitx,unity,unitz)
Spring.PlaySoundFile(quakeSnds[math.random(1,4)],15.0,unitx,unity,unitz)

local uDefID = Spring.GetUnitDefID(idUnitToBeSwallowed)
local unitHeight = UnitDefs[uDefID].height

Move(foodmagnet,y_axis,-50 - unitHeight, 11) -- expecting unit to be attached to foodmagnet from this point towards
Move(center,y_axis,-8, 11)
WaitForMove(center,y_axis)
Move(center,y_axis,-40, 7)
closeMouth()
for i=1,11 do
	randX=math.random(-25,25)
	randZ=math.random(-25,25)
	Spring.SpawnCEG("sworm_dirt",unitx+randX,unity,unitz+randZ,0,1,0,50,0)
	Sleep(100)
end
if (Spring.ValidUnitID (idUnitToBeSwallowed)) then -- this assures, that the unit in the mouth is alive until the very last moment
      Spring.DestroyUnit (idUnitToBeSwallowed,false,true) --this destroys the unit without wreckage. Knorke teached me that. If you want to know something, ask him. Its helpfull AND entertaining, to be his pupil.
end

while(true==Spring.UnitScript.IsInMove(center, y_axis)) do --spawns cegs and turns the 4fth segmet 
randX=math.random(-32,32)
randZ=math.random(-32,32)
Spring.SpawnCEG("sworm_dirt",unitx+randX,unity,unitz+randZ,0,1,0,32,0)
Sleep(300)
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
