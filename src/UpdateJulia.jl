module UpdateJulia

export update_julia

using JSON, Suppressor

macro os(windows, apple=windows, freebsd=apple, linux=freebsd, other=linux)
    @static if Sys.iswindows()
        windows
    elseif Sys.isapple()
        apple
    elseif @static VERSION >= v"1.1" && Sys.isfreebsd()
        freebsd
    elseif Sys.islinux()
        linux
    else
        other
    end
end

"""
    update_julia(version::AbstractString="")

Install the latest version of julia from https://julialang.org

If `version` is provided, installs the latest version that starts with `version`.
If `version` == "nightly", then installs the bleeding-edge nightly version.

# Keywrod Arguments
- `install_location = "$(@os "$(homedir())\\AppData\\Local\\Programs" "/Applications" "/opt/julias")"` the path to put installed binaries
- `bin = "$(@os "$(homedir())\\AppData\\Local\\Programs\\julia-bin" "/usr/local/bin")"` the place to store links to the binaries
- `os_str = "$(@os "winnt" "mac" "freebsd" "linux")"` the string representation of the opperating system: "linux", "mac", "winnt", or "freebsd".
- `arch = "$(@static Sys.WORD_SIZE == 64 ? "x86_64" : "i686")"` the string representation of the cpu archetecture: "x86_64", "i686", "aarch64", "armv7l", or "powerpc64le".
- `set_default = $(@os "false" "(version == \"\")")`` wheather to overwrite exisitng path entries of higher priority (not supported on windows).
"""
function update_julia(version::AbstractString="";
    set_default = (@static Sys.iswindows() ? false : version==""),
    install_location = (@os "$(homedir())\\AppData\\Local\\Programs" "/Applications" "/opt/julias"),
    bin = (@os nothing "/usr/local/bin"),
    os_str = (@os "winnt" "mac" "freebsd" "linux"),
    arch = @static Sys.WORD_SIZE == 64 ? "x86_64" : "i686")

    v, url = v_url(version, os_str, arch)
    prereport(v, url)

    if @static Sys.iswindows() && v < v"1.5.0-rc2" && endswith(url, ".exe")
        println("An manual installer was available but not an archive. Lanuching the manual installer now:")
        download_delete(file->run(`$file`), url)#TODO BROKEN
        return v
    end

    executable = download_delete(url) do file
        extract(install_location, file, v)
    end

    @static if Sys.iswindows()
        # Windows doesn't use the bin system, instead adding each individual julia
        # instillation to path. This approach does a worse job of handling multiple versions
        # overwriting eachother, but Windows doesn't support symlinks for ordinary users,
        # and hardlinks to julia from different executables don't run, so while possible, it
        # would be much more work to use the more effective unix approach. For now, we
        # create version specific executables, add everything to path, and let the user deal
        # with ordering path entries if they want to.
        bin = join(split(executable, "\\")[1:end-1], "\\")
        add_to_path(bin)
    end

    commands = ["julia-$v", "julia-$(v.major).$(v.minor)"]
    set_default && push!(commands, "julia")

    for command in commands
        link(executable, bin, command * (@os ".exe" ""), set_default, v)
    end

    !set_default && push!(commands, "julia")
    report(commands, v)

    v
end

## Fetch ##
function v_url(version_str, os_str, arch_str)
    if version_str == "nightly"
        arch_dir = arch_str == "aarch64" ? "aarch64" : "x$(Sys.WORD_SIZE)"
        arch_append = arch_str == "aarch64" ? "aarch64" : "$(Sys.WORD_SIZE)"
        os_append = os_str == "winnt" ? "win" : os_str
        extension = @os "zip" "dmg" "tar.gz"

        nightly(), "https://julialangnightlies-s3.julialang.org/bin/$os_str/$arch_dir/julia-latest-$os_append$arch_append.$extension"
    else
        v = latest(version_str)

        options = filter(x -> x["os"] == os_str && x["arch"] == arch_str, versions[][v]["files"])
        isempty(options) && error("No valid download for $vs matching $os and $arch")
        sort!(options, by = x->x["kind"])

        v, first(options)["url"]
    end
end

const last_fetched = Ref(0.0)
const versions = Ref{Dict{VersionNumber, Dict{String, Any}}}()
function fetch(force=false)
    try
        if force || time() > last_fetched[] + 60*60 # 1 hour
            download_delete("https://julialang-s3.julialang.org/bin/versions.json") do file
                open(file) do io
                    versions[] = Dict(VersionNumber(k)=>v for (k, v) in JSON.parse(read(io, String)))
                    last_fetched[] = time()
                    nothing
                end
            end
        end
    catch
        if force || time() > last_fetched[] + 24*60*60
            rethrow()
        end
    end
