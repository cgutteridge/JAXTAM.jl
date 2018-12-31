struct BinnedData <: JAXTAMData
    mission::Symbol
    instrument::Symbol
    obsid::String
    bin_time::Real
    counts::Array{Int,1}
    times::StepRangeLen
    gtis::DataFrames.DataFrame
end

"""
    _lcurve_filter_time(event_times::Arrow.Primitive{Float64}, event_energies::Arrow.Primitive{Float64},

Largely not used, as the GTI filtering is enough to deal with out-of-time-range events, and 
manually filtering those events out early is computationally intensive

Function takes in event times and energies, then filters any events outside of the `start` and `stop` times

Optionally performs early filtering to remove low count (under 1/sec) GTIs, disabled by default as this is 
performed later anyway

Returns array of filtered times, enegies, and GTIs
"""
function _lcurve_filter_time(event_times::Union{Array{<:AbstractFloat,1},Arrow.Primitive{<:AbstractFloat}}, event_energies::Union{Array{<:AbstractFloat,1},Arrow.Primitive{<:AbstractFloat}},
    gtis::DataFrames.DataFrame, start_time::Union{<:AbstractFloat,Int64}, stop_time::Union{<:AbstractFloat,Int64}, filter_low_count_gtis=false)
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

"""
    _lc_filter_energy(event_times::Array{Float64,1}, event_energies::Array{Float64,1}, good_energy_max::Float64, good_energy_min::Float64)

Optionally filters events by a custom energy range, not just that given in the RMF files for a mission

Returns filtered event times and energies
"""
function _lc_filter_energy(event_times::Array{<:AbstractFloat,1}, event_energies::Array{<:AbstractFloat,1}, good_energy_min::Float64, good_energy_max::Float64)
    @info "               -> Filtering energies"
    mask_good_energy = good_energy_min .<= event_energies .<= good_energy_max

    @info "               -> excluded $(count(mask_good_energy.==false)) energies out of $good_energy_min -> $good_energy_max range"
    
    event_times = event_times[mask_good_energy]
    event_energies = event_energies[mask_good_energy]

    return event_times, event_energies
end

"""
    _lc_bin(event_times::Array{Float64,1}, bin_time::Union{Float64,Int64}, time_start::Union{Float64,Int64}, time_stop::Union{Float64,Int64})

Bins the event times to bins of `bin_time` [sec] lengths

Performs binning out of memory for speed via `OnlineStats.jl` Hist function

Returns a range of `times`, with associated `counts` per time
"""
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
    online_hist_fit = OnlineStats.Hist(times)

    histogram = fit!(online_hist_fit, event_times)
    counts    = value(histogram)[2]
    times     = times[1:end-1] # One less count than times

    return times, counts
end

"""
    _group_select(data::BinnedData)

Checks the differennce in time between GTIs, if the difference is under 
a `group_period` (128 [sec] by default) then the GTIs are in the same `group`

Done as data frequently has small breaks between GTIs, even though there is no 
significant gap in the lightcurve. Groups are used during plotting, periodograms, 
and when grouping/averaging together power spectra

Returns GTIs with an extra `:group` column added in
"""
function _group_select(data::BinnedData)
    group_period = 128

    gti_gap_time = data.gtis[:start][2:end] .- data.gtis[:stop][1:end-1]
    gti_gap_time = [0; gti_gap_time]

    gti_group_index = zeros(Int, size(data.gtis, 1))

    group = 1
    for (i, gap) in enumerate(gti_gap_time)
        if gap > group_period
            group = group + 1
        end

        gti_group_index[i] = group
    end

    data.gtis[:group] = gti_group_index

    return data
end

"""
    _group_return(data::BinnedData)

Uses the `_group_select` function to find the group each GTI belongs in

Using these groups, splits sections of light curve up into an group, then 
creates a new `BinnedData` for just the lightcurve of that one group, finally 
returns a `Dict{Int64,JAXTAM.BinnedData}` where each `Int64` is for a different group
"""
function _group_return(data::BinnedData; min_length_sec=16)
    gtis = data.gtis
    gtis = gtis[(gtis[:, :stop]-gtis[:, :start]) .>= min_length_sec, :]
    available_groups = unique(gtis[:group])

    data_group = Dict{Int64,JAXTAM.BinnedData}()
    for group in available_groups
        if group == 0
            end_gti_idx = findfirst(data.gtis[:group] .== maximum(available_groups))

            first_gti_idx = findfirst(data.gtis[:group][end_gti_idx:end] .== group) + end_gti_idx
            last_gti_idx  = findlast(data.gtis[:group][end_gti_idx:end] .== group) + end_gti_idx

            if last_gti_idx > size(data.gtis, 1)
                last_gti_idx = size(data.gtis, 1)
            end
        else
            first_gti_idx = findfirst(data.gtis[:group] .== group)
            last_gti_idx  = findlast(data.gtis[:group] .== group)
        end

        first_gti = data.gtis[first_gti_idx, :]
        last_gti  = data.gtis[last_gti_idx,  :]

        first_idx = findfirst(data.times .>= first_gti[:start])
        last_idx  = findfirst(data.times .>= last_gti[:stop])

        if last_gti[1, :stop] >= data.times[end]
            last_idx = length(data.times)
        end
        
        data_group[group] = BinnedData(
            data.mission,
            data.instrument,
            data.obsid,
            data.bin_time,
            data.counts[first_idx:last_idx],
            data.times[first_idx:last_idx],
            data.gtis[first_gti_idx:last_gti_idx, :]
        )
    end

    return data_group
