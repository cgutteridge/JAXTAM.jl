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

function _read_calibration(pis::Array, path_rmf::String)
    calp, calEmin, calEmax = _read_rmf(path_rmf)

    es = zeros(length(pis))

    for (i, PI) in enumerate(pis)
        if PI in calp
            es[i] = (calEmin[PI+1] + calEmax[PI+1])/2
        end
    end

    return es
end

function _read_calibration(pis::Array, mission_name::Symbol)
    path_rmf = config(mission_name).path_rmf

    return _read_calibration(pis, path_rmf)
end

function _read_calibration(pis::Array)
    path_rmf = config(:default).path_rmf

    return _read_calibration(pis, path_rmf)
end

function calibrate(mission_name::Symbol, obs_row::DataFrames.DataFrame)
    obsid       = obs_row[:obsid][1]
    JAXTAM_path = abspath(string(obs_row[:obs_path][1], "/JAXTAM/"))

    JAXTAM_content = readdir(JAXTAM_path)
    JAXTAM_e_files = count(contains.(JAXTAM_content, "events"))
    JAXTAM_c_files = count(contains.(JAXTAM_content, "calib"))

    calibrated_energy = Dict{Symbol,InstrumentData}()

    instruments = unique(replace.(JAXTAM_content, r"(_gtis|_events|_calib|.feather)", ""))

    if JAXTAM_e_files > 0 && JAXTAM_e_files > JAXTAM_c_files
        info("Loading EVENTS for $(obsid) from $JAXTAM_path")

        for instrument in instruments
            info("Loading $instrument EVENTS")

            instrument_data            = read_cl(mission_name, obs_row)[Symbol(instrument)]
            instrument_data.events[:E] = _read_calibration(instrument_data.events[:PI], mission_name)

            info("Saving $instrument CALIB energy")

            Feather.write(joinpath(JAXTAM_path, "$instrument\_calib.feather"), DataFrame(E = instrument_data.events[:E]))

            calibrated_energy[Symbol(instrument)] = instrument_data
        end
    elseif JAXTAM_e_files > 0 && JAXTAM_e_files == JAXTAM_c_files
        info("Loading CALIB $(obsid): from $JAXTAM_path")

        for instrument in instruments
            info("Loading $instrument CALIB energy")

            events = Feather.read(joinpath(JAXTAM_path, "$instrument\_events.feather"))
            calib  = Feather.read(joinpath(JAXTAM_path, "$instrument\_calib.feather"))
            gtis   = Feather.read(joinpath(JAXTAM_path, "$instrument\_gtis.feather"))

            events_calib = events
            events_calib[:E] = calib[:E]

            calibrated_energy[Symbol(instrument)] = InstrumentData(instrument, events_calib, gtis)
        end
    end

    return calibrated_energy
end

function calibrate(mission_name::Symbol, append_df::DataFrames.DataFrame, obsid::String)
    obs_row = master_query(append_df, :obsid, obsid)

    return calibrate(mission_name, obs_row)
end

function calibrate(mission_name::Symbol, obsid::String)
    return calibrate(mission_name, master_a(mission_name), obsid)
end

#JAXTAM.calibrate(:nicer, "1010010192")