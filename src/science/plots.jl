
function plot!(data::FFTData; lab="", size_in=(1920,1080))
    bin_time_pow2 = Int(log2(data.bin_time))

    data.avg_amp[1] = NaN # Don't plot the 0Hz amplitude

    Plots.plot!(data.freqs, data.avg_amp,
        xlab="Freq (Hz)", ylab="Amplitude (Leahy)",
        lab=lab, alpha=0.5, title="FFT - $(data.obsid) - 2^$(bin_time_pow2) bt - $(data.bin_size) bs")

    return Plots.plot!(size=size_in)
end

function plot!(data::BinnedData; lab="", size_in=(1920,1080))
    bin_time_pow2 = Int(log2(data.bin_time))

    Plots.plot()

    Plots.plot!(data.times, data.counts,
        xlab="Time (s)", ylab="Counts",
        lab=lab, alpha=0.5, title="FFT - 2^$(bin_time_pow2) - $(data.bin_time) bt")

    Plots.vline!(data.gtis[:, 2], lab="GTI Stop", alpha=0.75)

    Plots.vline!(data.gtis[:, 1], lab="GTI Start", alpha=0.75)

    return Plots.plot!(size=size_in)
end

function plot(instrument_data::Dict{Symbol,JAXTAM.BinnedData}; size_in=(1920,1080))
    instruments = keys(instrument_data)

    plt = Plots.plot()
    
    for instrument in instruments
        plt = plot!(instrument_data[Symbol(instrument)]; lab=String(instrument))
    end

    return Plots.plot!(size=size_in)
end

function plot(instrument_data::Dict{Symbol,Dict{Int64,JAXTAM.FFTData}}; size_in=(1920,1080))
    instruments = keys(instrument_data)

    plt = Plots.plot()
    
    for instrument in instruments
        plt = plot!(instrument_data[Symbol(instrument)][-1]; lab=String(instrument))
    end

    return Plots.plot!(size=size_in)
end

function plot_summary(mission_name::Symbol, obsid::String)
    lc_1s = lcurve(mission_name, obsid, 1)

    fs_2m13 = fspec(mission_name, obsid, 2.0^-13, 256)
    fs_low1 = fspec(mission_name, obsid, 2.0^-3, 512)
    fs_low2 = fspec(mission_name, obsid, 2.0^-1, 512)

    plt_lc = plot(lc_1s; size_in=(1000, 400))
end