# Helper functions

function _savefig_obsdir(obs_row, mission_name, obsid, bin_time, subfolder, fig_name)
    plot_dir = joinpath(obs_row[1, :obs_path], "JAXTAM/lc/$bin_time/images/", subfolder)

    plot_path = joinpath(plot_dir, fig_name)

    mkpath(plot_dir)

    savefig(plot_path)
    @info "Saved $(plot_path)"
end

function _savefig_obsdir(mission_name, obsid, bin_time, fig_name)
    obs_row = master_query(mission_name, :obsid, obsid)
    _savefig_obsdir(obs_row, mission_name, obsid, bin_time, fig_name)
end

function _pull_data(instrument_data::Union{Dict{Symbol,Dict{Int64,JAXTAM.FFTData}},Dict{Symbol,Dict{Int64,JAXTAM.PgramData}}})
    inst1 = collect(keys(instrument_data))[1]
    gti1  = collect(keys(instrument_data[inst1]))[1]
    row1  = instrument_data[inst1][gti1]

    return row1
end

function _pull_data(instrument_data::Union{Dict{Symbol,JAXTAM.BinnedData},Dict{Symbol,JAXTAM.PgramData}})
    inst1 = collect(keys(instrument_data))[1]
    row1  = instrument_data[inst1]

    return row1
end

function _plot_formatter!()
    # Plots.plot!(title_location=:left, titlefontsize=12, margin=2mm, xguidefontsize=10, yguidefontsize=10)
    return Plots.plot!(title_location=:left, margin=2mm, xguidefontsize=12, yguidefontsize=12)
end

# Lightcurve plotting functions

function plot!(data::BinnedData; lab="", size_in=(1140,400), save_plt=true, title_append="")
    bin_time_pow2 = Int(log2(data.bin_time))

    Plots.plot()

    plot_title = "Lightcurve - 2^$(bin_time_pow2) - $(data.bin_time) bt$title_append"

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

    Plots.plot!(size=size_in)

    if(save_plt)
        _savefig_obsdir(data.mission, data.obsid, data.bin_time, NaN, "lc", "$(data.instrument)_lcurve.png")
    end

    _plot_formatter!()
    return Plots.plot!()
end

function plot(instrument_data::Dict{Symbol,JAXTAM.BinnedData}; size_in=(1140,400), save_plt=true, title_append="")
    instruments = keys(instrument_data)

    plt = Plots.plot()
    
    for instrument in instruments
        plt = plot!(instrument_data[Symbol(instrument)]; lab=String(instrument), save_plt=false, title_append=title_append)
    end

    if(save_plt)
        example_lc = _pull_data(instrument_data)
        obs_row    = master_query(example_lc.mission, :obsid, example_lc.obsid)
        _savefig_obsdir(obs_row, example_lc.mission, example_lc.obsid, example_lc.bin_time, "lc", "lcurve.png")
    end

    return Plots.plot!(size=size_in)
end

function plot_groups(instrument_data::Dict{Symbol,JAXTAM.BinnedData}; size_in=(1140,400), save_plt=true)
    instruments = keys(instrument_data)

    group_plots = Dict{Symbol,Dict{Int64,Plots.Plot}}()

    example_gti = _pull_data(instrument_data)
    obs_row     = master_query(example_gti.mission, :obsid, example_gti.obsid)

    for instrument in instruments
        instrument_group_data  = _group_return(instrument_data[instrument])
        instrument_group_plots = Dict{Int64,Plots.Plot}()

        available_groups = collect(keys(instrument_group_data))

        for group in available_groups
            group_lc = instrument_group_data[group]

            title_append = " - group $group/$(maximum(available_groups))"

            instrument_group_plots[group] = plot(Dict(instrument=>group_lc); save_plt=false,
                    title_append=title_append, size_in=size_in)

            if save_plt
                _savefig_obsdir(obs_row, group_lc.mission, group_lc.obsid, group_lc.bin_time, "lc/groups/", "$(group)_lcurve.png")
            end
        end

        group_plots[instrument] = instrument_group_plots
    end

    return group_plots
end

# Power spectra plotting functions

