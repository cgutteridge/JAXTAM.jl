function _webgen_subpage_css()
    @tags_noescape style

    style("
        #slider{
            width:100%;
            height:1450px;
            position:relative;
            overflow:hidden;
            float:left;
            padding:0;
        }

        .slide{
            position:absolute;
            width:100%;
            height:100%;
        }

        .slide-copy{
            position:absolute;
            bottom:0;
            left:0;
            padding:10px 20px 20px 20px;
            background:7f7f7f;
            background: rgba(0,0,0,0.5);
            width:100%;
            max-height:32%;
        }

        #prev, #next{
            cursor:pointer;
            z-index:100;
            background:#666;
            height:50px;
            width:50px;
            display:inline-block;
            position:relative;
            top:210px;
            margin:0;
            padding:0;
            opacity:0.7;
            filter: alpha(opacity=70);
        }

        #next{
            float:right;
            right:-2px;
        }

        #prev{
            float:left;
            left:0;
        }

        .arrow-right {
            width: 0; 
            height: 0; 
            border-top: 15px solid transparent;
            border-bottom: 15px solid transparent;	
            border-left: 15px solid #fff;
            position:relative;
            top:20%;
            right:-40%;
        }

        .arrow-left {
            width: 0;  
            height: 0; 
            border-top: 15px solid transparent;
            border-bottom: 15px solid transparent;	
            border-right:15px solid #fff; 
            position:relative;
            top:20%;
            left:30%;
        }
    "; class="init", :type=>"text/css")
end

