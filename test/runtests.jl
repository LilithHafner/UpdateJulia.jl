using UpdateJulia
using Test
using Random
using Suppressor

@testset "fetch()" begin
    @test UpdateJulia.last_fetched[] == 0
    t0 = time()
    @test nothing === UpdateJulia.fetch()
    t1 = time()
    @test 0 < t0 < UpdateJulia.last_fetched[] <= t1
end

@testset "docstring" begin
    display(@doc update_julia)
    println()
end

@testset "prefer()" begin
    @test UpdateJulia.prefer(v"1.7.0", v"1.3.6")
    @test !UpdateJulia.prefer(v"1.7.0", v"1.7.0")
    @test !UpdateJulia.prefer(v"1.7.0-rc1", v"1.6.4")
    @test !UpdateJulia.prefer(v"17.7.0-rc1", v"1.6.4")
    @test UpdateJulia.prefer(v"17.7.0-rc1", v"1.6.4-DEV")
    @test UpdateJulia.prefer(v"17.7.0-rc1", v"2.6.4-DEV")
    @test !UpdateJulia.prefer(v"17.7.0-DEV", v"2.6.4-rc1")

    @test !UpdateJulia.prefer(missing, v"1.6.4")
    @test !UpdateJulia.prefer(missing, missing)
    @test UpdateJulia.prefer(v"1.7.0-rc1", missing)
end

@testset "latest()" begin
    @test UpdateJulia.latest() >= v"1.7.0"
    @test UpdateJulia.latest().prerelease == ()
    @test UpdateJulia.latest("1.1.") == v"1.1.1"
    @test UpdateJulia.latest("1.5") == v"1.5.4"
    @test UpdateJulia.latest("1.2") == v"1.2.0"
    @test UpdateJulia.latest("1.4.0-") == v"1.4.0-rc2"

    l = UpdateJulia.latest()
    for v in keys(UpdateJulia.versions[])
        @test v === l || UpdateJulia.prefer(l, v)
    end
end

@testset "version_of()" begin
    @test ismissing(UpdateJulia.version_of("this-should-not-be-a-valid-command-gj493fD62l4"))
end

@testset "versions[]" begin
    @test VersionNumber[v"0.1.2", v"0.3.1", v"0.5.0-rc2", v"0.6.0-pre.beta", v"0.7.0-beta",
        v"1.0.0", v"1.1.1", v"1.2.0-rc2", v"1.2.0-rc3", v"1.2.0", v"1.3.0-rc3", v"1.4.1",
        v"1.4.2", v"1.5.1", v"1.5.4", v"1.6.0-rc3", v"1.6.1", v"1.6.4", v"1.7.0-beta2",
        v"1.7.0-beta3"] ⊊ keys(UpdateJulia.versions[])
end

@testset "dry tests" begin
    # Basics
    @test update_julia(dry_run = true) == UpdateJulia.latest()
    @suppress_out @test UpdateJulia.update_julia("nightly", dry_run=true, verbose=false) ==
        UpdateJulia.update_julia(string(UpdateJulia.nightly_version[]), dry_run=true, verbose=false) ==
        UpdateJulia.nightly_version[]

    # Speed
    f() = @test @suppress update_julia("1.7.0-rc1", dry_run=true, verbose=false) == v"1.7.0-rc1"
    @elapsed f()
    @test .05 > @elapsed f()

    # Force fetch
    t_before_fetch = UpdateJulia.last_fetched[]
    @test update_julia("1.7.0-rc3", fetch = true, dry_run=true) == v"1.7.0-rc3"
    t_after_fetch = UpdateJulia.last_fetched[]
    @test 0 < t_before_fetch < t_after_fetch < time()
end

installed_versions = [UpdateJulia.latest(), UpdateJulia.nightly_version[],
    #UpdateJulia.latest("$(VERSION.major).$(VERSION.minor)"),
    v"1.6.3", v"1.6.4", v"1.6.2", v"1.5.0-rc2", v"1.5.0"]

