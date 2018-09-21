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

function _sgram(lc::JAXTAM.BinnedData, stft_intervals=round(Int, 1024/(lc.bin_time)))
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

    sgrm = spectrogram(gti_only_counts, stft_intervals, 0; fs=1/lc.bin_time)

    sgram_pseudo_time = 1:size(sgrm.power, 2)
    sgram_freqs  = collect(sgrm.freq)
    sgram_powers = sgrm.power
    sgram_powers[1, :] .= NaN
    sgram_powers[sgram_powers .== -Inf] .= NaN

    heatmap(sgram_freqs, sgram_pseudo_time, sgram_powers', legend=true, size=(1140,400))
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

    dsp_stft      = abs.(stft(gti_only_counts, stft_intervals; fs=1/lc.bin_time))
    #dsp_stft      = dsp_stft.^2
    dsp_stft_time = collect(1:size(dsp_stft, 2)).*(lc.bin_time*stft_intervals/2)
    dsp_stft_freq = linspace(0, 0.5*(1/lc.bin_time), size(dsp_stft, 1))

    dsp_stft[1, :] .= NaN # NaN 0 Hz

    return heatmap(dsp_stft_freq, dsp_stft_time, dsp_stft', legend=true, size=(1140,400))
end