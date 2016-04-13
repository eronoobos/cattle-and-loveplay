- smooth out bits of tiling dune texture that break vehicle movement
- elongate slopes up to higher rock parts to allow vehicle passage
- put a variation layer in to the rock layers
- add spires in more planned locations
- maybe instead of giant glow to create slope up to rock, just smudge entrances and exits or make a painted entrance/exit layer

---

- move starting metal spots - / start location to northern high part of rock
- add metal spot to very center
- change light to 45 degrees (and possibly brighten)
- rotate sand dune bump map (make a copy and put it in Arrakis climate folder) 90 degrees
- add some noise (0.005 maybe) to cliffs for better transition
- make sure cliffs have enough score (no sand lip)
- experiment with morphologically eroding heightmap dunes so that they look more like dunes

---

- fix ramp to the place you forgot (done!)

- don't bother with "cliff" attribute - / texture
- draw rock/sand borders based on "rock 55" and "rock 100"
- on top of this use the green dunes --> yellow sand thing for those parts that are above rock, and spread it a little to make the transition less stark (also do this for low rock edges)
- use a harder brush for rock spice, so it doesn't have all those speckles
- do away with height-burning the sand spice

---

v1 --> v2

- make mapoption - / gadget that blocks building on sand
- create "steep rock" (as opposed to "cliff") based on a slopemap generated in wilbur to make nonbuildable areas on rock more visible
- put updated rocknoise layer into for-l3dt heightmap
- change metal spot appearance (not bright fucking orange)

---

v2 --> v3

- finish widget (or gadget?) that puts invalid build commands in the right places, so that AIs can play the map
  - reDir table needs to have a maximum allowable footprint attribute, calculated by getting multiple slope cross-sections of different-sized squares. either that or by simply making several reDir tables of different cell sizes, and which table to use is chosen based on how large the footprint of the building is (the footprint should always be smaller than the cell size)
- smooth ramps of start rocks and in the obviously unbalanced places
- move rocks/spires around to remove absurd bottlenecks in places
- put a couple of metal spots on the large southern rock?
- find some way to make metal spots look like dark sand without appearing as a "spot" of color
  * alternatively the metal spots could be odd-looking bits of rock jutting out of the sand to create an irregular platform
- shift some of the middle-southern metal spots to be more accessible from the large center rock, which should have a third ramp in the south-center to make it a more appealing place to build
- make starting rocks slightly larger and/or less ungainly to build on
- rocks should go all the way down to 10 (min height of sand dunes) within their borders, to get rid of those strange-looking sand ramps
- make spires kbot accessible (try using brush that fades up in value with random roundness/angle, and then adding cloud noise on top of that)
- if you don't want metal to be rocks poking out of the dunes, then they could just be painted directly onto the unlit texture (tinting and dark streaks)
- increase the scale of the dune bump-mapping in hopes of it not looking like vertical lines

scripting notes
- check if player is AI (if not, just block the order)
- resolve isOccupied issues (if something is occupied, the order that would be redirected there is disallowed, which is a problem) or remove

ongoing notes
- smooth the little impassable bits on the kbot spires (see screens)
- maybe kbot spires should just be redone with 70 -> 255 fg-bg fading, and slightly harder edges so that they can only be climbed one way
- round (blur) rock edges
- get rid of northern geothermal
- make air platforms in sothern corners?

- reshape that little nub that's basically impassable on one of the middle rocks
- make sure edges of rocks are smooth (1px or 2px box blur?)
- balance dunes
- move some of the metal spots close to the kbot hills
- reshape southern ramp so that the rock's buildable areas a bit bigger (make the ramp jut out a bit), and possibly expand the rock in general

- put the sand/rock border between "sand mask 1" and "sand mask 2" (the rock goes too far out onto the sand now)
- make sure geothermals are included (and line up with texture roughly)
- use a different (more prominent) bump map for steep cliffs
- make rough rock just as fast as rock in smd terraintypes
- radially fade the geothermal cracks a bit more
- make cliff (shallow cliff) a bit more brown than normal rock

---

two problems:
1) rock edges are STILL jagged in some places (in the heightmap)
2) texture edge between rock and sand is too large in some places, and too small in others
  - possible fix: overlay the dune layer on top of the finished heightmap with "difference" blending
  
some lesser issues:
- bump maps for steep cliff and for flat rock suck
- geothermal cracks could be significantly smaller (mounds 1/2 size and more round in shape, cracks only within mounds and 1/4 the thickness)
- "rough rock" could be quite a bit smaller (if it is to clearly indicate where things can be built)

---

idea for resolving bump map transitions: there are 4 levels of rock, so use something like this as a scheme:

A
AB (50% A, 50% B)
BC
C

