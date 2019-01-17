struct NICER <: Mission end

const nicer = NICER()

export nicer

_mission_name(::NICER) = "nicer"

_mission_master_url(::NICER) = "https://heasarc.gsfc.nasa.gov/FTP/heasarc/dbase/tdat_files/heasarc_nicermastr.tdat.gz"

function _obs_path_server(::NICER, obs_row::DataFrames.DataFrameRow{DataFrames.DataFrame})
    obsid      = obs_row[:obsid]
    date_time  = string(obs_row[:time])
    date_year  = date_time[1:4]
    date_month = date_time[6:7]

    folder_path = string("/.nicer_archive/.nicer_$(date_year)$(date_month)a/",
                            "obs/$(date_year)_$(date_month)/$obsid")

    return folder_path
end

function _obs_files_cl(::NICER, obs_row::DataFrames.DataFrameRow{DataFrames.DataFrame})
    cl_dir = joinpath(_obs_path_local(nicer, obs_row; kind=:download), "xti/event_cl/")

    cl_files = Dict(:XTI=>joinpath(cl_dir, "ni$(obs_row[:obsid])_0mpu7_cl.evt.gz"))

    return cl_files
end

_mission_good_e_range(::NICER) = (0.2, 12.0)

_mission_instruments(::NICER) = [:XTI]