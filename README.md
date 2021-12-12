# UpdateJulia

<!--[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://LilithHafner.github.io/UpdateJulia.jl/stable)-->
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

julia> update_julia("1.4")
installing julia 1.4.2
This version is out of date. The latest official release is 1.7.0
...
Success! `julia-1.4.2` & `julia-1.4` now to point to 1.4.1
v"1.4.2"
```

## Docstring
```
help?> update_julia
search: update_julia

  update_julia(version::AbstractString="")

  Install the latest version of Julia from https://julialang.org

  If version is provided, installs the latest version that starts with version. If version
  == "nightly", then installs the bleeding-edge nightly version.

  Keyword Arguments
  ≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡

  Behavior flags

    •  dry_run = false skip the actual download and instillation

    •  verbose = dry_run print the final value of all arguments

    •  migrate_packages = <upgrading to a Julia version without an existing environment>
       whether to copy Project.toml to the new version and run Pkg.update(). May be true,
       false, or :force. Only :force will replace an existing Project.toml

  Destination

    •  aliases = ["julia", "julia-$(v.major).$(v.minor)", "julia-$v"] which aliases to
       attempt to create for the installed version of Julia. Regardless, will not
       replace stable versions with less stable versions or newer versions with older
       versions of the same stability.

    •  systemwide = ... install for all users, false only installs for current user.

    •  install_location = systemwide ? "..." : "..." directory
       to put installed binaries

    •  bin = systemwide ? "..." : "..." directory to store links
       to the binaries

  Source

    •  os_str = "..." string representation of the operating system: "linux", "mac",
       "winnt", or "freebsd".

    •  arch = "..." string representation of the CPU architecture: "x86_64", "i686",
       "aarch64", "armv7l", or "powerpc64le".

    •  v = ... the VersionNumber to install

    •  url = ... URL to download that version from, if you explicitly set url, also
       explicitly set v lest they differ
```
The system dependent portions are replaced with `...`.

## Install locations

UpdateJulia will download Julia from [https://julialang-s3.julialang.org/bin/<os\>/\<arch\>/\<version\>/julia-\<version\>-\<os\>.\<extension\>](https://julialang.org/downloads/), unpack the contents of the download to an install location, and then link the executable in the install location to a symlink in a bin that should be on PATH. The exact install and bin locations depend both on operating system and on whether you choose to install Julia for the current user only `systemwide = false` or for every user on the system `systemwide = true`.

OS     | System install  | System bin                                | User install              | User bin
-------|-----------------|-------------------------------------------|---------------------------|----------
Unix   | `/opt`\*        | `/usr/local/bin`                          | `~/.local`\*              | `~/.local/bin`
Mac    | `/Applications` | `/usr/local/bin`                          | `~/Applications`          | `~/.local/bin`
Windows| `\Program Files`| automatically add install location to path| `~\AppData\Local\Programs`| automatically add install location to path

\* Unix has somewhat loose conventions for install locations. If you already have Julia installed in a location that falls within those conventions, UpdateJulia will install the new version of Julia right next to the one you are currently using.

## Known issues (contributions welcome!)
- Does not automatically migrate `Project.toml` and run `Pkg.update()`.
- Management of multiple versions on Windows is annoying. We have to parse your PATH and make some guesses. Hopefully this will work in most cases, but it could certianly fail on edge cases (e.g. if your path includes directories with `;` in their names, or already has multiple versions of julia on it in an unexpected order or in unexpected locations). If you run into such an edge case, please report them on this repository! You can also manually edit your path variables by pressing windows+r enterting `rundll32 sysdm.cpl,EditEnvironmentVariables`, and pressing ok.
