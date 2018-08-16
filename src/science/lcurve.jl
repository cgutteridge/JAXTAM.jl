struct BinnedData <: JAXTAMData
    mission::Symbol
    instrument::Symbol
    obsid::String
    bin_time::Real
    counts::Array
    times::StepRangeLen
    gtis::Array{Float64,2}
end

struct GTIData <: JAXTAMData
    mission::Symbol
    instrument::Symbol
    obsid::String
    bin_time::Real
    gti_index::Int
    gti_start_time::Real
    counts::Array
    times::StepRangeLen
end

function _lcurve_filter_time(event_times::Arrow.Primitive{Float64}, event_energies::Arrow.Primitive{Float64}, gtis::DataFrames.DataFrame, start_time::Union{Float64,Int64}, stop_time::Union{Float64,Int64}, filter_low_count_gtis=true)
    mask_good_times  = start_time .<= event_times .<= stop_time
    
    event_times    = event_times[mask_good_times]
    event_energies = event_energies[mask_good_times]
    
    event_times = event_times .- start_time
    gtis = hcat(gtis[:START], gtis[:STOP])
    gtis = gtis .- start_time

    # WARNING: rounding GTIs up/down to get integers, shouldn't(?) cause a problem
    # TODO: check with Diego
    # gtis[:, 1] = ceil.(gtis[:, 1])
    # gtis[:, 2] = floor.(gtis[:, 2])

    counts_per_gti_sec = [count(gtis[g, 1] .<= event_times .<= gtis[g, 2])/(gtis[g, 2] - gtis[g, 1]) for g in 1:size(gtis, 1)]
    mask_min_counts = counts_per_gti_sec .>= 1

    @info "Excluded $(size(gtis, 1) - count(mask_min_counts)) gtis under 1 count/sec"

    gtis = gtis[mask_min_counts, :]
    
    return event_times, event_energies, gtis
end

function _lc_filter_energy(event_times::Array{Float64,1}, event_energies::Array{Float64,1}, good_energy_max::Float64, good_energy_min::Float64)
    mask_good_energy = good_energy_min .<= event_energies .<= good_energy_max
    
    event_times = event_times[mask_good_energy]
    event_energies = event_energies[mask_good_energy]

    return event_times, event_energies
end

function _lc_bin(event_times::Array{Float64,1}, bin_time::Float64, time_start::Union{Float64,Int64}, time_stop::Union{Float64,Int64})
    if bin_time < 1
        if !ispow2(Int(1/bin_time))
            @warn "Bin time not pow2"
        end
    elseif bin_time > 1
        if !ispow2(Int(bin_time))
            @warn "Bin time not pow2"
        end
    elseif bin_time == 0
        throw(ArgumentError("Bin time cannot be zero"))
    end

    binned_histogram = fit(Histogram, event_times, 0:bin_time:(time_stop-time_start), closed=:left)

    counts = binned_histogram.weights
    times  = binned_histogram.edges[1][1:length(counts)]
    
    return times, counts
end

function _lcurve(instrument_data::InstrumentData, bin_time::Union{Float64,Int64})
    event_times, event_energies, gtis = _lcurve_filter_time(instrument_data.events[:TIME], instrument_data.events[:E], instrument_data.gtis, instrument_data.start, instrument_data.stop)

    mission_name = instrument_data.mission
    good_energy_min, good_energy_max = (Float64(config(mission_name).good_energy_min), Float64(config(mission_name).good_energy_max))

    event_times, event_energies = _lc_filter_energy(event_times, event_energies, good_energy_min, good_energy_max)

    binned_times, binned_counts = _lc_bin(event_times, bin_time, instrument_data.start, instrument_data.stop)

    return BinnedData(instrument_data.mission, instrument_data.instrument, instrument_data.obsid, bin_time, binned_counts, binned_times, gtis)
end

