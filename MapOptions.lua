local options = {

	{
    key    = '1_terrain_sect',
    name   = 'Terrain Settings',
    desc   = 'Settings affecting sand and rock.',
    type   = 'section',
	},

	{
		key	= 'restrict_sand_building',
		name	= 'Restrict Building on Sand',
		desc	= 'Non-metal-extracting buildings sink into the sand.',
		type	= 'bool',
		section = '1_terrain_sect',
		def	= 'true',
	},
	
	{
		key	= 'fast_rock',
		name	= 'Faster Movement on Rock',
		desc	= 'Ground unit movement on the rock is 125% of normal.',
		type	= 'bool',
		section = '1_terrain_sect',
		def	= 'true',
	},
	
	{
		key	= 'sink_wrecks',
		name	= 'Wrecks Sink Into Sand',
		desc	= 'Wrecks slowly sink into the sand (not really--they lose health).',
		type	= 'bool',
		section = '1_terrain_sect',
		def	= 'true',
	},

	{
		key  = 'Atmosphere',
		name = 'Atmosphere Settings',
		desc = 'Weather and time',
		type = 'section',
	},

	{
		key  = "timeofday",
		name = "Time of day",
		desc = "Night or day?",
		type = "list",
		def  = "day",
		section = 'Atmosphere',
		items = {
			{ key = "day",   name = "Day",   desc = "Day" },
			{ key = "night", name = "Night", desc = "Night" }
		},
	},
	
	{
    key    = '2_sworm_sect',
    name   = 'Sand Worm Settings',
    desc   = 'Settings for sand worms.',
    type   = 'section',
	},
	
	{
		key	= 'sand_worms',
		name	= 'Sand Worms',
		desc	= 'Sand worms will eat your units on the sand.',
		type	= 'bool',
		section = '2_sworm_sect',
		def	= 'true',
	},

	{
		key	= 'sworm_aggression',
		name	= 'Worm Aggression',
		desc	= 'How much do your units on the sand attract more worms?',
		type   = "number",
		section = '2_sworm_sect',
		   def    = 5,
		   min    = 1,
		   max    = 10,
		   step   = 1,
	},
	
	{
		key	= 'sworm_worm_speed',
		name	= 'Speed',
		desc	= 'How fast the worm moves under the sand.',
		type   = "number",
		section = '2_sworm_sect',
		   def    = 1,
		   min    = 0.5,
		   max    = 2,
		   step   = 0.25,
	},

	{
		key	= 'sworm_eat_mex',
		name	= 'Eats Metal Extractors',
		desc	= 'If checked, sand worms will eat metal extractors.',
		type   = "bool",
		section = '2_sworm_sect',
		def    = 'false',
	},

	{
		key	= 'sworm_eat_commander',
		name	= 'Eats Commanders',
		desc	= 'If checked, sand worms will eat commanders.',
		type   = "bool",
		section = '2_sworm_sect',
		def    = 'false',
	},
	
		{
		key  = 'Economy',
		name = 'Economy Settings',
		desc = '',
		type = 'section',
	},

	{
		key  = 'metal',
		name = 'Metal Production',
		desc = 'Metal production levels - How much metal is produced per second',
		type = 'list',
		section = 'Economy',
		def  = 'normal',
		items	= {
			{ key = 'low', name = "1.0 Low", desc = "Low, 1.0 metal per spot" },
			{ key = 'normal', name = "1.5 Default", desc = "Default, 1.5 metal per spot" },
			{ key = 'high', name = "2.0 High", desc = "High, 2.0 metal per spot" },
			{ key = 'superhigh', name = "3.0 Superhigh", desc = "Superhigh, 3.0 metal per spot" },
		},
	},

}

return options