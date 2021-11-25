using UpdateJulia
using Test

@testset "UpdateJulia.jl" begin

    printstyled("WARNING: this will both install out of date julia versions and change what the command `julia` points to.\n", color=Base.warn_color())
    printstyled("If all goes well, it will finish with the latest stable version of julia installed.\n", color=Base.warn_color())

    global v_latest = update_julia()
    @test v_latest == UpdateJulia.latest()
    @test v_latest >= v"1.6.4" && v_latest.prerelease == ()

    @static if Sys.iswindows()
        @test_skip "interactive windows installer"
    else
        @test update_julia("1.4", set_default=true) == v"1.4.2"
        @test update_julia("1.2", set_default=true) == v"1.2.0"
        @test update_julia("1.0.4") == v"1.0.4"
        @test update_julia("1.0.0") == v"1.0.0"
        global v10_latest = update_julia("1.0")
        @test v10_latest >= v"1.0.5" && v10_latest < v"1.1.0"
    end
    @test update_julia("1.7.0-rc1") == v"1.7.0-rc1"
    @test update_julia("1.7.0-rc3") == v"1.7.0-rc3"
    @test update_julia() == v_latest
    global v_nightly = update_julia("nightly")
    @test v_nightly >= v"1.8-DEV" && v_nightly > v_latest && v_nightly.prerelease == ("DEV",)

end

@testset "Preserve old versions" begin
    @test_nowarn UpdateJulia.test("julia", UpdateJulia.latest())
    @static if Sys.iswindows()
        @test_skip "interactive windows installer"
    else
        @test_nowarn UpdateJulia.test("julia-1.4", "1.4.2")
        @test_nowarn UpdateJulia.test("julia-1.2", "1.2.0")
        @test_nowarn UpdateJulia.test("julia-1.0.4", "1.0.4")
        @test_nowarn UpdateJulia.test("julia-1.0.0", "1.0.0")
        @test_nowarn UpdateJulia.test("julia-1.0", v10_latest)
    end
    @test_nowarn UpdateJulia.test("julia-1.7.0-rc1", "1.7.0-rc1")
    @test_nowarn UpdateJulia.test("julia-1.7.0-rc3", "1.7.0-rc3")
    @test_nowarn UpdateJulia.test("julia-1.7", "1.7.0-rc3")
    @test_nowarn UpdateJulia.test("julia", v_latest)
end
