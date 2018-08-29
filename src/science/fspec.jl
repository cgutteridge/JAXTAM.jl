struct FFTData <: JAXTAMData
    mission::Symbol
    instrument::Symbol
    obsid::String
    bin_time::Real
    bin_size::Int
    bin_count::Int
    gti_index::Int
    gti_start_time::Real
    orbit::Int
    amps::Array
    avg_amp::Array
    freqs::Array
end

function _FFTData(gti, freqs, amps, fspec_bin_size, bin_count)

    return FFTData(gti.mission, gti.instrument, gti.obsid, gti.bin_time, fspec_bin_size, bin_count,
        gti.gti_index, gti.gti_start_time, gti.orbit, amps, mean(amps, dims=2)[:], freqs)
end

function _fft(counts::Array, times::StepRangeLen, bin_time::Real, fspec_bin_size; leahy=true)
    FFTW.set_num_threads(4)

    spec_no = Int(floor(length(counts)/fspec_bin_size))

    counts = counts[1:Int(spec_no*fspec_bin_size)]
    counts = reshape(counts, fspec_bin_size, spec_no)

    amps = abs.(rfft(counts))
    freqs = Array(rfftfreq(fspec_bin_size, 1/bin_time))

    if leahy
        amps = (2 .*(amps.^2)) ./ sum(counts) # , dims=1
    end
    
    amps[1, :] .= 0 # Zero the 0Hz amplitude

    return freqs, amps, spec_no
end

function _best_gti_pow2(gtis::Dict{Int64,JAXTAM.GTIData})
    gti_pow2s = [prevpow(2, length(gti[2].counts)) for gti in gtis]
    min_pow2  = Int(median(gti_pow2s))
    exclude   = gti_pow2s .< min_pow2
    
    instrument = gtis[collect(keys(gtis))[1]].instrument

    @info "`$instrument` median `pow2` length is $min_pow2, excluded $(count(exclude)) gtis,
        $(length(gti_pow2s) - count(exclude)) remain"

    good_gtis = [gti for gti in gtis][.!exclude]

    return Dict(good_gtis), min_pow2
end

function gtis_pow2(mission_name::Symbol, gtis::Dict{Symbol,Dict{Int64,JAXTAM.GTIData}})
    instruments = config(mission_name).instruments

    gtis_pow2 = Dict{Symbol,Dict{Int64,JAXTAM.GTIData}}()

    for instrument in instruments
        gtis_pow2[Symbol(instrument)] = _best_gti_pow2(gtis[Symbol(instrument)])
    end

    return gtis_pow2
end

function _fspec_save(fspec_data::Dict{Int64,JAXTAM.FFTData}, fspec_dir::String)
    fspec_indecies = collect(keys(fspec_data))
    fspec_starts   = [t.gti_start_time for t in values(fspec_data)]
    fspec_b_counts = [t.bin_count for t in values(fspec_data)]
    fspec_orbits   = [o.orbit for o in values(fspec_data)]
    fspec_example  = fspec_data[fspec_indecies[1]]

    fspec_basename = string("$(fspec_example.instrument)_lc_$(fspec_example.bin_time)_fspec")
    fspec_meta     = DataFrame(mission=String(fspec_example.mission),
    instrument=String(fspec_example.instrument), obsid=fspec_example.obsid,
    bin_time=fspec_example.bin_time, bin_size=fspec_example.bin_size, orbits=fspec_orbits,
    indecies=fspec_indecies, starts=fspec_starts, b_counts=fspec_b_counts)
    
    Feather.write(joinpath(fspec_dir, "$(fspec_basename)_meta.feather"), fspec_meta)
    
    for index in fspec_indecies
        fspec_savepath  = joinpath(fspec_dir, "$(fspec_basename)_$(index).feather")

        fspec_data_df = DataFrame(fspec_data[index].amps)
        fspec_data_df[:freqs]   = fspec_data[index].freqs
        fspec_data_df[:avg_amp] = fspec_data[index].avg_amp
        
        Feather.write(fspec_savepath, fspec_data_df)
    end
end

