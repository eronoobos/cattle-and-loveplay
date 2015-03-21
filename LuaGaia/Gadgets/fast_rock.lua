function gadget:GetInfo()
  return {
    name      = "Cattle and Loveplay: Rock Modifier",
    desc      = "Modifies the terrain type definition of rock based on map option.",
    author    = "zoggop",
    date      = "February 2012",
    license   = "whatever",
    layer     = -3,
    enabled   = true
   }
end

-- synced
if gadgetHandler:IsSyncedCode() then

function gadget:GameStart()
	local mapOptions = Spring.GetMapOptions()
	if mapOptions then
		if Spring.GetMapOptions().fast_rock == "0" then
			Spring.SetTerrainTypeData(128, 1.0, 1.0, 1.0, 1.0)
			Spring.SetTerrainTypeData(0, 1.0, 1.0, 1.0, 1.0)
		end
	end
end

end
-- end synced