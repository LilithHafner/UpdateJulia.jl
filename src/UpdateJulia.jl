module UpdateJulia

export update_julia

using JSON, Suppressor

## Version fetching ##
const last_fetched = Ref(0.0)
const versions = Ref{Dict{VersionNumber, Dict{String, Any}}}()
const nightly_version = Ref{VersionNumber}()
function fetch()
    download_delete("https://julialang-s3.julialang.org/bin/versions.json") do file
        open(file) do io
            versions[] = Dict(VersionNumber(k)=>v for (k, v) in JSON.parse(read(io, String)))
        end
    end
    try # theoretically this is typically wasteful, but it is simple, and it is empirically fast
        download_delete("https://raw.githubusercontent.com/JuliaLang/julia/master/VERSION") do file
            open(file) do io
                nightly_version[] = VersionNumber(read(io, String))
            end
        end
    catch
        if !isassigned(nightly_version)
            v = maximum(keys(UpdateJulia.versions[]))
            nightly_version[] = VersionNumber("$(v.major).$(v.minor+1).0-DEV")
        end
    end
    last_fetched[] = time()
    nothing
end

"""
    prefer(v1, v2)

Whether to prefer v1 over v2.

Not part of the public API.
"""
function prefer(v1::Union{VersionNumber, Missing}, v2::Union{VersionNumber, Missing})
    ismissing(v1) && return false
    ismissing(v2) && return true
    stable(v1) && !stable(v2) && return true
    !stable(v1) && stable(v2) && return false
    return v1 > v2
end
stable(v::VersionNumber) = isempty(v.prerelease)

function latest(prefix="")
    kys = collect(filter(v->startswith(string(v), prefix), keys(versions[])))
    isempty(kys) && throw(ArgumentError("No released versions starting with \"$prefix\""))
    first(sort!(kys, lt=prefer))
end

## Keyword argument helpers ##
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

function v_url(version_str, os_str, arch_str, prefer_gui)
    if version_str == "nightly"
        arch_dir = arch_str == "aarch64" ? "aarch64" : "x$(Sys.WORD_SIZE)"
        arch_append = arch_str == "aarch64" ? "aarch64" : "$(Sys.WORD_SIZE)"
        os_append = os_str == "winnt" ? "win" : os_str
        extension = @static Sys.iswindows() ?  (prefer_gui ? "exe" : "zip") : (@static Sys.isapple() ?  "dmg" : "tar.gz")

        nightly_version[], "https://julialangnightlies-s3.julialang.org/bin/$os_str/$arch_dir/julia-latest-$os_append$arch_append.$extension"
    else
        v = latest(version_str)

        options = filter(x -> x["os"] == os_str && x["arch"] == arch_str, versions[][v]["files"])
        isempty(options) && error("No valid download for \"$version_str\" matching os=\"$os_str\" and arch=\"$arch_str\"")
        sort!(options, by = x->x["kind"], rev=prefer_gui)

        v, first(options)["url"]
    end
end

## Main ##
"""
    update_julia(version::AbstractString="")

Install the latest version of Julia from https://julialang.org

If `version` is provided, installs the latest version that starts with `version`.
If `version == "nightly"`, then installs the bleeding-edge nightly version.

# Keyword Arguments
Behavior flags
- `dry_run = false` skip the actual download and instillation
- `verbose = dry_run` print the final value of all arguments
$(Sys.iswindows() ? "- `prefer_gui = false` if true, prefer using the \"installer\" version rather than downloading the \"archive\" version and letting UpdateJulia automatically install it" : "")

Destination
- `aliases = ["julia", "julia-\$(v.major).\$(v.minor)", "julia-\$v"]` which aliases to attempt to create for the installed version of Julia. Regardless, will not replace stable versions with unstable versions or newer versions with older versions of the same stability.
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
    fetch = time() > last_fetched[] + 60 * 15, # 15 minutes
    _v_url = ((fetch && UpdateJulia.fetch()); v_url(version, os_str, arch, prefer_gui)),
    v = first(_v_url),
    url = last(_v_url),
    aliases = ["julia", "julia-$(v.major).$(v.minor)", "julia-$v"],
    systemwide = !startswith(Base.Sys.BINDIR, homedir()),
    install_location = default_install_location(systemwide, v),
    bin = (@static Sys.iswindows() ? nothing : (systemwide ? "/usr/local/bin" : joinpath(homedir(), ".local/bin"))),
    dry_run = false,
    verbose = dry_run)

    @static VERSION >= v"1.1" && verbose && display(Base.@locals)
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
        bin = dirname(executable)
    end

    isdir(bin) || (println("Making path to $bin"); mkpath(bin))
    ensure_on_path(bin, systemwide, v)

    for command in aliases
        link(executable, bin, command * (@os ".exe" ""), systemwide, v)
    end

    report(union(aliases, ["julia", "julia-$(v.major).$(v.minor)", "julia-$v"]), v)

    v
end

## Prereport ##
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
        folder = last(volumes)
        try
            cp("/Volumes/$folder/Julia-$(v.major).$(v.minor).app", "$install_location/$folder.app", force=true)
        finally
            for volume in volumes
                run(`hdiutil detach /Volumes/$volume`)
            end
        end
        "$install_location/$folder.app/Contents/Resources/julia/bin/julia"
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

## Link ##
function ensure_on_path(bin, systemwide, v)
    @static if Sys.iswindows()
        # Long term solution
        path = open(io -> read(io, String), `powershell.exe -nologo -noprofile -command "[Environment]::GetEnvironmentVariable(\"PATH\"$(systemwide ? "" : ", \"User\""))"`)
        new_path = instert_path(path, bin, v)
        if path != new_path
            run(`powershell.exe -nologo -noprofile -command "[Environment]::SetEnvironmentVariable(\"PATH\", \"$new_path\"$(systemwide ? "" : ", \"User\"")); }"`)
            println("Adding $bin to $(systemwide ? "system" : "user") path. Shell/PowerShell restart may be required.")
        end

        # Short term solution
        ENV["PATH"] = instert_path(ENV["PATH"], bin, v)
    else
        # Long term solution
        if !occursin(bin, ENV["PATH"])
            printstyled("Please add $bin to path\n", color=Base.warn_color())
        end

        # Short term solution
        occursin(bin, ENV["PATH"]) || (ENV["PATH"] *= ":$bin")
    end
end

"""
    instert_path(path, entry, v)

