using JAXTAM
using Test

const __testdir__  = abspath(@__DIR__, ".")
const __testconf__ = joinpath(__testdir__, "test_configs.jld2")
const __testmsn__  = joinpath(__testdir__, "heasarc/nicer/")

@testset "user_config.jl - Config function tests" begin
    @testset "Base config functions" begin
        @test JAXTAM._config_gen(__testconf__) == nothing
        @test JAXTAM._config_load(__testconf__) == Dict{Any,Any}(:_config_version => JAXTAM.__configver__)
        @test JAXTAM._config_edit(:test, "test", __testconf__) == nothing
        @test JAXTAM._config_rm(:test, __testconf__) == nothing
        @test JAXTAM._config_key_value(:_config_version, __testconf__) == JAXTAM.__configver__
    end

    @testset "User facing config functions" begin
        @test JAXTAM.config(config_path=__testconf__) == JAXTAM._config_load(__testconf__)
        @test JAXTAM.config(:test, "Stringie"; config_path=__testconf__) == Dict{Any,Any}(:_config_version => JAXTAM.__configver__, :test=>"Stringie")
        @test JAXTAM.config(:test; config_path=__testconf__) == "Stringie"
        @test JAXTAM.config_rm(:test; config_path=__testconf__) ==  Dict{Any,Any}(:_config_version => JAXTAM.__configver__)
    end

    @testset "User facing config default mission test" begin
        @test typeof(JAXTAM.config(:nicer, __testmsn__; config_path=__testconf__)[:nicer]) == JAXTAM.MissionDefinition
        @test JAXTAM.config(:nicer; config_path=__testconf__).path == __testmsn__
    end
end