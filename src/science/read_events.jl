struct InstrumentData <: JAXTAMData
    mission::Symbol
    instrument::Symbol
    obsid::String
    events::DataFrame
    gtis::DataFrame
    start::Number
    stop::Number
    header::DataFrame
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

    fits_header = read_header(fits_file[1])

    instrument_name = fits_header["INSTRUME"]
    fits_telescope  = fits_header["TELESCOP"]
    fits_telescope  = Symbol(lowercase(fits_telescope))
    
    fits_events_df = _read_fits_hdu(fits_file, "EVENTS")
    
    fits_gtis_df = _read_fits_hdu(fits_file, "GTI")
    
    fits_obsid = fits_header["OBS_ID"]
    fits_start = fits_header["TSTART"]
    fits_stop = fits_header["TSTOP"]

    fits_header_df = DataFrame()

    for (i, key) in enumerate(keys(fits_header))
        key = Symbol(replace(key, '-', '_'))
        if typeof(fits_header[i]) == Void
            fits_header_df[Symbol(key)] =  ""
        else
            fits_header_df[Symbol(key)] = fits_header[i]
        end
    end

    close(fits_file)

    return InstrumentData(fits_telescope, instrument_name, fits_obsid, fits_events_df, fits_gtis_df, fits_start, fits_stop, fits_header_df)
end

function read_cl_fits(mission_name::Symbol, obs_row::DataFrames.DataFrame)
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

function _save_cl_feather(feather_dir, instrument_name, fits_events_df, fits_gtis_df, fits_meta_df)
    Feather.write(joinpath(feather_dir, "$instrument_name\_events.feather"), fits_events_df)
    Feather.write(joinpath(feather_dir, "$instrument_name\_gtis.feather"), fits_gtis_df)
    Feather.write(joinpath(feather_dir, "$instrument_name\_meta.feather"), fits_meta_df)
end

function read_cl(mission_name::Symbol, obs_row::DataFrames.DataFrame)
    obsid       = obs_row[:obsid][1]
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

        #instruments = unique(replace.(JAXTAM_content, r"(_gtis|_events|_meta|_calib|.feather)", ""))

        instruments = config(mission_name).instruments

        for instrument in instruments
            info("Loading $(obsid): $instrument from $JAXTAM_path")
            inst_files = JAXTAM_content[contains.(JAXTAM_content, instrument)]

            path_events = joinpath(JAXTAM_path, inst_files[contains.(inst_files, "events")][1])
            data_events = Feather.read(path_events)

            path_gtis = joinpath(JAXTAM_path, inst_files[contains.(inst_files, "gtis")][1])
            data_gtis = Feather.read(path_gtis)

            file_meta  = joinpath(JAXTAM_path, inst_files[contains.(inst_files, "meta")][1])
            data_meta  = Feather.read(file_meta)
            meta_missn = Symbol(lowercase(data_meta[:TELESCOP][1]))
            meta_obsid = data_meta[:OBS_ID][1]
            meta_start = data_meta[:TSTART][1]
            meta_stop  = data_meta[:TSTOP][1]
            
            mission_data[Symbol(instrument)] = InstrumentData(meta_missn, instrument, meta_obsid, data_events, data_gtis, meta_start, meta_stop, data_meta)
        end
    else
        mission_data = read_cl_fits(mission_name, obs_row)

        for key in keys(mission_data)
            print("\n"); info("Saving $(string(key))")
            
            _save_cl_feather(JAXTAM_path, mission_data[key].instrument, mission_data[key].events, mission_data[key].gtis, mission_data[key].header)
        end
    end

    return mission_data
end

function read_cl(mission_name::Symbol, append_df::DataFrames.DataFrame, obsid::String)
    obs_row = master_query(append_df, :obsid, obsid)

    return read_cl(mission_name, obs_row)
end

function read_cl(mission_name::Symbol, obsid::String)
    append_df = master_a(mission_name)

    return read_cl(mission_name, append_df, obsid)
end