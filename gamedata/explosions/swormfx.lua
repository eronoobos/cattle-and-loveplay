return {
  ["sworm_dirt"] = {
    poof01 = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 1.0,
        alwaysvisible      = false,
        colormap           = [[0.9 0.72 0.44 1.0	0 0 0 0.0]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 25,
        emitvector         = [[0, 0, 0]],
        gravity            = [[r-0.05 r0.05, 0 r0.05, r-0.05 r0.05]],
        numparticles       = 5,
        particlelife       = 4,
        particlelifespread = 40,
        particlesize       = 10,
        particlesizespread = 0,
        particlespeed      = 3,
        particlespeedspread = 10,
        pos                = [[r-1 r1, r-1 r1, r-1 r1]],
        sizegrowth         = 0.8,
        sizemod            = 1.0,
        texture            = [[sworm_dirt]],
      },
    },
    poof02 = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 1.0,
        alwaysvisible      = false,
        colormap           = [[0.9 0.72 0.44 1.0	0 0 0 0.0]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 25,
        emitvector         = [[0, 1, 0]],
        gravity            = [[r-0.1 r0.1, 0 r0.1, r-0.1 r0.1]],
        numparticles       = 10,
        particlelife       = 4,
        particlelifespread = 20,
        particlesize       = 10,
        particlesizespread = 0,
        particlespeed      = 2,
        particlespeedspread = 1,
        pos                = [[r-1 r1, r-1 r1, r-1 r1]],
        sizegrowth         = 0.8,
        sizemod            = 1.0,
        texture            = [[sworm_dirt]],
      },
    },
  },
  ["sworm_dust"] = {
    poof01 = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 1.0,
        alwaysvisible      = false,
        colormap           = [[0 0 0 0.0  0.9 0.72 0.44 1.0  0 0 0 0.0]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 25,
        emitvector         = [[0, 0, 0]],
        gravity            = [[r-0.05 r0.05, 0 r0.05, r-0.05 r0.05]],
        numparticles       = 3,
        particlelife       = 4,
        particlelifespread = 40,
        particlesize       = 10,
        particlesizespread = 0,
        particlespeed      = 2,
        particlespeedspread = 10,
        pos                = [[r-1 r1, r-1 r1, r-1 r1]],
        sizegrowth         = 0.8,
        sizemod            = 1.0,
        texture            = [[sworm_dust]],
      },
    },
    poof02 = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 1.0,
        alwaysvisible      = false,
        colormap           = [[0 0 0 0.0  0.9 0.72 0.44 1.0  0 0 0 0.0]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 25,
        emitvector         = [[0, 1, 0]],
        gravity            = [[r-0.1 r0.1, 0 r0.1, r-0.1 r0.1]],
        numparticles       = 4,
        particlelife       = 4,
        particlelifespread = 20,
        particlesize       = 10,
        particlesizespread = 0,
        particlespeed      = 2,
        particlespeedspread = 1,
        pos                = [[r-1 r1, r-1 r1, r-1 r1]],
        sizegrowth         = 0.8,
        sizemod            = 1.0,
        texture            = [[sworm_dust]],
      },
    },
  },
  ["WORMSIGN_LIGHTNING"] = {
    bigswormglow = {
      class = [[CSimpleParticleSystem]],
      air = 1,
      water = 0,
      ground = 1,
      unit = 1,
      count = 1,
      properties = {
        useAirLos = 1,
        sizeGrowth = 0.0,
        sizeMod = 1.0,
        pos = [[0, 0, 0]],
        emitVector = [[0, 1, 0]],
        gravity = [[0,0,0]],
        colorMap = [[1.0 0.0 1.0 0.1  0 0 0 0.0]],
        texture = [[sworm_lightning_glow]],
        airdrag = 0.99,
        particleLife = 2,
        particleLifeSpread = 0,
        numParticles = 1,
        particleSpeed = 0.0,
        particleSpeedSpread = 0,
        particleSize = 1.5,
        particleSizeSpread = 0.0,
        directional = 1,
        emitRot = 0,
        emitRotSpread = 180,
      },
    },
    bigswormlightning = {
      class = [[CSimpleParticleSystem]],
      air = 1,
      water = 0,
      ground = 1,
      unit = 1,
      count = 1,
      properties = {
        useAirLos = 1,
        sizeGrowth = 0.0,
        sizeMod = 1.0,
        pos = [[0, 0, 0]],
        emitVector = [[0, 1, 0]],
        gravity = [[0,0,0]],
        colorMap = [[1.0 1.0 1.0 1.0  0 0 0 0.0]],
        texture = [[sworm_lightning]],
        airdrag = 0.99,
        particleLife = 2,
        particleLifeSpread = 0,
        numParticles = 1,
        particleSpeed = 0.0,
        particleSpeedSpread = 0,
        particleSize = 0.75,
        particleSizeSpread = 0.0,
        directional = 1,
        emitRot = 0,
        emitRotSpread = 180,
      },
    },
  },
  ["WORMSIGN_LIGHTNING_SMALL"] = {
    smallswormglow = {
      class = [[CSimpleParticleSystem]],
      properties = {
        sizeGrowth = 0.0,
        sizeMod = 1.0,
        pos = [[0, 0, 0]],
        emitVector = [[0, 1, 0]],
        gravity = [[0,0,0]],
        colorMap = [[1.0 0.0 1.0 0.1  0 0 0 0.0]],
        texture = [[sworm_lightning]],
        airdrag = 0.99,
        particleLife = 2.5,
        particleLifeSpread = 0,
        numParticles = 1,
        particleSpeed = 1,
        particleSpeedSpread = 0,
        particleSize = 1.1,
        particleSizeSpread = 0.0,
        directional = 1,
        emitRot = 0,
        emitRotSpread = 0,
      },
      air = 1,
      water = 0,
      ground = 1,
      unit = 1,
      count = 1,
    },
    smallswormlightning = {
      class = [[CSimpleParticleSystem]],
      properties = {
        sizeGrowth = 0.0,
        sizeMod = 1.0,
        pos = [[0, 0, 0]],
        emitVector = [[0, 1, 0]],
        gravity = [[0,0,0]],
        colorMap = [[1.0 1.0 1.0 1.0  0 0 0 0.0]],
        texture = [[sworm_lightning]],
        airdrag = 0.99,
        particleLife = 2.5,
        particleLifeSpread = 0,
        numParticles = 1,
        particleSpeed = 1,
        particleSpeedSpread = 0,
        particleSize = 0.55,
        particleSizeSpread = 0.0,
        directional = 1,
        emitRot = 0,
        emitRotSpread = 0,
      },
      air = 1,
      water = 0,
      ground = 1,
      unit = 1,
      count = 1,
    },
  },
  ["WORMSIGN_FLASH"] = {
    usedefaultexplosions = 0,
    groundflash = {
      flashSize = 100,
      flashAlpha = 0.35,
      ttl = 3,
      color = [[1.0, 0.5, 1.0]],
      useAirLos = 1,
    },
  },
  ["WORMSIGN_FLASH_SMALL"] = {
    usedefaultexplosions = 0,
    groundflash = {
      flashSize = 50,
      flashAlpha = 0.25,
      ttl = 3,
      color = [[1.0, 0.5, 1.0]],
    },
  },
}