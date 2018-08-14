#@tags head title meta div p h1 h2 h3 hr intro table thead tbody tr th td
#@tags_noescape script

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
        m("script", "
        \$(document).ready(function() {
            \$('#example').DataTable();
        } );"; :type=>"text/javascript", class="init")
    )
end

function _webgen_home_intro(mission_name::Symbol)
    node_intro = intro(
        m("div"; class="se-pre-con"),
        m("div"; class="container"),
        m("h1", "JAXTAM.jl WebView - $mission_name"),
        m("hr"),
        m("p", "JAXTAM results summary page for $mission_name")
    )
end

function _webgen_table(df::DataFrames.DataFrame)
    headers = names(df)

    rows, cols = size(a)

    node_table = table(
        thead(
            tr(
                th.(headers)
            )
        ),
        tbody(
            tr.([td.([df[r, c] for c in 1:cols]) for r in 1:rows])
        )
    )
end

function webgen_mission(mission_name::Symbol)
    web_dir = config(:web)
    
    web_home_dir  = joinpath(web_dir, "index.html")

    html = html(
        _webgen_head(mission_name),
        _webgen_home_intro(mission_name),
        _webgen_table(master_a(mission_name))
    )

    write(web_home_dir, Pretty(html))

    return web_home_dir
end