function plot!(data::FFTData; title_append="", norm=:rms, rebin=(:log10, 0.01),
        lab="", logx=true, logy=true, show_errors=true,
        size_in=(1140,600), save_plt=false
    )
    bin_time_pow2 = Int(log2(data.bin_time))

    # Don't plot the 0Hz amplitude
    avg_amp = data.avg_amp
    freqs   = data.freqs
    avg_amp[1] = NaN
    #freqs[2] > 1 ? freq_min = prevpow(10, freqs[2]) : freq_min =  1/prevpow(10, 1/freqs[2]) # Skip zero freq
    freq_min = 0.01 # Manually set minimum fequency, assume anything lower isn't useful in power spectra
    freqs[1]   = NaN

    freqs, avg_amp, errors = fspec_rebin(data, rebin=rebin)
    ylab = ""
    
    if norm == :rms
        errors = errors.*freqs
        avg_amp = (avg_amp.-2).*freqs
        amp_max = maximum(avg_amp[2:end]); amp_min = minimum(abs.(avg_amp[2:end]))
        avg_amp[avg_amp .<=0] .= NaN
        ylab = "Amplitude (Leahy - 2)*freq"
    elseif norm == :leahy
        amp_max = maximum(avg_amp[2:end]); amp_min = minimum(avg_amp[2:end])
        ylab = "Amplitude (Leahy)"
    else
        @error "Plot norm type '$norm' not found" 
    end

    if show_errors
        Plots.plot!(freqs, avg_amp, color=:black,
            yerr=errors,
            ylab=ylab, lab=lab)
    else
        Plots.plot!(freqs, avg_amp, color=:black,
            ylab=ylab, lab=lab)
    end

    if logx
        xaxis!(xscale=:log10, xformatter=xi->xi, xlim=(freq_min, freqs[end]))
    end

    if logy
        # If amp_min < 1, can't use prevpow10 for ylims, hacky little fix is 1/prevpow(10, 1/amp_min)
        # removed that anyway, set ylim to 1 if amp_min < 1
        amp_min > 1 ? ylim = (prevpow(10, amp_min), nextpow(10, amp_max)) : ylim = (1, nextpow(10, amp_max))
        yaxis!(yscale=:log10, yformatter=yi->yi, ylims=ylim)
    end
    
    Plots.plot!(xlab="Freq (Hz)", alpha=1,
        title="FFT - $(data.obsid) - 2^$(bin_time_pow2) bt - $(data.bin_size*data.bin_time) bs - $rebin rebin - $(data.bin_count) sections averaged $title_append")

    if(save_plt)
        _savefig_obsdir(data.mission, data.obsid, data.bin_time, "fspec.png")
    end

    _plot_formatter!()
    return Plots.plot!(size=size_in)
end

function plot(instrument_data::Dict{Symbol,Dict{Int64,JAXTAM.FFTData}}; title_append="",
        size_in=(1140,600), norm=:rms, rebin=(:log10, 0.01), logx=true, logy=true, save_plt=true)
    instruments = keys(instrument_data)

    plt = Plots.plot()
    
    for instrument in instruments
        plt = JAXTAM.plot!(instrument_data[Symbol(instrument)][-1]; title_append=title_append,
            norm=norm, rebin=rebin, logx=logx, logy=logy, lab=String(instrument), save_plt=false)
    end

    if(save_plt)
        example_gti = _pull_data(instrument_data)
        obs_row    = master_query(example_gti.mission, :obsid, example_gti.obsid)
        _savefig_obsdir(obs_row, example_gti.mission, example_gti.obsid, example_gti.bin_time, "fspec/$(example_gti.bin_size*example_gti.bin_time)", "fspec.png")
    end

    return Plots.plot!(size=size_in)
end

