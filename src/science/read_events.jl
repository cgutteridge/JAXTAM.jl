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

"""
    _read_fits_hdu(fits_file::FITS, hdu_id::String; cols="auto")

Reads the HDU `hdu_id` from the loaded FITS file `fits_file`, returns the HDU data

Cannot read `BitArray` type columns due to `FITSIO` limitations
"""
function _read_fits_hdu(fits_file::FITS, hdu_id::String; cols="auto")
    # Columns read individually, instead of using the FITSIO function to read
    # all the header, as if header contains non-supported column then that function
    # just fails. This avoids that problem and throws warning for non-supported columns
    if cols == "auto"
        fits_cols_events = Array{String,1}

        fits_cols_events = FITSIO.colnames(fits_file[hdu_id])
    else
        fits_cols_events = cols
    end

    fits_hdu_data = DataFrame()

    for col in fits_cols_events
        try
            fits_col_data = read(fits_file[hdu_id], col)

            if ndims(fits_col_data) == 1
                fits_hdu_data[Symbol(col)] = fits_col_data
            end
        catch error
            @warn "$col not supported by FITSIO, skipped - $error"
        end
    end

    return fits_hdu_data
end

"""
    _read_fits_event(fits_path::String)

Reads the standard columns for timing analysis ("TIME", "PI", "GTI") from a FITS file, 
returns `InstrumentData` type filled with the relevant data
"""
function _read_fits_event(fits_path::String, mission_name)
    @info "Loading $fits_path"
    fits_file   = FITS(fits_path)

    fits_header = read_header(fits_file["EVENTS"])

    instrument_name = fits_header["INSTRUME"]
    #fits_telescope  = fits_header["TELESCOP"]
    fits_telescope  = string(mission_name)
    fits_telescope  = Symbol(lowercase(fits_telescope))
    
    fits_events_df = _read_fits_hdu(fits_file, "EVENTS"; cols=String["TIME", "PI"])
    
    fits_gtis_df = _read_fits_hdu(fits_file, "GTI")
    
    fits_obsid = fits_header["OBS_ID"]
    fits_start = fits_header["TSTART"]
    fits_stop = fits_header["TSTOP"]

    fits_header_df = DataFrame()

    for (i, key) in enumerate(keys(fits_header))
        key = Symbol(replace(key, '-', '_')) # Colnames with `-` don't behave well with DataFrames/Feather
        if typeof(fits_header[i]) == Nothing
            fits_header_df[Symbol(key)] =  "empty" # Have to write something, or Feahter.jl errors saving ""
        else
            fits_header_df[Symbol(key)] = fits_header[i]
        end
    end

    close(fits_file)

    return InstrumentData(fits_telescope, instrument_name, fits_obsid, fits_events_df, fits_gtis_df, fits_start, fits_stop, fits_header_df)
end

"""
    read_cl_fits(mission_name::Symbol, obs_row::DataFrames.DataFrame)

Reads in FITS data for an observation, returns a `Dict{Symbol,InstrumentData}`, with the 
symbol as the instrument name. So `instrument_data[:XTI]` works for NICER, and either 
`instrument_data[:FPMA]` or `instrument_data[:FPMB]` work for NuSTAR
"""
function read_cl_fits(mission_name::Symbol, obs_row::DataFrames.DataFrame)
    # Required due to ambiguity over if a joined `master_df` + `append_df` is being used, or just `master_df`
    if :event_cl in names(obs_row)
        file_path = abspath.([i for i in obs_row[:event_cl][1]]) # Convert tuple to array, absolute path
    else
        file_path = config(mission_name).path_cl(obs_row, config(mission_name).path)
        file_path = abspath.([i for i in file_path])
    end
    
    obsid = obs_row[:obsid]
    
    files = []
    
    for file in file_path
        if isfile(file)
            append!(files, [file])
            @info "Found: $file"
        elseif isfile(string(file, ".gz")) # Check for files ending in .evt.gz too
            @info "Found: $(string(file, ".gz"))"
            append!(files, [string(file, ".gz")])
        else
            @warn "NOT found: $file"
            @info "Start download for `$mission_name` $(obs_row[1, :obsid])? (y/n)"
            response = readline(stdin)
            if response == "y" || response == "Y"
                download(mission_name, obs_row[1, :obsid])
                append!(files, [files])
                @info "Found: $file"
            elseif response == "n" || response == "N"
                throw(SystemError("$mission_name $(obs_row[1, :obsid]) files not found", 2))
            end
        end
    end
    
    file_no = length(files)
    
    @info "Found $file_no file(s) for $(obsid[1])"
    
    if file_no == 1
        instrument_data = _read_fits_event(files[1], mission_name)
        return Dict(instrument_data.instrument => instrument_data)
    elseif file_no > 1
        per_instrument = Dict{Symbol,InstrumentData}()
        for file in files
            instrument_data = _read_fits_event(file, mission_name)
            per_instrument[instrument_data.instrument] = instrument_data
        end
        
        return per_instrument
    end
