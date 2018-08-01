function _webgen_format_table(row::DataFrames.DataFrame)
    col_num = size(row, 2)

    table_th_full = ""
    table_td_full = ""

    for i = 1:col_num
        table_th = """
        <th>$(names(row)[i])</th>
        """
        
        table_th_full = string(table_th_full, table_th)

        table_td = """
        <td>$(row[1, i])</td>
        """

        table_td_full = string(table_td_full, table_td)
    end

    table_html = """
    <table id=\"example\" class=\"table table-striped table-bordered\" style=\"width:100%\">
    <thead>
    <tr>
    $table_th_full</tr>
    </thead>
    <tbody>
    <tr>
    $table_td_full</tr>
    </tbody>
    </table>
    """

    return table_html
end

_webgen_sub_body_intro = mt"""
<body>
<div class=\"container\">
<h1>Observation {{obsid}} - {{name}}</h1>
<hr>
<h2>Abstract</h2>
<h4>{{title}} - {{subject_category}}</h4>
<p>{{abstract}}</p>
<hr>
<h4>Status</h4>
<table id=\"example\" class=\"table table-striped table-bordered\" style=\"width:100%\">
<thead>
<tr>
<th>public_date</th>
<th>publicity</th>
<th>time</th>
<th>downloaded</th>
</tr>
</thead>
<tbody>
<tr>
<td>{{public_date}}</td>
<td>{{publicity}}</td>
<td>{{time}}</td>
<td>{{downloaded}}</td>
</tr>
</tbody>
</table>
<h4>Source Details</h4>
"""

function _webgen_sub(row::DataFrames.DataFrame)
    table_status = _webgen_format_table(row[[:public_date, :publicity, :time, :downloaded]])
    table_source = _webgen_format_table(row[[:name, :ra, :dec, :lii, :bii, :obs_type]])
    table_obsdet = _webgen_format_table(row[[:time, :end_time, :exposure, :remarks]])
    table_misc   = _webgen_format_table(row[[:processing_status, :processing_date, :processing_version, :num_processed, :caldb_version, :remarks]])
    
    header = _webgen_head(title="$(row[1, :obsid]) - $(row[1, :name])")

    result_html = """
    $header
    <body>
    <div class=\"container\">
    <h1>Observation {{obsid}} - {{name}}</h1>
    <hr>
    <h2>Abstract</h2>
    <h4>{{title}} - {{subject_category}}</h4>
    <p>{{abstract}}</p>
    <hr>
    <h4>Status</h4>
    $table_status
    <h4>Source Details</h4>
    $table_source
    <h4>Observation Details</h4>
    $table_obsdet
    <h4>Misc</h4>
    $table_misc
    </body>
    """

    return result_html
end