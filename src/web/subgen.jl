function _webgen_results_intro(obs_row)
    obsid = obs_row[1, :obsid]
    name  = obs_row[1, :name]
    abstract_text = obs_row[1, :abstract]
    node_intro = intro(
        div(class="se-pre-con"),
        div(class="container",
            h1("Observation $obsid - $name"),
            h2("Abstract"),
            p(abstract_text),
            hr(),
            h4("Status"),
            _webgen_table(obs_row[:, [:public_date, :publicity, :time]]; table_id=""),
            h4("Source Details"),
            _webgen_table(obs_row[:, [:name, :ra, :dec, :lii, :bii, :obs_type]]; table_id=""),
            h4("Observation Details"),
            _webgen_table(obs_row[: ,[:time, :end_time, :exposure, :remarks]]; table_id=""),
            h4("Misc"),
            _webgen_table(obs_row[[:processing_status, :processing_date, :processing_version, :num_processed, :caldb_version, :remarks]], table_id="")
        )
    )
end

function _webgen_results_body(obs_row; img_dict=Dict())

    node_body = div(class="container",
        hr(),
        h2("Plots"),
        [(h4(imgpair[1]), img(src=imgpair[2])) for imgpair in img_dict]
    )
end

function _webgen_subpage_findimg(JAXTAM_path)
    paths = []
    for (root, dirs, files) in walkdir(JAXTAM_path)
        for file in files
            if file[end-3:end] == ".png"
                append!(paths, [joinpath(root, file)])
            end
        end
    end

    img_bin_times  = []
    img_kinds      = []
    img_bin_sizes  = []
    img_orbits     = []
    img_titles     = []
    img_kind_ordrs = Array{Int64,1}()
    for path in paths
        img_dir  = splitdir(replace.(path, JAXTAM_path=>""))[1]
        img_name = splitdir(replace.(path, JAXTAM_path=>""))[2]

        img_dir_splt = split(img_dir, "/")

        # 1  - empty string, as split("/", "/") = ""
        @assert img_dir_splt[1] == ""

        # 2  - lc diectory
        @assert img_dir_splt[2] == "lc"

        # 3  - bin time
        img_bin_time = Meta.parse(img_dir_splt[3])
        @assert typeof(img_bin_time) == Float64
        if img_bin_time < 1.0
            # Pray this is a power of 2
            if ispow2(Int(1/img_bin_time))
                # Adopt semi-standard notation that -ve value implies a -ve power of 2
                img_bin_time = -log2(1/img_bin_time)
            else
                @warn "img_bin_time doesn't seem to be a power of 2"
            end
        end
        append!(img_bin_times, img_bin_time)

        try
            img_bin_time = Int(img_bin_time)
        finally
            if img_bin_time < 0
                img_bin_time = "2^$(img_bin_time)"
            end
        end
        
        # 4  - /images/ directory
        @assert img_dir_splt[4] == "images"

        # 5  - folder named after on of the plot kinds: fspec, lc, or pgram
        img_kind = img_dir_splt[5]
        @assert img_kind in ["fspec", "lc", "pgram"]
        append!(img_kinds, [img_kind])

        # 6  - Diverges based on kind
        if img_kind == "fspec"
            # 6a - fspec bin_size
            img_bin_size = img_dir_splt[6]
            if length(img_dir_splt) > 6 && img_dir_splt[7] == "orbits"
                # 7a1 - fspec orbits folder
                img_kind_ordr = 30
                img_orbit = parse(Int, replace(img_name, "_fspec.png"=>""))
                img_title = "Power Spectra - Orbit $img_orbit - $img_bin_time bt - $img_bin_size bs"
            else
                # 7a2 - not an orbit plot
                img_kind_ordr = 3
                img_title = "Power Spectra - $img_bin_time bt - $img_bin_size bs"
                img_orbit = 0
            end
        elseif img_kind == "lc"
            # 6b - lc has no bin size
            img_bin_size = missing
            if length(img_dir_splt) > 5 && img_dir_splt[6] == "orbits"
                # 6b1 - lc orbits folder
                img_kind_ordr = 10
                img_orbit = parse(Int, replace(img_name, "_lcurve.png"=>""))
                img_title = "Light Curve - Orbit $img_orbit - $img_bin_time bt"
            else
                # 6b2 - not an orbit plot
                img_kind_ordr = 1
                img_title = "Light Curve - $img_bin_time bt"
                img_orbit = 0
            end
        elseif img_kind == "pgram"
            # 6c - pgram has no bin size
            img_bin_size = missing
            if length(img_dir_splt) > 5 && img_dir_splt[6] == "orbits"
                # 6b1 - lc orbits folder
                img_kind_ordr = 20
                img_orbit = parse(Int, replace(img_name, "_pgram.png"=>""))
                img_title = "Periodogram - Orbit $img_orbit - $img_bin_time bt"
            else
                # 6b2 - not an orbit plot
                img_kind_ordr = 2
                img_title = "Periodogram - $img_bin_time bt"
                img_orbit = 0
            end
        end

        append!(img_bin_sizes, [img_bin_size])
        append!(img_orbits, [img_orbit])
        append!(img_titles, [img_title])
        append!(img_kind_ordrs, img_kind_ordr)
    end

    image_path_df = DataFrame(
                                path=replace.(paths, JAXTAM_path=>"./JAXTAM/"),
                                bin_times=img_bin_times,
                                kinds=img_kinds,
                                bin_size=img_bin_sizes,
                                img_orbit=img_orbits,
                                img_title=img_titles,
                                img_kind_ordr=img_kind_ordrs
                            )
