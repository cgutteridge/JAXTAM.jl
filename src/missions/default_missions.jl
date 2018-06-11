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
        _nicer_observation_dir
    )

    mission_nustar = MissionDefinition("nustar",
        "https://heasarc.gsfc.nasa.gov/FTP/heasarc/dbase/tdat_files/heasarc_numaster.tdat.gz",
        "mission_path",
        _nustar_observation_dir
    )

    return Dict(:nicer => mission_nicer, :nustar => mission_nustar)
end

# NICER Functions

function _nicer_observation_dir(obsid::String, mjd_day::String)
    date_time = string(Base.Dates.julian2datetime(parse(Float64, mjd_day) + 2400000.5))
    date_year = date_time[1:4]
    date_month = date_time[6:7]

    folder_path = string("/.nicer_archive/.nicer_$(date_year)$(date_month)a/obs/$(date_year)_$(date_month)/$obsid")

    return folder_path
end

function _nicer_obsdir_content()
    obsdirs = Array{String,1}()

    for (root, dirs, files) in Compat.walkdir(config(:nicer).path)
        append!(obsdirs, [root])
    end

    return obsdirs
end

# NuSTAR Functions

function _nustar_observation_dir(obsid::String)
    return string("/nustar/.nustar_archive/$obsid")
end