function _plot(data::JAXTAMData; lab="", xlab="", ylab="")
    x = data.avg_amp
    y = data.freqs

    return Dict(:x=>x, :y=>y, :xlab=>xlab, :ylab=>ylab, :lab=>lab)
end

function plot!(data::FFTData; lab="")
    bin_time_pow2 = Int(log2(data.bin_time))

    data.avg_amp[1] = NaN # Don't plot the 0Hz amplitude

    return Plots.plot!(data.freqs, data.avg_amp,
        xlab="Freq (Hz)", ylab="Amplitude (Leahy)",
        lab=lab, alpha=0.5, title="FFT - $(data.obsid) - 2^$(bin_time_pow2) bt - $(data.bin_size) bs")
end

function plot!(data::BinnedData; lab="")
    bin_time_pow2 = Int(log2(data.bin_time))

    data.avg_amp[1] = NaN # Don't plot the 0Hz amplitude

    return Plots.plot!(data.times, data.counts,
        xlab="Time (s)", ylab="Counts",
        lab=lab, alpha=0.5, title="FFT - 2^$(bin_time_pow2) - $(data.bin_time) bt")
end

function plot(instrument_data::Dict{Symbol,JAXTAM.BinnedData})
    instruments = keys(instrument_data)

    plt = Plots.plot()
    
    for instrument in instruments
        plt = plot!(instrument_data[Symbol(instrument)]; lab=String(instrument))
    end

    return plt
end

function plot(instrument_data::Dict{Symbol,Dict{Int64,JAXTAM.FFTData}})
    instruments = keys(instrument_data)

    plt = Plots.plot()
    
    for instrument in instruments
        plt = plot!(instrument_data[Symbol(instrument)][-1]; lab=String(instrument))
    end

    return plt
end