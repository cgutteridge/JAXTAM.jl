# struct SgramData <: JAXTAMData
#     mission::Symbol
#     instrument::Symbol
#     obsid::String
#     bin_time::Real
#     bin_size::Int
#     gti_index::Int
#     gti_start_time::Real
#     amps::Array
#     freqs::Array
# end

function _sgram(fs::Dict{Int64,JAXTAM.FFTData})
    delete!(fs, -1); delete!(fs, -1)

    scrunched_amps = [f[2].amps for f in fs]
    scrunched_amps = hcat(scrunched_amps...)
    
    sgram_freqs = fs[collect(keys(fs))[1]].freqs
    
    pseudo_times = 1:size(scrunched_amps, 2)
    
    scrunched_amps[1, :] .= NaN # NaN the 0 Hz amplitudes
    scrunched_amps[scrunched_amps .<= 0] .= NaN # Needed to avoid Inf after log

    return sgram_freqs, pseudo_times, scrunched_amps
end

function _stft(lc::JAXTAM.BinnedData, stft_intervals=round(Int, 1024/(lc.bin_time)))
    gti_only_counts = Array{Int64,1}()
    gti_only_times  = Array{Float64,1}()
    
    for gti in DataFrames.eachrow(lc.gtis)
        gti_start = gti[:start]
        gti_stop  = gti[:stop]

        if gti_stop - gti_start >= 16
            start = findfirst(lc.times .>= gti_start)
            stop  = findfirst(lc.times .>= gti_stop) - 1

            append!(gti_only_counts, lc.counts[start:stop])
            append!(gti_only_times, lc.times[start:stop])
        end
    end

    dsp_stft      = abs.(stft(gti_only_counts, stft_intervals, 0; fs=1/lc.bin_time))
    #dsp_stft      = dsp_stft.^2
    dsp_stft_time = collect(1:size(dsp_stft, 2)).*(lc.bin_time*stft_intervals/2)
    dsp_stft_freq = linspace(0, 0.5*(1/lc.bin_time), size(dsp_stft, 1))

    dsp_stft[1, :] .= NaN # NaN 0 Hz
    return dsp_stft
end