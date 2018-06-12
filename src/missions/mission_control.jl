"""
    MissionDefinition

Type holding critical mission variables: mission name,
HEASARC mastertable url, and mission folder path
"""
mutable struct MissionDefinition
    name::String
    url::String
    path::String
    obs_path::Expr
end