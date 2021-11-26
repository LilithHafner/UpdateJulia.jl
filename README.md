# UpdateJulia

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://LilithHafner.github.io/UpdateJulia.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://LilithHafner.github.io/UpdateJulia.jl/dev)
[![Build Status](https://github.com/LilithHafner/UpdateJulia.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/LilithHafner/UpdateJulia.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/LilithHafner/UpdateJulia.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/LilithHafner/UpdateJulia.jl)

```jl
]add UpdateJulia
using UpdateJulia
update_julia()
# installing the latest version of julia (1.6.4) from https://julialang-s3.julialang.org/bin/.../1.6/julia-1.6.4-...
# Success! `julia-1.6.4` & `julia-1.6` & `julia` now to point to 1.6.4
update_julia("1.4")
# installing julia 1.4.2 from https://julialang-s3.julialang.org/bin/.../1.4/julia-1.4.2-...
# This version is out of date. The latest official release is 1.6.4
# Success! `julia-1.4.2` & `julia-1.4` now to point to 1.4.2
```

## Known issues (contributions welcome!)
- Cannot install nightly builds on ubuntu
- Management of multiple versions on Windows is annoying. As with other opperating systems, UpdateJulia will install new versions which can be reached via the commands `julia`, `julia-major.minor` (e.g. `julia-1.6`) or `julia-major.minor.patch` (e.g. `julia-1.6.4`), but because we append to the path variable, older instillations will take precidence where there are name conflicts. You can manually edit your path varialbles by pressing windows+r enterting `rundll32 sysdm.cpl,EditEnvironmentVariables`, and pressing ok.
- On windows below version `1.5.0-rc2`, only a manual `.exe` installer is availible, not a `.zip` archive, so UpdateJulia cannot automatically install these old windows versions. Further, UpdateJulia's attempt to support these installers is broken.
