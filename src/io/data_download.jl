function _ftp_dir(mission_name::Symbol, obs_row::DataFrames.DataFrame)
    obs_path_function = config(mission_name).path_obs

    return obs_path_function(obs_row)
end

function _ftp_dir(obsid::String)
    config = _config_load()

    if "default" in keys(config)
        mission_name = config["default"]
        @info "Using default mission - $mission_name"
        return _ftp_dir(mission_name, master_query(master(mission_name), :obsid, obsid))
    else
        @warn "Default mission not found, set with config(:default, :default_mission_name)"
        throw(KeyError(:default))
    end
end

function _ftp_dir(mission_name::Symbol, obsid::String)
    return _ftp_dir(mission_name, master_query(master(mission_name), :obsid, obsid))
end

function _ftp_dir(mission_name::Symbol, master::DataFrames.DataFrame, obsid::String)
    return _ftp_dir(mission_name, master_query(master, :obsid, obsid))
end

function _clean_path_dots(dir)
    return abspath(replace(dir, "." => "")) # Remove . from folders to un-hide them
end

function download(mission_name::Symbol, master::DataFrames.DataFrame, obsid::String; overwrite=false)
    dir_down = _ftp_dir(mission_name, master, obsid)
    dir_dest = string(config(mission_name).path, dir_down)
    dir_dest = _clean_path_dots(dir_dest)

    @info "heasarc.gsfc.nasa.gov:$dir_down --> $dir_dest"
    download_command = `lftp heasarc.gsfc.nasa.gov -e "mirror \"$dir_down\" \"$dir_dest\" --parallel=10 --only-newer --exclude-glob *ufa.evt.gz --exclude-glob *ufa.evt --exclude-glob *uf.evt.gz && exit"`
    

    if isdir(dir_dest) && !overwrite
        @warn "Skipping download, dir exists"
        return
    else
        mkpath(dir_dest)

        println(download_command)
        run(download_command)
    end
end

function download(mission_name::Symbol, obsid::String; overwrite=false)
    download(mission_name, master(mission_name), obsid; overwrite=overwrite)
end

function download(mission_name::Symbol, master::DataFrames.DataFrame, obsids::Array; overwrite=false)
    for (i, obsid) in enumerate(obsids)
        print("\n")
        @info "\t\t$i of $(length(obsids))"
        download(mission_name, master, obsid; overwrite=overwrite)
    end
end

function download(mission_name::Symbol, obsids::Array; overwrite=false)
    master_table = master(mission_name)

    download(mission_name, master_table, obsids; overwrite=overwrite)
end