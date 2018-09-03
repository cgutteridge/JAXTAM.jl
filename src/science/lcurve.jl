struct BinnedData <: JAXTAMData
    mission::Symbol
    instrument::Symbol
    obsid::String
    bin_time::Real
    counts::Array{Int,1}
    times::StepRangeLen
    gtis::DataFrames.DataFrame
end

function _lcurve_filter_time(event_times::Arrow.Primitive{Float64}, event_energies::Arrow.Primitive{Float64},
    gtis::DataFrames.DataFrame, start_time::Union{Float64,Int64}, stop_time::Union{Float64,Int64}, filter_low_count_gtis=false)
    @info "               -> Filtering times"

    if abs(event_times[1] - start_time) < 2.0^-8 && abs(event_times[end] - stop_time) < 2.0^-8
        # Times within tolerence
    else
        start_time_idx = findfirst(event_times .> start_time)
        stop_time_idx  = findfirst(event_times .>= stop_time)
        if stop_time_idx == nothing
            stop_time_idx = length(event_times)
        else
            stop_time_idx = stop_time_idx - 1
        end
        event_times    = event_times[start_time_idx:stop_time_idx]
        event_energies = event_energies[start_time_idx:stop_time_idx]
    end

    event_times = event_times .- start_time
    gtis = hcat(gtis[:START], gtis[:STOP])
    gtis = gtis .- start_time

    # WARNING: rounding GTIs up/down to get integers, shouldn't(?) cause a problem
    # TODO: check with Diego
    # gtis[:, 1] = ceil.(gtis[:, 1])
    # gtis[:, 2] = floor.(gtis[:, 2])

    if filter_low_count_gtis # Move GTI count filtering to post-binning stages
        counts_per_gti_sec = [count(gtis[g, 1] .<= event_times .<= gtis[g, 2])/(gtis[g, 2] - gtis[g, 1]) for g in 1:size(gtis, 1)]
        mask_min_counts = counts_per_gti_sec .>= 1

        @info "Excluded $(size(gtis, 1) - count(mask_min_counts)) gtis under 1 count/sec"

        gtis = gtis[mask_min_counts, :]
    end
    
    return Array(event_times), Array(event_energies), gtis
end

function _lc_filter_energy(event_times::Array{Float64,1}, event_energies::Array{Float64,1}, good_energy_max::Float64, good_energy_min::Float64)
    @info "               -> Filtering energies"
    mask_good_energy = good_energy_min .<= event_energies .<= good_energy_max
    
    event_times = event_times[mask_good_energy]
    event_energies = event_energies[mask_good_energy]

    return event_times, event_energies
end

function _lc_bin(event_times::Array{Float64,1}, bin_time::Union{Float64,Int64}, time_start::Union{Float64,Int64}, time_stop::Union{Float64,Int64})
    @info "               -> Running OoM binning"

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

    times = 0:bin_time:(time_stop-time_start)
    online_hist_fit = Hist(times)

    histogram = fit!(online_hist_fit, event_times)
    counts    = value(histogram)[2]
    times     = times[1:end-1] # One less count than times

    return times, counts
end

function _orbit_select(data::BinnedData)
    orbit_period = 92*60 # Orbital persiod of ISS, used with NICER, TODO: GENERALISE WITH MISSION CONFIG
    orbit_times  = data.gtis[:, 1][findall(diff(data.gtis[:, 2]) .> orbit_period/2)]
    orbit_times  = [orbit_times.-orbit_period/2 orbit_times]
    
    orbit_indecies = [findfirst(x .<= data.times) for x in orbit_times]

    gti_orbit_index = zeros(Int, size(data.gtis, 1))

    for i = 1:size(orbit_indecies, 1)
        gtis_in_orbit = data.gtis[(orbit_times[i, 1] .<= data.gtis[:, 2] .<= orbit_times[i, 2])[:], :]

        gti_orbit_index[orbit_times[i, 1] .<= data.gtis[:, 2] .<= orbit_times[i, 2]] .= i
    end

    data.gtis[:orbit] = gti_orbit_index

    return data
end

