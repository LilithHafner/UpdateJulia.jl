# UpdateJulia

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://LilithHafner.github.io/UpdateJulia.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://LilithHafner.github.io/UpdateJulia.jl/dev)
[![Build Status](https://github.com/LilithHafner/UpdateJulia.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/LilithHafner/UpdateJulia.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/LilithHafner/UpdateJulia.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/LilithHafner/UpdateJulia.jl)

## Simple cross platform julia installer

Note: this is a julia package that requires julia 1.0 or higher to run. If you would like to install julia and don't have at least julia 1.0 installed already, please visit https://julialang.org/downloads/.

## Usage
```jl
]add UpdateJulia
using UpdateJulia
update_julia()
```

## Examples
```julia
julia> update_julia()
installing the latest version of julia (1.6.4) from 
https://julialang-s3.julialang.org/bin/.../1.6/julia-1.6.4-...
...
Success! `julia-1.6.4` & `julia-1.6` & `julia` now to point to 1.6.4

julia> update_julia("1.4")
installing julia 1.4.2 from https://julialang-s3.julialang.org/bin/.../1.4/julia-1.4.2-...
This version is out of date. The latest official release is 1.6.4
...
Success! `julia-1.4.2` & `julia-1.4` now to point to 1.4.2

help?> update_julia
search: update_julia

  update_julia(version::AbstractString="")

  Install the latest version of julia from https://julialang.org

  If version is provided, installs the latest version that starts with version. 
  If version == "nightly", then installs the bleeding-edge nightly version.

  Keywrod Arguments
  ≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡

    •    install_location = "..." the path to put installed binaries

    •    bin = "/usr/local/bin" the place to store links to the binaries

    •    os_str = "..." the string representation of the opperating system: 
         "linux", "mac", "winnt", or "freebsd".

    •    arch = "..." the string representation of the cpu archetecture: 
         "x86_64", "i686", "aarch64", "armv7l", or "powerpc64le".

    •    set_default = ... wheather to overwrite exisitng path 
         entries of higher priority (not supported on windows).

    •    prefer_gui = false wheather to prefer using the "installer" version 
         rather than downloading the "archive" version and letting UpdateJulia 
         automatically install it (only supported on windows).
```
The system dependent portions of info statements are replaced with `...`.

## Install locations

OS|System install|System bin|User install|User bin
-|-|-|-|-
unix   | `/opt/julias`   | `/usr/local/bin`| `~/.local/julias`         | `~/.local/bin`
mac    | `/Applications` | `/usr/local/bin`| `~/Applications`          | `~/.local/bin`
windows| `\Program Files`| automatically add install location to path | `~\AppData\Local\Programs`| automatically add install location to path

(For user instillation, make sure your bin location is on your path)

## Known issues (contributions welcome!)
- Cannot install nightly builds on ubuntu
- Does not automatically migrate `Project.toml` and run `Pkg.update()`.
- Management of multiple versions on Windows is annoying. As with other opperating systems, UpdateJulia will install new versions which can be reached via the commands `julia`, `julia-major.minor` (e.g. `julia-1.6`) or `julia-major.minor.patch` (e.g. `julia-1.6.4`), but because we append to the path variable, older installations will take precedence where there are name conflicts. You can manually edit your path variables by pressing windows+r enterting `rundll32 sysdm.cpl,EditEnvironmentVariables`, and pressing ok.
