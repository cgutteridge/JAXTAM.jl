struct FFTData <: JAXTAMData
    mission::Symbol
    instrument::Symbol
    obsid::String
    bin_time::Real
    bin_size::Int
    gti_index::Int
    gti_start_time::Real
    amps::Array
    avg_amp::Array
    freqs::Array
end

function _FFTData(gti, freqs, amps, fspec_bin_size)

    return FFTData(gti.mission, gti.instrument, gti.obsid, gti.bin_time, fspec_bin_size,
        gti.gti_index, gti.gti_start_time, amps, mean(amps, 2)[:], freqs)
end

function _fft(counts::SparseVector{Int64,Int64}, times::StepRangeLen, bin_time::Real, fspec_bin_size; leahy=true)
    FFTW.set_num_threads(4)

    spec_no = Int(floor(length(counts)/fspec_bin_size))

    counts = counts[1:Int(spec_no*fspec_bin_size)]
    counts = reshape(counts, fspec_bin_size, spec_no)

    amps = abs.(rfft(counts))
    freqs = Array(rfftfreq(fspec_bin_size, 1/bin_time))

    if leahy
        amps = (2.*(amps.^2)) ./ sum(counts, 1)
    end
    
    amps[1, :] = 0 # Zero the 0Hz amplitude

    return freqs, amps
end

function _best_gti_pow2(gtis::Dict{Int64,JAXTAM.GTIData})
    gti_pow2s = [prevpow2(length(gti[2].counts)) for gti in gtis]
    min_pow2  = Int(median(gti_pow2s))
    exclude   = gti_pow2s .< min_pow2
    
    instrument = gtis[collect(keys(gtis))[1]].instrument

    info("$instrument median pow2 length is $min_pow2, excluded $(count(exclude)) gtis, ", 
        "$(length(gti_pow2s) - count(exclude)) remain")

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
    fspec_example  = fspec_data[fspec_indecies[1]]

    fspec_basename = string("$(fspec_example.instrument)\_lc_$(fspec_example.bin_time)\_fspec")
    fspec_meta     = DataFrame(mission=String(fspec_example.mission), instrument=String(fspec_example.instrument), obsid=fspec_example.obsid, bin_time=fspec_example.bin_time, bin_size=fspec_example.bin_size, indecies=fspec_indecies, starts=fspec_starts)

    Feather.write(joinpath(fspec_dir, "$fspec_basename\_meta.feather"), fspec_meta)

    for index in fspec_indecies
        fspec_savepath  = joinpath(fspec_dir, "$fspec_basename\_$index\.feather")

        fspec_data_df = DataFrame(fspec_data[index].amps)
        fspec_data_df[:freqs]   = fspec_data[index].freqs
        fspec_data_df[:avg_amp] = fspec_data[index].avg_amp

        Feather.write(fspec_savepath, fspec_data_df)
    end
end

function _fspec_load(fspec_dir, instrument, bin_time, fspec_bin)
    bin_time = float(bin_time)

    fspec_basename  = string("$instrument\_lc_$bin_time\_fspec")
    fspec_meta_path = joinpath(fspec_dir, "$fspec_basename\_meta.feather")

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
        fspec_file    = Feather.read(joinpath(fspec_dir, "$fspec_basename\_$fspec_idx\.feather"))
        fspec_freqs   = Array(fspec_file[:freqs]); delete!(fspec_file, :freqs)
        fspec_ampavg  = Array(fspec_file[:avg_amp]); delete!(fspec_file, :avg_amp)
        fspec_amps    = Array(fspec_file)

        fspec_data[fspec_idx] = FFTData(fspec_mission, fspec_inst, fspec_obsid, fspec_bin_t, fspec_bin_sze, fspec_idx, fspec_starts, fspec_amps, fspec_ampavg, fspec_freqs)
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
    
    if !ispow2(fspec_bin_size)
        warn("fspec_bin_size not pow2: $fspec_bin_size, fspec_bin = $fspec_bin ($(1/fspec_bin)), bin_time: $(gti.bin_time) ($(1/gti.bin_time)")
    end

    for gti in values(gtis)
        if length(gti.counts) < fspec_bin_size
            warn(("Skipped gti $(gti.gti_index) as it is under the fspec_bin_size of $fspec_bin_size"))
            continue
        end

        freqs, amps = _fft(gti.counts, gti.times, gti.bin_time, fspec_bin_size)

        powspec[gti.gti_index] = _FFTData(gti, freqs, amps, fspec_bin_size)
    end

    return powspec
end

