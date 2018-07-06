struct BinnedData
    obsid::String
    bin_time::Real
    counts::SparseVector
    times::StepRangeLen
    gtis::Array{Float64,2}
end


function _lcurve_filter_time(event_times, event_energies, gtis, start_time, stop_time)
    mask_good_times  = start_time .<= event_times .<= stop_time
    
    event_times    = event_times[mask_good_times]
    event_energies = event_energies[mask_good_times]
    
    event_times = event_times .- start_time
    gtis = hcat(gtis[:START], gtis[:STOP])
    gtis = gtis .- start_time
    
    return event_times, event_energies, gtis
end

function _lc_filter_energy(event_times, event_energies, good_energy_max, good_energy_min)
    mask_good_energy = good_energy_min .<= event_energies .<= good_energy_max
    
    event_times = event_times[mask_good_energy]
    event_energies = event_energies[mask_good_energy]

    return event_times, event_energies
end

function _lc_bin(event_times, bin_time, time_start, time_stop)
    if bin_time < 0
        if (1/bin_time & ((1/bin_time)-1)) != 0
            warn("Bin time not pow2")
        end
    elseif bin_time > 0
        if (bin_time & (bin_time-1)) != 0
            warn("Bin time not pow2")
        end
    elseif bin_time == 0
        error("Bin time cannot be zero")
    end

    binned_histogram = fit(Histogram, event_times, 0:bin_time:(time_stop-time_start), closed=:right)

    counts = sparse(binned_histogram.weights)
    times  = binned_histogram.edges[1]
    
    return times, counts
end

function _lc_filter_gtis(binned_times, binned_counts, gtis, time_start, time_stop)
    # Dodgy way to convert a matrix into an array of arrays
    # so each GTI is stored as an array of [start; finish]
    # and each of those GTI arrays is an array itself
    # makes life a bit easier for the following `for gti in gtis` loop
    gtis = [gtis[x, :] for x in 1:size(gtis, 1)]

    counts_in_gti = Array{Array{Int,1},1}()
    times_in_gti  = Array{Array{Float64,1},1}()

    bin_time = binned_times[2] - binned_times[1]

    excluded_gti_count = 0

    for gti in gtis # For each GTI, store the selected times and count rate within that GTI
        start = findfirst(binned_times .>= gti[1])
        stop  = findfirst(binned_times .>= gti[2])-1

        if (stop-start)*bin_time > 30
            append!(counts_in_gti, [binned_counts[start:stop]])
            append!(times_in_gti, [binned_times[start:stop].-gti[1]]) # Subtract GTI start time from all times, so all start from t=0
        else
            excluded_gti_count += 1
        end
    end

    total_counts = sum(binned_counts)[1]
    gti_counts   = sum(sum.(counts_in_gti))
    count_delta  = gti_counts-total_counts

    info("Original counts: $total_counts, counts in GTI: $gti_counts, delta: $count_delta")

    if excluded_gti_count > 0
        warn("Excluded $excluded_gti_count gtis < 30s")
    end

    if abs(count_delta) > 0.1*total_counts
        warn("Count delta > 0.1% of total counts")
    end

    return counts_in_gti, times_in_gti
end

function _lcurve2(instrument_data, bin_time)
    event_times, event_energies, gtis = _lcurve_filter_time(instrument_data.events[:TIME], instrument_data.events[:E], instrument_data.gtis, instrument_data.start, instrument_data.stop)

    mission_name = instrument_data.mission
    good_energy_min, good_energy_max = (config(mission_name).good_energy_min, config(mission_name).good_energy_max)

    event_times, event_energies = _lc_filter_energy(event_times, event_energies, good_energy_min, good_energy_max)

    binned_times, binned_counts = _lc_bin(event_times, bin_time, instrument_data.start, instrument_data.stop)

    counts_in_gti, times_in_gti = _lc_filter_gtis(binned_times, binned_counts, gtis, instrument_data.start, instrument_data.stop)
end

function _lcurve(instrument_data, bin_time)
    event_times = instrument_data.events[:TIME]
    event_energies = instrument_data.events[:E]

    start = instrument_data.start
    stop  = instrument_data.stop
    
    times_zeroed = times_in_range .- start

    gtis = hcat(instrument_data.gtis[:START], instrument_data.gtis[:STOP])
    gtis = gtis .- start

    return BinnedData(instrument_data.obsid, bin_time, sparse(counts.weights), counts.edges[1], gtis)
end