function _fspec_load(fspec_dir, instrument, bin_time, fspec_bin)
    bin_time = float(bin_time)

    fspec_basename  = string("$(instrument)_lc_$(bin_time)_fspec")
    fspec_meta_path = joinpath(fspec_dir, "$(fspec_basename)_meta.feather")

    fspec_meta = Feather.read(fspec_meta_path)

    fspec_data = Dict{Int64,JAXTAM.FFTData}()

    for row_idx in 1:size(fspec_meta, 1)
        current_row = fspec_meta[row_idx, :]
        fspec_mission = Symbol(current_row[:mission][1])
        fspec_inst    = Symbol(current_row[:instrument][1])
        fspec_obsid   = current_row[:obsid][1]
        fspec_bin_t   = current_row[:bin_time][1]
        fspec_bin_sze = current_row[:bin_size][1]
        fspec_idx     = current_row[:indecies][1]
        fspec_starts  = current_row[:starts][1]
        fspec_b_count = current_row[:b_counts][1]
        fspec_orbit   = current_row[:orbits][1]
        fspec_file    = Feather.read(joinpath(fspec_dir, "$(fspec_basename)_$(fspec_idx).feather"))
        fspec_freqs   = Array(fspec_file[:freqs]); delete!(fspec_file, :freqs)
        fspec_ampavg  = Array(fspec_file[:avg_amp]); delete!(fspec_file, :avg_amp)
        if fspec_idx != -1
            fspec_amps = convert(Array, fspec_file[:, names(fspec_file)])
        else # If avg_amp is loaded, fspec_amps = [], throws Argument Error on convert
            fspec_amps = []
        end

        fspec_data[fspec_idx] = FFTData(fspec_mission, fspec_inst, fspec_obsid, fspec_bin_t,
            fspec_bin_sze, fspec_b_count, fspec_idx, fspec_starts, fspec_orbit, fspec_amps, fspec_ampavg,
            fspec_freqs)
    end

    return fspec_data
end

function _fspec(gtis::Dict{Int64,JAXTAM.GTIData}, fspec_bin::Real; pow2=true, fspec_bin_type=:time)
    powspec = Dict{Int64,FFTData}()

    first_gti = gtis[collect(keys(gtis))[1]]

    if fspec_bin_type == :time
        fspec_bin_size = Int(fspec_bin/first_gti.bin_time)
    elseif fspec_bin_type == :length
        fspec_bin_size = Int(fspec_bin)
    end

    @info "                       -> fspec_bin_size = $fspec_bin_size"

    if !ispow2(fspec_bin_size)
        @warn "`fspec_bin_size` not `pow2`: $fspec_bin_size, `fspec_bin` = $fspec_bin ($(1/fspec_bin))"
    end

    for gti in values(gtis)
        if length(gti.counts) < fspec_bin_size
            @info "                       -> skipped gti $(lpad(gti.gti_index, 3)) (under by: $(length(gti.counts) - fspec_bin_size))"
            continue
        end

        freqs, amps, bin_count = _fft(gti.counts, gti.times, gti.bin_time, fspec_bin_size)

        powspec[gti.gti_index] = _FFTData(gti, freqs, amps, fspec_bin_size, bin_count)
    end

    return powspec
end

function _scrunch_sections(instrument_data::Dict{Int64,JAXTAM.FFTData}; append_mean=true)
    gtis = keys(instrument_data)
    gti_example = instrument_data[collect(gtis)[1]]

    joined_powspecs = Dict{Symbol,Array}()
    joined_together = Array{Float64,2}(undef, size(gti_example.amps, 1), 0)

    bin_count_sum = 0

    for gti in values(instrument_data)
        if gti.gti_index <= 0 # Don't try and scrunch special, non-gti values
            continue
        end

        bin_count_sum += gti.bin_count
        joined_together = hcat(joined_together, gti.amps)
    end

    if append_mean
        instrument_data[-1] = FFTData(
            gti_example.mission, gti_example.instrument, gti_example.obsid,
            gti_example.bin_time, gti_example.bin_size, bin_count_sum, -1, -1, -1, [],
            mean(joined_together, dims=2)[:], gti_example.freqs
        )
    end

    return instrument_data
