# NuSTAR Mission Definition
# Good energy range: 3 - 78.4 keV

function _nustar_observation_dir(obs_row::DataFrames.DataFrame)
    obsid = obs_row[:obsid][1]
    return string("/nustar/.nustar_archive/$obsid")
end

function _nustar_observation_dir(obsid::String, master_df::DataFrames.DataFrame)
    obs_row = filter(row -> row[:obsid] == obsid, master_df)

    return _nustar_observation_dir(obs_row)
end

function _nustar_observation_dir(obsid::String)
    return _nustar_observation_dir(obsid, master(:nustar))
end

function _nustar_cl_dir(obs_row::DataFrames.DataFrame, root_dir::String)
    obs_dir = _clean_path_dots(_nustar_observation_dir(obs_row))

    return abspath(string(root_dir, obs_dir, "/event_cl/"))
end

function _nustar_cl_files(obs_row::DataFrames.DataFrame, root_dir::String)
    cl_dir = _nustar_cl_dir(obs_row, root_dir)
    obsid  = obs_row[:obsid][1]

    instrument_data = (
        string(cl_dir, "/nu$(obsid)A01_cl.evt"),
        string(cl_dir, "/nu$(obsid)B01_cl.evt")
    )

    return abspath.(instrument_data)
end

function _nustar_uf_dir(obs_row::DataFrames.DataFrame, root_dir::String)
    obs_dir = _clean_path_dots(_nustar_observation_dir(obs_row))

    return abspath(string(root_dir, obs_dir, "/event_uf/"))
end

function _nustar_uf_files(obs_row::DataFrames.DataFrame, root_dir::String)
    uf_dir = _nustar_uf_dir(obs_row, root_dir)
    obsid  = obs_row[:obsid][1]

    instrument_data = (
        string(uf_dir, "/nu$(obsid)A_uf.evt"),
        string(uf_dir, "/nu$(obsid)B_uf.evt")
    )

    return abspath.(instrument_data)
end