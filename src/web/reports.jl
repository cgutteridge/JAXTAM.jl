function _plot_fspec_grid(fs::Dict{Symbol,Dict{Int64,JAXTAM.FFTData}},
        obs_row)
    example = _recursive_first(fs)

    plt_1 = plot(fs; norm=:rms,   save=false, save_csv=true)
    plt_2 = plot(fs; norm=:leahy, save=false)

    plt_3 = plot(fs, norm=:leahy, save=false, freq_lims=(0, 1),     rebin=(:linear, 1),
        logx=false, logy=false, title_append=" - 0 to 1 Hz")
    plt_4 = plot(fs, norm=:leahy, save=false, freq_lims=(1, :end),  rebin=(:linear, 1),
        logx=false, logy=false, title_append=" - 1 to :end Hz")
    plt_4 = plot(fs, norm=:leahy, save=false, freq_lims=(50, :end), rebin=(:linear, 1),
        logx=false, logy=false, title_append=" - 50 to :end Hz")

    Plots.plot(plt_1, plt_2, plt_3, plt_4, layout=grid(4,1), size=(1140,600*4))

    savefig(example, obs_row, example.e_range; plot_name="grid")
end

function report(mission, obs_row; e_range=_mission_good_e_range(mission), overwrite=false, nuke=false)
    path_jaxtam = abspath(_obs_path_local(mission, obs_row; kind=:jaxtam), "JAXTAM")
    path_web    = abspath(_obs_path_local(mission, obs_row; kind=:web), "JAXTAM")

    if nuke
        GC.gc() # Required due to Feather.jl loading files lazily, meaning they can't be removed from disk
                # until garbace collection runs and un-lazily-loads them
        ispath(path_jaxtam) ? rm(path_jaxtam, recursive=true) : false
        ispath(path_web)    ? rm(path_web,    recursive=true) : false
    end

    images = _log_query(mission, obs_row, "images", e_range)

    img_count_groupless = ismissing(images) ? 0 : size(filter(x->ismissing(x[:group]), images), 1)
    # Expect five 'groupless' plots: lightcurve, periodogram, powerspectra, spectrogram, pulsations
    if img_count_groupless < 5 || overwrite
        lc = JAXTAM.lcurve(mission, obs_row, 2.0^0; e_range=e_range)
        JAXTAM.plot(lc; save=true); JAXTAM.plot_groups(lc; save=true, size_in=(1140,400/2))
        pg = JAXTAM.pgram(lc); JAXTAM.plot(pg; save=true);
        pg = JAXTAM.pgram(lc; per_group=true); JAXTAM.plot_groups(pg; save=true, size_in=(1140,600/2));
        lc = 0; pg=0; GC.gc()

        lc = JAXTAM.lcurve(mission, obs_row, 2.0^-13; e_range=e_range)
        gtis = JAXTAM.gtis(mission, obs_row, 2.0^-13; lcurve_data=lc); lc = 0

        fs = JAXTAM.fspec(mission, obs_row, 2.0^-13, 128; gtis_data=gtis)
        @info "Plotting fspec grid";    JAXTAM._plot_fspec_grid(fs, obs_row)
        @info "Plotting fspec groups";  JAXTAM.plot_groups(fs; save=true, size_in=(1140,600/2))
        @info "Plotting sgram";         JAXTAM.plot_sgram(fs;  save=true, size_in=(1140,600))
        @info "Plotting pulses";        JAXTAM.plot_pulses_candle(fs; save=true, size_in=(1140,600/2))
        @info "Plotting pulses groups"; JAXTAM.plot_pulses_candle_groups(fs; save=true, size_in=(1140,600/2))
        fs = 0; GC.gc()

        # Disable second 64 s power spectra plots
        # fs = JAXTAM.fspec(mission_name, obs_row, 2.0^-13, 64)
        # JAXTAM._plot_fspec_grid(fs, obs_row, mission_name, 2.0^-13, "fspec/64.0/", "fspec.png")
        # JAXTAM.plot_groups(fs; save=true, size_in=(1140,600/2))
        # JAXTAM.plot_sgram(fs;  save=true, size_in=(1140,600/2))
        # JAXTAM.plot_pulses_candle(fs; save=true, size_in=(1140,600/2))
        # fs = 0; GC.gc()

        # _call_all_espec(mission, obs_row)
    end

    sp = _webgen_subpage(mission, obs_row; e_range=e_range)

    # webgen_mission(mission)

    return sp
end

function report(mission::Mission, obsid::String; e_range=_mission_good_e_range(mission), overwrite=false, nuke=false)
    obs_row = master_query(mission, :obsid, obsid)

    return report(mission, obs_row; e_range=e_range, overwrite=overwrite, nuke=nuke)
end

function report_all(mission::Mission, obs_row::DataFrames.DataFrameRow; e_ranges=[(0.2,12.0), (2.0,10.0), (0.2,2.0)], overwrite=false, nuke=false)
    if nuke
        path_jaxtam = abspath(_obs_path_local(mission, obs_row; kind=:jaxtam), "JAXTAM")
        path_web    = abspath(_obs_path_local(mission, obs_row; kind=:web), "JAXTAM")
    
        GC.gc() # Required due to Feather.jl loading files lazily, meaning they can't be removed from disk
                # until garbace collection runs and un-lazily-loads them
        ispath(path_jaxtam) ? rm(path_jaxtam, recursive=true) : false
        ispath(path_web)    ? rm(path_web,    recursive=true) : false
    end

    for e_range in e_ranges
        report(mission, obs_row; e_range=e_range, overwrite=overwrite)
    end

    # Run it again to re-generate report pages so that they all have each others links in them
    for e_range in e_ranges
        println("Report path:\n\t$(report(mission, obs_row; e_range=e_range, overwrite=false))")
    end
end

function report_all(mission::Mission, obsid::String; e_ranges=[(0.2,12.0), (2.0,10.0), (0.2,2.0)], overwrite=false, nuke=false)
    obs_row = _master_query(mission, :obsid, obsid)

    return report_all(mission, obs_row; e_ranges=e_ranges, overwrite=overwrite, nuke=nuke)
end