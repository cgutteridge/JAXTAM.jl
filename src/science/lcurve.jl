struct BinnedData
    mission::Symbol
    instrument::Symbol
    obsid::String
    bin_time::Real
    counts::SparseVector
    times::StepRangeLen
    gtis::Array{Float64,2}
end

struct GTIData
    mission::Symbol
    instrument::Symbol
    obsid::String
    gti_index::Int
    gti_start_time::Number
    counts::Array
    times::Array
end

function _lcurve_filter_time(event_times, event_energies, gtis, start_time, stop_time, filter_low_count_gtis=true)
    mask_good_times  = start_time .<= event_times .<= stop_time
    
    event_times    = event_times[mask_good_times]
    event_energies = event_energies[mask_good_times]
    
    event_times = event_times .- start_time
    gtis = hcat(gtis[:START], gtis[:STOP])
    gtis = gtis .- start_time

    # WARNING: rounding GTIs up/down to get integers, shouldn't(?) cause a problem
    # TODO: check with Diego
    gtis[:, 1] = ceil.(gtis[:, 1])
    gtis[:, 2] = floor.(gtis[:, 2])

    #counts_per_gti_sec = [count(gtis[g, 1] .<= event_times .<= gtis[g, 2])/(gtis[g, 2] - gtis[g, 1]) for g in 1:size(gtis, 1)]
    #println(counts_per_gti_sec)
    
    return event_times, event_energies, gtis
end

function _lc_filter_energy(event_times, event_energies, good_energy_max, good_energy_min)
    mask_good_energy = good_energy_min .<= event_energies .<= good_energy_max
    
    event_times = event_times[mask_good_energy]
    event_energies = event_energies[mask_good_energy]

    return event_times, event_energies
end

function _lc_bin(event_times, bin_time, time_start, time_stop)
    if bin_time < 1
        if (Int(1/bin_time) & Int((1/bin_time)-1)) != 0
            warn("Bin time not pow2")
        end
    elseif bin_time > 1
        if (bin_time & (bin_time-1)) != 0
            warn("Bin time not pow2")
        end
    elseif bin_time == 0
        error("Bin time cannot be zero")
    end

    binned_histogram = fit(Histogram, event_times, 0:bin_time:(time_stop-time_start), closed=:left)

    counts = sparse(binned_histogram.weights)
    times  = binned_histogram.edges[1][1:length(counts)]
    
    return times, counts
end

function _lcurve(instrument_data, bin_time)
    event_times, event_energies, gtis = _lcurve_filter_time(instrument_data.events[:TIME], instrument_data.events[:E], instrument_data.gtis, instrument_data.start, instrument_data.stop)

    mission_name = instrument_data.mission
    good_energy_min, good_energy_max = (config(mission_name).good_energy_min, config(mission_name).good_energy_max)

    event_times, event_energies = _lc_filter_energy(event_times, event_energies, good_energy_min, good_energy_max)

    binned_times, binned_counts = _lc_bin(event_times, bin_time, instrument_data.start, instrument_data.stop)

    return BinnedData(instrument_data.mission, instrument_data.instrument, instrument_data.obsid, bin_time, binned_counts, binned_times, gtis)
end

function _lcurve_save(lightcurve_data::BinnedData, lc_dir::String)
    lc_basename = string("$(lightcurve_data.instrument)\_lc_$(lightcurve_data.bin_time)")

    lc_meta = DataFrame(mission=string(lightcurve_data.mission), instrument=string(lightcurve_data.instrument), obsid=lightcurve_data.obsid, bin_time=lightcurve_data.bin_time, times=[lightcurve_data.times[1], lightcurve_data.times[2] - lightcurve_data.times[1], lightcurve_data.times[end]])

    lc_gtis = DataFrame(start=lightcurve_data.gtis[:, 1], stop=lightcurve_data.gtis[:, 2])

    lc_data = DataFrame(counts=lightcurve_data.counts)

    Feather.write(joinpath(lc_dir, "$lc_basename\_meta.feather"), lc_meta)
    Feather.write(joinpath(lc_dir, "$lc_basename\_gtis.feather"), lc_gtis)
    Feather.write(joinpath(lc_dir, "$lc_basename\_data.feather"), lc_data)
end

