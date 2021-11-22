using UpdateJulia
using Test

@testset "UpdateJulia.jl" begin

    update_julia(v"1.2", set_as_default=true)
    update_julia(v"1.0.0")
    update_julia(v"1.0.5")
    update_julia(v"1.7.0-rc2")
    update_julia(v"1.7.0-rc1")
    update_julia(v"1.7.0-rc3")
    update_julia(v"1.6.4")
    update_julia(v"1.6.4", set_as_default=true)
    update_julia(v"1.6.4", set_as_default=true)
    @test true
    
end
