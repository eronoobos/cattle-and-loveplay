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
        colormap           = [[0.9 0.78 0.55 1.0	0 0 0 0.0]],
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
        colormap           = [[0.9 0.78 0.55 1.0	0 0 0 0.0]],
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
        airdrag            = 0.9,
        alwaysvisible      = false,
        colormap           = [[0 0 0 0.0  0.9 0.78 0.55 1.0  0 0 0 0.0]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 25,
        emitvector         = [[0, 0, 0]],
        gravity            = [[r-0.05 r0.05, 0 r0.05, r-0.05 r0.05]],
        numparticles       = 3,
        particlelife       = 8,
        particlelifespread = 160,
        particlesize       = [[d1]],
        particlesizespread = 0,
        particlespeed      = 0.0,
        particlespeedspread = 0.05,
        pos                = [[r-1 r1, r-1 r1, r-1 r1]],
        sizegrowth         = 0.25,
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
        airdrag            = 0.9,
        alwaysvisible      = false,
        colormap           = [[0 0 0 0.0  0.9 0.78 0.55 1.0  0 0 0 0.0]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 25,
        emitvector         = [[0, 1, 0]],
        gravity            = [[r-0.1 r0.1, 0 r0.1, r-0.1 r0.1]],
        numparticles       = 4,
        particlelife       = 8,
        particlelifespread = 80,
        particlesize       = [[d1]],
        particlesizespread = 0,
        particlespeed      = 0.05,
        particlespeedspread = 0.025,
        pos                = [[r-1 r1, r-1 r1, r-1 r1]],
        sizegrowth         = 0.25,
        sizemod            = 1.0,
        texture            = [[sworm_dust]],
      },
    },
  },
}