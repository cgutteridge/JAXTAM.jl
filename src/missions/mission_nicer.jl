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

function _nicer_cl_dir(obs_row::DataFrames.DataFrame, root_dir::String)
    obs_dir = _clean_path_dots(_nicer_observation_dir(obs_row))

    return abspath(string(root_dir, obs_dir, "/xti/event_cl/"))
end

function _nicer_cl_files(obs_row::DataFrames.DataFrame, root_dir::String)
    cl_dir = _nicer_cl_dir(obs_row, root_dir)
    obsid  = obs_row[:obsid][1]

    return Tuple([abspath(string(cl_dir, "/ni$obsid\_0mpu7_cl.evt"))])
end

function _nicer_uf_dir(obs_row::DataFrames.DataFrame, root_dir::String)
    obs_dir = _clean_path_dots(_nicer_observation_dir(obs_row))

    return abspath(string(root_dir, obs_dir, "/xti/event_uf/"))
end

function _nicer_uf_files(obs_row::DataFrames.DataFrame, root_dir::String)
    uf_dir = _nicer_uf_dir(obs_row, root_dir)
    obsid  = obs_row[:obsid][1]
    
    instrument_data = (
        string(uf_dir, "/ni$obsid\_0mpu0_uf.evt"),
        string(uf_dir, "/ni$obsid\_0mpu1_uf.evt"),
        string(uf_dir, "/ni$obsid\_0mpu2_uf.evt"),
        string(uf_dir, "/ni$obsid\_0mpu3_uf.evt"),
        string(uf_dir, "/ni$obsid\_0mpu4_uf.evt"),
        string(uf_dir, "/ni$obsid\_0mpu5_uf.evt"),
        string(uf_dir, "/ni$obsid\_0mpu6_uf.evt")
    )

    return abspath.(instrument_data)
end