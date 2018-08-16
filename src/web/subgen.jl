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

function _webgen_subpage(mission_name, obs_row)
    obsid = obs_row[1, :obsid] 

    obs_dir  = _clean_path_dots(config(mission_name).path_obs(obs_row))
    obs_path = string(config(mission_name).path, obs_dir)
    obs_path = replace(obs_path, "//"=>"/")
    JAXTAM_path = joinpath(obs_path, "JAXTAM")
    
    results_page_dir = string(config(mission_name).path_web, obs_dir)
    results_page_dir = replace(results_page_dir, "//"=>"/")
    JAXTAM_path_web = joinpath(results_page_dir, "JAXTAM")

    img_dir_lcurve = joinpath(results_page_dir, "JAXTAM/lc/1/images/lcurve.png")
    img_dir_fspec  = joinpath(results_page_dir, "JAXTAM/lc/0.0009765625/images/fspec.png")

    img_dict = Dict("Light Curve"=>img_dir_lcurve, "Power Spectra"=>img_dir_fspec)

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
end