end

function fspec(mission_name::Symbol, gtis::Dict{Symbol,Dict{Int64,JAXTAM.GTIData}}, fspec_bin::Real; pow2=true, fspec_bin_type=:time, scrunched=true)
    instruments = config(mission_name).instruments

    instrument_fspecs = Dict{Symbol,Dict{Int,JAXTAM.FFTData}}()

    for instrument in instruments
        instrument_fspecs[Symbol(instrument)] = _fspec(gtis[Symbol(instrument)], fspec_bin, pow2=pow2, fspec_bin_type=fspec_bin_type)

        if scrunched
            instrument_fspecs = _scrunch_sections(instrument_fspecs[Symbol(instrument)])
        end
    end


    return instrument_fspecs
end

function fspec(mission_name::Symbol, obs_row::DataFrames.DataFrame, bin_time::Real, fspec_bin::Real;
        overwrite_fs=false, overwrite_gtis=false, save_fspec=false, pow2=true, fspec_bin_type=:time, scrunched=true)
    obsid       = obs_row[:obsid][1]
    instruments = Symbol.(config(mission_name).instruments)

    JAXTAM_path          = abspath(string(obs_row[:obs_path][1], "/JAXTAM/"))

    JAXTAM_gti_path      = joinpath(JAXTAM_path, "lc/$bin_time/gtis/"); mkpath(JAXTAM_gti_path)
    JAXTAM_gti_content   = readdir(JAXTAM_gti_path)
    JAXTAM_gti_metas     = Dict([Symbol(inst) => joinpath(JAXTAM_gti_path, "$(inst)_lc_$(float(bin_time))_gti_meta.feather") for inst in instruments])

    JAXTAM_fspec_path    = joinpath(JAXTAM_path, "lc/$bin_time/fspec/"); mkpath(JAXTAM_fspec_path)
    JAXTAM_fspec_content = readdir(JAXTAM_path)
    JAXTAM_fspec_metas   = Dict([Symbol(inst) => joinpath(JAXTAM_fspec_path, "$(inst)_lc_$(float(bin_time))_fspec_meta.feather") for inst in instruments])

    JAXTAM_all_gti_metas   = unique([isfile(meta) for meta in values(JAXTAM_gti_metas)])
    JAXTAM_all_fspec_metas = unique([isfile(meta) for meta in values(JAXTAM_fspec_metas)])

    if JAXTAM_all_gti_metas != [true] || overwrite_gtis
        @info "Not all GTI metas found"
    end

    gtis = JAXTAM.gtis(mission_name, obs_row, bin_time; overwrite=overwrite_gtis)
    
    instrument_fspecs = Dict{Symbol,Dict{Int64,JAXTAM.FFTData}}()

    for instrument in instruments
        if fspec_bin == 0
            fspec_bin = _best_gti_pow2(gtis[instrument])[2]*bin_time
            @info "Auto picking `fspec_bin`: $fspec_bin"
        end

        if !isfile(JAXTAM_fspec_metas[instrument]) || overwrite_fs
            @info "Computing $instrument fspecs"

            fspec_data = _fspec(gtis[instrument], fspec_bin; pow2=pow2, fspec_bin_type=fspec_bin_type)

            if scrunched
                @info "                       -> scrunching gtis"
                fspec_data = _scrunch_sections(fspec_data)
            end

            if save_fspec
                @info "                       -> saving $instrument -> $JAXTAM_fspec_path"
                _fspec_save(fspec_data, JAXTAM_fspec_path)
            end

            instrument_fspecs[instrument] = fspec_data
        else
            @info "Loading $instrument fspecs"
            instrument_fspecs[instrument] = _fspec_load(JAXTAM_fspec_path, instrument, bin_time, fspec_bin)
        end
    end

    return instrument_fspecs
end

