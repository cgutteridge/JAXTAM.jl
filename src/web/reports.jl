function _plot_fspec_grid(fs::Dict{Symbol,Dict{Int64,JAXTAM.FFTData}})
    plt_1 = plot(fs; save_plt=false)
    plt_2 = plot(fs; norm=:leahy)
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
        lc = lcurve(mission_name, obs_row, 2.0^0)
        JAXTAM.plot(lc); JAXTAM.plot_groups(lc; size_in=(1140,400/2))
        pg = pgram(lc); JAXTAM.plot(pg);
        pg = pgram(lc; per_group=true); JAXTAM.plot_groups(pg; size_in=(1140,600/2));
        lc = 0; pg=0; GC.gc()

        lcurve(mission_name, obs_row, 2.0^-13); GC.gc()

        fs = fspec(mission_name, obs_row, 2.0^-13, 128)
        JAXTAM.plot(fs); JAXTAM.plot_groups(fs; size_in=(1140,600/2))
        JAXTAM.plot_sgram(fs; size_in=(1140,600/2))
        fs = 0; GC.gc()

        fs = fspec(mission_name, obs_row, 2.0^-13, 64)
        JAXTAM.plot(fs); JAXTAM.plot_groups(fs; size_in=(1140,600/2))
        JAXTAM.plot_sgram(fs; size_in=(1140,600/2))
        fs = 0; GC.gc()
    end

    sp = _webgen_subpage(mission_name, obs_row)

    webgen_mission(mission_name)

    return sp
end