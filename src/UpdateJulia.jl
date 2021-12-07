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

function default_install_location(systemwide, v)
    default = if systemwide
        @os "\\Program Files" "/Applications" "/opt"
    else
        (joinpath(homedir(), (@os "AppData\\Local\\Programs" "Applications" ".local")))
    end
    current = dirname(dirname(
        @static Sys.isapple() ? dirname(dirname(dirname(Base.Sys.BINDIR))) : Base.Sys.BINDIR))

    if systemwide == startswith(Base.Sys.BINDIR, homedir())
        default # installing at a different systemwide level
    elseif current == default || (@static Sys.isunix() && (@static !Sys.isapple() && (
                                ( systemwide && startswith(current, "/opt/julia")) ||
                                (!systemwide && startswith(current, homedir()   )) )))
        current # current is already a conventional location
    elseif v === nothing
        "$default\" or \"$current"
    else
        println("julia-$VERSION is currently installed in $current. Install julia-$v in $default instead? Y/n")
        response = readline(stdin)
        if isempty(response) || uppercase(first(response)) == 'Y'
            default
        elseif uppercase(first(response)) == 'N'
            current
        else
            error("Unknown input: $response. Expected 'y' or 'n'.")
        end
    end
end

"""
    update_julia(version::AbstractString="")

Install the latest version of Julia from https://julialang.org

If `version` is provided, installs the latest version that starts with `version`.
If `version == "nightly"`, then installs the bleeding-edge nightly version.

# Keyword Arguments
Behavior flags
$(Sys.iswindows() ? "" : "- `set_default = (v == latest())` make 'julia' point to installed version.")
$(Sys.iswindows() ? "- `prefer_gui = false` if true, prefer using the \"installer\" version rather than downloading the \"archive\" version and letting UpdateJulia automatically install it" : "")
- `dry_run = false` skip the actual download and instillation
- `verbose = dry_run` print the final value of all arguments

Destination
- `systemwide = $(!startswith(Base.Sys.BINDIR, homedir()))` install for all users, `false` only installs for current user.
- `install_location = systemwide ? "$(default_install_location(true, nothing))" : "$(default_install_location(false, nothing))"` directory to put installed binaries
$(Sys.iswindows() ? "" : "- `bin = systemwide ? \"/usr/local/bin\" : \"$(joinpath(homedir(), ".local/bin"))\"` directory to store links to the binaries")

Source
- `os_str = "$(@os "winnt" "mac" "freebsd" "linux")"` string representation of the operating system: "linux", "mac", "winnt", or "freebsd".
- `arch = "$(string(Base.Sys.ARCH))"` string representation of the CPU architecture: "x86_64", "i686", "aarch64", "armv7l", or "powerpc64le".

- `v = ...` the `VersionNumber` to install
- `url = ...` URL to download that version from, if you explicitly set `url`, also explicitly set `v` lest they differ
"""
function update_julia(version::AbstractString="";
    os_str = (@os "winnt" "mac" "freebsd" "linux"),
    arch = string(Base.Sys.ARCH),
    prefer_gui = false,
    force_fetch = false,
    _v_url = v_url(version, os_str, arch, prefer_gui, force_fetch),
    v = first(_v_url),
    url = last(_v_url),
    set_default = (@static Sys.iswindows() ? false : v==latest()),
    systemwide = !startswith(Base.Sys.BINDIR, homedir()),
    install_location = default_install_location(systemwide, v),
    bin = (@static Sys.iswindows() ? nothing : (systemwide ? "/usr/local/bin" : joinpath(homedir(), ".local/bin"))),
    dry_run = false,
    verbose = dry_run)

    @static VERSION >= v"1.1" && verbose && display(Base.@locals)
    @static Sys.iswindows() && set_default && (println("set_default=true not supported for windows"); set_default=false)
    @static Sys.iswindows() && bin !== nothing && (println("bin not supported for windows"); bin=nothing)

    prereport(v) #TODO should this report more info?

    if @static Sys.iswindows() && endswith(url, ".exe")
        prefer_gui || printstyled("A GUI installer was available but not an archive.\n", color=Base.warn_color())
        dry_run && (println("aborting before download & install"); return v)
        download_delete(url) do file
            mv(file, file*".exe")
            try
                printstyled("Lanuching GUI installer now:\n", color=:green)
                run(`$file.exe`)
            finally
                mv(file*".exe", file)
            end
        end
        return v
    elseif prefer_gui
        printstyled("An archive was available but not a GUI. Installing the archive now.\n", color=Base.warn_color())
    end


    dry_run && (println("aborting before download & install"); return v)
    executable = try
        download_delete(url) do file
            extract(install_location, file, v)
        end
    catch x
        if x isa Base.IOError && systemwide && occursin("permission denied", x.msg)
            printstyled("Permission denied attempting to perform a systemwide instilation."*
                "Try again with `systemwide=false` or run with elevated permissions.\n",
                color=Base.error_color())
        end
        rethrow()
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
    end

    isdir(bin) || (println("Making path to $bin"); mkpath(bin))
    ensure_on_path(bin, systemwide)

    commands = ["julia-$v", "julia-$(v.major).$(v.minor)"]
    set_default && push!(commands, "julia")

    for command in commands
        link(executable, bin, command * (@os ".exe" ""), set_default, systemwide, v)
    end

    union!(commands, ["julia"])
    report(commands, v)

    v