end

"""
    _lcurve(instrument_data::InstrumentData, bin_time::Union{Float64,Int64})

Takes in the `InstrumentData` and desired `bin_time`

Runs functions to perform extra time (`_lcurve_filter_time`) and energy (`_lc_filter_energy`) filtering

Runs the binning (`_lc_bin`) function, then finally `_group_select` to append group numbers to each GTI

Returns a `BinnedData` lightcurve
"""
function _lcurve(instrument_data::InstrumentData, bin_time::Union{Float64,Int64})
    event_times, event_energies, gtis = _lcurve_filter_time(instrument_data.events[:TIME], instrument_data.events[:E], instrument_data.gtis, instrument_data.start, instrument_data.stop)

    mission_name = instrument_data.mission
    good_energy_min, good_energy_max = (Float64(config(mission_name).good_energy_min), Float64(config(mission_name).good_energy_max))

    event_times, event_energies = _lc_filter_energy(event_times, event_energies, good_energy_min, good_energy_max)

    binned_times, binned_counts = _lc_bin(event_times, bin_time, instrument_data.start, instrument_data.stop)

    gtis = DataFrame(start=gtis[:, 1], stop=gtis[:, 2])

    lc = BinnedData(instrument_data.mission, instrument_data.instrument, instrument_data.obsid, bin_time, binned_counts, binned_times, gtis)

    lc = _group_select(lc)

    return lc
end

"""
    _lcurve_save(lightcurve_data::BinnedData, lc_dir::String)

Takes in `BinnedData` and splits the information up into three files, `meta`, `gtis`, and `data`

Saves the files in a lightcurve directory (`/JAXTAM/lc/\$bin_time/*`) per-instrument
"""
function _lcurve_save(mission_name::Symbol, obs_row::DataFrames.DataFrame, instrument::Union{String,Symbol}, e_range::Tuple, bin_time::Union{String,Real},
        lcurve_dir::String, lightcurve_data::BinnedData; log=true)
    @info "               -> Saving `$instrument` $(lightcurve_data.bin_time)s lightcurve data"
    mkpath(lcurve_dir)

    lc_basename = string("$(lightcurve_data.instrument)_lc_$(lightcurve_data.bin_time)")

    lc_meta = DataFrame(mission=string(lightcurve_data.mission), instrument=string(lightcurve_data.instrument),
        obsid=lightcurve_data.obsid, bin_time=lightcurve_data.bin_time, times=[lightcurve_data.times[1], 
        lightcurve_data.times[2] - lightcurve_data.times[1], lightcurve_data.times[end]])

    lc_gtis = lightcurve_data.gtis # DataFrame(start=lightcurve_data.gtis[:, 1], stop=lightcurve_data.gtis[:, 2])

    lc_data = DataFrame(counts=lightcurve_data.counts)

    path_meta = joinpath(lcurve_dir, "$(lc_basename)_meta.feather")
    path_gtis = joinpath(lcurve_dir, "$(lc_basename)_gtis.feather")
    path_data = joinpath(lcurve_dir, "$(lc_basename)_data.feather")

    Feather.write(path_meta, lc_meta)
    Feather.write(path_gtis, lc_gtis)
    Feather.write(path_data, lc_data)

    if log
        _log_add(mission_name, obs_row, 
            Dict("data" =>
                Dict(:lcurve =>
                    Dict(e_range =>
                        Dict(bin_time =>
                            Dict(instrument =>
                                Dict(
                                    :path_data => path_data,
                                    :path_gtis => path_gtis,
                                    :path_meta => path_meta,
                                )
                            )
                        )
                    )
                )
            )
        )
    end

    @info "               -> Saving `$instrument` $(lightcurve_data.bin_time)s lightcurve data finished"
end

