module UpdateJulia

export update_julia

using JSON, Suppressor

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
    # Find source
    if version == "nightly"
        arch_dir = arch == "aarch64" ? "aarch64" : "x$(Sys.WORD_SIZE)"
        arch_append = arch == "aarch64" ? "aarch64" : "$(Sys.WORD_SIZE)"
        extension = Sys.isapple() ? "dmg" : (Sys.iswindows() ? "zip" : "tar.gz")
        url = "https://julialangnightlies-s3.julialang.org/bin/$os/$arch_dir/julia-latest-$os$arch_append.$extension"
        v = nothing
    else
        vs = latest(version)
        v = VersionNumber(vs)
        mm = "$(v.major).$(v.minor)"

        use_installer = false
        files = versions[vs]["files"]
        index = findfirst(x -> x["os"] == os && x["arch"] == arch && x["kind"] != "installer", files)
        if index === nothing
            index = findfirst(x -> x["os"] == os && x["arch"] == arch && x["kind"] == "installer", files)
            use_installer = true
        end
        index === nothing && error("No valid download for $vs matching $os and $arch")
        url = files[index]["url"]

        latest_v = VersionNumber(latest())
        version_color = isempty(v.build) ? (v == latest_v ? :green : :yellow) : :red
        printstyled("installing julia $v from $url\n", color = version_color)
        if v > latest_v
            printstyled("This version is un-released. The latest official release is $latest_v\n", color = version_color)
        elseif v < latest_v
            printstyled("This version is out of date. The latest official release is $latest_v\n", color = version_color)
        end

        if use_installer
            (@static Sys.iswindows() && v < v"1.5.0-rc2") ||  @warn "Unexpected use of a manual installer"
            println("An manual installer was available but not an archive. Lanuching the manual installer now:")
            download_delete(file->run(`$file`), url)
            return v
        end
    end

    # Install
    download_delete(url) do file
        @static if Sys.isapple()
            run(`hdiutil attach $file`)
            if v === nothing
                volumes = unique(first.(split.(filter(x->startswith(x, "Julia-"), readdir("/Volumes")))))
                ver(x) = VersionNumber(join(split(x, '-')[1:2],'-'))
                mx = maximum(ver.(volumes))
                volumes = filter(x->ver(x) == mx, volumes)
                @assert !isempty(volumes)
                v_mount = VersionNumber(last(volumes)[7:end])
            else
                v_mount = v
            end
        elseif Sys.iswindows()
            printstyled("=== Before line 80 ===\n", color=:purple)
            println(isfile("$file"))
            #run(`$file`)
            download = "$(homedir())\\AppData\\Local\\Programs\\Julia 1.6.4"
            run(`powershell.exe -nologo -noprofile -command "& { Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::ExtractToDirectory('$file', '$download'); }"`)
            println(isdir("$download"))
            printstyled("=== After line 80 ===\n", color=:purple)
        else
            mkpath("/opt/julias")
            run(`tar zxf $file -C /opt/julias`)
            download = "/opt/julias/julia-$v"
        end
        try
            @static if Sys.isapple()
                if v === nothing
                    length(volumes) > 1 && error("Can't decide which volume to choose from in /Volumes: $volumes. Perhaps detach them all and try again?")
                    mm = "$(v_mount.major).$(v_mount.minor)"
                    cp("/Volumes/Julia-$v_mount/Julia-$mm.app", "/Applications/Julia-$mm.app", force=true)
                else
                    cp("/Volumes/Julia-$v/Julia-$mm.app", "/Applications/Julia-$mm.app", force=true)
                end
                download = "/Applications/Julia-$mm.app/Contents/Resources/julia"
            end

            executable = joinpath(download, "bin", @static Sys.iswindows() ? "julia.exe" : "julia")
            v === nothing && (v = VersionNumber(strip(open(f->read(f, String), `$executable -v`))[15:end]))
            link(executable, "julia-$mm", v)
            @static if Sys.islinux() # Linux conventions call for installing patch releasess
                link(executable, "julia-$v", v) # paralell to eachother, while
            end # mac overwrites 1.6.1 with 1.6.4 which would break this.
            if set_as_default
                link(executable, "julia", v)
            end
        finally
            @static if Sys.isapple()
                run(`hdiutil detach /Volumes/Julia-$v_mount`)
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

function link(executable, command, version, bin=@static Sys.iswindows() ? "C:\\Windows\\System32" : "/usr/local/bin")
    # Because force is not available via Base.symlink
    run(`ln -sf $executable $(joinpath(bin, command))`)
    try
        test(command, version)
    catch x
        if x isa AssertionError
            printstyled("Failed to alias $command to Julia version $version. "*
            "Results of `which -a $command`: \"", color=Base.warn_color())
            open(`which -a $command`) do io
                printstyled(strip(read(io, String)), color=Base.info_color())
            end
            printstyled("\"\n", color=Base.warn_color())

            target = strip(open(x -> read(x, String), `which $command`))
            printstyled("Additionally linking to $target\n", color=Base.info_color())
            run(`ln -sf $executable $target`)

            test(command, version)
        else
            printstyled("Unexpected error, Giving up.\n", color=Base.error_color())
            printstyled("Perhaps $bin is not on your PATH?\n", color=Base.debug_color()) # TODO conditional gaurd on this
            rethrow()
        end
    end
    println("Linked $command to $version stored at $executable")
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
    # use download instead of Downloads.download for backwards compatability
    file = @suppress_err download(url)
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
