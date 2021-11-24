using UpdateJulia
using Test

@testset "UpdateJulia.jl" begin

    printstyled("WARNING: this will both install out of date julia versions and change what the command `julia` points to.\n", color=Base.warn_color())
    printstyled("If all goes well, it will finish with the latest stable version of julia installed.\n", color=Base.warn_color())
    @test update_julia("1.4", set_as_default=true) == v"1.4.2"
    @test update_julia("1.2", set_as_default=true) == v"1.2.0"
    @test update_julia("1.0.5") == v"1.0.5"
    @test update_julia("1.0.0") == v"1.0.0"
    global v10_latest = update_julia("1.0")
    @test v10_latest >= v"1.0.5" && v10_latest < v"1.1.0"
    @test update_julia("1.7.0-rc1") == v"1.7.0-rc1"
    @test update_julia("1.7.0-rc3") == v"1.7.0-rc3"
    global v_latest = update_julia()
    @test v_latest == VersionNumber(UpdateJulia.latest())
    @test v_latest >= v"1.6.4" && v_latest.prerelease == ()

end

@testset "Preserve old versions" begin
    @test_nowarn UpdateJulia.test("julia", UpdateJulia.latest())
    @test_nowarn UpdateJulia.test("julia-1.4", "1.4.2")
    @test_nowarn UpdateJulia.test("julia-1.2", "1.2.0")
    Sys.islinux() && @test_nowarn UpdateJulia.test("julia-1.0.4", "1.0.4")
    Sys.islinux() && @test_nowarn UpdateJulia.test("julia-1.0.0", "1.0.0")
    @test_nowarn UpdateJulia.test("julia-1.0", v10_latest)
    Sys.islinux() && @test_nowarn UpdateJulia.test("julia-1.7.0-rc1", "1.7.0-rc1")
    Sys.islinux() && @test_nowarn UpdateJulia.test("julia-1.7.0-rc3", "1.7.0-rc3")
    @test_nowarn UpdateJulia.test("julia-1.7", "1.7.0-rc3")
    @test_nowarn UpdateJulia.test("julia", v_latest)
end
