using UpdateJulia
using Test

@testset "UpdateJulia.jl" begin

    printstyled("WARNING: this will both install out of date julia versions and change what the command `julia` points to.\n", color=Base.warn_color())
    printstyled("If all goes well, it will finish with the latest stable version of julia installed.\n", color=Base.warn_color())

    global v_latest = update_julia(prefer_gui = !Sys.iswindows())  # not supported. test fallback.
    @test v_latest == UpdateJulia.latest()
    @test v_latest >= v"1.6.4" && v_latest.prerelease == ()

    #=@static if Sys.iswindows()
        @test_skip "interactive windows installer"
    else=#
        @test update_julia("1.4", set_default=true) == v"1.4.2" # TODO check that this reports succeeds on all three counts
        @test update_julia("1.2", set_default=true) == v"1.2.0"
        @test update_julia("1.0.4") == v"1.0.4"
        @test update_julia("1.0.0") == v"1.0.0"
        global v10_latest = update_julia("1.0")
        @test v10_latest >= v"1.0.5" && v10_latest < v"1.1.0"
    #end
    @test update_julia("1.7.0-rc1") == v"1.7.0-rc1"
    @test update_julia("1.7.0-rc3") == v"1.7.0-rc3"
    @test update_julia() == v_latest
    @static if Sys.iswindows() || Sys.isapple()
        global v_nightly = update_julia("nightly")
        @test v_nightly >= v"1.8-DEV" && v_nightly > v_latest && v_nightly.prerelease == ("DEV",)
    else
        @test_broken "ubuntu nightly"
    end
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
    @test UpdateJulia.test("julia-1.7.0-rc1", "1.7.0-rc1")
    @test UpdateJulia.test("julia-1.7.0-rc3", "1.7.0-rc3")
    @static if Sys.iswindows()
        @test_skip "path management"
    else
        @test UpdateJulia.test("julia-1.7", "1.7.0-rc3")
        @test UpdateJulia.test("julia", v_latest)
    end
end
