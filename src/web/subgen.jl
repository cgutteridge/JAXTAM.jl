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

function _webgen_report_intro(mission_name, obs_row, report_page_dir)
    mission_config = config(mission_name)
    e_min, e_max = mission_config.good_energy_min, mission_config.good_energy_max
    missions = string.(collect(keys(JAXTAM.config())))
    missions = missions[missions .!= string(mission_name)] # Remove the current mission from the list
    
    missions_split = split.(missions, "_") # Spit off the _ to remove energy bound notation
    # Select missions with the same base name 
    similar_missions = [any(occursin.(split(string(mission_name), "_")[1], m)) for m in missions_split]
    similar_missions = missions[similar_missions]

    similar_missions_links = Dict()
    # TODO: Enable similar missions again
    # for similar_mission in Symbol.(similar_missions)
    #     similar_obs_row = JAXTAM.master_query(similar_mission, :obsid, obs_row[1, :obsid])

    #     if similar_obs_row[1, :reports_path] != "NA"
    #         similar_missions_links[similar_mission] = similar_obs_row[1, :reports_path]
    #     end
    # end
    
    # To avoid requiring the URL (if the website is actually hosted) all the paths are relative
    # this is a very awkward way of using relative path movements to move up to another mission's
    # reports page
    relative_path_addon = split(splitdir(replace(report_page_dir, mission_config.path_web=>""))[1], "/")
    relative_path_addon = repeat("../", 3+length(relative_path_addon))
    similar_mission_text = p()
    if length(similar_missions_links) != 0
        similar_mission_text = p("Other energy ranges: ", 
            [a(string("$(l[1]) "), href=string(relative_path_addon, l[1], "/web/", l[2][3:end])) for l in similar_missions_links])
    end

    obsid = obs_row[1, :obsid]
    name  = obs_row[1, :name]
    abstract_text = obs_row[1, :abstract]
    node_intro = div(
        h1("Observation $obsid - $name - $e_min to $e_max keV"),
        similar_mission_text,
        h2("Abstract"),
        p(abstract_text),
        hr(),
        h4("Status"),
        _webgen_table(obs_row[[:public_date, :publicity, :time]], mission_config.path_web; table_id="report_page"),
        h4("Source Details"),
        _webgen_table(obs_row[[:name, :ra, :dec, :lii, :bii, :obs_type]], mission_config.path_web; table_id=""),
        h4("Observation Details"),
        _webgen_table(obs_row[[:time, :end_time, :exposure, :remarks]], mission_config.path_web; table_id=""),
        h4("Misc"),
        _webgen_table(obs_row[[:processing_status, :processing_date, :processing_version, :num_processed, :caldb_version]], mission_config.path_web, table_id="")
    )
end

function _webgen_report_body(obs_row, img_df_overview)
    images = []
    for link in img_df_overview[:path]
        images = [images; img(src=link)]
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
                [(img(src=row[:path])) for row in DataFrames.eachrow(group_images)]
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

function _webgen_subpage(mission_name, obs_row)
    mission_config = config(mission_name)
    obs_dir  = _clean_path_dots(mission_config.path_obs(obs_row))
    obs_path = string(mission_config.path, obs_dir)
    obs_path = replace(obs_path, "//"=>"/")
    JAXTAM_path = joinpath(obs_path, "JAXTAM")
    
    report_page_dir = string(mission_config.path_web, obs_dir)
    report_page_dir = replace(report_page_dir, "//"=>"/")
    JAXTAM_path_web  = joinpath(report_page_dir, "JAXTAM")

    obs_log = _log_read(mission_name, obs_row)
    # fix e_range call here once all energies unified
    e_range = "$(mission_config.good_energy_min)_$(mission_config.good_energy_max)"
    img_log = obs_log["images"]
    img_log = filter(r->r[:e_range] == e_range, img_log)

    img_details_overview = filter(x->ismissing(x[:group]), img_log)
    img_details_overview = sort(img_details_overview, (:group, :kind_order))
    
    img_details_groups   = filter(x->!ismissing(x[:group]), img_log)
    img_details_groups   = sort(img_details_groups, (:group, :kind_order))

    
    html_out = html(
        _webgen_head(;title_in="$mission_name - $(obs_row[1, :name]) - $(obs_row[1, :obsid]) - Reports"),
        _webgen_subpage_css(),
        _webpage_subgen_slider_js(),
        body(
            div(class="se-pre-con"),
            div(class="container",
                _webgen_report_intro(mission_name, obs_row, report_page_dir),
                _webgen_report_body(obs_row, img_details_overview),
                _webgen_report_body_groups(obs_row, img_details_groups),
                _webgen_subpage_footer()
            )
        )
    )

    mkpath(report_page_dir)
    !islink(JAXTAM_path_web) ? symlink(JAXTAM_path, JAXTAM_path_web) : ""
    
    write(joinpath(report_page_dir, "JAXTAM/report.html"), string(Pretty(html_out)))
    return joinpath(report_page_dir, "JAXTAM/report.html")
end

function webgen_subpage(mission_name, obsid)
    obs_row = master_query(mission_name, :obsid, obsid)

    return _webgen_subpage(mission_name, obs_row)
end