function _orbit_return(data::BinnedData)
    gtis = data.gtis
    gtis = gtis[(gtis[:, :stop]-gtis[:, :start]) .>= 16, :] # Ignore gtis under 16s long
    available_orbits = unique(gtis[:orbit])

    data_orbit = Dict{Int64,JAXTAM.BinnedData}()
    for orbit in available_orbits
        if orbit == 0
            end_gti_idx = findfirst(data.gtis[:orbit] .== maximum(available_orbits))

            first_gti_idx = findfirst(data.gtis[:orbit][end_gti_idx:end] .== orbit) + end_gti_idx
            last_gti_idx  = findlast(data.gtis[:orbit][end_gti_idx:end] .== orbit) + end_gti_idx

            if last_gti_idx > size(data.gtis, 1)
                last_gti_idx = size(data.gtis, 1)
            end
        else
            first_gti_idx = findfirst(data.gtis[:orbit] .== orbit)
            last_gti_idx  = findlast(data.gtis[:orbit] .== orbit)
        end

        first_gti = data.gtis[first_gti_idx, :]
        last_gti  = data.gtis[last_gti_idx,  :]

        first_idx = findfirst(data.times .>= first_gti[:start])
        last_idx  = findfirst(data.times .>= last_gti[:stop])

        if last_gti[1, :stop] >= data.times[end]
            last_idx = length(data.times)
        end
        
        data_orbit[orbit] = BinnedData(
            data.mission,
            data.instrument,
            data.obsid,
            data.bin_time,
            data.counts[first_idx:last_idx],
            data.times[first_idx:last_idx],
            data.gtis[first_gti_idx:last_gti_idx, :]
        )
    end

    return data_orbit
end

function _lcurve(instrument_data::InstrumentData, bin_time::Union{Float64,Int64})
    event_times, event_energies, gtis = _lcurve_filter_time(instrument_data.events[:TIME], instrument_data.events[:E], instrument_data.gtis, instrument_data.start, instrument_data.stop)

    mission_name = instrument_data.mission
    good_energy_min, good_energy_max = (Float64(config(mission_name).good_energy_min), Float64(config(mission_name).good_energy_max))

    event_times, event_energies = _lc_filter_energy(event_times, event_energies, good_energy_min, good_energy_max)

    binned_times, binned_counts = _lc_bin(event_times, bin_time, instrument_data.start, instrument_data.stop)

    gtis = DataFrame(start=gtis[:, 1], stop=gtis[:, 2])

    lc = BinnedData(instrument_data.mission, instrument_data.instrument, instrument_data.obsid, bin_time, binned_counts, binned_times, gtis)

    lc = _orbit_select(lc)

    return lc
end

function _lcurve_save(lightcurve_data::BinnedData, lc_dir::String)
    lc_basename = string("$(lightcurve_data.instrument)_lc_$(lightcurve_data.bin_time)")

    lc_meta = DataFrame(mission=string(lightcurve_data.mission), instrument=string(lightcurve_data.instrument),
        obsid=lightcurve_data.obsid, bin_time=lightcurve_data.bin_time, times=[lightcurve_data.times[1], 
        lightcurve_data.times[2] - lightcurve_data.times[1], lightcurve_data.times[end]])

    lc_gtis = lightcurve_data.gtis # DataFrame(start=lightcurve_data.gtis[:, 1], stop=lightcurve_data.gtis[:, 2])

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

    return BinnedData(Symbol(lc_meta[:mission][1]), Symbol(lc_meta[:instrument][1]), lc_meta[:obsid][1], 
        lc_meta[:bin_time][1], lc_data[:counts], lc_meta[:times][1]:lc_meta[:times][2]:lc_meta[:times][3], 
        lc_gtis)
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
        return lcurve(mission_name, obs_row, bin_time; overwrite=overwrite)
    end

    if (JAXTAM_c_files > 0 && JAXTAM_c_files > JAXTAM_lc_files) || (JAXTAM_c_files > 0 && overwrite)
        calibrated_data = calibrate(mission_name, obs_row)
    
        for instrument in instruments
            @info "Binning LCURVE"
            lightcurve_data = _lcurve(calibrated_data[instrument], bin_time)

            @info "               -> Saving `$instrument` $(bin_time)s lightcurve data"

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