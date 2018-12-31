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

    (e_min, e_max) = (config(example.mission).good_energy_min, config(example.mission).good_energy_max)

    savefig(example, obs_row, (e_min, e_max); plot_name="grid")
end

function report(mission_name, obsid; overwrite=false, nuke=false)
    obs_row = master_query(mission_name, :obsid, obsid)

    obsid = obs_row[1, :obsid] 

    obs_dir  = _clean_path_dots(config(mission_name).path_obs(obs_row))
    obs_path = string(config(mission_name).path, obs_dir)
    obs_path = replace(obs_path, "//"=>"/")
    JAXTAM_path = joinpath(obs_path, "JAXTAM")

    e_range = (config(mission_name).good_energy_min, config(mission_name).good_energy_max)

    if nuke && ispath(JAXTAM_path)
        GC.gc() # Required due to Feather.jl loading files lazily, meaning they can't be removed from disk
                # until garbace collection runs and un-lazily-loads them
        rm(JAXTAM_path, recursive=true)
    end

    obs_log = _log_read(mission_name, obs_row)
    img_count = if haskey(obs_log, "images")
        size(obs_log["images"][e_range], 1)
    else
        0
    end

    if img_count < 1 || overwrite
        lc = JAXTAM.lcurve(mission_name, obs_row, 2.0^0)
        JAXTAM.plot(lc; save=true); JAXTAM.plot_groups(lc; save=true, size_in=(1140,400/2))
        pg = JAXTAM.pgram(lc); JAXTAM.plot(pg; save=true);
        pg = JAXTAM.pgram(lc; per_group=true); JAXTAM.plot_groups(pg; save=true, size_in=(1140,600/2));
        lc = 0; pg=0; GC.gc()

        JAXTAM.lcurve(mission_name, obs_row, 2.0^-13); GC.gc()

        fs = JAXTAM.fspec(mission_name, obs_row, 2.0^-13, 128)
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

        _call_all_espec(mission_name, obs_row)
    end

    sp = _webgen_subpage(mission_name, obs_row)

    webgen_mission(mission_name)

    return sp
end

function report_all(similar_missions::Array{Symbol,1}, obsid::String; overwrite=false, nuke=false)
    for mission in similar_missions
        report.(mission, obsid, overwrite=overwrite, nuke=nuke)
        report.(mission, obsid)
    end
end

function report_all(base_mission::Symbol, obsids::Union{Array{String,1},String}; overwrite=false, nuke=false)
    missions = string.(collect(keys(JAXTAM.config())))
    missions = missions[missions .!= string(base_mission)] # Remove the current mission from the list
    
    missions_split = split.(missions, "_") # Spit off the _ to remove energy bound notation
    # Select missions with the same base name 
    similar_missions = [any(occursin.(split(string(base_mission), "_")[1], m)) for m in missions_split]
    similar_missions = Symbol.([base_mission; missions[similar_missions]])
    
    typeof(obsids) == String ? obsids = [obsids] : ""
    for obsid in obsids
        report_all(similar_missions, obsid; overwrite=overwrite, nuke=nuke)
    end
end