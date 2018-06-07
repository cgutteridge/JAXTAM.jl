function _ftp_folder(mission_name::Union{String,Symbol}, obs_row::DataFrames.DataFrame)
    if string(mission_name) == "nicer"
        return _nicer_observation_folder(obs_row[:obsid], obs_row[:time])
    elseif string(mission_name) == "nustar"
        return string("./nustar_archive/$(obs_row[:obsid][1])")
    end
end

function _ftp_folder(obsid::String)
    config = _config_load()

    if "default" in keys(config)
        mission_name = config["default"]
        info("Using default mission - $mission_name")
        return _ftp_folder(mission_name, master_query(master(mission_name), :obsid, obsid))
    else
        error("Default mission not found, set with config(:default, :default_mission_name)")
    end
end

function _ftp_folder(mission_name::Union{String,Symbol}, obsid::String)
    return _ftp_folder(mission_name, master_query(master(mission_name), :obsid, obsid))
end

function _ftp_folder(mission_name::Union{String,Symbol}, master::DataFrames.DataFrame, obsid::String)
    return _ftp_folder(mission_name, master_query(master, :obsid, obsid))
end