function _lc_read(lc_dir::String, instrument::Symbol, bin_time)
    lc_basename = string("$(instrument)\_lc_$(string(bin_time))")

    lc_meta = Feather.read(joinpath(lc_dir, "$lc_basename\_meta.feather"))
    lc_gtis = Feather.read(joinpath(lc_dir, "$lc_basename\_gtis.feather"))
    lc_data = Feather.read(joinpath(lc_dir, "$lc_basename\_data.feather"))

    return BinnedData(Symbol(lc_meta[:mission][1]), Symbol(lc_meta[:instrument][1]), lc_meta[:obsid][1], lc_meta[:bin_time][1], lc_data[:counts], lc_meta[:times][1]:lc_meta[:times][2]:lc_meta[:times][3], hcat(lc_gtis[:start], lc_gtis[:stop]))
end

function lcurve(mission_name::Symbol, obs_row::DataFrame, bin_time::Number; overwrite=false)
    obsid          = obs_row[:obsid][1]
    JAXTAM_path    = abspath(string(obs_row[:obs_path][1], "/JAXTAM/"))
    JAXTAM_content = readdir(JAXTAM_path)
    JAXTAM_lc_path = joinpath(JAXTAM_path, "lc/$bin_time/")
    
    mkpath(JAXTAM_lc_path)
    
    JAXTAM_c_files  = count(contains.(JAXTAM_content, "calib"))
    JAXTAM_lc_files = Int(count(contains.(readdir(JAXTAM_lc_path), "lc_"))/3)

    instruments = Symbol.(config(mission_name).instruments)

    lightcurves = Dict{Symbol,BinnedData}()

    if (JAXTAM_c_files > 0 && JAXTAM_c_files > JAXTAM_lc_files) || (JAXTAM_c_files > 0 && overwrite)
        calibrated_data = calibrate(mission_name, obs_row)
    
        for instrument in instruments
            lightcurve_data = _lcurve(calibrated_data[instrument], bin_time)

            info("Saving $instrument $bin_time\s lightcurve data")

            _lcurve_save(lightcurve_data, JAXTAM_lc_path)

            lightcurves[instrument] = lightcurve_data
        end
    elseif JAXTAM_c_files > 0 && JAXTAM_c_files == JAXTAM_lc_files
        info("Loading LC $(obsid): from $JAXTAM_lc_path")

        for instrument in instruments
            return _lc_read(JAXTAM_lc_path, instrument, bin_time)
            lightcurves[instrument] = _lc_read(JAXTAM_lc_path, instrument, bin_time)
        end
    end
    
    return lightcurves
end

function lcurve(mission_name::Symbol, obsid::String, bin_time::Number; overwrite=false)
    obs_row = JAXTAM.master_query(mission_name, :obsid, obsid)

    return lcurve(mission_name, obs_row, bin_time; overwrite=overwrite)
end

function _lc_filter_gtis(binned_times, binned_counts, gtis, time_start, time_stop, mission, instrument, obsid; min_gti_sec=5)
    # Dodgy way to convert a matrix into an array of arrays
    # so each GTI is stored as an array of [start; finish]
    # and each of those GTI arrays is an array itself
    # makes life a bit easier for the following `for gti in gtis` loop
    gtis = [gtis[x, :] for x in 1:size(gtis, 1)]

    gti_data = Array{GTIData,1}()

    bin_time = binned_times[2] - binned_times[1]

    excluded_gti_count = 0

    for (i, gti) in enumerate(gtis) # For each GTI, store the selected times and count rate within that GTI
        start = findfirst(binned_times .> gti[1])-1
        stop  = findfirst(binned_times .>= gti[2])-1 # >= required for -1 to not overshoot

        if (stop-start)*bin_time > min_gti_sec
            append!(gti_data, [GTIData(mission, instrument, obsid, i, start, binned_counts[start:stop], binned_times[start:stop].-gti[1])]) # Subtract GTI start time from all times, so all start from t=0
        else
            excluded_gti_count += 1
        end
    end

    total_counts = sum(binned_counts)[1]
    gti_counts   = sum([sum(gti.counts) for gti in gti_data])
    count_delta  = gti_counts-total_counts
    delta_prcnt  = round(count_delta/total_counts*100, 2)

    info("Original counts: $total_counts, counts in GTI: $gti_counts, delta: $count_delta ($delta_prcnt %)")

    if excluded_gti_count > 0
        warn("Excluded $excluded_gti_count gtis < $(min_gti_sec)s")
    end

    if abs(count_delta) > 0.1*total_counts
        warn("Count delta > 0.1% of total counts")
    end

    return gti_data
end

function _gtis(lc::BinnedData)
    gti_data = _lc_filter_gtis(lc.times, lc.counts, lc.gtis, lc.times[1], lc.times[end], lc.mission, lc.instrument, lc.obsid)

    return gti_data
end