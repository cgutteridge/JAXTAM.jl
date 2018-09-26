struct GTIData <: JAXTAMData
    mission::Symbol
    instrument::Symbol
    obsid::String
    bin_time::Real
    gti_index::Int
    gti_start_time::Real
    counts::Array
    times::StepRangeLen
    orbit::Int
end

"""
    _lc_filter_gtis(binned_times::StepRangeLen, binned_counts::Array{Int,1}, gtis::DataFrames.DataFrame, mission::Symbol, instrument::Symbol, obsid::String; min_gti_sec=16)

Splits the lightcurve (count) data into GTIs

First, removes GTIs under `min_gti_sec`, then puts the lightcurve data 
into a `Dict{Int,GTIData}`, with the key as the `index` of the GTI
"""
function _lc_filter_gtis(binned_times::StepRangeLen, binned_counts::Array{Int,1}, gtis::DataFrames.DataFrame, mission::Symbol, instrument::Symbol, obsid::String; min_gti_sec=16)
    gti_data = Dict{Int,GTIData}()

    gti_orbits = gtis[:orbit]
    gti_times  = hcat(gtis[:start], gtis[:stop])
    
    bin_time = binned_times[2] - binned_times[1]
    
    gti_mask = (gtis[:stop] .- gtis[:start]) .>= min_gti_sec # Exclude GTIs under `min_gti_sec`
    gti_times[gti_mask.==false, :] .= -1 # Set excluded GTIs to -1, GTIs aren't just discarded so that their absolute index can be kept track of

    excluded_gti_count = count(gti_mask.==false)

    @info "               -> prelim. excluded $excluded_gti_count GTIs under $(min_gti_sec)s"

    # Do this as the first GTI being zero screws with the initial start index
    # in the upcoming `for gtis` loop
    if gti_times[1, 1] == 0
        gti_times[1, 1] = eps()
    end

    # Dodgy way to convert a matrix into an array of arrays
    # so each GTI is stored as an array of [start; finish]
    # and each of those GTI arrays is an array itself
    # makes life a bit easier for the following `for gti in gtis` loop
    gti_times = [gti_times[x, :] for x in 1:size(gti_times, 1)]

    @info "               -> sorting GTIs"

    # Offset if binned_times are a subarray of the lightcurve
    if typeof(binned_times) <: SubArray
        subarray_offset = binned_times.offset1
    else
        subarray_offset = 0
    end

    for (i, gti) in enumerate(gti_times) # For each GTI, store the selected times and count rate within that GTI
        if gti[1] == -1 # Short GTIs have their start time set to -1, skipped here
            continue
        end
        
        start = ceil(Int, gti[1]/bin_time)+1 - subarray_offset
        stop  = floor(Int, gti[2]/bin_time)-1 - subarray_offset

        # Subtract GTI start time from all times, so all start from t=0
        array_times = binned_times[start:stop].-gti[1]
        range_times = array_times[1]:bin_time:array_times[end]

        gti_data[Int(i)] = GTIData(mission, instrument, obsid, bin_time, i, start, 
            binned_counts[start:stop], range_times, gti_orbits[i])
    end

    total_counts = sum(binned_counts)[1]
    gti_counts   = sum([sum(gti.counts) for gti in values(gti_data)])
    count_delta  = gti_counts-total_counts
    delta_prcnt  = round(count_delta/total_counts*100, digits=2)

    @info "               -> original counts: $total_counts | remaining: $gti_counts | delta: $count_delta ($delta_prcnt %)"

    if delta_prcnt > 10
        @warn "Count delta > 10% of total counts"
    end

    return gti_data
end

"""
    _gtis(lc::BinnedData)

Calls `_lc_filter_gtis` using `BinnedData` input
"""
function _gtis(lc::BinnedData)
    gti_data = _lc_filter_gtis(lc.times, lc.counts, lc.gtis, lc.mission, lc.instrument, lc.obsid)

    return gti_data
end

