# Imports missions included in JAXTAM by default

include("mission_nicer.jl")
include("mission_nustar.jl")

"""
    _get_default_missions()

Function returning dictionary of some pre-set HEASARC missions,
using the `MissionDefinition` type. Name and heasarc url pre-set,
mission path is left as blank string

NB: JLD cannot save functions as of 0.5.0+, instead an expression
is saved, which then calls a function in the JAXTAM package. Thus send
a PR if you want another dir function to be added to JAXTAM
"""
function _get_default_missions()
    mission_nicer = MissionDefinition("nicer",
        "https://heasarc.gsfc.nasa.gov/FTP/heasarc/dbase/tdat_files/heasarc_nicermastr.tdat.gz",
        "mission_path",
        JAXTAM._nicer_observation_dir,
        JAXTAM._nicer_cl_dir,
        JAXTAM._nicer_uf_dir
    )

    mission_nustar = MissionDefinition("nustar",
        "https://heasarc.gsfc.nasa.gov/FTP/heasarc/dbase/tdat_files/heasarc_numaster.tdat.gz",
        "mission_path",
        JAXTAM._nustar_observation_dir,
        JAXTAM._nustar_cl_dir,
        JAXTAM._nustar_uf_dir
    )

    return Dict(:nicer => mission_nicer, :nustar => mission_nustar)
end