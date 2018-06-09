function _ftp_dir(mission_name::Union{String,Symbol}, obs_row::DataFrames.DataFrame)
    if string(mission_name) == "nicer"
        return _nicer_observation_dir(obs_row[:obsid], obs_row[:time])
    elseif string(mission_name) == "nustar"
        return string("./nustar_archive/$(obs_row[:obsid][1])")
    end
end

function _ftp_dir(obsid::String)
    config = _config_load()

    if "default" in keys(config)
        mission_name = config["default"]
        info("Using default mission - $mission_name")
        return _ftp_dir(mission_name, master_query(master(mission_name), :obsid, obsid))
    else
        error("Default mission not found, set with config(:default, :default_mission_name)")
    end
end

function _ftp_dir(mission_name::Union{String,Symbol}, obsid::String)
    return _ftp_dir(mission_name, master_query(master(mission_name), :obsid, obsid))
end

function _ftp_dir(mission_name::Union{String,Symbol}, master::DataFrames.DataFrame, obsid::String)
    return _ftp_dir(mission_name, master_query(master, :obsid, obsid))
end

function download(mission_name::Union{String,Symbol}, master, obsid::String)
    dir_down = _ftp_dir(mission_name, master, obsid)
    dir_dest = string(config(mission_name).path, dir_down)
    dir_dest = replace(dir_dest, ".", "") # Remove . from folders to un-hide them
    dir_dest = abspath(dir_dest)

    mkpath(dir_dest)
    cd(dir_dest)

    if pwd() != dir_dest
        error("cd to $dir_dest seems to have failed, aborting")
    end

    download_command = `lftp heasarc.gsfc.nasa.gov:$dir_down -e 'mirror --parallel=10 --only-newer && exit'`
    println(download_command)

    run(download_command)
end

function download(mission_name::Union{String,Symbol}, obsid::String)
    download(mission_name::Union{String,Symbol}, master(), obsid::String)
end