function fspec(mission_name::Symbol, obsid::String, bin_time::Number, fspec_bin::Real;
    overwrite_fs=false, overwrite_gtis=false, pow2=true, fspec_bin_type=:time, scrunched=true)

    obs_row = master_query(mission_name, :obsid, obsid)

    fs = fspec(mission_name, obs_row, bin_time, fspec_bin; overwrite_fs=overwrite_fs, overwrite_gtis=overwrite_gtis,
        pow2=pow2, fspec_bin_type=fspec_bin_type, scrunched=scrunched)
    
    return fs
end

function _fspec_rebin(amps, freqs, bin_count::Int, rebin=(:log10, 0.01))
    rebin_type   = rebin[1]
    rebin_factor = rebin[2]
    freq_intervals = freqs[3] - freqs[2]

    if rebin_type == :log10
        freq_max = freqs[end]

        scale_start  = log10(rebin_factor)

        scale = exp10.(range(scale_start, step=rebin_factor, stop=log10(freq_max)))
        scale = [0; scale[1:end-1]]
        scale = scale./freq_intervals
        scale = ceil.(Int, scale[:, 1])
        scale[1, 1] = 1
        scale = unique(scale)

        final_scale_value = ceil(Int, exp10(log10(scale[end])+rebin_factor))
        final_scale_value > length(amps) ? final_scale_value=length(amps) : ""
        scale = [scale [scale[2:end]; final_scale_value].+1]

        errors = amps
        errors = [mean(errors[scale[i, 1]:scale[i, 2]]) for i = 1:size(scale, 1)]
        errors = errors ./ sqrt.(diff(scale, dims=2).*bin_count)

        rebinned_fspec = [mean(amps[scale[i, 1]:scale[i, 2]]) for i = 1:size(scale, 1)]
        
        freq_scale = freqs[round.(Int, (scale[:, 2]+scale[:, 1])./2)]
        
        rebinned_fspec[rebinned_fspec.==0] .= NaN
    elseif rebin_type == :linear
        if rebin_factor < 1 || typeof(rebin_factor) != Int
            error("Rebin factor must be a >1 integer for linear rebinning")
        end

        in_rebin = floor(Int, size(amps, 1)/rebin_factor).*rebin_factor

        errors = amps ./ sqrt(bin_count*rebin_factor)
        errors = mean(reshape(errors[1:in_rebin], rebin_factor, :), dims=1)'

        rebinned_fspec = mean(reshape(amps[1:in_rebin], rebin_factor, :), dims=1)'

        freq_scale = mean(reshape(freqs[1:in_rebin], rebin_factor, :), dims=1)'
    end 

    return freq_scale, rebinned_fspec, errors
end

function fspec_rebin(fs::JAXTAM.FFTData; rebin=(:log10, 0.01))
    rebinned_data = _fspec_rebin(fs.avg_amp, fs.freqs, fs.bin_count, rebin)

    return rebinned_data
end

function _orbit_select(data::FFTData)
    orbit_period = 92*60 # Orbital persiod of ISS, used with NICER, TODO: GENERALISE WITH MISSION CONFIG
    orbit_times  = data.gtis[:, 1][findall(diff(data.gtis[:, 2]) .> orbit_period/2)]
    orbit_times  = [orbit_times.-orbit_period/2 orbit_times]
    
    orbit_indecies = [findfirst(x .<= data.times) for x in orbit_times]

    lc_indecies = Array{Int,2}(undef, size(orbit_indecies,2), 2)
    orbit_data = Dict{Int64, BinnedOrbitData}()
    for i = 1:size(orbit_indecies, 1)
        gtis_in_orbit = data.gtis[(orbit_times[i, 1] .<= data.gtis[:, 2] .<= orbit_times[i, 2])[:], :]

        adjusted_indecies = [findfirst(data.times .>= gtis_in_orbit[1, 1]), findfirst(data.times .>= gtis_in_orbit[end, 2])]

        orbit_data[i] = BinnedOrbitData(data.mission, data.instrument, data.obsid, data.bin_time,
            view(data.counts, adjusted_indecies[1]:adjusted_indecies[2]), view(data.times, adjusted_indecies[1]:adjusted_indecies[2]),
            gtis_in_orbit, i)
    end

    return BinnedData(data.mission, data.instrument, data.obsid,
        data.bin_time, data.counts, data.times, data.gtis, orbit_data)
end