function random_matrix_test(n)
    versions = vcat(UpdateJulia.nightly_version[], filter!(collect(keys(UpdateJulia.versions[]))) do x
        x >= (Sys.iswindows() ? v"1.5.0-rc2" : v"1.0.0")
    end)
    keywords = [
        # os_str => untested
        # arch => untested
        :prefer_gui => Sys.iswindows() ? [false] : [true, false],
        :fetch => Bool,
        # _v_url => untested
        # v => untested
        :migrate_packages => [true, false, :force],
        # url => untested
        # aliases => untested
        # :systemwide => Bool, unfortunatly, we can't do this trivially because userspace installs choose not to overwrite systemwide installs
        :install_location => [mktempdir(), mktempdir()], # Tuple sampling is missing in julia 1.0
        # bin => untested
        :dry_run => Bool,
        :verbose => Bool]

    seed = rand(UInt32)
    @testset "install" begin
        Random.seed!(seed)
        for _ in 1:n
            v = rand(versions)
            version = rand(["", "$(v.major)", "$(v.major).$(v.minor)", "$(v.major).$(v.minor).$(v.patch)", "$v"])
            kw = [k=>rand(source) for (k, source) in filter(x->rand(Bool), keywords)]
            v_inst = update_julia(version; kw...)
            @test v_inst === v || UpdateJulia.prefer(v_inst, v)
            if (:dry_run => true) ∉ kw
                push!(installed_versions, v_inst)
            end
        end
    end

    commands = unique(vcat("julia", [["julia-$(v.major).$(v.minor)", "julia-$v"]
        for v in vcat(UpdateJulia.nightly_version[], versions)]...))
    @test String["julia", "julia-1.8", "julia-1.5.1", "julia-1.6.2", "julia-1.5.0-rc2",
        "julia-1.7.0-rc1", "julia-1.7.0-beta2"] ⊊ commands
    Sys.iswindows() || @test String["julia-1.0", "julia-1.4",  "julia-1.3.1",
        "julia-1.3.0-rc3", "julia-1.3.0-alpha"] ⊊ commands


    @testset "check" begin
        for c in commands
            cvs = c[7:end]
            installed = filter(installed_versions) do x
                xs = string(x)
                xs == cvs && true # Exact match counts
                # If inexact, and cvs is a complete version string, don't match
                try string(VersionString(cvs)) == cvs && return false catch end
                # Otherwise match if prefix TODO migrate this to UpdateJulia.match
                startswith(xs, cvs)
            end
            actual = UpdateJulia.version_of(c)
            for i in installed
                if UpdateJulia.prefer(i, actual)
                    println("Running: $c")
                    println("Gives result: $actual")
                    println("Installed these compatible versions, in this order: $installed")
                    println("Specifically, $i, which is better than $actual")
                    @test false
                else
                    @test true
                end
            end
            if !ismissing(actual) && actual ∉ installed
                @warn "Unexpectedly found julia version $actual when running `$c -v`. Only installed $installed in testing."
            end
        end
    end
end

