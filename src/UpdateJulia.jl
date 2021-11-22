module UpdateJulia

export update_julia

using Downloads
using Test

"""
    update_julia(v::VersionNumber; set_as_default = false)

Install the specified version of julia and link `julia-MAJOR.MINOR` to it.

Optionally also link `julia`

# Examples
```julia-repl
julia> update_julia(v"1.6.1")
[system log...]
Success! julia-1.6 now to points to 1.6.1

julia> ;

shell> julia-1.6
               _
   _       _ _(_)_     |  Documentation: https://docs.julialang.org
  (_)     | (_) (_)    |
   _ _   _| |_  __ _   |  Type "?" for help, "]?" for Pkg help.
  | | | | | | |/ _` |  |
  | | |_| | | | (_| |  |  Version 1.6.1 (2021-04-23)
 _/ |\\__'_|_|_|\\__'_|  |  Official https://julialang.org/ release
|__/                   |

julia> ^d

shell> ^C

julia> update_julia(v"1.6.4", set_as_default=true)
[system log...]
Success! julia and julia-1.6 now to point to 1.6.4

julia> ;

shell> julia
               _
   _       _ _(_)_     |  Documentation: https://docs.julialang.org
  (_)     | (_) (_)    |
   _ _   _| |_  __ _   |  Type "?" for help, "]?" for Pkg help.
  | | | | | | |/ _` |  |
  | | |_| | | | (_| |  |  Version 1.6.4 (2021-11-19)
 _/ |\\__'_|_|_|\\__'_|  |  Official https://julialang.org/ release
|__/                   |

julia>
```
"""
function update_julia(v::VersionNumber; set_as_default = false)

    mm = "$(v.major).$(v.minor)"

    file = Downloads.download("https://julialang-s3.julialang.org/bin/mac/x64/$mm/julia-$v-mac64.dmg")
    try
        run(`hdiutil attach $file`)
        try
            cp("/Volumes/Julia-$v/Julia-$mm.app", "/Applications/Julia-$mm.app", force=true)
            # Because force is not available via Base.symlink
            run(`ln -sf /Applications/Julia-$mm.app/Contents/Resources/julia/bin/julia /usr/local/bin/julia-$mm`)
            @test open(f->read(f, String), `julia-$mm -v`) == "julia version $v\n"

            if set_as_default
                # Because force is not available via Base.symlink
                run(`ln -sf /Applications/Julia-$mm.app/Contents/Resources/julia/bin/julia /usr/local/bin/julia`)
                @test open(f->read(f, String), `julia -v`) == "julia version $v\n"
            end
        finally
            run(`hdiutil detach /Volumes/Julia-$v`)
        end
    finally
        rm("$file")
    end

    if set_as_default
        printstyled("Success! julia and julia-$mm now to point to $v\n", color=:green)
    else
        printstyled("Success! julia-$mm now to points to $v\n", color=:green)
    end
end

end