end

function latest(prefix="")
    fetch()
    kys = collect(filter(v->startswith(string(v), prefix), keys(versions[])))
    isempty(kys) && throw(ArgumentError("No released versions starting with \"$prefix\""))
    sort!(kys)
    sort!(kys, by=x->isempty(x.prerelease))
    last(kys)
end

const nightly_version = Ref{VersionNumber}()
function nightly(url="https://raw.githubusercontent.com/JuliaLang/julia/master/VERSION")
    try
        contents = download_delete(url) do file
            open(file) do io
                read(io, String)
            end
        end
        nightly_version[] = VersionNumber(contents)
    catch
        nightly_version[]
    end
end

function prereport(v, url)
    if v == latest()
        printstyled("installing the latest version of julia ($v) from $url\n", color = :green)
    elseif "DEV" ∈ v.prerelease
        printstyled("installing julia $v from $url\n"*
        "This version is an expiremental development build nor reccomended for most users. "*
        "The latest official release is $(latest())\n", color = :red)
    else
        printstyled("installing julia $v from $url\n", color = :yellow)
        printstyled("This version is $(v > latest() ? "un-released" : "out of date"). "*
        "The latest official release is $(latest())\n", color = :yellow)
    end
end

## Download ##
function download_delete(f, url)
    # use download instead of Downloads.download for backwards compatability
    file = @suppress_err download(url)
    try
        f(file)
    finally
        rm("$file")
    end
end

## Extract ##
function extract(install_location, download_file, v)
    @static if Sys.iswindows()
        before = readdir(install_location)
        run(`powershell.exe -nologo -noprofile -command "& { Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::ExtractToDirectory('$download_file', '$install_location'); }"`)
        after = readdir(install_location)
        new = filter(x->startswith(x, "julia-"), setdiff(after, before))
        "julia-$v" ∉ new && length(new)==1 && mv(joinpath(install_location, first(new)), joinpath(install_location, "julia-$v"), force=true)

        joinpath(install_location, "julia-$v", "bin", "julia.exe")
    elseif Sys.isapple()
        run(`hdiutil attach $download_file`)
        volumes = filter(x->startswith(x, "Julia-$v"), readdir("/Volumes"))
        try
            cp("/Volumes/$(last(volumes))/Julia-$(v.major).$(v.minor).app", "$install_location/Julia-$v.app", force=true)
        finally
            for volume in volumes
                run(`hdiutil detach /Volumes/$volume`)
            end
        end
        "$install_location/Julia-$v.app/Contents/Resources/julia/bin/julia"
    else
        mkpath("/opt/julias")
        run(`tar zxf $download_file -C $install_location`)
        "/opt/julias/julia-$v/bin/julia"
    end
end

function add_to_path(bin)
    @assert Sys.iswindows()
    isdir(bin) || mkdir(bin)
    if !occursin(bin, open(io -> read(io, String), `powershell.exe -nologo -noprofile -command "[Environment]::GetEnvironmentVariable('PATH')"`))
        run(`powershell.exe -nologo -noprofile -command "& { \$PATH = [Environment]::GetEnvironmentVariable(\"PATH\", \"User\"); [Environment]::SetEnvironmentVariable(\"PATH\", \"\${PATH}$bin;\", \"User\"); }"`)
        println("Adding $bin to path. Shell/PowerShell restart may be required.")
    end
    occursin(bin, ENV["PATH"]) || (ENV["PATH"] *= "$bin;")
end

## Link ##
function link(executable, bin, command, set_default, v)
    link = joinpath(bin, command)
    symlink_replace(executable, link)

    if set_default && open(f->read(f, String), `$command -v`) != "julia version $v\n"
        link = strip(open(x -> read(x, String), `$(@os "which.exe" "which") $command`))
        printstyled("Replacing symlink @ $link\n", color=Base.info_color())
        symlink_replace(executable, link)
    end
end

function symlink_replace(target, link)
    # Because force is not available via Base.symlink
    @static if Sys.iswindows()
        #Technically this isn't a replacement at all...
        isfile(link) || run(`cmd.exe -nologo -noprofile /c "mklink /H $link $target"`)
    else
        run(`ln -sf $target $link`)
    end
end

## Test ##
function report(commands, version)
    successes = filter(c->test(c, version), commands)
    @assert !isempty(successes)
    printstyled("Success! \`$(join(successes, "\` & \`"))\` now to point to $version\n", color=:green)
end

function test(command, version)
    open(f->read(f, String), `$command -v`) == "julia version $version\n"
end

end
