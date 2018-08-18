function _savefig_obsdir(mission_name, obsid, bin_time, fig_name)
    plot_dir = joinpath(master_query(mission_name, :obsid, obsid)[1, :obs_path], "JAXTAM/lc/$bin_time/images")
    mkpath(plot_dir)
    savefig(joinpath(plot_dir, fig_name))
end

function plot!(data::BinnedData; lab="", size_in=(1140,400), save_plt=true)
    bin_time_pow2 = Int(log2(data.bin_time))

    Plots.plot()

    Plots.plot!(data.times, data.counts,
        xlab="Time (s)", ylab="Counts (log10)",
        lab=lab, alpha=1, title="FFT - 2^$(bin_time_pow2) - $(data.bin_time) bt")

    Plots.vline!(data.gtis[:, 2], lab="GTI Stop", alpha=0.75)

    Plots.vline!(data.gtis[:, 1], lab="GTI Start", alpha=0.75)

    count_min = maximum([minimum(data.counts[data.counts != 0]), 0.1])
    count_max = maximum(data.counts)
    yticks = range(log10(prevpow(10, count_min)), step=0.2, stop=log10(nextpow(10, count_min)))

    yticks = round.(exp10.(yticks), sigdigits=3)

    count_min > 1 ? ylim = (prevpow(10, count_min), nextpow(10, count_max)) : ylim = (1/prevpow(10, 1/count_min), nextpow(10, count_max))
    yaxis!(yscale=:log10, yticks=yticks, ylims=ylim)

    try
        yaxis!(yformatter=yi->round(Int, yi))
    catch
        yaxis!(yformatter=yi->yi)
    end

    if(save_plt)
        _savefig_obsdir(data.mission, data.obsid, data.bin_time, "lcurve.png")
    end

    return Plots.plot!(size=size_in)
end

function plot(instrument_data::Dict{Symbol,JAXTAM.BinnedData}; size_in=(1140,400), save_plt=true)
    instruments = keys(instrument_data)

    plt = Plots.plot()
    
    for instrument in instruments
        plt = plot!(instrument_data[Symbol(instrument)]; lab=String(instrument), save_plt=false)
    end

    if(save_plt)
        data = instrument_data[collect(keys(instrument_data))[1]]
        _savefig_obsdir(data.mission, data.obsid, data.bin_time, "lcurve.png")
    end

    return Plots.plot!(size=size_in)
end

function plot!(data::FFTData; lab="", size_in=(1140,600), save_plt=true, norm=:RMS, rebin=rebin, logx=true, logy=true)
    bin_time_pow2 = Int(log2(data.bin_time))

    # Don't plot the 0Hz amplitude
    avg_amp = data.avg_amp
    freqs   = data.freqs
    avg_amp[1] = NaN
    freq_min   = freqs[1] + eps() # Make it not be exactly equal to zero
    freqs[1]   = NaN

    freqs, avg_amp = fspec_rebin(avg_amp, freqs; rebin=rebin)

    if norm == :RMS
        avg_amp = (avg_amp.*freqs).-2
        amp_max = maximum(avg_amp[2:end]); amp_min = minimum(abs.(avg_amp[2:end]))
        avg_amp[avg_amp .<=0] .= NaN

        Plots.plot!(freqs, avg_amp, ylab="Amplitude (Leahy - 2)*freq", lab=lab)
    elseif norm == :Leahy
        amp_max = maximum(avg_amp[2:end]); amp_min = minimum(avg_amp[2:end])
        
        Plots.plot!(freqs, avg_amp, ylab="Amplitude (Leahy)", lab=lab)
    else
        @error "Plot norm type '$norm' not found"
    end
    
    if logx
        xaxis!(xscale=:log10, xformatter=xi->xi, xlim=(freq_min, freqs[end]))
    end

    if logy
        # If amp_min < 1, can't use prevpow10 for ylims, hacky little fix:
        amp_min > 1 ? ylim = (prevpow(10, amp_min), nextpow(10, amp_max)) : ylim = (1/prevpow(10, 1/amp_min), nextpow(10, amp_max))
        yaxis!(yscale=:log10, yformatter=yi->yi, ylims=ylim)
    end
    
    Plots.plot!(xlab="Freq (Hz)", alpha=1,
        title="FFT - $(data.obsid) - 2^$(bin_time_pow2) bt - $(data.bin_size*data.bin_time) bs")

    if(save_plt)
        _savefig_obsdir(data.mission, data.obsid, data.bin_time, "fspec.png")
    end

    return Plots.plot!(size=size_in)
end

function plot(instrument_data::Dict{Symbol,Dict{Int64,JAXTAM.FFTData}}; size_in=(1140,600), norm=:RMS, rebin=(:log10, 0.01), logx=true, logy=true, save_plt=true)
    instruments = keys(instrument_data)

    plt = Plots.plot()
    
    for instrument in instruments
        plt = plot!(instrument_data[Symbol(instrument)][-1];norm=norm, rebin=rebin, logx=logx, logy=logy, lab=String(instrument), save_plt=false)
    end

    Plots.plot!(title_location=:left, titlefontsize=12, margin=2mm, xguidefontsize=10, yguidefontsize=10)

    if(save_plt)
        data = instrument_data[collect(keys(instrument_data))[1]][-1]
        _savefig_obsdir(data.mission, data.obsid, data.bin_time, "fspec.png")
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