function plot_groups(instrument_data::Dict{Symbol,Dict{Int64,JAXTAM.FFTData}};
    size_in=(1140,600), norm=:rms, rebin=(:log10, 0.01), logx=true, logy=true, save_plt=true)

    instruments = keys(instrument_data)

    group_plots = Dict{Symbol,Dict{Int64,Plots.Plot}}()

    example_gti = _pull_data(instrument_data)
    obs_row     = master_query(example_gti.mission, :obsid, example_gti.obsid)

    for instrument in instruments
        available_groups = unique([gti.group for gti in values(instrument_data[instrument])])
        available_groups = available_groups[available_groups .>= 0] # Excluse -1, -2, etc... for scrunched/mean FFTData

        instrument_group_plots = Dict{Int64,Plots.Plot}()

        for group in available_groups
            instrument_data_group = Dict{Int64,JAXTAM.FFTData}()
            gtis_in_group = [gti.gti_index for gti in values(instrument_data[instrument]) if gti.group == group]

            for gti_no in gtis_in_group
                instrument_data_group[gti_no] = instrument_data[instrument][gti_no]
            end

            title_append = " - group $group/$(maximum(available_groups))"

            # Have to run _scrunch_sections on group data, since it lacks the -1 indexed average amplitudes
            instrument_group_plots[group] = plot(Dict(instrument=>_scrunch_sections(instrument_data_group));
                    size_in=size_in, norm=norm, rebin=rebin, logx=logx, logy=logy, save_plt=false,
                    title_append=title_append)
            
            if save_plt
                data = instrument_data_group[gtis_in_group[1]]
                _savefig_obsdir(obs_row, data.mission, data.obsid, data.bin_time,
                    "fspec/$(data.bin_size.*data.bin_time)/groups/", "$(group)_fspec.png")
            end

        end

        group_plots[instrument] = instrument_group_plots
    end

    return group_plots
end

# Periodogram plotting functions

function plot!(data::PgramData; title_append="", rebin=(:linear, 10),
        lab="", logx=true, logy=true, size_in=(1140,600))
    bin_time_pow2 = Int(log2(data.bin_time))

    # Don't plot the 0Hz amplitude
    powers = data.powers
    freqs  = data.freqs
    powers[1] = NaN
    freqs[1]   = NaN

    freqs, powers, errors = _fspec_rebin(powers, freqs, 1, rebin)

    ylab = "Amplitude"

    Plots.plot!(freqs, powers, color=:black, ylab=ylab, lab="$lab - $(data.pg_type)")

    Plots.plot!(xlab="Freq (Hz)", alpha=1,
    title="Periodogram - $(data.obsid) - 2^$(bin_time_pow2) bt - $rebin rebin$title_append")
    
    if logy      
        amp_min = minimum(powers[2:end])
        amp_max = maximum(powers[2:end])
        # If amp_min < 1, can't use prevpow10 for ylims, hacky little fix is 1/prevpow(10, 1/amp_min)
        # removed that anyway, set ylim to 1 if amp_min < 1
        # TODO: Look at/fix the manual ylim settings, since it seems to... make things worse usually
        # amp_min > 1 ? ylim = (prevpow(10, amp_min), nextpow(10, amp_max)) : ylim = (1, nextpow(10, amp_max))
        yaxis!(yscale=:log10, yformatter=yi->round(yi, sigdigits=3))
    end

    _plot_formatter!()
    return Plots.plot!(size=size_in)
end

function plot(instrument_data::Dict{Symbol,JAXTAM.PgramData};
        rebin=(:linear, 1), logx=false, logy=true, save_plt=true,
        size_in=(1140,600), title_append="")

    instruments = keys(instrument_data)

    plt = Plots.plot()

    for instrument in instruments
        plt = plot!(instrument_data[instrument], lab=string(instrument),
            rebin=rebin, size_in=size_in, logx=logx, logy=logy, title_append=title_append)
    end

    if save_plt
        example_pgram = _pull_data(instrument_data)
        obs_row       = master_query(example_pgram.mission, :obsid, example_pgram.obsid)
        _savefig_obsdir(obs_row, example_pgram.mission, example_pgram.obsid, example_pgram.bin_time,
            "pgram", "$(example_pgram.pg_type)_pgram.png")
    end

    return Plots.plot!(size=size_in)
end

function plot_groups(instrument_data::Dict{Symbol,Dict{Int64,JAXTAM.PgramData}};
    rebin=(:linear, 1), logx=false, logy=true, save_plt=true,
    size_in=(1140,600), title_append="")

    instruments = keys(instrument_data)

    example_pgram = _pull_data(instrument_data)
    obs_row       = master_query(example_pgram.mission, :obsid, example_pgram.obsid)

    group_plots = Dict{Symbol,Dict{Int64,Plots.Plot}}()
    for instrument in instruments
        instrument_group_plots = Dict{Int64,Plots.Plot}()
        available_groups = unique([gti.group for gti in values(instrument_data[instrument])])
        available_groups = available_groups[available_groups .>= 0] # Excluse -1, -2, etc... for scrunched/mean FFTData

        for group in available_groups
            title_append = " - group $group/$(maximum(available_groups))"

            instrument_group_plots[group] = plot(Dict(instrument=>instrument_data[instrument][group]);
                title_append=title_append, size_in=size_in, save_plt=false)

            if save_plt
                _savefig_obsdir(obs_row, example_pgram.mission, example_pgram.obsid, example_pgram.bin_time,
                "pgram/groups/", "$(group)_pgram.png")
            end
        end

        group_plots[instrument] = instrument_group_plots
    end

    return group_plots
