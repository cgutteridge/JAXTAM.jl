# NICER Mission Definition
# Good energy range: 0.3 - 12 keV

"""
    _nicer_observation_dir(obs_row::DataFrames.DataFrame)

Uses a row from the NICER master table to find the HEASARC server-side
path of the observation
"""
function _nicer_observation_dir(obs_row::DataFrames.DataFrame)
    obsid      = obs_row[:obsid][1]
    date_time  = string(obs_row[:time][1])
    date_year  = date_time[1:4]
    date_month = date_time[6:7]

    folder_path = string("/.nicer_archive/.nicer_$(date_year)$(date_month)a/",
                            "obs/$(date_year)_$(date_month)/$obsid")

    return folder_path
end

"""
    _nicer_observation_dir(obsid::String, master_df::DataFrames.DataFrame)

Takes in observation `obsid` and NICER master dataframe, calls the main
`nicer_observation_dir(obs_row::DataFrames.DataFrame)` function with the
`obs_row` of `obsid`
"""
function _nicer_observation_dir(obsid::String, master_df::DataFrames.DataFrame)
    obs_row = filter(row -> row[:obsid] == obsid, master_df)

    return _nicer_observation_dir(obs_row)
end

"""
    _nicer_observation_dir(obsid::String)

Takes in observation `obsid`, lowas NICER master dataframe, calls the
`_nicer_observation_dir(obsid::String, master_df::DataFrames.DataFrame)` function
"""
function _nicer_observation_dir(obsid::String)
    return _nicer_observation_dir(obsid, master(:nicer))
end

"""
    _nicer_cl_dir(obs_row::DataFrames.DataFrame, root_dir::String)

Returns the `/xti/event_cl/` dir for a NICER observation, using the `obs_row`
and `root_dir` (from `_nicer_observation_dir()`) of the observation
"""
function _nicer_cl_dir(obs_row::DataFrames.DataFrame, root_dir::String)
    obs_dir = _clean_path_dots(_nicer_observation_dir(obs_row))

    return abspath(string(root_dir, obs_dir, "/xti/event_cl/"))
end

"""
    _nicer_cl_files(obs_row::DataFrames.DataFrame, root_dir::String)

Returns the path of the cleaned (`ni\$(obsid)_0mpu7_cl.evt`) file for the
observation of `obs_row` with `rood_dir`
"""
function _nicer_cl_files(obs_row::DataFrames.DataFrame, root_dir::String)
    cl_dir = _nicer_cl_dir(obs_row, root_dir)
    obsid  = obs_row[:obsid][1]

    return Tuple([abspath(string(cl_dir, "/ni$(obsid)_0mpu7_cl.evt"))])
end

"""
    _nicer_uf_dir(obs_row::DataFrames.DataFrame, root_dir::String)

Returns the `/xti/event_uf/` dir for a NICER observation, using the `obs_row`
and `root_dir` (from `_nicer_observation_dir()`) of the observation
"""
function _nicer_uf_dir(obs_row::DataFrames.DataFrame, root_dir::String)
    obs_dir = _clean_path_dots(_nicer_observation_dir(obs_row))

    return abspath(string(root_dir, obs_dir, "/xti/event_uf/"))
end

"""
    _nicer_uf_files(obs_row::DataFrames.DataFrame, root_dir::String)

Returns the path of the raw (`ni\$(obsid)_0mpu\$(i)_uf.evt`) file for the
observation of `obs_row` with `rood_dir`
"""
function _nicer_uf_files(obs_row::DataFrames.DataFrame, root_dir::String)
    uf_dir = _nicer_uf_dir(obs_row, root_dir)
    obsid  = obs_row[:obsid][1]
    
    instrument_data = (
        string(uf_dir, "/ni$(obsid)_0mpu0_uf.evt"),
        string(uf_dir, "/ni$(obsid)_0mpu1_uf.evt"),
        string(uf_dir, "/ni$(obsid)_0mpu2_uf.evt"),
        string(uf_dir, "/ni$(obsid)_0mpu3_uf.evt"),
        string(uf_dir, "/ni$(obsid)_0mpu4_uf.evt"),
        string(uf_dir, "/ni$(obsid)_0mpu5_uf.evt"),
        string(uf_dir, "/ni$(obsid)_0mpu6_uf.evt")
    )

    return abspath.(instrument_data)
end