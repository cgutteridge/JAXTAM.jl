@tags html head body title meta div p h1 h2 h3 h4 h5 hr intro table thead tbody tr th td img a
@tags_noescape script style
@tags intro

function _webgen_offline_sheets(path_web)
    sheet_urls_css = [
        "cdn/css/",
        "https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.1.1/css/bootstrap.css",
        "https://cdn.datatables.net/1.10.19/css/dataTables.bootstrap4.min.css",
        "https://cdn.datatables.net/v/bs4/dt-1.10.18/b-1.5.2/b-html5-1.5.2/fc-3.2.5/fh-3.1.4/sc-1.5.0/datatables.min.css"
    ]

    sheet_urls_js  = [
        "cdn/js/",
        "https://code.jquery.com/jquery-3.3.1.js",
        "https://cdn.datatables.net/1.10.19/js/jquery.dataTables.min.js",
        "https://cdn.datatables.net/1.10.19/js/dataTables.bootstrap4.min.js",
        "https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.36/pdfmake.min.js",
        "https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.36/vfs_fonts.js",
        "https://cdn.datatables.net/v/bs4/dt-1.10.18/b-1.5.2/b-html5-1.5.2/fc-3.2.5/fh-3.1.4/sc-1.5.0/datatables.min.js"
    ]

    for sheet_urls in [sheet_urls_css, sheet_urls_js]
        dir  = sheet_urls[1]
        urls = sheet_urls[2:end]
        file_names = basename.(urls)
        file_paths = string.(path_web, dir, file_names)
        println(file_paths)
    end
end

function _webgen_head(;title_in="")
    node = m("head",
        m("title", title_in),
        m("meta"; charset="utf-8"),
        m("link"; rel="stylesheet", :type=>"text/css", href="https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.1.1/css/bootstrap.css"),
        m("link"; rel="stylesheet", :type=>"text/css", href="https://cdn.datatables.net/1.10.19/css/dataTables.bootstrap4.min.css"),
        m("link"; rel="stylesheet", :type=>"text/css", href="https://cdn.datatables.net/v/bs4/dt-1.10.18/b-1.5.2/b-html5-1.5.2/fc-3.2.5/fh-3.1.4/sc-1.5.0/datatables.min.css"),
        m("style"; :type=>"text/css", class="init"),
        m("script"; :type=>"text/javascript", language="javascript", src="https://code.jquery.com/jquery-3.3.1.js"),
        m("script"; :type=>"text/javascript", language="javascript", src="https://cdn.datatables.net/1.10.19/js/jquery.dataTables.min.js"),
        m("script"; :type=>"text/javascript", language="javascript", src="https://cdn.datatables.net/1.10.19/js/dataTables.bootstrap4.min.js"),
        m("script"; :type=>"text/javascript", src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.36/pdfmake.min.js"),
        m("script"; :type=>"text/javascript", src="https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.36/vfs_fonts.js"),
        m("script"; :type=>"text/javascript", src="https://cdn.datatables.net/v/bs4/dt-1.10.18/b-1.5.2/b-html5-1.5.2/fc-3.2.5/fh-3.1.4/sc-1.5.0/datatables.min.js"),
        m("script"; :type=>"text/javascript", class="init"),
        script("
        \$(document).ready(function() {
            \$('#example').DataTable();
        } );"; :type=>"text/javascript", class="init")
    )
end

function _webgen_home_intro(mission_name::Symbol, e_min, e_max)
    node_intro = intro(
        m("div"; class="se-pre-con"),
        div(class="container",
            m("div"; class="container"),
            m("h1", "JAXTAM.jl WebView - $mission_name ($e_min to $e_max keV)"),
            m("hr"),
            m("p", "JAXTAM reports summary page for $mission_name")
        )
    )
end

function _add_obsid_url(obsid, report_path)
    reports_exist = report_path .!= "NA"

    obsid_url = Array{Union{Hyperscript.Node{Hyperscript.HTMLSVG},String},1}(undef, size(reports_exist, 1))

    obsid_url[reports_exist] = [a(obsid[i], href=report_path[i]) for i in findall(reports_exist)]
    obsid_url[reports_exist .!= true] = obsid[reports_exist .!= true]

    return obsid_url
end

function _webgen_table(df::DataFrames.DataFrame; table_id="example")
    # Replaces plain string obsid with hyperlink to the report
    if haskey(df, :obsid)
        obsid_url = _add_obsid_url(df[:obsid], df[:report_path])
        delete!(df, [:obsid, :report_path])
        df[:obsid] = obsid_url
        permutecols!(df, [:obsid; names(df)[1:end-1][:]])
    end

    if haskey(df, :countrate)
        df[:countrate][df[:countrate] .== Inf] .= -2.0
        df[:countrate][isnan.(df[:countrate])] .= -3.0
        df[:countrate] = round.(Int, df[:countrate])
    end

    if haskey(df, :time) && table_id=="report_page"
        # Include MJD time in report summary
        df[:time] = string.(df[:time], " | ", round.(JAXTAM._datetime2mjd.(convert.(Dates.DateTime, df[:time])), digits=3), " (MJD 3dp)")
    end
    
    rows, cols = size(df)
    headers = names(df)

    replace!(headers, :subject_category=>:cat)
    replace!(headers, :reports_exist=>:report)
    
    node_table = div(class="container",
        table(id=table_id, class="table table-striped table-bordered", style="width:100%", 
            thead(
                tr(
                    th.(headers)
                )
            ),
            tbody(
                tr.([td.([df[r, c] for c in 1:cols]) for r in 1:rows])
            )
        )
    )
end

function webgen_mission(mission_name::Symbol)
    append_update(mission_name)
    mission_config = config(mission_name)
    web_dir = mission_config.path_web

    e_min, e_max = mission_config.good_energy_min, mission_config.good_energy_max
    
    web_home_dir = joinpath(web_dir, "index.html")

    master_a_df  = master_a(mission_name)
    
    included_cols = [
        :name,
        :obsid,
        :report_exists,
        :subject_category,
        :obs_type,
        :publicity,
        :downloaded,
        :time,
        :report_path
    ]

    if haskey(master_a_df, :countrate)
        append!(included_cols, [:countrate])

        countrate = master_a_df[:countrate]
        countrate[isnan.(countrate)] .= -2.0
        countrate[countrate .== Inf] .= -3.0
        countrate = floor.(Int, countrate)
    end

    html_out = html(
        _webgen_head(;title_in="JAXTAM $mission_name homepage"),
        body(
            _webgen_home_intro(mission_name, e_min, e_max),
            _webgen_table(master_a_df[:, included_cols])
        )
    )

    write(web_home_dir, string(Pretty(html_out)))

    return web_home_dir
end