function _scrunch_sections(mission_name::Symbol, powspecs::Dict{Symbol,Dict{Int64,JAXTAM.FFTData}}; return_mean=true)
    instruments = config(mission_name).instruments

    joined_powspecs = Dict{Symbol,Array}()

    for instrument in instruments
        gti_example = powspecs[Symbol(instrument)][collect(keys(powspecs[Symbol(instrument)]))[1]]

        joined_together = Array{Float64,2}(size(gti_example.amps, 1), 0)

        for gti in values(powspecs[Symbol(instrument)])
            joined_together = hcat(joined_together, gti.amps)
        end

        if return_mean
            powspecs[Symbol(instrument)][-1] = FFTData(mission_name, gti_example.instrument, gti_example.obsid, gti_example.bin_time, gti_example.bin_size, -1, -1, [], mean(joined_together, 2), gti_example.freqs)
        else
            powspecs[Symbol(instrument)][-2] = FFTData(mission_name, gti_example.instrument, gti_example.obsid, gti_example.bin_time, gti_example.bin_size, -1, -1, joined_together, [], gti_example.freqs)
        end
    end

    return powspecs
end

function fspec(mission_name::Symbol, gtis::Dict{Symbol,Dict{Int64,JAXTAM.GTIData}}, fspec_bin::Real; pow2=true, fspec_bin_type=:time, scrunched=true)
    instruments = config(mission_name).instruments

    instrument_fspecs = Dict{Symbol,Dict{Int,JAXTAM.FFTData}}()

    for instrument in instruments
        instrument_fspecs[Symbol(instrument)] = _fspec(gtis[Symbol(instrument)], fspec_bin, pow2=pow2, fspec_bin_type=fspec_bin_type)
    end

    if scrunched
        instrument_fspecs = _scrunch_sections(mission_name, instrument_fspecs)
    end

    return instrument_fspecs
end

function fspec(mission_name::Symbol, obs_row::DataFrames.DataFrame, bin_time::Real, fspec_bin::Real; overwrite=false, pow2=true, fspec_bin_type=:time, scrunched=true)
    obsid       = obs_row[:obsid][1]
    instruments = config(mission_name).instruments

    JAXTAM_path          = abspath(string(obs_row[:obs_path][1], "/JAXTAM/"))

    JAXTAM_gti_path      = joinpath(JAXTAM_path, "lc/$bin_time/gtis/"); mkpath(JAXTAM_gti_path)
    JAXTAM_gti_content   = readdir(JAXTAM_gti_path)
    JAXTAM_gti_metas     = Dict([Symbol(inst) => joinpath(JAXTAM_gti_path, "$inst\_lc_$(float(bin_time))\_gti_meta.feather") for inst in instruments])

    JAXTAM_fspec_path    = joinpath(JAXTAM_path, "lc/$bin_time/fspec/"); mkpath(JAXTAM_fspec_path)
    JAXTAM_fspec_content = readdir(JAXTAM_path)
    JAXTAM_fspec_metas   = Dict([Symbol(inst) => joinpath(JAXTAM_fspec_path, "$inst\_lc_$(float(bin_time))_fspec_meta.feather") for inst in instruments])

    JAXTAM_all_gti_metas   = unique([isfile(meta) for meta in values(JAXTAM_gti_metas)])
    JAXTAM_all_fspec_metas = unique([isfile(meta) for meta in values(JAXTAM_fspec_metas)])

    if JAXTAM_all_gti_metas != [true] || overwrite
        info("Not all GTI metas found")
    end

    gtis = JAXTAM.gtis(mission_name, obs_row, bin_time; overwrite=overwrite)
    
    instrument_fspecs = Dict{Symbol,Dict{Int64,JAXTAM.FFTData}}() # DataStructures.OrderedDict{Int64,JAXTAM.GTIData}

    for instrument in instruments
        if fspec_bin == 0
            fspec_bin = _best_gti_pow2(gtis[Symbol(instrument)])[2]*bin_time
            info("Auto picking `fspec_bin`: $fspec_bin")
        end

        if !isfile(JAXTAM_fspec_metas[Symbol(instrument)]) || overwrite
            info("Computing $instrument fspecs")

            fspec_data = _fspec(gtis[Symbol(instrument)], fspec_bin; pow2=pow2, fspec_bin_type=fspec_bin_type)

            info("Saving $instrument fspecs -> $JAXTAM_fspec_path")
            _fspec_save(fspec_data, JAXTAM_fspec_path)

            instrument_fspecs[Symbol(instrument)] = fspec_data
        else
            info("Loading $instrument fspecs")
            instrument_fspecs[Symbol(instrument)] = _fspec_load(JAXTAM_fspec_path, instrument, bin_time, fspec_bin)
        end
    end

    if scrunched
        instrument_fspecs = _scrunch_sections(mission_name, instrument_fspecs)
    end

    return instrument_fspecs
end

function fspec(mission_name::Symbol, obsid::String, bin_time::Number, fspec_bin::Real; overwrite=false, pow2=true, fspec_bin_type=:time, scrunched=true)
    obs_row = master_query(mission_name, :obsid, obsid)

    return fspec(mission_name, obs_row, bin_time, fspec_bin; overwrite=overwrite, pow2=pow2, fspec_bin_type=fspec_bin_type, scrunched=scrunched)
end