end

# Spectrogram plotting functions

function plot_sgram(fs::Dict{Symbol,Dict{Int64,JAXTAM.FFTData}}; 
        rebin=(:log10, 0.01), size_in=(1140,600), save_plt=true)
    instruments = keys(fs)

    sgram_instrument_plots = Dict{Symbol,Plots.Plot}()
    for instrument in instruments
        example_data = fs[instrument][-1]
        bin_time_pow2 = Int(log2(example_data.bin_time))

        sgram_freq, sgram_power, sgram_bounds, sgram_groups = fspec_rebin_sgram(fs[instrument], rebin=rebin)
        sgram_power = (sgram_power .- 2) .* sgram_freq
        sgram_power[sgram_power .<= 0] .= 0
        sgram_power = sgram_power'

        heatmap(sgram_power, 
            size=size_in, fill=true, #legend=false,
            xlab="Freq (Hz - log10 - log scale support faulty, ticks excluded)", ylab="Group",
            title="Spectrogram - $(example_data.obsid) - 2^$(bin_time_pow2) bt - $(example_data.bin_size*example_data.bin_time) bs - $rebin rebin")

        xticks!([0])

        if length(sgram_bounds) < 25
            hline!(sgram_bounds.+0.5, alpha=0.75, line=:dot, lab="")
            yaxis_bounds_to_group = Dict(diag([(bound,group) for bound in sgram_bounds, group in sgram_groups]))
            yaxis!(yticks=sgram_bounds, yformatter=yi->yaxis_bounds_to_group[Int(yi)])
        end

        _plot_formatter!()

        sgram_instrument_plots[instrument] = Plots.plot!()

        if(save_plt)
            obs_row = master_query(example_data.mission, :obsid, example_data.obsid)
            _savefig_obsdir(obs_row, example_data.mission, example_data.obsid, example_data.bin_time, "sgram/$(example_data.bin_size*example_data.bin_time)", "sgram.png")
        end
    end

    return sgram_instrument_plots
end

# Covariance plotting

function plot_fspec_cov1d(fs::Dict{Symbol,Dict{Int64,JAXTAM.FFTData}}; size_in=(1140,600), rebin=(:log10, 0.01))
    instruments = keys(fs)

    example_data = _pull_data(fs)
    obsid = example_data.obsid
    bin_time = example_data.bin_time
    bin_time_pow2 = Int(log2(example_data.bin_time))
    bin_size = example_data.bin_size

    cov1d_plots = Dict{Symbol,Plots.Plot}()
    for instrument in instruments
        fspec_freq, fspec_power = JAXTAM.fspec_rebin_sgram(fs[instrument]; rebin=rebin)

        fspec_diag = diag(cov(fspec_power, dims=2))
        yaxis_max  = nextpow(10, maximum(fspec_diag))

        bin_count = size(fspec_power, 2)

        fspec_diag[fspec_diag .<= 10] .= NaN

        Plots.plot(fspec_freq, fspec_diag, lab=instrument,
            color=:black, size=size_in,
            title="FFT 1D Covariance - $(obsid) - 2^$(bin_time_pow2) bt - $(bin_size*bin_time) bs - $rebin rebin - $(bin_count) sections averaged")

        xaxis!(xscale=:log10, xformatter=xi->xi, xlab="Freq (Hz - log10)", xlims=(0.01, nextpow(2, maximum(fspec_freq))))
        yaxis!(yscale=:log10, yformatter=xi->xi, ylab="Cov (diag - log10)", ylims=(10, yaxis_max))
        hline!([4000], lab="4000 - Threshold")
        
        cov1d_plots[instrument] = _plot_formatter!()
    end

    return cov1d_plots
