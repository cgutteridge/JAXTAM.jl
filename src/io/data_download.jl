"""
    download(mission::Mission, master::DataFrames.DataFrame, obsid::String; overwrite=false)

Finds the FTP server-side path via `_ftp_dir`, downloads folder using `lftp`, currently excludes the `uf` files
assuming calibrations are up to date. Saves download folder to local, dot-free, path
"""
function download(mission::Mission, obs_row::DataFrames.DataFrameRow{DataFrames.DataFrame}; overwrite=false)
    dir_down = _obs_path_server(mission, obs_row)
    dir_dest = _obs_path_local(mission, obs_row, kind=:download)

    @info "heasarc.gsfc.nasa.gov:$dir_down --> $dir_dest"

    download_command = `lftp heasarc.gsfc.nasa.gov -e "mirror \"$dir_down\" \"$dir_dest\" --parallel=10 --only-newer --exclude-glob *ufa.evt.gz --exclude-glob *ufa.evt --exclude-glob *uf.evt.gz && exit"`

    if _log_query(mission, obs_row, "meta", :downloaded) && !overwrite
        @warn "Skipping download, dir exists"
    else
        mkpath(dir_dest)

        println(download_command)
        run(download_command)
        _log_add(mission, obs_row, Dict("meta"=>Dict(:downloaded=>true)))
    end
end

function download(mission::Mission, obs_rows::DataFrames.DataFrame; overwrite=false)
    for obs_row in DataFrames.eachrow(obs_rows)
        download(mission, obs_row; overwrite=overwrite)
    end
end

function download(mission::Mission, obsid::String; overwrite=false)
    obs_rows = master_query(mission, :obsid, obsid)

    download(mission, obs_rows; overwrite=overwrite)
end