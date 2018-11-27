# Imports missions included in JAXTAM by default

include("mission_nicer.jl")
include("mission_nustar.jl")

"""
    _get_default_missions()

Function returning dictionary of some pre-set HEASARC missions,
using the `MissionDefinition` type. Name and heasarc url pre-set,
mission path is left as blank string
"""
function _get_default_missions()
    mission_nicer = MissionDefinition("nicer",
        "https://heasarc.gsfc.nasa.gov/FTP/heasarc/dbase/tdat_files/heasarc_nicermastr.tdat.gz",
        "mission_path",
        JAXTAM._nicer_observation_dir,
        JAXTAM._nicer_cl_files,
        JAXTAM._nicer_uf_files,
        string(ENV["CALDB"], "/data/nicer/xti/cpf/rmf/nixtiref20170601v001.rmf"),
        "mission_path_web",
        0.3,
        12.0,
        ["XTI"]
    )

    mission_nustar = MissionDefinition("nustar",
        "https://heasarc.gsfc.nasa.gov/FTP/heasarc/dbase/tdat_files/heasarc_numaster.tdat.gz",
        "mission_path",
        JAXTAM._nustar_observation_dir,
        JAXTAM._nustar_cl_files,
        JAXTAM._nustar_uf_files,
        string(ENV["CALDB"], "/data/nustar/fpm/cpf/rmf/nuAdet3_20100101v002.rmf"),
        "mission_path_web",
        3.0,
        78.4,
        ["FPMA", "FPMB"]
    )

    return Dict(:nicer => mission_nicer, :nustar => mission_nustar)
end