function _lcurve_save(lightcurve_data::BinnedData, lc_dir::String)
    lc_basename = string("$(lightcurve_data.instrument)_lc_$(lightcurve_data.bin_time)")

    lc_meta = DataFrame(mission=string(lightcurve_data.mission), instrument=string(lightcurve_data.instrument), obsid=lightcurve_data.obsid, bin_time=lightcurve_data.bin_time, times=[lightcurve_data.times[1], lightcurve_data.times[2] - lightcurve_data.times[1], lightcurve_data.times[end]])

    lc_gtis = DataFrame(start=lightcurve_data.gtis[:, 1], stop=lightcurve_data.gtis[:, 2])

    lc_data = DataFrame(counts=lightcurve_data.counts)

    Feather.write(joinpath(lc_dir, "$(lc_basename)_meta.feather"), lc_meta)
    Feather.write(joinpath(lc_dir, "$(lc_basename)_gtis.feather"), lc_gtis)
    Feather.write(joinpath(lc_dir, "$(lc_basename)_data.feather"), lc_data)
end

function _lc_read(lc_dir::String, instrument::Symbol, bin_time)
    lc_basename = string("$(instrument)_lc_$(string(bin_time))")

    lc_meta = Feather.read(joinpath(lc_dir, "$(lc_basename)_meta.feather"))
    lc_gtis = Feather.read(joinpath(lc_dir, "$(lc_basename)_gtis.feather"))
    lc_data = Feather.read(joinpath(lc_dir, "$(lc_basename)_data.feather"))

    return BinnedData(Symbol(lc_meta[:mission][1]), Symbol(lc_meta[:instrument][1]), lc_meta[:obsid][1], lc_meta[:bin_time][1], lc_data[:counts], lc_meta[:times][1]:lc_meta[:times][2]:lc_meta[:times][3], hcat(lc_gtis[:start], lc_gtis[:stop]))
end

function lcurve(mission_name::Symbol, obs_row::DataFrame, bin_time::Number; overwrite=false)
    obsid          = obs_row[:obsid][1]
    JAXTAM_path    = abspath(string(obs_row[:obs_path][1], "/JAXTAM/")); mkpath(JAXTAM_path)
    JAXTAM_content = readdir(JAXTAM_path)
    JAXTAM_lc_path = joinpath(JAXTAM_path, "lc/$bin_time/")
    
    mkpath(JAXTAM_lc_path)
    
    JAXTAM_c_files  = count(contains.(JAXTAM_content, "calib"))
    JAXTAM_lc_files = count(contains.(readdir(JAXTAM_lc_path), "lc_"))/3

    instruments = Symbol.(config(mission_name).instruments)

    lightcurves = Dict{Symbol,BinnedData}()

    if JAXTAM_c_files == 0
        @warn "No calibrated files found, running calibration"
        calibrate(mission_name, obs_row)
    end

    if (JAXTAM_c_files > 0 && JAXTAM_c_files > JAXTAM_lc_files) || (JAXTAM_c_files > 0 && overwrite)
        calibrated_data = calibrate(mission_name, obs_row)
    
        for instrument in instruments
            @info "Binning LCURVE"
            lightcurve_data = _lcurve(calibrated_data[instrument], bin_time)

            @info "Saving `$instrument` $(bin_time)s lightcurve data"

            _lcurve_save(lightcurve_data, JAXTAM_lc_path)

            lightcurves[instrument] = lightcurve_data
        end
    elseif JAXTAM_c_files > 0 && JAXTAM_c_files == JAXTAM_lc_files
        @info "Loading LC $(obsid): from $JAXTAM_lc_path"

        for instrument in instruments
            lightcurves[instrument] = _lc_read(JAXTAM_lc_path, instrument, bin_time)
        end
    end
    
    return lightcurves
end

function lcurve(mission_name::Symbol, obsid::String, bin_time::Number; overwrite=false)
    obs_row = JAXTAM.master_query(mission_name, :obsid, obsid)

    return lcurve(mission_name, obs_row, bin_time; overwrite=overwrite)
end