Instert entry into path following these guidelines
- after versions `prefer`red over `v`
- before versions `v` is `prefer`red over
- skip operation if `entry` already meets above guidelines
- before existing entries for `v`
- as late as possible

Not part of the public API
"""
function instert_path(path, entry, v)
    @assert Sys.iswindows()
    println(path)
    entries = split(path, ";")
    println(entries)
    keys = map(entries) do entry
        l = skipmissing(try VersionNumber(m[2]) catch; missing end
            for m in eachmatch(r"julia(-|\\)([0-9.a-zA-Z\-+]*)\\\\", entry))
        isempty(l) ? missing : maximum(l)
    end
    println(keys)

    # after versions `prefer`red over `v`
    last_better = findlast(k->prefer(k, v), keys)
    last_better === nothing && (last_better = 0)
    println(last_better)

    # before versions `v` is `prefer`red over & before existing entries for `v`
    first_worse_or_eq = findfirst(k->!prefer(k, v), keys[last_better+1:end])
    first_worse_or_eq === nothing && (first_worse_or_eq = lastindex(entries)+1-last_better)
    first_worse_or_eq += last_better
    println(first_worse_or_eq)

    # skip operation if `entry` already meets above guidelines
    entry ∈ entries[last_better+1:first_worse_or_eq] && return path

    join(insert!(entries, first_worse_or_eq, entry), ";")
end

function link(executable, bin, command, systemwide, v)
    @static if Sys.iswindows()
        # Make a hard link from julia.exe to julia-1.6.4.exe within the same directory
        # because that hardlink won't work accross directories and a symlink requires
        # priviledges
        isfile(link) || run(`cmd.exe -nologo -noprofile /c mklink /H $link $target`)
    else
        # Make a link from the executable in the install location to a bin shared with other julia versions
        link = joinpath(bin, command)
        old = version_of(command)
        if !prefer(old, v) # If v is as good or better than old, a symlink is warrented
            run(`ln -sf $executable $link`) # Because force is not available via Base.symlink

            old = version_of(command)
            if prefer(v, old) # A worse symlink has higher precidence

                link = strip(open(x -> read(x, String), `$(@os "which.exe" "which") $command`))
                if !systemwide && !startswith(link, homedir())
                    printstyled("`julia` points to $link, not editing that file because this is not a systemwide instilation\n", color=Base.warn_color())
                else
                    printstyled("Replacing $link with a symlink to this instilation\n", color=Base.info_color())
                    run(`ln -sf $executable $link`) # Because force is not available via Base.symlink
                end

            end
        end
    end
end

## Test ##
function report(commands, v)
    successes = filter(c->version_of(c)==v, commands)
    @assert !isempty(successes)
    printstyled("Success! \`$(join(successes, "\` & \`"))\` now to point to $v\n", color=:green)
end

function version_of(command)
    try
        str = open(f->read(f, String), `$command -v`)
        @assert startswith(str, "julia version ")
        @assert endswith(str, "\n")
        VersionNumber(str[15:end-1])
    catch x
        missing
    end
end

end
