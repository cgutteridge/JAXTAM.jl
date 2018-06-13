function _ftp_dir(mission_name::Symbol, obs_row::DataFrames.DataFrame)
    obs_path_function = eval(config(mission_name).obs_path)

    return obs_path_function(obs_row)
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

function _ftp_dir(mission_name::Symbol, obsid::String)
    return _ftp_dir(mission_name, master_query(master(mission_name), :obsid, obsid))
end

function _ftp_dir(mission_name::Symbol, master::DataFrames.DataFrame, obsid::String)
    return _ftp_dir(mission_name, master_query(master, :obsid, obsid))
end

function _clean_path_dots(dir)
    return abspath(replace(dir, ".", "")) # Remove . from folders to un-hide them
end

function download(mission_name::Symbol, master::DataFrames.DataFrame, obsid::String; skip_exists=true)
    dir_down = _ftp_dir(mission_name, master, obsid)
    dir_dest = string(config(mission_name).path, dir_down)
    dir_dest = _clean_path_dots(dir_dest)

    info("heasarc.gsfc.nasa.gov:$dir_down --> $dir_dest")
    download_command = `lftp heasarc.gsfc.nasa.gov -e "mirror \"$dir_down\" \"$dir_dest\" --parallel=10 --only-newer && exit"`
    

    if isdir(dir_dest) && skip_exists
        warn("Skipping download, dir exists")
        return
    else
        mkpath(dir_dest)

        println(download_command)
        run(download_command)
    end
end

function download(mission_name::Symbol, obsid::String; skip_exists=true)
    download(mission_name, master(), obsid; skip_exists=skip_exists)
end

function download(mission_name::Symbol, master::DataFrames.DataFrame, obsids::Array; skip_exists=true)
    for (i, obsid) in enumerate(obsids)
        print("\n")
        info("\t\t$i of $(length(obsids))")
        download(mission_name, master, obsid; skip_exists=skip_exists)
    end
end

function download(mission_name::Symbol, obsids::Array; skip_exists=true)
    master_table = master(mission_name)

    download(mission_name, master_table, obsids; skip_exists=skip_exists)
end