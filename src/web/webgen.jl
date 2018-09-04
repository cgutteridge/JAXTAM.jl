@tags html head body title meta div p h1 h2 h3 h4 hr intro table thead tbody tr th td img a
@tags_noescape script
@tags intro

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

function _webgen_home_intro(mission_name::Symbol)
    node_intro = intro(
        m("div"; class="se-pre-con"),
        div(class="container",
            m("div"; class="container"),
            m("h1", "JAXTAM.jl WebView - $mission_name"),
            m("hr"),
            m("p", "JAXTAM results summary page for $mission_name")
        )
    )
end

function _add_obsid_url(obsid, results_path)
    results_exist = results_path .!= "NA"

    obsid_url = Array{Union{Hyperscript.Node{Hyperscript.HTMLSVG},String},1}(undef, size(results_exist, 1))

    obsid_url[results_exist] = [a(obsid[i], href=results_path[i]) for i in findall(results_exist)]
    obsid_url[results_exist .!= true] = obsid[results_exist .!= true]

    return obsid_url
end

function _webgen_table(df::DataFrames.DataFrame; table_id="example")
    if :obsid in names(df)
        obsid_url = _add_obsid_url(df[:obsid], df[:results_path])
        delete!(df, [:obsid, :results_path])
        df[:obsid] = obsid_url
        permutecols!(df, [:obsid; names(df)[1:end-1][:]])
    end
    
    rows, cols = size(df)
    headers = names(df)
    
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
    
    web_dir = config(mission_name).path_web
    
    web_home_dir  = joinpath(web_dir, "index.html")

    html_out = html(
        _webgen_head(;title_in="JAXTAM $mission_name homepage"),
        body(
            _webgen_home_intro(mission_name),
            _webgen_table(master_a(mission_name)[:, [:name, :obsid, :subject_category, :obs_type, :publicity, :downloaded, :analysed, :time, :results_path]])
        )
    )

    write(web_home_dir, string(Pretty(html_out)))

    return web_home_dir
end