end

function _plot_cov2d(fs::Dict{Int64,JAXTAM.FFTData}, rebin::Tuple, zoom_log10=false)
    fspec_freq, fspec_power = JAXTAM.fspec_rebin_sgram(fs; rebin=rebin) 

    if rebin[1] == :linear
        fspec_cov_2d = cov(reverse(reverse(fspec_power, dims=2), dims=1), dims=2)
    elseif rebin[1] == :log10
        fspec_cov_2d = cov(fspec_power, dims=2)
    else
        error("Invalid rebin type: $(rebin[1])")
    end

    fspec_cov_2d[isnan.(fspec_cov_2d)] .= 0
    
    max_ind_2d = findmax(fspec_cov_2d)[2]
    max_freq_x = fspec_freq[max_ind_2d[1]]
    max_freq_y = fspec_freq[max_ind_2d[2]]

    if zoom_log10!=false && rebin[1]==:log10
        zoom_ind_start = findfirst(fspec_freq .>= max_freq_x - max_freq_x*zoom_log10)
        zoom_ind_stop  = findfirst(fspec_freq .>= max_freq_x + max_freq_x*zoom_log10)
        println(zoom_log10)
        println(zoom_ind_start)
        println(zoom_ind_stop)
        fspec_cov_2d = fspec_cov_2d[zoom_ind_start:zoom_ind_stop, zoom_ind_start:zoom_ind_stop]

        max_ind_2d = findmax(fspec_cov_2d)[2]
        max_freq_x = fspec_freq[max_ind_2d[1]]
        max_freq_y = fspec_freq[max_ind_2d[2]]

        rebin = (rebin[1], rebin[2], "$(zoom_log10) zoom")
    end

    heatmap(fspec_cov_2d, legend=false, aspect_ratio=:equal, xlab="$rebin cov")

    vline!([max_ind_2d[1]], color=:cyan, alpha=0.25, line=:dot)
    hline!([max_ind_2d[2]], color=:cyan, alpha=0.25, line=:dot)
    xticks!([max_ind_2d[1]]); yticks!([0])
    xaxis!(xformatter=xi->"$(round(max_freq_x, sigdigits=3)) Hz")
    yaxis!(yformatter=xi->"$(round(max_freq_y, sigdigits=3)) Hz")
end

function plot_fspec_cov2d(fs::Dict{Symbol,Dict{Int64,JAXTAM.FFTData}}; size_in=(1140,600*2))
    instruments = keys(fs)

    example_data = _pull_data(fs)
    obsid = example_data.obsid
    bin_time = example_data.bin_time
    bin_time_pow2 = Int(log2(example_data.bin_time))
    bin_size = example_data.bin_size
    fs_length = length(example_data.avg_amp)

    rebin_lin = (:linear, maximum([floor(Int, fs_length/1024), 1]))
    rebin_log = (:log10, 0.01)

    for instrument in instruments
        fspec_freq, fspec_power = JAXTAM.fspec_rebin_sgram(fs[instrument]; rebin=rebin_lin)

        cov2d_linear_plot = _plot_cov2d(fs[instrument], rebin_lin)

        cov2d_log_plot = _plot_cov2d(fs[instrument], rebin_log, false)

        cov2d_log_plot_x1 = _plot_cov2d(fs[instrument], rebin_log, 1)
        cov2d_log_plot_x2 = _plot_cov2d(fs[instrument], rebin_log, 0.5)

        bin_count = size(fspec_power, 2)

        l = @layout [b c; d e] # [a{.001h}; [b c; d e]]
        dual_cov_plot = Plots.plot(
            # Plots.plot(title="FFT 2D Covariances - $(obsid) - 2^$(bin_time_pow2) bt - $(bin_size*bin_time) bs - $(bin_count) sections averaged",
            #     #annotation=(0.25, 0.5, 
            #     #"FFT 2D Covariances - $(obsid) - 2^$(bin_time_pow2) bt - $(bin_size*bin_time) bs - $(bin_count) sections averaged", 12),
            #     framestyle = :none), 
            cov2d_linear_plot,
            cov2d_log_plot,
            cov2d_log_plot_x1,
            cov2d_log_plot_x2,
            layout=l,
            size=size_in)

        _plot_formatter!()

        return dual_cov_plot
    end
end