function _webpage_subgen_slider_js()
    script("
    \$(document).ready(function() {
        // options
        var speed = 100; //transition speed - fade
        var autoswitch = false; //auto slider options
        var autoswitch_speed = 5000; //auto slider speed

        // add first initial active class
        \$(\".slide\")
          .first()
          .addClass(\"active\");

        // hide all slides
        \$(\".slide\").hide;

        // show only active class slide
        \$(\".active\").show();

        // Next Event Handler
        \$(\"#next\").on(\"click\", nextSlide); // call function nextSlide

        // Prev Event Handler
        \$(\"#prev\").on(\"click\", prevSlide); // call function prevSlide

        document.onkeydown = function(evt) {
            evt = evt || window.event;
            switch (evt.keyCode) {
                case 37:
                    prevSlide();
                    break;
                case 39:
                    nextSlide();
                    break;
            }
        };

        // Auto Slider Handler
        if (autoswitch == true) {
          setInterval(nextSlide, autoswitch_speed); // call function and value 4000
        }

        // Switch to next slide
        function nextSlide() {
          \$(\".active\")
            .removeClass(\"active\")
            .addClass(\"oldActive\");
          if (\$(\".oldActive\").is(\":last-child\")) {
            \$(\".slide\")
              .first()
              .addClass(\"active\");
          } else {
            \$(\".oldActive\")
              .next()
              .addClass(\"active\");
          }
          \$(\".oldActive\").removeClass(\"oldActive\");
          \$(\".slide\").fadeOut(speed);
          \$(\".active\").fadeIn(speed);
        }

        // Switch to prev slide
        function prevSlide() {
          \$(\".active\")
            .removeClass(\"active\")
            .addClass(\"oldActive\");
          if (\$(\".oldActive\").is(\":first-child\")) {
            \$(\".slide\")
              .last()
              .addClass(\"active\");
          } else {
            \$(\".oldActive\")
              .prev()
              .addClass(\"active\");
          }
          \$(\".oldActive\").removeClass(\"oldActive\");
          \$(\".slide\").fadeOut(speed);
          \$(\".active\").fadeIn(speed);
        }
      });
    ")
end 

function _webgen_report_intro(mission::Mission, obs_row::DataFrames.DataFrameRow{DataFrames.DataFrame},
        report_page_dir::String; e_range=_mission_good_e_range(mission)
    )
    obsid = obs_row[:obsid]
    name  = obs_row[:name]
    abstract_text = obs_row[:abstract]

    log_reports = _log_query(mission, obs_row, "web")
    if ismissing(log_reports)
        report_df = DataFrame()
    else
        report_e_ranges = ["$(e_r[1]) to $(e_r[2]) keV" for e_r in keys(log_reports)]
        report_rel_path = [a(link, href=link) for link in [replace(path, report_page_dir=>"..") for path in values(log_reports)]]
        report_df = DataFrame(e_range=report_e_ranges, report=report_rel_path)
    end
    node_intro = div(
        h1("Observation $obsid - $name - $e_range keV"),
        h2("Available Energy Range Reports"),
        _webgen_table(report_df, ""; table_id="report_page"),
        h2("Abstract"),
        p(abstract_text),
        hr(),
        h4("Status"),
        _webgen_table(obs_row[[:public_date, :publicity, :time]], ""; table_id="report_page"),
        h4("Source Details"),
        _webgen_table(obs_row[[:name, :ra, :dec, :lii, :bii, :obs_type]], ""; table_id=""),
        h4("Observation Details"),
        _webgen_table(obs_row[[:time, :end_time, :exposure, :remarks]], ""; table_id=""),
        h4("Misc"),
        _webgen_table(obs_row[[:processing_status, :processing_date, :processing_version, :num_processed, :caldb_version]], "", table_id="")
    )
end

function _webgen_report_body(obs_row, img_df_overview)
    images = []
    for link in img_df_overview[:path]
        images = [images; img(src=string(repeat("../", 2), link))]
    end

    node_body = div(
        hr(),
        h2("Plots"),
        images
    )
end

function _webgen_report_body_groups(obs_row, img_df)
    groups = unique(img_df[:group])

    group_container = Array{Hyperscript.Node{Hyperscript.HTMLSVG},1}()
    for group in groups
        group_images = filter(x->x[:group]==group, img_df)
        
        node_group = div(class="slide",
            div(
                h4("group - $group"),
                [(img(src=string(repeat("../", 2), row[:path]))) for row in DataFrames.eachrow(group_images)]
            )
        )
        
        push!(group_container, node_group)
    end

    slider_node = div(
        h2("Per-Group Plots"),
        p("Use the left and right arrow keys to move between groups."),
        div(id="slider",
            div(id="next", ald="Next", title="Next", 
                div(class="arrow-right")
            ),
            div(id="prev", alt="Prev", title="Prev",
                div(class="arrow-left")
            ),
            group_container
        )
    )
    
    return slider_node
end

function _webgen_subpage_footer()
    div(
        hr(),
        h4("Notes"),
        h5("Lightcurve"),
            p("Plot of events binned to 1-second intervals. Red/green vertical lines show the start/stop times of the GTIs."),
        h5("Periodogram"),
            p("Periodograms created with the LombScargle.jl `periodogram` function, using the `:standard` normalisation, which is based on Zechmeister, M., Kürster, M. 2009, A&A, 496, 577."),
        h5("Power Spectra"),
            p("Leahy-normalised power spectra, amplitudes -2, then multipled by the frequency. Both x and y axis are log10 scale."),
        h5("Spectrogram"),
            p("Spectrograms are made by plotting each individual power spectra as a row on the heatmap. Normalisation is the same as for the power spectra."),
            p("Note that when looking at the spectrogram the gaps in the lightcurve are not displayed, so trends shown in the spectrogram may not represent reality. Currently plotting function limitations mean that the x-axis ticks are not accurate for the spectorgram, so they have been disabled. 
            The spectrogram should only be used as an indication of QPOs moving over time, further analysis should be performed using external software."),
            p("The orange horizontal lines denote the boundry between different groups. The zone under a line belongs to the group on the line's y-axis tick."),
        h5("Pulsation Plots"),
            p("Only powers above 30 are plotted. Instead of an average, as for the FFTs above, each individual power spectra is used."),
            p("Candle lines go up to the power, a scatter plot with dots is overlayed on top as well to help show the density of points."),
            p("Pulsation plots are used to find intermittent/weak pulsations which may be hidden by the averaging done for the main power spectra plots"),
        # h5("Pulsation Spectrogram"),
        #     p("Spectrograms with a `:freq_binary` rebin are used to search for pulsations."),
        #     p("The rebin has two numbers: the first signifies the size of the frequency bins (by default 10 Hz), and the second is an array of threshold values (default 10, 25, 50)."),
        #     p("If any values of the power spectra in the frequency bins is above one of the thresholds, the point is set to the threshold value."),
        #     p("This makes it easy to spot any high-frequency, intermittent pulsations, as they will show up as a pattern of bright points/bands."),
        #     p("A good example of this is the nicer observation `1013010126` (PSR_B0531+21), which shows clear, bright, banding patterns from ~50 to ~500 Hz."),
        h5("Groups"),
            p("\"Groups\" are GTIs seperated by less than 128 seconds, which have been grouped together. They are used to select smaller chunks of the lightcurve, which are then passed through periodogram and power spectra functions. Left and right arrow keys can be used to move between groups."),
    )
end

function _webgen_subpage(mission::Mission, obs_row::DataFrames.DataFrameRow{DataFrames.DataFrame}; e_range=_mission_good_e_range(mission))
    path_web = abspath(_obs_path_local(mission, obs_row; kind=:web), "JAXTAM", "web")
    mkpath(path_web)
    
    log_images  = _log_query(mission, obs_row, "images", e_range)

    img_details_overview = filter(x->ismissing(x[:group]), log_images)
    img_details_overview = sort(img_details_overview, (:group, :kind_order))
    
    img_details_groups   = filter(x->!ismissing(x[:group]), log_images)
    img_details_groups   = sort(img_details_groups, (:group, :kind_order))
    
    html_out = html(
        _webgen_head(;title_in="$(_mission_name(mission)) - $e_range keV - $(obs_row[:name]) - $(obs_row[:obsid]) - Reports"),
        _webgen_subpage_css(),
        _webpage_subgen_slider_js(),
        body(
            div(class="se-pre-con"),
            div(class="container",
                _webgen_report_intro(mission, obs_row, path_web; e_range=e_range),
                _webgen_report_body(obs_row, img_details_overview),
                _webgen_report_body_groups(obs_row, img_details_groups),
                _webgen_subpage_footer()
            )
        )
    )

    path_report = joinpath(path_web, "$e_range", "report.html")
    mkpath(dirname(path_report))
    
    write(path_report, string(Pretty(html_out)))
    _log_add(mission, obs_row,
        Dict("web" =>
            Dict(e_range => path_report)
        )
    )
    return path_report
end

function webgen_subpage(mission::Mission, obsid::String; e_range=_mission_good_e_range(mission))
    obs_row = master_query(mission, :obsid, obsid)

    return _webgen_subpage(mission, obs_row; e_range=e_range)
end
