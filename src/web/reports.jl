function _plot_fspec_grid(fs::Dict{Symbol,Dict{Int64,JAXTAM.FFTData}},
        obs_row, mission_name, bin_time, subfolder, fig_name)
    plt_1 = plot(fs; norm=:rms,   save=false, save_csv=true)
    plt_2 = plot(fs; norm=:leahy, save=false)

    plt_3 = plot(fs, norm=:leahy, save=false, freq_lims=(0, 1),     rebin=(:linear, 1),
        logx=false, logy=false, title_append=" - 0 to 1 Hz")
    plt_4 = plot(fs, norm=:leahy, save=false, freq_lims=(1, :end),  rebin=(:linear, 1),
        logx=false, logy=false, title_append=" - 1 to :end Hz")
    plt_4 = plot(fs, norm=:leahy, save=false, freq_lims=(50, :end), rebin=(:linear, 1),
        logx=false, logy=false, title_append=" - 50 to :end Hz")

    Plots.plot(plt_1, plt_2, plt_3, plt_4, layout=grid(4,1), size=(1140,600*4))

    _savefig_obsdir(obs_row, mission_name, bin_time, subfolder, fig_name)
end

function report(mission_name, obsid; overwrite=false, nuke=false)
    obs_row = master_query(mission_name, :obsid, obsid)

    obsid = obs_row[1, :obsid] 

    obs_dir  = _clean_path_dots(config(mission_name).path_obs(obs_row))
    obs_path = string(config(mission_name).path, obs_dir)
    obs_path = replace(obs_path, "//"=>"/")
    JAXTAM_path = joinpath(obs_path, "JAXTAM")

    if nuke
        rm(JAXTAM_path, recursive=true)
    end

    if isdir(JAXTAM_path)
        images = _webgen_subpage_findimg(JAXTAM_path)
    else
        images = []
    end

    if size(images, 1) < 1 || overwrite
        lc = JAXTAM.lcurve(mission_name, obs_row, 2.0^0)
        JAXTAM.plot(lc; save=true); JAXTAM.plot_groups(lc; save=true, size_in=(1140,400/2))
        pg = JAXTAM.pgram(lc); JAXTAM.plot(pg; save=true);
        pg = JAXTAM.pgram(lc; per_group=true); JAXTAM.plot_groups(pg; save=true, size_in=(1140,600/2));
        lc = 0; pg=0; GC.gc()

        JAXTAM.lcurve(mission_name, obs_row, 2.0^-13); GC.gc()

        fs = JAXTAM.fspec(mission_name, obs_row, 2.0^-13, 128)
        @info "Plotting fspec grid";    JAXTAM._plot_fspec_grid(fs, obs_row, mission_name, 2.0^-13, "fspec/128.0/", "fspec.png")
        @info "Plotting fspec groups";  JAXTAM.plot_groups(fs; save=true, size_in=(1140,600/2))
        @info "Plotting sgram";         JAXTAM.plot_sgram(fs;  save=true, size_in=(1140,600/2))
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
    end

    sp = _webgen_subpage(mission_name, obs_row)

    webgen_mission(mission_name)

    return sp
end