"""
    _gtis_save(gtis, gti_dir::String)

Splits up the GTI data into a `_meta.feather` file containing non-array variables for each GTI (index, start/stop times, etc...) 
and multiple `_gti.feather` files for each GTI containing the counts and times
"""
function _gtis_save(gtis, gti_dir::String)
    gti_indecies = [k for k in keys(gtis)]
    gti_starts   = [t.gti_start_time for t in values(gtis)]
    gti_example  = gtis[gti_indecies[1]]
    gti_orbits   = [o.orbit for o in values(gtis)]

    gti_basename = string("$(gti_example.instrument)_lc_$(gti_example.bin_time)_gti")
    gtis_meta    = DataFrame(mission=String(gti_example.mission), instrument=String(gti_example.instrument),
        obsid=gti_example.obsid, bin_time=gti_example.bin_time, indecies=gti_indecies, starts=gti_starts, orbits=gti_orbits)

    Feather.write(joinpath(gti_dir, "$(gti_basename)_meta.feather"), gtis_meta)

    for index in gti_indecies
        gti_savepath = joinpath(gti_dir, "$(gti_basename)_$(index).feather")
        Feather.write(gti_savepath, DataFrame(counts=gtis[index].counts, times=gtis[index].times))
    end
end

"""
    _gtis_load(gti_dir, instrument, bin_time)

Loads and parses the `_meta` and `_gti` files, puts into a `GTIData` constructor, returns `Dict{Int,GTIData}`
"""
function _gtis_load(gti_dir, instrument, bin_time)
    bin_time = float(bin_time)

    gti_basename  = string("$(instrument)_lc_$(bin_time)_gti")
    gti_meta_path = joinpath(gti_dir, "$(gti_basename)_meta.feather")

    gti_meta = Feather.read(gti_meta_path)

    gti_data = Dict{Int,GTIData}()

    for row_idx in 1:size(gti_meta, 1)
        current_row = gti_meta[row_idx, :]
        gti_mission = Symbol(current_row[:mission][1])
        gti_inst    = Symbol(current_row[:instrument][1])
        gti_obsid   = current_row[:obsid][1]
        gti_bin_t   = current_row[:bin_time][1]
        gti_idx     = current_row[:indecies][1]
        gti_starts  = current_row[:starts][1]
        current_gti = Feather.read(joinpath(gti_dir, "$(gti_basename)_$(gti_idx).feather"))
        gti_counts  = current_gti[:counts]
        gti_times   = current_gti[:times]
        gti_times   = gti_times[1]:gti_bin_t:gti_times[end] # Convert Array to Step Range
        gti_orbit   = current_row[:orbits][1]
        
        gti_data[gti_idx] = GTIData(gti_mission, gti_inst, gti_obsid, gti_bin_t, gti_idx,
            gti_starts, gti_counts, gti_times, gti_orbit)
    end

    return gti_data
end

"""
    gtis(mission_name::Symbol, obs_row::DataFrames.DataFrame, bin_time::Number; overwrite=false)

Handles file management, checks to see if GTI files exist already and loads them, if files do not 
exist then the `_gits` function is ran, then the data is saved
"""
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
    
    @info "Selecting GTIs"

    if JAXTAM_all_metas != [true] || overwrite
        @info "               -> not all GTI metas found"
        lc = lcurve(mission_name, obs_row, bin_time)
    end
    
    instrument_gtis = Dict{Symbol,Dict{Int64,JAXTAM.GTIData}}() # DataStructures.OrderedDict{Int64,JAXTAM.GTIData}

    for instrument in instruments
        if !isfile(JAXTAM_gti_metas[Symbol(instrument)]) || overwrite
            @info "               -> $instrument GTIs"

            gtis_data = _gtis(lc[Symbol(instrument)])

            @info "               -> saving `$instrument GTIs`"
            _gtis_save(gtis_data, JAXTAM_gti_path)

            instrument_gtis[Symbol(instrument)] = gtis_data
        else
            @info "               -> loading `$instrument GTIs`"
            instrument_gtis[Symbol(instrument)] = _gtis_load(JAXTAM_gti_path, instrument, bin_time)
        end
    end

    return instrument_gtis
end

"""
    gtis(mission_name::Symbol, obsid::String, bin_time::Number; overwrite=false)

Runs `master_query` to load the `obs_row` for a given `obsid`, runs main `gits` function
"""
function gtis(mission_name::Symbol, obsid::String, bin_time::Number; overwrite=false)
    obs_row = master_query(mission_name, :obsid, obsid)

    return gtis(mission_name, obs_row, bin_time, overwrite=overwrite)
end