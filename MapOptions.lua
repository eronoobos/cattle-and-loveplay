local options = {

	{
    key    = 'main_sect',
    name   = 'Main Settings',
    desc   = 'Major map options.',
    type   = 'section',
	},

	{
		key	= 'restrict_sand_building',
		name	= 'Restrict Building on Sand',
		desc	= 'Non-metal-extracting buildings sink into the sand.',
		type	= 'bool',
		section = 'main_sect',
		def	= 'true',
	},
	
	{
		key	= 'fast_rock',
		name	= 'Faster Movement on Rock',
		desc	= 'Ground unit movement on the rock is 125% of normal.',
		type	= 'bool',
		section = 'main_sect',
		def	= 'true',
	},
	
	{
		key	= 'sink_wrecks',
		name	= 'Wrecks Sink Into Sand',
		desc	= 'Wrecks slowly sink into the sand (not really--they lose health).',
		type	= 'bool',
		section = 'main_sect',
		def	= 'true',
	},
	
	{
		key	= 'sand_worms',
		name	= 'Sand Worms',
		desc	= 'Sand worms will eat your units on the sand.',
		type	= 'bool',
		section = 'main_sect',
		def	= 'true',
	},
	
	{
    key    = 'sworm_sect',
    name   = 'Sand Worm Settings',
    desc   = 'Settings for sand worms.',
    type   = 'section',
	},
	
	{
		key	= 'sworm_max_worms',
		name	= 'Maximum Worms',
		desc	= 'The maximum number of worms that can be active on the map at once.',
		type   = "number",
		section = 'sworm_sect',
		   def    = 1,
		   min    = 1,
		   max    = 8,
		   step   = 1,
	},
	
	{
		key	= 'sworm_base_worm_chance',
		name	= 'Base Spawn Chance',
		desc	= 'The percentage of cases that a worm will be spawned when a worm spawning event occurs. Each unit on the sand will at 1% to this.',
		type   = "number",
		section = 'sworm_sect',
		   def    = 50,
		   min    = 10,
		   max    = 100,
		   step   = 10,
	},
	
	{
		key	= 'sworm_worm_event_frequency',
		name	= 'Spawn Event Period',
		desc	= 'Seconds between potential worm spawning events.',
		type   = "number",
		section = 'sworm_sect',
		   def    = 30,
		   min    = 15,
		   max    = 300,
		   step   = 15,
	},
	
	{
		key	= 'sworm_base_worm_duration',
		name	= 'Base Lifespan',
		desc	= 'Seconds a worm lives if no units are within its sensing range',
		type   = "number",
		section = 'sworm_sect',
		   def    = 45,
		   min    = 15,
		   max    = 120,
		   step   = 15,
	},
	
	{
		key	= 'sworm_worm_speed',
		name	= 'Speed',
		desc	= 'How fast the worm moves under the sand.',
		type   = "number",
		section = 'sworm_sect',
		   def    = 1,
		   min    = 0.5,
		   max    = 2,
		   step   = 0.25,
	},
	
	{
		key	= 'sworm_worm_sensing_range',
		name	= 'Attack Range',
		desc	= 'How far away in elmos the worm can sense units.',
		type   = "number",
		section = 'sworm_sect',
		   def    = 1500,
		   min    = 500,
		   max    = 5000,
		   step   = 500,
	},

	{
		key	= 'sworm_eat_mex',
		name	= 'Eats Metal Extractors',
		desc	= 'If checked, sand worms will eat metal extractors.',
		type   = "bool",
		section = 'sworm_sect',
		def    = 'false',
	},
	
}

return options