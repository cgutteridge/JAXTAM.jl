function _savefig_obsdir(mission_name, obsid, bin_time, fig_name)
    plot_dir = joinpath(master_query(mission_name, :obsid, obsid)[1, :obs_path], "JAXTAM/lc/$bin_time/images")
    mkpath(plot_dir)
    savefig(joinpath(plot_dir, fig_name))
end

function plot!(data::Union{BinnedData,BinnedOrbitData}; lab="", size_in=(1140,400), save_plt=true)
    bin_time_pow2 = Int(log2(data.bin_time))

    Plots.plot()

    if typeof(data) == BinnedData
        plot_title = "FFT - 2^$(bin_time_pow2) - $(data.bin_time) bt"
    elseif typeof(data) == BinnedOrbitData
        plot_title = "FFT - 2^$(bin_time_pow2) - $(data.bin_time) bt - orbit $(data.orbit_id)"
    end

    Plots.plot!(data.times, data.counts,
        xlab="Time (s)", ylab="Counts (log10)",
        lab=lab, alpha=1, title=plot_title)

    Plots.vline!(data.gtis[:, 2], lab="GTI Stop",  alpha=0.75)
    Plots.vline!(data.gtis[:, 1], lab="GTI Start", alpha=0.75)

    count_min = maximum([minimum(data.counts[data.counts != 0]), 0.1])
    count_max = maximum(data.counts)
    log10_min = count_min > 1 ? prevpow(10, count_min) : 1/prevpow(10, 1/count_min)
    yticks = range(log10(log10_min), stop=log10(nextpow(10, count_max)), length=5)

    yticks = round.(exp10.(yticks), sigdigits=3)

    ylim = (log10_min, nextpow(10, count_max))
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

function plot!(data::FFTData; norm=:RMS, rebin=(:log10, 0.01),
        lab="", logx=true, logy=true, show_errors=true,
        size_in=(1140,600), save_plt=true,
    )
    bin_time_pow2 = Int(log2(data.bin_time))

    # Don't plot the 0Hz amplitude
    avg_amp = data.avg_amp
    freqs   = data.freqs
    avg_amp[1] = NaN
    freq_min   = freqs[2] # Skip zero freq
    freqs[1]   = NaN

    
    if norm == :RMS
        freqs, avg_amp, errors = fspec_rebin(data, rebin=rebin)
        errors = errors.*freqs
        avg_amp = (avg_amp.-2).*freqs
        amp_max = maximum(avg_amp[2:end]); amp_min = minimum(abs.(avg_amp[2:end]))
        avg_amp[avg_amp .<=0] .= NaN

        if show_errors
            Plots.plot!(freqs, avg_amp, color=:black,
                yerr=errors, #yerr=errors, marker=stroke(0.01, :black, :none),
                ylab="Amplitude (Leahy - 2)*freq", lab=lab)
        else
            Plots.plot!(freqs, avg_amp, color=:black,
                ylab="Amplitude (Leahy - 2)*freq", lab=lab)
        end
    elseif norm == :Leahy
        freqs, avg_amp, errors = fspec_rebin(data, rebin=rebin)
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
        amp_min > 1 ? ylim = (prevpow(10, amp_min), nextpow(10, amp_max)) : ylim = (1, nextpow(10, amp_max))# 1/prevpow(10, 1/amp_min)
        yaxis!(yscale=:log10, yformatter=yi->yi, ylims=ylim)
    end
    
    Plots.plot!(xlab="Freq (Hz)", alpha=1,
        title="FFT - $(data.obsid) - 2^$(bin_time_pow2) bt - $(data.bin_size*data.bin_time) bs - $rebin rebin - $(data.bin_count) sections averaged")

    if(save_plt)
        _savefig_obsdir(data.mission, data.obsid, data.bin_time, "fspec.png")
    end

    return Plots.plot!(size=size_in)
end

function plot(instrument_data::Dict{Symbol,Dict{Int64,JAXTAM.FFTData}}; size_in=(1140,600), norm=:RMS, rebin=(:log10, 0.01), logx=true, logy=true, save_plt=true)
    instruments = keys(instrument_data)

    plt = Plots.plot()
    
    for instrument in instruments
        plt = JAXTAM.plot!(instrument_data[Symbol(instrument)][-1];
            norm=norm, rebin=rebin, logx=logx, logy=logy, lab=String(instrument), save_plt=false)
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