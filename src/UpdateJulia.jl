module UpdateJulia

export update_julia

using JSON

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

function update_julia(version::AbstractString=""; set_as_default = version=="")
    vs = latest(version)
    files = versions[vs]["files"]
    url = files[findfirst(x -> x["os"] == os && x["arch"] == arch, files)]["url"]
    v = VersionNumber(vs)
    latest_v = VersionNumber(latest())
    version_color = isempty(v.build) ? (v == latest_v ? :green : :yellow) : :red
    printstyled("installing julia $v from $url\n", color = version_color)
    if v > latest_v
        printstyled("This version is un-released. The latest official release is $latest_v\n", color = version_color)
    elseif v < latest_v
        printstyled("This version is out of date. The latest official release is $latest_v\n", color = version_color)
    end

    mm = "$(v.major).$(v.minor)"

    # use download instead of Downloads.download for backwards compatability
    download_delete(url) do file
        @static if Sys.isapple()
            run(`hdiutil attach $file`)
            cp("/Volumes/Julia-$v/Julia-$mm.app", "/Applications/Julia-$mm.app", force=true)
            download = "/Applications/Julia-$mm.app/Contents/Resources/julia"
        elseif Sys.iswindows() #nested ifs are worse than non-static branching.
            printstyled("=== Before line 80 ===\n", color=:purple)
            display(isfile($file))
            run(`$file`)
            printstyled("=== After line 80 ===\n", color=:purple)
        else
            mkpath("/opt/julias")
            run(`tar zxf $file -C /opt/julias`)
            download = "/opt/julias/julia-$v"
        end
        try
            link("$download/bin/julia", "julia-$mm", v)
            @static if Sys.islinux() # Linux conventions call for installing patch releasess
                link("$download/bin/julia", "julia-$v", v) # paralell to eachother, while
            end # mac overwrites 1.6.1 with 1.6.4 which would break this.
            if set_as_default
                link("$download/bin/julia", "julia", v)
            end
        finally
            @static if Sys.isapple()
                run(`hdiutil detach /Volumes/Julia-$v`)
            end
        end
    end

    if set_as_default
        printstyled("Success! julia and julia-$mm now to point to $v\n", color=:green)
    else
        printstyled("Success! julia-$mm now to points to $v\n", color=:green)
    end

    v
end

function link(source, command, version)
    # Because force is not available via Base.symlink
    run(`ln -sf $source /usr/local/bin/$command`)
    try
        test(command, version)
    catch
        printstyled("Failed to alias $command to Julia version $version. Results of `which -a $command`:\n", color=Base.warn_color())
        run(`which -a $command`)

        target = strip(open(x -> read(x, String), `which $command`))
        if target == "$command not found"
            printstyled("Perhaps /usr/local/bin/ is not in your paths (on mac your paths are located at /etc/paths), giving up.", color=Base.error_color())
            rethrow()
        else
            printstyled("Additionally linking to $target\n", color=Base.info_color())
            run(`ln -sf $source $target`)

            test(command, version)
        end
    end
end

function test(command, version)
    @assert open(f->read(f, String), `$command -v`) == "julia version $version\n"
end

last_fetched = 0
versions = nothing
function fetch(force=false)
    if force || time() > last_fetched + 1*60*60
        download_delete("https://julialang-s3.julialang.org/bin/versions.json") do file
            open(file) do io
                global versions = JSON.parse(read(io, String))
                global last_fetched = time()
                nothing
            end
        end
    end
end

function latest(prefix="")
    fetch()
    kys = collect(filter(v->startswith(v, prefix), keys(versions)))
    isempty(kys) && throw(ArgumentError("No available versions starting with \"$prefix\""))
    sort!(kys, by=VersionNumber)
    sort!(kys, by=x->isempty(VersionNumber(x).prerelease))
    last(kys)
end

function download_delete(f, url)
    file = download(url)
    try
        f(file)
    finally
        rm("$file")
    end
end

const os = if Sys.isapple()
    "mac"
elseif Sys.islinux()
    "linux"
elseif Sys.iswindows()
    "winnt"
elseif Sys.isbsd()
    "freebsd"
else
    error("Unknown OS")
end

arch = Sys.WORD_SIZE == 64 ? "x86_64" : "i686"
@warn "If your CPU archetecture is not $arch, you must manually change UpdateJulia.arch
Recommended values: \"x86_64\", \"i686\", \"aarch64\", \"armv7l\", and \"powerpc64le\""

end
