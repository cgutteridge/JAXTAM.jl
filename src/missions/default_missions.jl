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
        :(JAXTAM._nicer_observation_dir)
    )

    mission_nustar = MissionDefinition("nustar",
        "https://heasarc.gsfc.nasa.gov/FTP/heasarc/dbase/tdat_files/heasarc_numaster.tdat.gz",
        "mission_path",
        :(JAXTAM._nustar_observation_dir)
    )

    return Dict(:nicer => mission_nicer, :nustar => mission_nustar)
end


# NICER Functions

function _nicer_observation_dir(obs_row::DataFrames.DataFrame)
    obsid      = obs_row[:obsid][1]
    date_time  = string(obs_row[:time][1])
    date_year  = date_time[1:4]
    date_month = date_time[6:7]

    folder_path = string("/.nicer_archive/.nicer_$(date_year)$(date_month)a/",
                            "obs/$(date_year)_$(date_month)/$obsid")

    return folder_path
end

function _nicer_observation_dir(obsid::String, master_df::DataFrames.DataFrame)
    obs_row = @from row in master_df begin
        @where row.obsid == obsid
        @select row
        @collect DataFrame
    end

    return _nicer_observation_dir(obs_row)
end

function _nicer_observation_dir(obsid::String)
    return _nicer_observation_dir(obsid, master(:nicer))
end


# NuSTAR Functions

function _nustar_observation_dir(obs_row::DataFrames.DataFrame)
    obsid = obs_row[:obsid][1]
    return string("/nustar/.nustar_archive/$obsid")
end

function _nustar_observation_dir(obsid::String, master_df::DataFrames.DataFrame)
    obs_row = @from row in master_df begin
        @where row.obsid == obsid
        @select row
        @collect DataFrame
    end

    return _nustar_observation_dir(obs_row)
end

function _nustar_observation_dir(obsid::String)
    return _nustar_observation_dir(obsid, master(:nustar))
end