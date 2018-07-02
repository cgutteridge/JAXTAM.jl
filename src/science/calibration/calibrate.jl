function _read_rmf(path_rmf::String)
    if !isfile(path_rmf)
        error("Not found: $path_rmf")
    end

    fits_file = FITSIO.FITS(path_rmf)

    fits_ebounds = fits_file["EBOUNDS"]

    pis = read(fits_ebounds, "CHANNEL")

    e_mins = read(fits_ebounds, "E_MIN")
    e_maxs = read(fits_ebounds, "E_MAX")
    
    close(fits_file)

    return pis, e_mins, e_maxs
end

function _read_rmf(mission_name::Symbol)
    path_rmf = config(mission_name).path_rmf

    return _read_rmf(path_rmf)
end

function _read_rmf()
    path_rmf = config(:default).path_rmf

    return _read_rmf(path_rmf)
end

function _read_calibration(pis::Array{Int16,1}, path_rmf::String)
    calp, calEmin, calEmax = _read_rmf(path_rmf)

    es = zeros(length(pis))

    for (i, PI) in enumerate(pis)
        if PI in calp
            es[i] = (calEmin[PI-1] + calEmax[PI-1])/2
        end
    end

    return es
end

function _read_calibration(pis::Array{Int16,1}, mission_name::Symbol)
    path_rmf = config(mission_name).path_rmf

    return _read_calibration(pis, path_rmf)
end

function _read_calibration(pis::Array{Int16,1})
    path_rmf = config(:default).path_rmf

    return _read_calibration(pis, path_rmf)
end

function calibrate(mission_name::Symbol, obs_row::DataFrames.DataFrame)
    JAXTAM_path = abspath(string(obs_row[:obs_path][1], "/JAXTAM/"))

    JAXTAM_content = readdir(JAXTAM_path)
    JAXTAM_e_files = count(contains.(JAXTAM_content, "events"))
    JAXTAM_c_files = count(contains.(JAXTAM_content, "calib"))

    if JAXTAM_e_files > 0 && JAXTAM_e_files > JAXTAM_c_files
        
    end

    pis = read_cl(mission_name, obs_row)[:XTI].events[:PI]
    es  = _read_calibration(pis, mission_name)

    return es
end

function calibrate(mission_name::Symbol, append_df::DataFrames.DataFrame, obsid::String)
    obs_row = master_query(append_df, :obsid, obsid)

    return calibrate(mission_name, obs_row)
end

function calibrate(mission_name::Symbol, obsid::String)
    return calibrate(mission_name, master_a(mission_name), obsid)
end