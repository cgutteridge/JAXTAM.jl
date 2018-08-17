function _savefig_obsdir(mission_name, obsid, bin_time, fig_name)
    plot_dir = joinpath(master_query(mission_name, :obsid, obsid)[1, :obs_path], "JAXTAM/lc/$bin_time/images")
    mkpath(plot_dir)
    savefig(joinpath(plot_dir, fig_name))
end

function plot!(data::BinnedData; lab="", size_in=(1140,400), save_plt=true)
    bin_time_pow2 = Int(log2(data.bin_time))

    Plots.plot()

    Plots.plot!(data.times, data.counts,
        xlab="Time (s)", ylab="Counts",
        lab=lab, alpha=1, title="FFT - 2^$(bin_time_pow2) - $(data.bin_time) bt")

    Plots.vline!(data.gtis[:, 2], lab="GTI Stop", alpha=0.75)

    Plots.vline!(data.gtis[:, 1], lab="GTI Start", alpha=0.75)

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

function plot!(data::FFTData; lab="", size_in=(1140,600), save_plt=true, norm=:RMS, rebin_log=true)
    bin_time_pow2 = Int(log2(data.bin_time))

    # Don't plot the 0Hz amplitude
    avg_amp = data.avg_amp[2:end]
    freqs   = data.freqs[2:end]

    if norm == :RMS
        avg_amp = (avg_amp.*freqs).-2
        avg_amp[avg_amp .<=0] .= NaN

        if rebin_log
            freqs, avg_amp = fspec_rebin(avg_amp, freqs; rebin_type=:log10, rebin_factor=0.01)
        end

        Plots.plot!(freqs, avg_amp, ylab="Amplitude (Leahy - 2)", yaxis=:log10, xaxis=:log10, xlim=(10^-2, freqs[end]), lab=lab)
    elseif norm == :Leahy
        Plots.plot!(freqs, avg_amp, ylab="Amplitude (Leahy)", lab=lab)
    else
        @error "Plot norm type '$norm' not found"
    end

    Plots.plot!(xlab="Freq (Hz)", alpha=1,
        title="FFT - $(data.obsid) - 2^$(bin_time_pow2) bt - $(data.bin_size*data.bin_time) bs")

    if(save_plt)
        _savefig_obsdir(data.mission, data.obsid, data.bin_time, "fspec.png")
    end

    return Plots.plot!(size=size_in)
end

function plot(instrument_data::Dict{Symbol,Dict{Int64,JAXTAM.FFTData}}; size_in=(1140,600), save_plt=true)
    instruments = keys(instrument_data)

    plt = Plots.plot()
    
    for instrument in instruments
        plt = plot!(instrument_data[Symbol(instrument)][-1]; lab=String(instrument), save_plt=false)
    end

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