end

function _webgen_subpage(mission_name, obs_row)
    obsid = obs_row[1, :obsid] 

    obs_dir  = _clean_path_dots(config(mission_name).path_obs(obs_row))
    obs_path = string(config(mission_name).path, obs_dir)
    obs_path = replace(obs_path, "//"=>"/")
    JAXTAM_path = joinpath(obs_path, "JAXTAM")
    
    results_page_dir = string(config(mission_name).path_web, obs_dir)
    results_page_dir = replace(results_page_dir, "//"=>"/")
    JAXTAM_path_web = joinpath(results_page_dir, "JAXTAM")

    img_details = _webgen_subpage_findimg(JAXTAM_path)
    img_details = sort(img_details, (:img_orbit, :img_kind_ordr))
    img_tuple   = [img[:img_title]=>img[:path] for img in DataFrames.eachrow(img_details)]
    img_dict    = OrderedDict(img_tuple)

    # img_dir_lcurve = "./JAXTAM/lc/1/images/lcurve.png"
    # img_dir_fspec  = "./JAXTAM/lc/0.0009765625/images/fspec.png"

    # img_dict = Dict("Light Curve"=>img_dir_lcurve, "Power Spectra"=>img_dir_fspec)

    html_out = html(
        _webgen_head(;title_in="$mission_name - $obsid - Results"),
        body(
            _webgen_results_intro(obs_row),
            _webgen_results_body(obs_row; img_dict=img_dict)
        )
    )

    mkpath(results_page_dir)
    !islink(JAXTAM_path_web) ? symlink(JAXTAM_path, JAXTAM_path_web) : ""
    
    write(joinpath(results_page_dir, "result.html"), string(Pretty(html_out)))
    return joinpath(results_page_dir, "result.html")
end

function webgen_subpage(mission_name, obsid)
    obs_row = master_query(mission_name, :obsid, obsid)

    return _webgen_subpage(mission_name, obs_row)
end

function report(mission_name, obsid)
    obs_row = master_query(mission_name, :obsid, obsid)

    obsid = obs_row[1, :obsid] 

    obs_dir  = _clean_path_dots(config(mission_name).path_obs(obs_row))
    obs_path = string(config(mission_name).path, obs_dir)
    obs_path = replace(obs_path, "//"=>"/")
    JAXTAM_path = joinpath(obs_path, "JAXTAM")

    if isdir(JAXTAM_path)
        images = _webgen_subpage_findimg(JAXTAM_path)
    else
        images = []
    end

    if size(images, 1) < 1
        lc = lcurve(mission_name, obs_row, 2.0^0)
        JAXTAM.plot(lc); JAXTAM.plot_orbits(lc)
        pgf = pgram(lc); JAXTAM.plot(pgf);
        lc = 0; GC.gc()

        lcurve(mission_name, obs_row, 2.0^-13); gc()

        fs = fspec(mission_name, obs_row, 2.0^-13, 128)
        JAXTAM.plot(fs); JAXTAM.plot_orbits(fs)
        fs = 0; GC.gc()

        fs = fspec(mission_name, obs_row, 2.0^-13, 64)
        JAXTAM.plot(fs); JAXTAM.plot_orbits(fs)
        fs = 0; GC.gc()
    end

    sp =  _webgen_subpage(mission_name, obs_row)

    webgen_mission(mission_name)

    return sp
end