"""
    _ftp_dir(mission_name::Symbol, obs_row::DataFrames.DataFrame)

Returns the HEASARC FTP server path to an observation using the 
mission defined `path_obs` function
"""
function _ftp_dir(mission_name::Symbol, obs_row::DataFrames.DataFrame)
    obs_path_function = config(mission_name).path_obs

    return obs_path_function(obs_row)
end

"""
    _ftp_dir(mission_name::Symbol, obsid::String)

Uses `master_query` to get `obs_row` for `obsid`, calls `_ftp_dir(mission_name::Symbol, obs_row::DataFrames.DataFrame)`

Calls `master(mission_name)` each time
"""
function _ftp_dir(mission_name::Symbol, obsid::String)
    return _ftp_dir(mission_name, master_query(master(mission_name), :obsid, obsid))
end

"""
    _ftp_dir(mission_name::Symbol, master::DataFrames.DataFrame, obsid::String)

Same as `_ftp_dir(mission_name::Symbol, obsid::String)`, takes in `master` as argument to avoid
running `master()` to load the master table each time
"""
function _ftp_dir(mission_name::Symbol, master::DataFrames.DataFrame, obsid::String)
    return _ftp_dir(mission_name, master_query(master, :obsid, obsid))
end

"""
    _clean_path_dots(dir)

FTP directories use hidden dot folders frequentyl, function removes from a path for local use
"""
function _clean_path_dots(dir)
    return abspath(replace(dir, "." => "")) # Remove . from folders to un-hide them
end

"""
    download(mission_name::Symbol, master::DataFrames.DataFrame, obsid::String; overwrite=false)

Finds the FTP server-side path via `_ftp_dir`, downloads folder using `lftp`, currently excludes the `uf` files
assuming calibrations are up to date. Saves download folder to local, dot-free, path
"""
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

"""
    download(mission_name::Symbol, obsid::String; overwrite=false)

Calls `master(mission_name)`, then calls `download(mission_name::Symbol, master::DataFrames.DataFrame, obsid::String; overwrite=false)`
"""
function download(mission_name::Symbol, obsid::String; overwrite=false)
    download(mission_name, master(mission_name), obsid; overwrite=overwrite)
end

"""
    download(mission_name::Symbol, master::DataFrames.DataFrame, obsids::Array; overwrite=false)

Calls `download(mission_name::Symbol, master::DataFrames.DataFrame, obsid::String; overwrite=false)` with 
an array of multiple obsids
"""
function download(mission_name::Symbol, master::DataFrames.DataFrame, obsids::Array; overwrite=false)
    for (i, obsid) in enumerate(obsids)
        print("\n")
        @info "\t\t$i of $(length(obsids))"
        download(mission_name, master, obsid; overwrite=overwrite)
    end
end

"""
    download(mission_name::Symbol, obsids::Array; overwrite=false)

Calls `master(mission_name)`, then `download(mission_name::Symbol, master::DataFrames.DataFrame, obsids::Array; overwrite=false)`
"""
function download(mission_name::Symbol, obsids::Array; overwrite=false)
    master_df = master(mission_name)

    download(mission_name, master_df, obsids; overwrite=overwrite)
end