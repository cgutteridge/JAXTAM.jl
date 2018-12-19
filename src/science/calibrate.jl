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

function _read_rmf(mission_name::Symbol)
    path_rmf = config(mission_name).path_rmf

    return _read_rmf(path_rmf)
end

"""
    _calibrate_pis(pis::Union{Array,Arrow.Primitive{Int16}}, path_rmf::String)

Loads the RMF calibration data, creates PI channels for energy conversion

Channel bounds are the average of the min and max energy range
"""
function _calibrate_pis(pis::Union{Array,Arrow.Primitive{Int16},Arrow.Primitive{Int64}}, path_rmf::String)
    calp, calEmin, calEmax = _read_rmf(path_rmf)

    return map(x -> (calEmin[x+1] + calEmax[x+1])/2, pis)
end

function _calibrate_pis(pis::Union{Array,Arrow.Primitive{Int16},Arrow.Primitive{Int64}}, mission_name::Symbol)
    path_rmf = config(mission_name).path_rmf

    return _calibrate_pis(pis, path_rmf)
end

function _save_calibrated(mission_name::Symbol, obs_row::DataFrames.DataFrame, instrument::Symbol, 
        feather_dir::String, calibrated_energy::DataFrames.DataFrame;
        log=true)

    calibrated_file_path = joinpath(feather_dir, "$(instrument)_calib.feather")

    Feather.write(calibrated_file_path, calibrated_energy)

    if log
        _log_add(mission_name, obs_row, 
            Dict("data" =>
                Dict(:feather_cl =>
                    Dict(instrument =>
                        Dict(
                            :path_calib => calibrated_file_path
                        )
                    )
                )
            )
        )
    end

    @info "Saved '$instrument' calib files to $feather_dir"
end

function _read_calibration(path_calib::String)
    calib = Feather.read(path_calib)
end

"""
    calibrate(mission_name::Symbol, obs_row::DataFrames.DataFrame)

Loads in the calibrated event data, as well as the mission calibration RMF file, 
then filters the events by the energy ranges/PI channels in the RMF file

Saves the calibrated files as a `calib.feather` if none exists

Loads `calib.feater` file if it does exist

Returns a calibrated (filtered to contain only good energies) `InstrumentData` type
"""
function calibrate(mission_name::Symbol, obs_row::DataFrames.DataFrame;
    instrument_data::Dict{Symbol,JAXTAM.InstrumentData}=Dict{Symbol,InstrumentData}(), overwrite=false)
    obsid       = obs_row[1, :obsid]
    instruments = Symbol.(config(mission_name).instruments)
    cl_files    = _log_query(mission_name, obs_row, "data", :feather_cl)

    if !all(haskey.(instrument_data, instruments))
        instrument_data = read_cl(mission_name, obs_row)
    end

    calibration_instrument_data = Dict{Symbol,DataFrames.DataFrame}()
    for instrument in instruments
        if haskey(cl_files[instrument], :path_calib) && !overwrite # Check if log has calibration file path
            @info "Loading feather calib files for $instrument"
            calibration_instrument_data[instrument] = _read_calibration(cl_files[instrument][:path_calib])
        else
            @info "Generating calib files for $instrument"
            calibration_instrument_data[instrument] = DataFrame(E=_calibrate_pis(instrument_data[instrument].events[:PI], mission_name))

            _save_calibrated(mission_name, obs_row, instrument,
                abspath(string(obs_row[1, :obs_path], "/JAXTAM/data/feather_cl/")), calibration_instrument_data[instrument])
        end

        instrument_data[instrument].events[:E] = calibration_instrument_data[instrument][:E]
    end
    
    return instrument_data
end

function calibrate(mission_name::Symbol, append_df::DataFrames.DataFrame, obsid::String; overwrite=false)
    obs_row = master_query(append_df, :obsid, obsid)

    return calibrate(mission_name, obs_row; overwrite=overwrite)
end

function calibrate(mission_name::Symbol, obsid::String; overwrite=false)
    return calibrate(mission_name, master_a(mission_name), obsid; overwrite=overwrite)
end