end

## Fetch ##
function v_url(version_str, os_str, arch_str, prefer_gui, force_fetch)
    if version_str == "nightly"
        arch_dir = arch_str == "aarch64" ? "aarch64" : "x$(Sys.WORD_SIZE)"
        arch_append = arch_str == "aarch64" ? "aarch64" : "$(Sys.WORD_SIZE)"
        os_append = os_str == "winnt" ? "win" : os_str
        extension = @static Sys.iswindows() ?  (prefer_gui ? "exe" : "zip") : (@static Sys.isapple() ?  "dmg" : "tar.gz")

        nightly(), "https://julialangnightlies-s3.julialang.org/bin/$os_str/$arch_dir/julia-latest-$os_append$arch_append.$extension"
    else
        v = latest(version_str, force_fetch)

        options = filter(x -> x["os"] == os_str && x["arch"] == arch_str, versions[][v]["files"])
        isempty(options) && error("No valid download for \"$version_str\" matching os=\"$os_str\" and arch=\"$arch_str\"")
        sort!(options, by = x->x["kind"], rev=prefer_gui)

        v, first(options)["url"]
    end
end

const last_fetched = Ref(0.0)
const versions = Ref{Dict{VersionNumber, Dict{String, Any}}}()
function fetch(force)
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

function latest(prefix="", force=false)
    fetch(force)
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

function prereport(v)
    if v == latest()
        printstyled("installing the latest version of julia: $v\n", color = :green)
    elseif "DEV" ∈ v.prerelease
        printstyled("installing julia $v\n"*
        "This version is an expiremental development build not reccomended for most users. "*
        "The latest official release is $(latest())\n", color = :red)
    else
        printstyled("installing julia $v\n", color = :yellow)
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
    isdir(install_location) || (println("Making path to $install_location"); mkpath(install_location))

    @static if Sys.isapple()
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
        # We have to extract to a temporary location instead of directly into
        # install_location because we don't know what the name of the extracted folder is.
        # Specifically, on nightlies, it is (today) julia-db1d2f5891. We need to return the
        # executable location which entails determining this extension.
        extract_location = mktempdir()
        @static if Sys.iswindows()
            run(`powershell.exe -nologo -noprofile -command "& { Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::ExtractToDirectory('$download_file', '$extract_location'); }"`)
        else
            run(`tar zxf $download_file -C $extract_location`)
        end
        folders = readdir(extract_location)
        @assert length(folders) == 1
        folder = first(folders)
        folder == "julia-$v" || startswith(folder, "julia-") && v.prerelease == ("DEV",) ||
            @warn "Unexpected install folder: $folder"

        mv(joinpath(extract_location, folder), joinpath(install_location, folder), force=true)
        rm(extract_location)

        joinpath(install_location, folder, "bin", @os "julia.exe" "julia")
    end
end

function ensure_on_path(bin, systemwide)
    @static if Sys.iswindows()
        # Long term solution
        if !occursin(bin, open(io -> read(io, String), `powershell.exe -nologo -noprofile -command "[Environment]::GetEnvironmentVariable('PATH')"`))
            run(`powershell.exe -nologo -noprofile -command "& { \$PATH = [Environment]::GetEnvironmentVariable(\"PATH\"$(systemwide ? "" : ", \"User\"")); [Environment]::SetEnvironmentVariable(\"PATH\", \"\${PATH};$bin\"$(systemwide ? "" : ", \"User\"")); }"`)
            println("Adding $bin to $(systemwide ? "system" : "user") path. Shell/PowerShell restart may be required.")
        end

        # Short term solution
        occursin(bin, ENV["PATH"]) || (ENV["PATH"] *= ";$bin")
    else
        # Long term solution
        if !occursin(bin, ENV["PATH"])
            printstyled("Please add $bin to path\n", color=Base.warn_color())
        end

        # Short term solution
        occursin(bin, ENV["PATH"]) || (ENV["PATH"] *= ":$bin")
    end
end

## Link ##
function link(executable, bin, command, set_default, systemwide, v)
    link = joinpath(bin, command)
    symlink_replace(executable, link)

    if set_default && open(f->read(f, String), `$command -v`) != "julia version $v\n"
        link = strip(open(x -> read(x, String), `$(@os "which.exe" "which") $command`))
        if !systemwide && !startswith(link, homedir())
            printstyled("`julia` points to $link, not editing that file because this is not a systemwide instilation\n", color=Base.warn_color())
        else
            printstyled("Replacing $link with a symlink to this instilation\n", color=Base.info_color())
            symlink_replace(executable, link)
        end
    end
end

function symlink_replace(target, link)
    # Because force is not available via Base.symlink
    @static if Sys.iswindows()
        #Technically this isn't a replacement at all...
        isfile(link) || run(`cmd.exe -nologo -noprofile /c mklink /H $link $target`)
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
