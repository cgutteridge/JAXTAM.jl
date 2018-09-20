"""
    MissionDefinition

Type holding mission specific variables and functions, either set manually or
pulled from the `default_missions.jl`.
"""
mutable struct MissionDefinition
    name::String
    url::String
    path::String
    path_obs::Function
    path_cl::Function
    path_uf::Function
    path_rmf::String
    path_web::String
    good_energy_max::Number
    good_energy_min::Number
    instruments::Array
end