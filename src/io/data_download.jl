function _ftp_dir(mission_name::Union{String,Symbol}, obs_row::DataFrames.DataFrame)
    if string(mission_name) == "nicer"
        return _nicer_observation_dir(obs_row[:obsid], obs_row[:time])
    elseif string(mission_name) == "nustar"
        return _nustar_observation_dir(obs_row[:obsid][1])
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

function download(mission_name::Union{String,Symbol}, master::DataFrames.DataFrame, obsid::String)
    dir_down = _ftp_dir(mission_name, master, obsid)
    dir_dest = string(config(mission_name).path, dir_down)
    dir_dest = replace(dir_dest, ".", "") # Remove . from folders to un-hide them
    dir_dest = abspath(dir_dest)

    mkpath(dir_dest)

    info("heasarc.gsfc.nasa.gov:$dir_down --> $dir_dest")
    download_command = `lftp heasarc.gsfc.nasa.gov -e "mirror $dir_down $dir_dest --parallel=10 --only-newer && exit"`
    println(download_command)

    run(download_command)
end

function download(mission_name::Union{String,Symbol}, obsid::String)
    download(mission_name::Union{String,Symbol}, master(), obsid::String)
end

function download(mission_name::Union{String,Symbol}, master::DataFrames.DataFrame, obsids::Array)
    for (i, obsid) in enumerate(obsids)
        print("\n")
        info("\t\t$i of $(length(obsids))")
        download(mission_name, master, obsid)
    end
end

function download(mission_name::Union{String,Symbol}, obsids::Array)
    master_table = master(mission_name)

    download(mission_name, master_table, obsids)
end