- the current rock bump map is great, so keep that (as A)
- B should be the "rough rock" texture (also nice looking)

---

- rocks are correct in NW and short in SE because of nearest-neighbor resizing, i think. use bicubic, sharpen, and dissolve (and/or possibly posterize). compare to original attributes to confirm
- sand could be a bit more yellow (it looks as if it's been bleached)

- for effeciency, the gadget's isNotValid table could be transferred to the widget at runtime
- could use image for the big circled X
- need to fix the dragons teeth problem (they don't sink)
- add ignoreplacementrestriction to the isNotValid table creation checks

- it doesn't make any sense that the ambient light is blue if the sky is orange

- bring back little dune bump map, but make them diagonal (not vertical or horizontal). the spice should just have slightly taller little dunes

- increase the right-side cliffs just a bit more, maybe 100% expand 5px radius from the fullsize vehicle block map
- use slightly larger rock layer, too (the shallow edges with the sand are too sandy)
- do not blur rock noise at edges
- revert to 0.3 bump strength on spice and 0.2 bump strength on rippled sand
- use properly bump-mapped ambient

---

- if you wanted to be super dorky, make a sand-dune formation gadget based on in-game wind to create star dunes, and also have rocks make a difference in the shapes

---

- fix luarules and luaui and you're done!
  - include ignoreplacement restriction in check
  - fix redirect matrix so it neither blocks factories nor kills build orders. perhaps a secondary and tertiary redirect should be stored and used if the first is blocked
  - fix dragons teeth problem (maybe use some kind of test to see if the unit is actually sinking; if not, blow it up)
  - fix the build facing being reset by movectrl

---  

- make backup of redirect_matrix.lua on the macbook! (the only copy is currently there)

---

before releasing v5 w- / sand worms (- / means it's done):

- / fix worm not attaching unit to foodmagnet
- / fix the worm registering sworm units as targets--just use an isWorm[unitID] table
- / fix worms getting stuck in rock concavities (maybe some sort of concavity test could be called whenever the redirection table is used)
	- actually this could be precalculated and written into the redirection table. i need to have some kind of concavity code, 1-9 meaning concave in that grid-direction, and maybe 10-13 meaning more or less flat along one axis. or maybe it would be better simply to denote what directions of approach are not valid. or maybe if it's concave at all, i should just redirect to a different sand cell entirely.
	- at the moment the trouble is that the redirection table moves its vector target to a place it can't traverse to, only teleport to (rock is between the old sand position and the new one)
		- maybe i should make some sort of vector addition/subtraction thing in response to a short-range rock search in the cardinal directions?
- / instead of a fixed time limit, start it with a time limit, and then add time if there are nearby units (wormAnger or some such thing), so that worm will keep attacking until you get off the rock
- / introduce true worm movement by splitting wormMove() into wormDirect() to set wormVector and wormMove() to move it every game frame
	- this will make for better wormsigns, and might also allow some and ripples
- / make worm not eat air units (and possibly not hover either)
- / work out kinks in swallow animation--at the moment the units don't go far enough into the gullet. should perhaps depend upon unit height.
- / make dirt ceg less shitty
- / lightning ceg shouldn't rely on BA texture
- / turn some of the configuration variables into map options
- / add sand worm text to start alert widget
- / worm realtime obstacle avoidance: running into the edge of the map should reverse its favored side
- / fix LOD (it's a brown square) http://springrts.com/wiki/Trouble-shooting_s3o_units#Disappearing_Unit
- / make worm table more elegant (worm[wID].x etc)
	- or turn it into a class
- / worms should not target air units (or anything else that doesn't touch the ground like hovers?)
- / use a proper way to get game options into the gadgets and widgets (see http://springrts.com/wiki/Modoptions.lua#Reading )
- / make wormsign notifier not rely on marker add point and remove point
- add sounds
	- "worm sign" alarm
	- / roar that they make when coming out of the sand
	- / lightning sound
	- / rumbling sound
	- sand shifting sound
- / lightning should be useAirLos
- / get rid of stupid penis-ghost somehow (groundOffset in unit defs?)
- / worm should not move during attack pause
- worms should not target the same thing (how?)
- / worm radar:
	- / lightning icon w/o outline, should alpha-flash in bright red or pink
	- / distinguish between radar signs and LOS signs. if it's an LOS sign, it shouldn't be visible except as an arrow off-screen
	- / play an alarm ( a not so annoying one )
- / make option to make worms not eat mexes
- bug: if unit is destroyed in the middle of swallow, bad things happen and worm doesn't die
- scale worm according to unit size? could be done by making several versions in upspring, maybe diameter 64 through diameter 256, going up by 64.
- use movectrl instead of attaching
- once the above four are resolved, it can finally be released i think

---

september 7, 2013:

- / audio alarm only if the worm is seen for the first time (i.e. it's in a totally new location)
- / flashing lightning marker only if the worm is off screen or if the view distance is far away
	- / and only if it's in radar LOS and *not* in visual LOS
- dust only in visual LOS (it seems to be showing even if it's in radar los)

---

v6 -> v7

- / random unit to spawn near makes clumps of low-value units more likely to attract the worm, which is too easy to exploit. random location, and a base lifespan that's ETA to next target
- / when worm 'dies', the next spawn event should be delayed, so that a new worm doesn't spawn instantly across the map
- / unit value should matter more
- / scrap concept of sensing range
- / more units moving across sand should escalate everything, even in extreme cases adding more worms
- / worms get stuck on things, take too long to arrive. need a way to spawn nearish to units without prioritizing clumps. ah, a grid.
- / keep track of units eaten, and use a belly limit, so that worms will go away and move on to new targets soon after
- / move to intercept target, not directly to target
- / prioritize targets that are standing still or moving towards worm, i.e., can be caught
- / smaller attack range, more frequent checks for units in range
- / sounds for ground lightning: quiet lightning
- / sounds for air lightning: all of the long thunder rumbles
- / use sounds.lua
- / convert tdf cegs to lua
- / convert tga bitmaps to png
- / if it hasn't eaten anything in say 90 seconds, worm should "die". targetting time and eta should be irrelevant
- / more frequent worm spawn events with more worm anger
- / maximum 3 worms
- / prevent worms from eating commanders
- / randomize worm speed slightly
- / open mouth wider (80 degrees?)
- / unit that aren't getting eaten get stuck if right under emerging worm. either push them away, or eat them, too
- / limit second unit to eat by footprint size
- / instead of first and second meal, just an array of units to eat and an array of units to push away. even ten units may be eaten if the meal is the right size
- / worm bites off pieces of units
- / hide unit pieces as they're bitten off
- / create four different worm sizes, the current being the smallest. worm spawns large enough to eat the largest unit on the sand
- / damage unit by halving current health every time
- / add unified bulges with heightmapfunc
- / only spawn cegs on sand
- / do not target or eat units near an emerged worm, probably easiest by getting units in radius from each emerged worm and excluding them
- / emerge at least the worm's radius and a bit more from the rock
- / limit bites to 3 or 4, and shatter multiple pieces at once if necessary
- / use astar instead of dynamicrockavoid (keep worms from moving too near to the rock) see https://github.com/GloryFish/lua-astar/
- / fix broken unit icons
- / prevent worms from eating units, by passing unitdefids and unitids from the gadget
- / use native radar instead of widget radar? by making an invisible unit move around the map as the underground worm?
- / maybe only emerged worm should be attackable?
- / silence weapon fire of unit being eaten
- / localize all Spring and math functions
- / spawn worms near boxes far from the other worms
- / spawn worms along the target box's average movement vector
- / make sandType table, not single variable (to be used on Desert Needles and others)
- / remove fast_rock and associated map options
- / make gui_start_alerts use sandType table
- / make gui_start_alerts find groundTypes more efficiently, a la the nearestSand fallback in sand_worms
- / don't do wormtarget or wormdirect to worms that have an emergedID
- / add fallback AI build order redirection (using similar system of nearestSand fallback)
- / sink units when construction has begun
- / check if unit footprints are on sand
- / make sure both fallbacks work (wormredir and ai redir)
- / fix hide/reveal underworm
- / fix worm not being able to eat certain units: armpw, armak. Was problem with the keys of the unitsToSwallow table being distance (therefore the only unit that showed up was underworm)
- / make default to not sink wrecks
- / make start alerts persist a small while after the game starts, if the start type is something other than choose in-game
- / change style of start position warning
- / use displaylists in start alerts
- / remove ripple signs
- / rename valid_node_func to neighbor_node_func
- / distinguish between little and medium lightning with sounds
- / branching lightning? and lightning arcing over underworm
- build helper requests isNotValid, sand restrict gadget provides on demand
- update build pic
- remove worm radar
- worm radar highlights w/ crosshair in minimap and edge arrows when new worm appears or when one of your units is being eaten. this can all be found out without passing info from gadget.
- add nighttime dust and dirt ceg bitmaps
- delete unecessary files
- fix unitscript errors (check if piece is valid before exploding it?)
- smooth transition from underworm to emerged if possible
- make lightning more efficient & less dumb looking by either using projectiles (beamlaser), or with opengl lines?
- BAD IDEA?: rather than movectrl, wait until the worms lips are most of the way out of the sand, and then evaluate what is inside and eat it. use a four-lipped worm to form a cage from with units can't escape. the model must have lips halfway open, so that when the mouth is fully open, the colvols are at 45 degrees or so