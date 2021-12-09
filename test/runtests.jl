using UpdateJulia
using Test
using Random

@testset "fetch" begin
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
end

@testset "versions" begin
    @test VersionNumber[v"0.1.2", v"0.3.1", v"0.5.0-rc2", v"0.6.0-pre.beta", v"0.7.0-beta",
        v"1.0.0", v"1.1.1", v"1.2.0-rc2", v"1.2.0-rc3", v"1.2.0", v"1.3.0-rc3", v"1.4.1",
        v"1.4.2", v"1.5.1", v"1.5.4", v"1.6.0-rc3", v"1.6.1", v"1.6.4", v"1.7.0-beta2",
        v"1.7.0-beta3"] ⊊ keys(UpdateJulia.versions[])
end

@testset "dry tests" begin
    @test UpdateJulia.update_julia(string(UpdateJulia.nightly_version[]), dry_run=true) ==
        UpdateJulia.nightly_version[]
end

@testset "quick test" begin
    @test update_julia() == UpdateJulia.latest()
    v_nightly = update_julia("nightly")
    @test v_nightly >= v"1.8-DEV" && v_nightly > UpdateJulia.latest() && v_nightly.prerelease == ("DEV",)
end

#@testset "randomized tests" begin

    printstyled("WARNING: this will both install out of date julia versions and change what the command `julia` points to.\n", color=Base.warn_color())
    printstyled("If all goes well, it will finish with the latest stable version of julia installed.\n", color=Base.warn_color())

    versions = vcat(UpdateJulia.nightly_version[], filter!(collect(keys(UpdateJulia.versions[]))) do x
        x >= (Sys.iswindows() ? v"1.5.0-rc2" : v"1.0.0")
    end)
    keywords = [
        # os_str => untested
        # arch => untested
        # prefer_gui => untested
        :fetch => Bool,
        # _v_url => untested
        # v => untested
        # url => untested
        # aliases => untested
        :systemwide => Bool,
        :install_location => (mktempdir(), mktempdir()),
        # bin => untested
        :dry_run => Bool,
        :verbose => Bool]

    installed_versions = []
    #@testset "install" begin
    #    Random.seed!()
        for _ in 1:10
            v = rand(versions)
            version = rand(["", "$(v.major)", "$(v.major).$(v.minor)", "$(v.major).$(v.minor).$(v.patch)", "$v"])
            kw = [k=>rand(source) for (k, source) in filter(x->rand(Bool), keywords)]
            v_inst = update_julia(version; kw...)
            @test v_inst === v || UpdateJulia.prefer(v_inst, v)
            if (:dry_run => true) ∉ kw
                push!(installed_versions, v_inst)
            end
        end
    #end

    commands = unique(vcat("julia", [["julia-$(v.major).$(v.minor)", "julia-$v"]
        for v in vcat(UpdateJulia.nightly_version[], versions)]...))
    @test String["julia", "julia-1.0", "julia-1.4", "julia-1.8",  "julia-1.3.1",
        "julia-1.5.1", "julia-1.6.2", "julia-1.3.0-rc3", "julia-1.7.0-rc1",
        "julia-1.3.0-alpha", "julia-1.7.0-beta2"] ⊊ commands

    @testset "check" begin
        for c in commands
            installed = filter(x->startswith(string(x), c[7:end]), installed_versions)
            actual = UpdateJulia.version_of(c)
            for i in installed
                println(installed)
                println(join([c, i, actual], ", "))
                @test !UpdateJulia.prefer(i, actual)
            end
            if !ismissing(actual) && actual ∉ installed
                @warn "Unexpectedly found julia version $actual when running `$c -v`. Only installed $installed in testing."
            end
        end
    end

    @static if Sys.iswindows()
        @test_skip "interactive windows installer"
    else
        @test update_julia("1.4") == v"1.4.2" # TODO check that this reports succeeds on all three counts
        @test update_julia("1.2") == v"1.2.0"
        @test update_julia("1.0.4") == v"1.0.4"
        global v10_latest = update_julia("1.0")
        @test v10_latest >= v"1.0.5" && v10_latest < v"1.1.0"
        @test update_julia("1.0.0") == v"1.0.0"
    end

    #Dry run
    @elapsed @test update_julia("1.7.0-rc1", dry_run = true) == v"1.7.0-rc1"
    @test .1 > @elapsed @test update_julia("1.7.0-rc1", dry_run = true) == v"1.7.0-rc1"

    #Force fetch
    t_before_force_fetch = UpdateJulia.last_fetched[]
    @test update_julia("1.7.0-rc3", fetch = true) == v"1.7.0-rc3"
    t_after_force_fetch = UpdateJulia.last_fetched[]
    @test 0 < t_before_force_fetch < t_after_force_fetch < time()

    #Finish with latest
    @test update_julia() == UpdateJulia.latest()
#end

@testset "report path" begin
    println(ENV["PATH"])
    if Sys.iswindows()
        for systemwide in (true,false)
            println(strip(open(io -> read(io, String), `powershell.exe -nologo -noprofile -command "[Environment]::GetEnvironmentVariable(\"PATH\"$(systemwide ? "" : ", \"User\""))"`)))
        end
    end
end