"""
    _lc_read(lc_dir::String, instrument::Symbol, bin_time)

Reads the split files saved by `_lcurve_save`, combines them to return a single `BinnedData` type
"""
function _lc_read(lc_dir::String, instrument::Symbol, bin_time)
    @info "Loading `$instrument` lightcurve data"
    lc_basename = string("$(instrument)_lc_$(string(bin_time))")

    lc_meta = Feather.read(joinpath(lc_dir, "$(lc_basename)_meta.feather"))
    lc_gtis = Feather.read(joinpath(lc_dir, "$(lc_basename)_gtis.feather"))
    lc_data = Feather.read(joinpath(lc_dir, "$(lc_basename)_data.feather"))

    bd = BinnedData(Symbol(lc_meta[:mission][1]), Symbol(lc_meta[:instrument][1]), lc_meta[:obsid][1], 
        lc_meta[:bin_time][1], lc_data[:counts], lc_meta[:times][1]:lc_meta[:times][2]:lc_meta[:times][3], 
        lc_gtis)

    @info "Loading `$instrument` lightcurve data finished"

    return bd
end

"""
    lcurve(mission_name::Symbol, obs_row::DataFrame, bin_time::Number; overwrite=false)

Main function, handles all the lightcurve binning

Runs binning functions if no files are found, then saves the generated `BinnedData`

Loads saved files if they exist

Returns `Dict{Symbol,BinnedData}`, with the instrument as a symbol, e.g. `lc[:XTI]` for NICER, 
`lc[:FPMA]`/`lc[:FPMB]` for NuSTAR
"""
function lcurve(mission_name::Symbol, obs_row::DataFrame, bin_time::Number; overwrite=false,
        calibrated_data::Dict{Symbol,JAXTAM.InstrumentData}=Dict{Symbol,InstrumentData}())
    obsid       = obs_row[:obsid][1]
    instruments = Symbol.(config(mission_name).instruments)
    e_range     = (config(mission_name).good_energy_min, config(mission_name).good_energy_max)
    bin_time_p2 = "2pow$(Int(log2(bin_time)))"
    lc_files    = _log_query(mission_name, obs_row, "data", :lcurve, e_range, bin_time_p2)

    lc_path = abspath(obs_row[1, :obs_path], "JAXTAM", _log_query_path(; category=:data, kind=:lcurve, e_range=e_range, bin_time=bin_time))

    lightcurves = Dict{Symbol,BinnedData}()
    for instrument in instruments
        if ismissing(lc_files) || !haskey(lc_files, instrument) || overwrite
            @info "Missing lcurve files for $instrument"
            
            if !all(haskey.(calibrated_data, instruments))
                calibrated_data = calibrate(mission_name, obs_row)
            end

            @info "Generating lcurve files for $instrument"
            lightcurve_data = _lcurve(calibrated_data[instrument], bin_time)

            _lcurve_save(mission_name, obs_row, instrument, e_range, bin_time_p2, lc_path, lightcurve_data)

            lightcurves[instrument] = lightcurve_data
        else
            lightcurves[instrument] = _lc_read(lc_path, instrument, bin_time)
        end
    end

    if ismissing(_log_query(mission_name, obs_row, "meta", :countrates, e_range))
        @info "Computing countrates for $e_range keV, this  may take a while"
        countrates = Dict{Symbol,Float64}()
        for instrument in instruments
            gtis = [[gti[:start], gti[:stop]] for gti in DataFrames.eachrow(lightcurves[instrument].gtis) if sum([gti[:start], gti[:stop]]) > 1]

            counts = 0
            for gti in gtis
                start_idx = findfirst(lightcurves[instrument].times .>= gti[1])
                stop_idx  = findfirst(lightcurves[instrument].times .>= gti[2])

                if stop_idx == nothing && gti[2] == gtis[end][2]
                    stop_idx = length(lightcurves[instrument].counts)
                end

                counts += sum(lightcurves[instrument].counts[start_idx:stop_idx])
            end

            countrates[instrument] = counts/sum(diff.(gtis))[1]
        end
        _log_add(mission_name, obs_row, Dict("meta" => Dict(:countrates => Dict(e_range => countrates))))
    end

    return lightcurves
end

"""
    lcurve(mission_name::Symbol, obsid::String, bin_time::Number; overwrite=false)

Runs `master_query` to find the desired `obs_row` for the observation

Calls main `lcurve(mission_name::Symbol, obs_row::DataFrame, bin_time::Number; overwrite=false)` function
"""
function lcurve(mission_name::Symbol, obsid::String, bin_time::Number; overwrite=false)
    obs_row = JAXTAM.master_query(mission_name, :obsid, obsid)

    return lcurve(mission_name, obs_row, bin_time; overwrite=overwrite)
end