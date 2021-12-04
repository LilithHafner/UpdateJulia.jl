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
installing the latest version of julia: 1.7.0
...
Success! `julia-1.7.0` & `julia-1.7` & `julia` now to point to 1.7.0
v"1.7.0"

julia> update_julia("1.4", dry_run=true)
Dict{Symbol, Any} with 14 entries:
  :os_str           => "..."
  :dry_run          => true
  :version          => "1.4"
  :set_default      => false
  :force_fetch      => false
  :prefer_gui       => false
  :url              => "https://julialang-s3.julialang.org/bin/.../.../1.4/julia-1.4.2-..."
  :verbose          => true
  :v                => v"1.4.2"
  :bin              => "..."
  :systemwide       => ...
  :_v_url           => (v"1.4.2", "https://julialang-s3.julialang.org/bin/.../.../1.4/ju…")
  :install_location => "..."
  :arch             => "..."
installing julia 1.4.2
This version is out of date. The latest official release is 1.7.0
aborting before download & install
v"1.4.2"

help?> update_julia
search: update_julia

  update_julia(version::AbstractString="")

  Install the latest version of Julia from https://julialang.org

  If version is provided, installs the latest version that starts with version. If version
  == "nightly", then installs the bleeding-edge nightly version.

  Keyword Arguments
  ≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡

  Behavior flags

    •  set_default = (v == latest()) make 'julia' point to installed version.

    •  dry_run = false skip the actual download and instillation

    •  verbose = dry_run print the final value of all arguments

  Destination

    •  systemwide = true install for all users, false only installs for current user.

    •  install_location = systemwide ? "/Applications" : "/Users/x/Applications" directory
       to put installed binaries

    •  bin = systemwide ? "/usr/local/bin" : "/Users/x/.local/bin" directory to store links
       to the binaries

  Source

    •  os_str = "mac" string representation of the operating system: "linux", "mac",
       "winnt", or "freebsd".

    •  arch = "x86_64" string representation of the CPU architecture: "x86_64", "i686",
       "aarch64", "armv7l", or "powerpc64le".

    •  v = ... the VersionNumber to install

    •  url = ... URL to download that version from, if you explicitly set url, also
       explicitly set v lest they differ
```
The system dependent portions of info statements are replaced with `...`.

## Install locations

OS     | System install  | System bin                                | User install              | User bin
-------|-----------------|-------------------------------------------|---------------------------|----------
unix   | `/opt`          | `/usr/local/bin`                          | `~/.local   `             | `~/.local/bin`
mac    | `/Applications` | `/usr/local/bin`                          | `~/Applications`          | `~/.local/bin`
windows| `\Program Files`| automatically add install location to path| `~\AppData\Local\Programs`| automatically add install location to path

## Known issues (contributions welcome!)
- Cannot install nightly builds on ubuntu
- Does not automatically migrate `Project.toml` and run `Pkg.update()`.
- Management of multiple versions on Windows is annoying. As with other opperating systems, UpdateJulia will install new versions which can be reached via the commands `julia`, `julia-major.minor` (e.g. `julia-1.6`) or `julia-major.minor.patch` (e.g. `julia-1.6.4`), but because we append to the path variable, older installations will take precedence where there are name conflicts. You can manually edit your path variables by pressing windows+r enterting `rundll32 sysdm.cpl,EditEnvironmentVariables`, and pressing ok.
