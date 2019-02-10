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

"""
    report(::Mission, ::DataFrameRow; e_range::Tuple{Float64,Float64}, overwrite::Bool, nuke::Bool, update_masterpage::Bool)

Generates a report for the default energy range

Creates plots for:
    * Lightcurve (+ grouped lightcurves)
    * Periodigram (+ grouped periodograms)
    * Power Spectra
        * :rms, full range, log-rebinned, log-log plot
        * :leahy, full range, log-rebinned, log-log plot
        * :leahy, 0 to 1 Hz, no rebin, linear-linear plot
        * :leahy, 1 to end Hz, no rebin, linear-linear plot
        * :leahy, 50 to end Hz, no regin, linear-linear plot
    * Spectrogram
    * Pulsation search plot

Produces HTML report page

Updates the homepage
"""
function report(mission, obs_row; e_range=_mission_good_e_range(mission), overwrite=false, nuke=false, update_masterpage=true)
    path_jaxtam = abspath(_obs_path_local(mission, obs_row; kind=:jaxtam), "JAXTAM")
    path_web    = abspath(_obs_path_local(mission, obs_row; kind=:web), "JAXTAM")

    if nuke
        GC.gc() # Required due to Feather.jl loading files lazily, meaning they can't be removed from disk
                # until garbace collection runs and un-lazily-loads them
        ispath(path_jaxtam) ? rm(path_jaxtam, recursive=true) : false
        ispath(path_web)    ? rm(path_web,    recursive=true) : false
    end

    if ismissing(_log_query(mission, obs_row, "meta", :downloaded; surpress_warn=true)) || !_log_query(mission, obs_row, "meta", :downloaded)
        try
            download(mission, obs_row)
        catch err
            if typeof(err) == JAXTAMError
                _log_add(mission, obs_row, Dict{String,Any}("errors"=>Dict(err.step=>err)))
                @warn err
                return nothing
            else
                rethrow(err)
            end
        end
    end

    if !ismissing(JAXTAM._log_query(mission, obs_row, "errors", :read_cl; surpress_warn=true))
        @warn "Error logged at :read_cl stage, no files to be analysed, skipping report gen"
        return nothing
    end

    images = _log_query(mission, obs_row, "images", e_range)

    img_count_groupless = ismissing(images) ? 0 : size(filter(x->ismissing(x[:group]), images), 1)
    # Expect five 'groupless' plots: lightcurve, periodogram, powerspectra, spectrogram, pulsations
    if img_count_groupless < 5 || overwrite
        try
            lc = JAXTAM.lcurve(mission, obs_row, 2.0^0; e_range=e_range)
            JAXTAM.plot(lc; save=true); JAXTAM.plot_groups(lc; save=true, size_in=(1140,400/2))
            pg = JAXTAM.pgram(lc); JAXTAM.plot(pg; save=true);
            pg = JAXTAM.pgram(lc; per_group=true); JAXTAM.plot_groups(pg; save=true, size_in=(1140,600/2));
            lc = nothing; pg = nothing; GC.gc()
        catch err
            if typeof(err) == JAXTAMError
                _log_add(mission, obs_row, Dict{String,Any}("errors"=>Dict(err.step=>err)))
                @warn err
            else
                rethrow(err)
            end
        end

        try
            lc = JAXTAM.lcurve(mission, obs_row, 2.0^-13; e_range=e_range)
            gtis = JAXTAM.gtis(mission, obs_row, 2.0^-13; lcurve_data=lc, e_range=e_range); lc = 0

            fs = JAXTAM.fspec(mission, obs_row, 2.0^-13, 128; gtis_data=gtis, e_range=e_range)
            @info "Plotting fspec grid";    JAXTAM._plot_fspec_grid(fs, obs_row)
            @info "Plotting fspec groups";  JAXTAM.plot_groups(fs; save=true, size_in=(1140,600/2))
            @info "Plotting sgram";         JAXTAM.plot_sgram(fs;  save=true, size_in=(1140,600))
            @info "Plotting pulses";        JAXTAM.plot_pulses_candle(fs; save=true, size_in=(1140,600/2))
            @info "Plotting pulses groups"; JAXTAM.plot_pulses_candle_groups(fs; save=true, size_in=(1140,600/2))
            fs = 0; GC.gc()
        catch err
            if typeof(err) == JAXTAMError
                _log_add(mission, obs_row, Dict{String,Any}("errors"=>Dict(err.step=>err)))
                @warn err
            else
                rethrow(err)
            end
        end

        # Disable second 64 s power spectra plots
        # fs = JAXTAM.fspec(mission_name, obs_row, 2.0^-13, 64)
        # JAXTAM._plot_fspec_grid(fs, obs_row, mission_name, 2.0^-13, "fspec/64.0/", "fspec.png")
        # JAXTAM.plot_groups(fs; save=true, size_in=(1140,600/2))
        # JAXTAM.plot_sgram(fs;  save=true, size_in=(1140,600/2))
        # JAXTAM.plot_pulses_candle(fs; save=true, size_in=(1140,600/2))
        # fs = 0; GC.gc()

        # _call_all_espec(mission, obs_row)
    end

    sp = try
        _webgen_subpage(mission, obs_row; e_range=e_range)
    catch err
        if typeof(err) == JAXTAMError 
            _log_add(mission, obs_row, Dict{String,Any}("errors"=>Dict(err.step=>err)))
            @warn err
        else
            rethrow(err)
        end
        return nothing
    end

    if update_masterpage
        webgen_mission(mission)
    end

    return sp
end

function report(mission::Mission, obsid::String; e_range=_mission_good_e_range(mission), overwrite=false, nuke=false, update_masterpage=true)
    obs_row = master_query(mission, :obsid, obsid)

    return report(mission, obs_row; e_range=e_range, overwrite=overwrite, nuke=nuke, update_masterpage=update_masterpage)
end

"""
    report_all(::Mission, ::DataFrameRow; e_ranges=[(0.2,12.0), (2.0,10.0), (0.2,2.0)], overwrite::Bool, nuke::Bool, update_masterpage::Bool)

Calls `report` with three default energy ranges
"""
function report_all(mission::Mission, obs_row::DataFrames.DataFrameRow; e_ranges=[(0.2,12.0), (2.0,10.0), (0.2,2.0)], overwrite=false, nuke=false, update_masterpage=true)
    if nuke
        path_jaxtam = abspath(_obs_path_local(mission, obs_row; kind=:jaxtam), "JAXTAM")
        path_web    = abspath(_obs_path_local(mission, obs_row; kind=:web), "JAXTAM")
    
        GC.gc() # Required due to Feather.jl loading files lazily, meaning they can't be removed from disk
                # until garbace collection runs and un-lazily-loads them
        ispath(path_jaxtam) ? rm(path_jaxtam, recursive=true) : false
        ispath(path_web)    ? rm(path_web,    recursive=true) : false
    end

    for e_range in e_ranges
        report(mission, obs_row; e_range=e_range, overwrite=overwrite, update_masterpage=update_masterpage)
    end

    # Run it again to re-generate report pages so that they all have each others links in them
    for e_range in e_ranges
        println("Report path:\n\t$(report(mission, obs_row; e_range=e_range, overwrite=false))")
    end
end

function report_all(mission::Mission, obsid::String; e_ranges=[(0.2,12.0), (2.0,10.0), (0.2,2.0)], overwrite=false, nuke=false, update_masterpage=true)
    obs_row = _master_query(mission, :obsid, obsid)

    return report_all(mission, obs_row; e_ranges=e_ranges, overwrite=overwrite, nuke=nuke, update_masterpage=update_masterpage)
end