"""
    _get_default_missions()

Function returning dictionary of some pre-set HEASARC missions,
using the `MissionDefinition` type. Name and heasarc url pre-set,
mission path is left as blank string
"""
function _get_default_missions()
    mission_nicer = MissionDefinition("nicer", "https://heasarc.gsfc.nasa.gov/FTP/heasarc/dbase/tdat_files/heasarc_nicermastr.tdat.gz", "")

    mission_nustar = MissionDefinition("nustar", "https://heasarc.gsfc.nasa.gov/FTP/heasarc/dbase/tdat_files/heasarc_numaster.tdat.gz", "")

    return Dict("nicer" => mission_nicer, "nustar" => mission_nustar)
end

function _nicer_observation_dir(obsid::String, mjd_day::String)
    date_time = string(Base.Dates.julian2datetime(parse(Float64, mjd_day) + 2400000.5))
    date_year = date_time[1:4]
    date_month = date_time[6:7]

    folder_path = string("/.nicer_archive/.nicer_$(date_year)$(date_month)a/obs/$(date_year)_$(date_month)/$obsid")

    return folder_path
end

function _nicer_observation_dir(obsid::Array, mjd_day::Array)
    if length(obsid) == 0
        warn("No obsid entered, `master_query` likely returned null")

        return
    end

    return _nicer_observation_dir(obsid[1], mjd_day[1])
end