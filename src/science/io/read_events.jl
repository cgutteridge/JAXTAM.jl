struct InstrumentData
    instrument::Symbol
    events::DataFrame
    gti::DataFrame
end

function _read_fits_hdu(fits_file, hdu_id)
    fits_cols_events = Array{String,1}

    try
        fits_cols_events = FITSIO.colnames(fits_file[hdu_id])
    catch UndefVarError
        warn("FITSIO colnames function not found, try trunning `Pkg.checkout(\"FITSIO\")`")
        error("colnames not defined")
    end

    fits_hdu_data = DataFrame()

    for col in fits_cols_events
        try
            fits_col_data = read(fits_file[hdu_id], col)

            if ndims(fits_col_data) == 1
                fits_hdu_data[Symbol(col)] = fits_col_data
            end
        catch
            warn("$col not supported by FITSIO, skipped")
        end
    end

    return fits_hdu_data
end

function _read_fits_event(fits_path)
    print("\n"); info("Loading $fits_path")
    fits_file   = FITS(fits_path)

    instrument_name = read_header(fits_file[1])["INSTRUME"]

    fits_events_df = _read_fits_hdu(fits_file, 2)

    fits_gti_df = _read_fits_hdu(fits_file, 3)

    close(fits_file)

    return InstrumentData(instrument_name, fits_events_df, fits_gti_df)
end

function _save_fits_feather(feather_dir, instrument_name, fits_events_df, fits_gti_df)
    Feather.write(joinpath(feather_dir, "$instrument_name\_events.feather"), fits_events_df)
    Feather.write(joinpath(feather_dir, "$instrument_name\_gtis.feather"), fits_gti_df)
end

function read_cl_fits(mission_name, obs_row)
    file_path = abspath.([i for i in obs_row[:event_cl][1]]) # Convert tuple to array, abdolute path

    obsid = obs_row[:obsid]
    
    files = []
    
    for file in file_path
        if isfile(file)
            append!(files, [files])
            info("Found: $file")
        elseif isfile(string(file, ".gz")) # Check for files ending in .evt.gz too
            info("Found: $(string(file, ".gz"))")
            append!(files, [string(file, ".gz")])
        else
            warn("NOT found: $file")
        end
    end

    file_no = length(files)

    print("\n"); info("Found $file_no file(s) for $(obsid[1])")

    if file_no == 1
        instrument_data = _read_fits_event(files[1])
        return Dict(instrument_data.instrument => instrument_data)
    elseif file_no > 1
        per_instrument = Dict{Symbol,InstrumentData}()
        for file in files
            instrument_data = _read_fits_event(file)
            per_instrument[instrument_data.instrument] = instrument_data
        end

        return per_instrument
    end
end

function read_cl(mission_name, obs_row)
    obsid       = obs_row[:obsid]
    JAXTAM_path = abspath(string(obs_row[:obs_path][1], "/JAXTAM/"))

    if !isdir(obs_row[:obs_path][1])
        error("$(obs_row[:obs_path][1]) not found")
    end

    if !isdir(JAXTAM_path)
        mkdir(JAXTAM_path)
    end

    JAXTAM_content = readdir(JAXTAM_path)
    JAXTAM_e_files = count(contains.(JAXTAM_content, "events"))
    JAXTAM_g_files = count(contains.(JAXTAM_content, "gtis"))

    if JAXTAM_e_files > 0 && JAXTAM_g_files > 0 && JAXTAM_e_files == JAXTAM_g_files
        mission_data = Dict{Symbol,InstrumentData}()

        instruments = unique(replace.(JAXTAM_content, r"(_gtis|_events|_calib|.feather)", ""))

        for instrument in instruments
            info("Loading $(obsid[1]): $instrument from $JAXTAM_path")
            inst_files = JAXTAM_content[contains.(JAXTAM_content, instrument)]
            file_event = joinpath(JAXTAM_path, inst_files[contains.(inst_files, "events")][1])
            file_gtis  = joinpath(JAXTAM_path, inst_files[contains.(inst_files, "gtis")][1])
            
            mission_data[Symbol(instrument)] = InstrumentData(instrument, Feather.read(file_event), Feather.read(file_gtis))
        end
    else
        mission_data = read_cl_fits(mission_name, obs_row, obsid)

        for key in keys(mission_data)
            print("\n"); info("Saving $(string(key))")

            _save_fits_feather(JAXTAM_path, mission_data[key].instrument, mission_data[key].events, mission_data[key].gti)
        end
    end

    return mission_data
end

function read_cl(mission_name, append_df, obsid)
    obs_row = master_query(append_df, :obsid, obsid)

    return read_cl(mission_name, obs_row)
end