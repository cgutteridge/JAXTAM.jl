
function _lc_filter_gtis(binned_times, binned_counts, gtis, time_start, time_stop, mission, instrument, obsid; min_gti_sec=5)
    # Dodgy way to convert a matrix into an array of arrays
    # so each GTI is stored as an array of [start; finish]
    # and each of those GTI arrays is an array itself
    # makes life a bit easier for the following `for gti in gtis` loop
    gtis = [gtis[x, :] for x in 1:size(gtis, 1)]

    gti_data = Dict{Int,GTIData}()

    bin_time = binned_times[2] - binned_times[1]

    excluded_gti_count = 0

    for (i, gti) in enumerate(gtis) # For each GTI, store the selected times and count rate within that GTI
        if gti[2] > binned_times[end]
            if gti[2]-1 <= binned_times[end]
                gti[2] = gti[2]-1
            else
                @error "GTI out of bounds\nContact developer for fix"
            end
        end
        start = findfirst(binned_times .> gti[1])
        stop  = findfirst(binned_times .>= gti[2])-1 # >= required for -1 to not overshoot

        if start == 0 || stop > length(binned_times) || start > stop
            @warn "GTI start/stop times invalid, skipping: start: $start | stop: $stop | length: $(length(binned_times))"
        else
            if (stop-start)*bin_time > min_gti_sec
                # Subtract GTI start time from all times, so all start from t=0
                array_times = binned_times[start:stop].-gti[1]
                range_times = array_times[1]:bin_time:array_times[end]

                gti_data[Int(i)] = GTIData(mission, instrument, obsid, bin_time, i, start, 
                    binned_counts[start:stop], range_times)
            else
                excluded_gti_count += 1
            end
        end
    end

    total_counts = sum(binned_counts)[1]
    gti_counts   = sum([sum(gti.counts) for gti in values(gti_data)])
    count_delta  = gti_counts-total_counts
    delta_prcnt  = round(count_delta/total_counts*100, digits=2)

    @info "Original counts: $total_counts, counts in GTI: $gti_counts, delta: $count_delta ($delta_prcnt %)"

    if excluded_gti_count > 0
        @warn "Excluded $excluded_gti_count gtis (< $(min_gti_sec)s) out of $(size(gtis, 1))"
    end

    if abs(count_delta) > 0.1*total_counts
        @warn "Count delta > 0.1% of total counts"
    end

    return gti_data
end

function _gtis(lc::BinnedData)
    gti_data = _lc_filter_gtis(lc.times, lc.counts, lc.gtis, lc.times[1], lc.times[end], lc.mission, lc.instrument, lc.obsid)

    return gti_data
end

function _gtis_save(gtis, gti_dir::String)
    gti_indecies = [k for k in keys(gtis)]
    gti_starts   = [t.gti_start_time for t in values(gtis)]
    gti_example  = gtis[gti_indecies[1]]

    gti_basename = string("$(gti_example.instrument)_lc_$(gti_example.bin_time)_gti")
    gtis_meta    = DataFrame(mission=String(gti_example.mission), instrument=String(gti_example.instrument), obsid=gti_example.obsid, bin_time=gti_example.bin_time, indecies=gti_indecies, starts=gti_starts)

    Feather.write(joinpath(gti_dir, "$(gti_basename)_meta.feather"), gtis_meta)

    for index in gti_indecies
        gti_savepath = joinpath(gti_dir, "$(gti_basename)_$(index).feather")
        Feather.write(gti_savepath, DataFrame(counts=gtis[index].counts, times=gtis[index].times))
    end
end

function _gtis_load(gti_dir, instrument, bin_time)
    bin_time = float(bin_time)

    gti_basename  = string("$(instrument)_lc_$(bin_time)_gti")
    gti_meta_path = joinpath(gti_dir, "$(gti_basename)_meta.feather")

    gti_meta = Feather.read(gti_meta_path)

    gti_data = Dict{Int,GTIData}()

    for row_idx in 1:size(gti_meta, 1)
        current_row = gti_meta[row_idx, :]
        gti_mission = current_row[:mission][1]
        gti_inst    = current_row[:instrument][1]
        gti_obsid   = current_row[:obsid][1]
        gti_bin_t   = current_row[:bin_time][1]
        gti_idx     = current_row[:indecies][1]
        gti_starts  = current_row[:starts][1]
        current_gti = Feather.read(joinpath(gti_dir, "$(gti_basename)_$(gti_idx).feather"))
        gti_counts  = current_gti[:counts]
        gti_times   = current_gti[:times]
        gti_times   = gti_times[1]:gti_bin_t:gti_times[end] # Convert Array to Step Range
        

        gti_data[gti_idx] = GTIData(gti_mission, gti_inst, gti_obsid, gti_bin_t, gti_idx, gti_starts, gti_counts, gti_times)
    end

    return gti_data
end

function gtis(mission_name::Symbol, obs_row::DataFrames.DataFrame, bin_time::Number; overwrite=false)
    obsid              = obs_row[:obsid][1]
    instruments        = config(mission_name).instruments

    JAXTAM_path        = abspath(string(obs_row[:obs_path][1], "/JAXTAM/"))
    JAXTAM_lc_path     = joinpath(JAXTAM_path, "lc/$bin_time/"); mkpath(JAXTAM_lc_path)
    JAXTAM_lc_content  = readdir(JAXTAM_path)
    JAXTAM_gti_path    = joinpath(JAXTAM_path, "lc/$bin_time/gtis/"); mkpath(JAXTAM_gti_path)
    JAXTAM_gti_content = readdir(JAXTAM_gti_path)
    JAXTAM_gti_metas   = Dict([Symbol(inst) => joinpath(JAXTAM_gti_path, "$(inst)_lc_$(float(bin_time))_gti_meta.feather") for inst in instruments])
    JAXTAM_all_metas   = unique([isfile(meta) for meta in values(JAXTAM_gti_metas)])

    if JAXTAM_all_metas != [true] || overwrite
        @info "Not all GTI metas found"
        lc = lcurve(mission_name, obs_row, bin_time)
    end
    
    instrument_gtis = Dict{Symbol,Dict{Int64,JAXTAM.GTIData}}() # DataStructures.OrderedDict{Int64,JAXTAM.GTIData}

    for instrument in instruments
        if !isfile(JAXTAM_gti_metas[Symbol(instrument)]) || overwrite
            @info "Computing `$instrument GTIs`"

            gtis_data = _gtis(lc[Symbol(instrument)])

            @info "Saving `$instrument GTIs`"
            _gtis_save(gtis_data, JAXTAM_gti_path)

            instrument_gtis[Symbol(instrument)] = gtis_data
        else
            @info "Loading `$instrument GTIs`"
            instrument_gtis[Symbol(instrument)] = _gtis_load(JAXTAM_gti_path, instrument, bin_time)
        end
    end

    return instrument_gtis
end

function gtis(mission_name::Symbol, obsid::String, bin_time::Number; overwrite=false)
    obs_row = master_query(mission_name, :obsid, obsid)

    return gtis(mission_name, obs_row, bin_time, overwrite=overwrite)
end