if ("CI" => "true") ∈ ENV
    printstyled("WARNING: this will both install out of date julia versions and change what the command `julia` points to.\n", color=Base.warn_color())
    printstyled("If all goes well, it will finish with the latest stable version of julia installed.\n", color=Base.warn_color())

    @testset "curated tests" begin
        # TODO add any failing tests from the random matrix here so that we have a readable,
        # reproducible, and efficient list of tests to start with.

        # default functionality
        @test update_julia() == UpdateJulia.latest()

        # nightly
        @test update_julia("nightly") == UpdateJulia.nightly_version[]

        # Begin PREVIOUSLY FAILED TESTS
        UpdateJulia.migrate_packages(VERSION, true) # Forcibly migrate packages to same directory
        # ERROR: ArgumentError: 'src' and 'dst' refer to the same file/dir.This is not supported.
        # End PREVIOUSLY FAILED TESTS

        # this version
        mm = "$(VERSION.major).$(VERSION.minor)"
        #@test update_julia(mm) == UpdateJulia.latest(mm) TODO if we need this, say why.

        # all these versions have to be at least 1.5.0-rc2 when windows archive became available
        # fallback for prefer_gui when not available
        # explicit systemwide
        # migrate packages
        Sys.iswindows() || println("requesting GUI...")
        @test update_julia("1.6.3", prefer_gui = !Sys.iswindows(), systemwide=false, migrate_packages=true) == v"1.6.3"
        # enusre there is something to overwrite
        @test UpdateJulia.version_of("julia-1.6") ∈ (VERSION == v"1.6.4" ? [v"1.6.3", v"1.6.4"] : [v"1.6.3"])
        # ensure that we actually have packages to migrate (this is not first to test fallback when we don't)
        project_toml = joinpath(first(Base.DEPOT_PATH), "environments", "v$mm", "Project.toml")
        if !isfile(project_toml)
            mkpath(dirname(project_toml))
            open(io -> write(io, "Statistics = \"10745b16-79ce-11e8-11f9-7d13ad32a3b2\"\n"), project_toml, "w")
        end
        # note that the systemwide instilation happens after the user instilation so that it can overwrite
        @test update_julia("1.6", systemwide=true, migrate_packages=true) == UpdateJulia.latest("1.6") > v"1.6.3"
        # ensure that migration actually happened
        @test isfile(joinpath(first(Base.DEPOT_PATH), "environments", "v1.6", "Project.toml"))
        # do overwrite
        @test UpdateJulia.version_of("julia-1.6") == UpdateJulia.latest("1.6")
        # failed migrate packages without force
        @test update_julia("1.6.2", migrate_packages=true) == v"1.6.2"
        # don't overwrite
        @test UpdateJulia.version_of("julia-1.6") == UpdateJulia.latest("1.6")

        # successfully migrate packages with force
        @test update_julia("1.5.0-", systemwide=true, migrate_packages=:force, verbose=true) == v"1.5.0-rc2"
        # Manifest.toml is not neccessarily created until we migrate with force.
        @test isfile(joinpath(first(Base.DEPOT_PATH), "environments", "v1.5", "Manifest.toml"))
        @test update_julia("1.5.0", systemwide=false, migrate_packages=:force, verbose=true) == v"1.5.0"
        @test UpdateJulia.@os(
            # windows doesn't use a bin, and its only the user path we are reordering.
            UpdateJulia.version_of("julia-1.5") == v"1.5.0",
            # can't overwite the old instilation because it was systemwide
            UpdateJulia.version_of("julia-1.5") == v"1.5.0-rc2",
            # system bin may come after user bin, so we have to specify the bin
            UpdateJulia.version_of("/usr/local/bin/julia-1.5") == v"1.5.0-rc2"
        )
        # but still successfully sets julia-1.5.0
        @test UpdateJulia.version_of("julia-1.5.0") == v"1.5.0"
    end

    # Get proper 1.5.0 installed so we don't trigger false positives in the matrix
    @test update_julia("1.5.0", systemwide=true) == v"1.5.0"

    @testset "random matrix" begin
        random_matrix_test(4) # Reproducible
    end

    random_matrix_test(15) # Random seed

    # Finish with latest version installed
    @test UpdateJulia.version_of("julia") == UpdateJulia.latest()
else
    @warn "Skipped installation tests!"
end

@testset "report path" begin
    println(ENV["PATH"])
    if Sys.iswindows()
        for systemwide in (true,false)
            println(strip(open(io -> read(io, String), `powershell.exe -nologo -noprofile -command "[Environment]::GetEnvironmentVariable(\"PATH\"$(systemwide ? "" : ", \"User\""))"`)))
        end
    end
end
