using UpdateJulia
using Test

@testset "UpdateJulia.jl" begin

    printstyled("WARNING: this will both install out of date julia versions and change what the command `julia` points to.\n", color=Base.warn_color())
    printstyled("If all goes well, it will finish with the latest stable version of julia installed.\n", color=Base.warn_color())
    @test update_julia("1.4", set_as_default=true) == v"1.4.2"
    @test update_julia("1.2", set_as_default=true) == v"1.2.0"
    @test update_julia("1.0.5") == v"1.0.5"
    @test update_julia("1.0.0") == v"1.0.0"
    @test update_julia("1.7.0-rc1") == v"1.7.0-rc1"
    @test update_julia("1.7.0-rc3") == v"1.7.0-rc3"
    @test update_julia().prerelease == ()

end
