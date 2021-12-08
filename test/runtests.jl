using UpdateJulia
using Test

@testset "UpdateJulia.prefer" begin
    @test UpdateJulia.prefer(v"1.7.0", v"1.3.6")
    @test !UpdateJulia.prefer(v"1.7.0", v"1.7.0")
    @test !UpdateJulia.prefer(v"1.7.0-rc1", v"1.6.4")
    @test !UpdateJulia.prefer(v"17.7.0-rc1", v"1.6.4")
    @test UpdateJulia.prefer(v"17.7.0-rc1", v"1.6.4-DEV")
    @test UpdateJulia.prefer(v"17.7.0-rc1", v"2.6.4-DEV")

    @test !UpdateJulia.prefer(missing, v"1.6.4")
    @test !UpdateJulia.prefer(missing, missing)
    @test UpdateJulia.prefer(v"1.7.0-rc1", missing)
end

@testset "UpdateJulia.jl" begin

    display(@doc update_julia)
    println()
    #TODO optimize testing

    printstyled("WARNING: this will both install out of date julia versions and change what the command `julia` points to.\n", color=Base.warn_color())
    printstyled("If all goes well, it will finish with the latest stable version of julia installed.\n", color=Base.warn_color())

    global v_latest = update_julia()
    @test v_latest == UpdateJulia.latest()
    @test v_latest >= v"1.6.4" && v_latest.prerelease == ()

    @static if Sys.iswindows()
        @test_skip "interactive windows installer"
    else
        @test update_julia("1.4", set_default=true) == v"1.4.2" # TODO check that this reports succeeds on all three counts
        @test update_julia("1.2", set_default=true) == v"1.2.0"
        @test update_julia("1.0.4") == v"1.0.4"
        @test update_julia("1.0.0") == v"1.0.0"
        global v10_latest = update_julia("1.0")
        @test v10_latest >= v"1.0.5" && v10_latest < v"1.1.0"
    end

    @test update_julia("1.5.2", prefer_gui = !Sys.iswindows()) == v"1.5.2" # not supported. test fallback.
    @test update_julia("1.5.3", set_default=true, systemwide=true, verbose=true) == v"1.5.3" # TODO check that this reports succeeds on all three counts
    @test update_julia("1.5.1", set_default=true, systemwide=false) == v"1.5.1"
    @elapsed @test update_julia("1.7.0-rc1", dry_run = true) == v"1.7.0-rc1"
    @test .1 > @elapsed @test update_julia("1.7.0-rc1", dry_run = true) == v"1.7.0-rc1"
    @test update_julia("1.7.0-rc1", dry_run = true, verbose = false) == v"1.7.0-rc1"
    @test update_julia("1.7.0-rc1") == v"1.7.0-rc1"
    t_before_force_fetch = UpdateJulia.last_fetched[]
    @test update_julia("1.7.0-rc3", fetch = true) == v"1.7.0-rc3"
    t_after_force_fetch = UpdateJulia.last_fetched[]
    @test 0 < t_before_force_fetch < t_after_force_fetch < time()
    @test update_julia() == v_latest
    global v_nightly = update_julia("nightly")
    @test v_nightly >= v"1.8-DEV" && v_nightly > v_latest && v_nightly.prerelease == ("DEV",)
end

@testset "Preserve old versions" begin
    @static if Sys.iswindows()
        @test_skip "interactive windows installer & path management"
    else
        @test UpdateJulia.test("julia", UpdateJulia.latest())
        @test UpdateJulia.test("julia-1.4", "1.4.2")
        @test UpdateJulia.test("julia-1.2", "1.2.0")
        @test UpdateJulia.test("julia-1.0.4", "1.0.4")
        @test UpdateJulia.test("julia-1.0.0", "1.0.0")
        @test UpdateJulia.test("julia-1.0", v10_latest)
    end
    @test UpdateJulia.test("julia-1.5.1", "1.5.1")
    @test UpdateJulia.test("julia-1.5.2", "1.5.2")
    @test UpdateJulia.test("julia-1.5.3", "1.5.3")
    @test UpdateJulia.test("julia-1.7.0-rc1", "1.7.0-rc1")
    @test UpdateJulia.test("julia-1.7.0-rc3", "1.7.0-rc3")
    @static if Sys.iswindows()
        @test_skip "path management"
    else
        @test_skip UpdateJulia.test("julia-1.7", "1.7.0-rc3") # Depends on what the latest 1.7 release is
        @test_skip UpdateJulia.test("julia-1.5", "1.5.1") # Could be 1.5.1 or 1.5.3 depending on path order b.c. of coexisting systemwide and user installations
        @test update_julia("1.5") >= v"1.5.3"
        @test UpdateJulia.test("julia", v_latest)
    end
end
