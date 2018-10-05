"""
    _read_rmf(path_rmf::String)

Reads an RMF calibration file (from HEASARC caldb), loads in energy bands and PI channels 
for use when filtering events out of a good energy range

Returns the PI channels, and the min/max good energy ranges
"""
function _read_rmf(path_rmf::String)
    if !isfile(path_rmf)
        throw(SystemError("opening file RMF file `$path_rmf`", 2))
    end

    fits_file = FITSIO.FITS(path_rmf)

    fits_ebounds = fits_file["EBOUNDS"]

    pis = read(fits_ebounds, "CHANNEL")

    e_mins = read(fits_ebounds, "E_MIN")
    e_maxs = read(fits_ebounds, "E_MAX")
    
    close(fits_file)

    return pis, e_mins, e_maxs
end

"""
    _read_rmf(mission_name::Symbol)

Calls `_read_rmf(path_rmf)` using the `path_rmf` loaded from a mission configuration file
"""
function _read_rmf(mission_name::Symbol)
    path_rmf = config(mission_name).path_rmf

    return _read_rmf(path_rmf)
end

"""
    _read_calibration(pis::Union{Array,Arrow.Primitive{Int16}}, path_rmf::String)

Loads the RMF calibration data, creates PI channels for energy conversion

Channel bounds are the average of the min and max energy range
"""
function _read_calibration(pis::Union{Array,Arrow.Primitive{Int16},Arrow.Primitive{Int64}}, path_rmf::String)
    calp, calEmin, calEmax = _read_rmf(path_rmf)

    es = zeros(length(pis))

    for (i, PI) in enumerate(pis)
        if PI in calp
            es[i] = (calEmin[PI+1] + calEmax[PI+1])/2
        end
    end

    return es
end

"""
    _read_calibration(pis::Union{Array,Arrow.Primitive{Int16}}, mission_name::Symbol)

Loads the RMF path from the mission configuration file, then calls 
`_read_calibration(pis::Union{Array,Arrow.Primitive{Int16}}, path_rmf::String)`
"""
function _read_calibration(pis::Union{Array,Arrow.Primitive{Int16},Arrow.Primitive{Int64}}, mission_name::Symbol)
    path_rmf = config(mission_name).path_rmf

    return _read_calibration(pis, path_rmf)
end

"""
    calibrate(mission_name::Symbol, obs_row::DataFrames.DataFrame)

Loads in the calibrated event data, as well as the mission calibration RMF file, 
then filters the events by the energy ranges/PI channels in the RMF file

Saves the calibrated files as a `calib.feather` if none exists

Loads `calib.feater` file if it does exist

Returns a calibrated (filtered to contain only good energies) `InstrumentData` type
"""
function calibrate(mission_name::Symbol, obs_row::DataFrames.DataFrame)
    obsid       = obs_row[:obsid][1]
    JAXTAM_path = abspath(string(obs_row[:obs_path][1], "/JAXTAM/"))

    if isdir(JAXTAM_path)
        JAXTAM_content = readdir(JAXTAM_path)
        JAXTAM_e_files = count(contains.(JAXTAM_content, "events"))
        JAXTAM_c_files = count(contains.(JAXTAM_content, "calib"))
    else
        JAXTAM_e_files = 0
        JAXTAM_c_files = 0
    end


    calibrated_energy = Dict{Symbol,InstrumentData}()

    instruments = config(mission_name).instruments

    if JAXTAM_e_files == 0
        @warn "No events files found, running read_cl"
        read_cl(mission_name, obs_row)
        return calibrate(mission_name, obs_row)
    end

    if JAXTAM_e_files > 0 && JAXTAM_e_files > JAXTAM_c_files
        @info "Loading EVENTS for $(obsid) from $JAXTAM_path"

        for instrument in instruments
            @info "Loading $instrument EVENTS"

            instrument_data            = read_cl(mission_name, obs_row)[Symbol(instrument)]
            instrument_data.events[:E] = _read_calibration(instrument_data.events[:PI], mission_name)

            @info "Saving $instrument CALIB energy"

            Feather.write(joinpath(JAXTAM_path, "$(instrument)_calib.feather"), DataFrame(E = instrument_data.events[:E]))

            calibrated_energy[Symbol(instrument)] = instrument_data
        end
    elseif JAXTAM_e_files > 0 && JAXTAM_e_files == JAXTAM_c_files
        @info "Loading CALIB $(obsid): from $JAXTAM_path"

        for instrument in instruments
            @info "Loading $instrument CALIB energy"

            events = Feather.read(joinpath(JAXTAM_path, "$(instrument)_events.feather"))
            calib  = Feather.read(joinpath(JAXTAM_path, "$(instrument)_calib.feather"))
            gtis   = Feather.read(joinpath(JAXTAM_path, "$(instrument)_gtis.feather"))
            meta   = Feather.read(joinpath(JAXTAM_path, "$(instrument)_meta.feather"))

            events_calib = events
            events_calib[:E] = calib[:E]

            meta_missn = mission_name #Symbol(lowercase(meta[:TELESCOP][1]))
            meta_obsid = meta[:OBS_ID][1]
            meta_start = meta[:TSTART][1]
            meta_stop  = meta[:TSTOP][1]

            calibrated_energy[Symbol(instrument)] = InstrumentData(meta_missn, instrument, meta_obsid, events_calib, gtis, meta_start, meta_stop, meta)
        end
    end

    return calibrated_energy
end

"""
    calibrate(mission_name::Symbol, append_df::DataFrames.DataFrame, obsid::String)

Calls `master_query` to load in the relevant `obs_row`

Calls and returns `calibrate(mission_name::Symbol, obs_row::DataFrames.DataFrame)`
"""
function calibrate(mission_name::Symbol, append_df::DataFrames.DataFrame, obsid::String)
    obs_row = master_query(append_df, :obsid, obsid)

    return calibrate(mission_name, obs_row)
end

"""
    calibrate(mission_name::Symbol, obsid::String)

Calls `master_a` to load in the master table

Calls and returns `calibrate(mission_name::Symbol, append_df::DataFrames.DataFrame, obsid::String)`
"""
function calibrate(mission_name::Symbol, obsid::String)
    return calibrate(mission_name, master_a(mission_name), obsid)
end