end

"""
    _save_cl_feather(feather_dir::String, instrument_name::Union{String,Symbol},
        fits_events_df::DataFrame, fits_gtis_df::DataFrame, fits_meta_df::DataFrame)

Due to Feather file restrictions, cannot save all the event and GTI data in one, so 
they are split up into three files: `events`, `gtis`, and `meta`. The `meta` file contains 
just the mission name, obsid, and observation start and stop times
"""
function _save_cl_feather(feather_dir::String, instrument_name::Union{String,Symbol},
        fits_events_df::DataFrames.DataFrame, fits_gtis_df::DataFrames.DataFrame, fits_meta_df::DataFrames.DataFrame)
    Feather.write(joinpath(feather_dir, "$(instrument_name)_events.feather"), fits_events_df)
    Feather.write(joinpath(feather_dir, "$(instrument_name)_gtis.feather"), fits_gtis_df)
    Feather.write(joinpath(feather_dir, "$(instrument_name)_meta.feather"), fits_meta_df)
end

"""
    read_cl(mission_name::Symbol, obs_row::DataFrames.DataFrame; overwrite=false)

Attempts to read saved (feather) data, if none is found then the `read_cl_fits` function is ran 
and the data is saved with `_save_cl_feather` for future use
"""
function read_cl(mission_name::Symbol, obs_row::DataFrames.DataFrame; overwrite=false)
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

    if JAXTAM_e_files > 0 && JAXTAM_g_files > 0 && JAXTAM_e_files == JAXTAM_g_files && !overwrite
        mission_data = Dict{Symbol,InstrumentData}()

        instruments = config(mission_name).instruments

        for instrument in instruments
            @info "Loading $(obsid): $instrument from $JAXTAM_path"
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

        instruments = keys(mission_data)
        for instrument in instruments
            @info "Saving $(string(instrument))"

            if size(mission_data[instrument].events, 1) == 0
                bad_events = DataFrame(TIME=[0], PI=[0])
                bad_gtis   = DataFrame(START=[0], STOP=[0])
                _save_cl_feather(JAXTAM_path, mission_data[instrument].instrument, bad_events,
                    bad_gtis, mission_data[instrument].header)

                mission_data[instrument] = InstrumentData(mission_data[instrument].mission, mission_data[instrument].instrument, mission_data[instrument].obsid,
                    bad_events, bad_gtis, mission_data[instrument].start, mission_data[instrument].stop, mission_data[instrument].header)
            else    
                _save_cl_feather(JAXTAM_path, mission_data[instrument].instrument, mission_data[instrument].events,
                    mission_data[instrument].gtis, mission_data[instrument].header)
            end
        end
    end

    return mission_data
end

"""
    read_cl(mission_name::Symbol, append_df::DataFrames.DataFrame, obsid::String; overwrite=false)

Calls `master_query()` to get the `obs_row`, then calls read_cl(mission_name::Symbol, obs_row::DataFrames.DataFrame; overwrite=false)
"""
function read_cl(mission_name::Symbol, append_df::DataFrames.DataFrame, obsid::String; overwrite=false)
    obs_row = master_query(append_df, :obsid, obsid)

    return read_cl(mission_name, obs_row; overwrite=overwrite)
end

"""
    read_cl(mission_name::Symbol, obsid::String; overwrite=false)

Calls `master_a()`, then calls `read_cl(mission_name::Symbol, append_df::DataFrames.DataFrame, obsid::String; overwrite=false)`
"""
function read_cl(mission_name::Symbol, obsid::String; overwrite=false)
    append_df = master_a(mission_name)

    return read_cl(mission_name, append_df, obsid; overwrite=overwrite)
end