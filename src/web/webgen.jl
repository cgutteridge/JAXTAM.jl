function _html_escape(cell)
    if typeof(cell) == Missings.Missing
        return "missing"
    end

    cell = string(cell)

    cell = replace(cell, "&"=>"&amp;")
    cell = replace(cell, "<"=>"&lt;")
    cell = replace(cell, ">"=>"&gt;")
    return cell
end

function _webgen_head(; title="")
    return_html = "<!DOCTYPE html>
<html class=\"no-js\">
<head>
    <title>$title</title>
    <meta charset=\"utf-8\">

    <link rel=\"stylesheet\" type=\"text/css\" href=\"https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.1.1/css/bootstrap.css\">
    <link rel=\"stylesheet\" type=\"text/css\" href=\"https://cdn.datatables.net/1.10.19/css/dataTables.bootstrap4.min.css\">
    <link rel=\"stylesheet\" type=\"text/css\" href=\"https://cdn.datatables.net/v/bs4/dt-1.10.18/b-1.5.2/b-html5-1.5.2/fc-3.2.5/fh-3.1.4/sc-1.5.0/datatables.min.css\"/>
    <style type=\"text/css\" class=\"init\">
    
    </style>
    <script type=\"text/javascript\" language=\"javascript\" src=\"https://code.jquery.com/jquery-3.3.1.js\"></script>
    <script type=\"text/javascript\" language=\"javascript\" src=\"https://cdn.datatables.net/1.10.19/js/jquery.dataTables.min.js\"></script>
    <script type=\"text/javascript\" language=\"javascript\" src=\"https://cdn.datatables.net/1.10.19/js/dataTables.bootstrap4.min.js\"></script>
    <script type=\"text/javascript\" src=\"https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.36/pdfmake.min.js\"></script>
    <script type=\"text/javascript\" src=\"https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.1.36/vfs_fonts.js\"></script>
    <script type=\"text/javascript\" src=\"https://cdn.datatables.net/v/bs4/dt-1.10.18/b-1.5.2/b-html5-1.5.2/fc-3.2.5/fh-3.1.4/sc-1.5.0/datatables.min.js\"></script>
    <script type=\"text/javascript\" class=\"init\">
        \$(document).ready(function() {
            \$(\'#example\').DataTable();
        } );
    </script>
</head>
    "
end

function _webgen_home(mission_name::Symbol)
    header = _webgen_head(title="JAXTAM.jl Web View")

    body = "<body>
    <div class=\"se-pre-con\"></div>
    <div class=\"container\">
    <h1>JAXTAM.jl WebView - $mission_name</h1>
    <hr>
    <p>This JAXTAM results summary page is for <b>$mission_name</b></p>
    "

    return string(header, body)
end

function _webgen_mastertable_row(row::DataFrames.DataFrame)
    row_html = "\t<tr>
                <td>$(_html_escape(row[1, :name]))</td>
                <td>$(_html_escape(row[1, :obsid]))</td>
                <td>$(_html_escape(row[1, :subject_category]))</td>
                <td>$(_html_escape(row[1, :obs_type]))</td>
                <td>$(_html_escape(row[1, :publicity]))</td>
                <td>$(_html_escape(row[1, :downloaded]))</td>
                <td>PLOTTED_PLACEHOLDER</td>
        </tr>"
end

function _webgen_mastertable(mission_name::Symbol)
    master_df = master_a(mission_name)

    table_header = "<table id=\"example\" class=\"table table-striped table-bordered\" style=\"width:100%\">
        <thead>
            <tr>
                <th>name</th>
                <th>obsid</th>
                <th>category</th>
                <th>obstype</th>
                <th>public</th>
                <th>downloaded</th>
                <th>plotted</th>
            </tr>
        </thead>
        <tbody>"

    table_body = ""
    
    for row_i in 1:size(master_df,1)
        row = master_df[row_i, :]
        table_body = string(table_body, _webgen_mastertable_row(row))
    end

    table_footer = "</tbody>
    </table>
    </body>
    "

    return string(table_header, table_body, table_footer)
end

function webgen_mission(mission_name::Symbol)
    web_html = string(_webgen_home(mission_name), _webgen_mastertable(mission_name))

    return web_html
end