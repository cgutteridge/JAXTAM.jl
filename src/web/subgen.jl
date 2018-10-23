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

function _webgen_results_intro(mission_name, obs_row, results_page_dir)
    mission_config = config(mission_name)
    e_min, e_max = mission_config.good_energy_min, mission_config.good_energy_max
    missions = string.(collect(keys(JAXTAM.config())))
    missions = missions[missions .!= string(mission_name)] # Remove the current mission from the list
    
    missions_split = split.(missions, "_") # Spit off the _ to remove energy bound notation
    # Select missions with the same base name 
    similar_missions = [any(occursin.(split(string(mission_name), "_")[1], m)) for m in missions_split]
    similar_missions = missions[similar_missions]

    similar_missions_links = Dict()
    for similar_mission in Symbol.(similar_missions)
        similar_obs_row = JAXTAM.master_query(similar_mission, :obsid, obs_row[1, :obsid])

        if similar_obs_row[1, :results_path] != "NA"
            similar_missions_links[similar_mission] = similar_obs_row[1, :results_path]
        end
    end
    
    # To avoid requiring the URL (if the website is actually hosted) all the paths are relative
    # this is a very awkward way of using relative path movements to move up to another mission's
    # results page
    relative_path_addon = split(splitdir(replace(results_page_dir, mission_config.path_web=>""))[1], "/")
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
        _webgen_table(obs_row[[:public_date, :publicity, :time]]; table_id="report_page"),
        h4("Source Details"),
        _webgen_table(obs_row[[:name, :ra, :dec, :lii, :bii, :obs_type]]; table_id=""),
        h4("Observation Details"),
        _webgen_table(obs_row[[:time, :end_time, :exposure, :remarks]]; table_id=""),
        h4("Misc"),
        _webgen_table(obs_row[[:processing_status, :processing_date, :processing_version, :num_processed, :caldb_version]], table_id="")
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
    img_groups     = []
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
        @assert img_kind in ["fspec", "lc", "pgram", "sgram", "pulse"]
        append!(img_kinds, [img_kind])

        # 6  - Diverges based on kind
        if img_kind == "fspec"
            # 6a - fspec bin_size
            img_bin_size = img_dir_splt[6]
            if length(img_dir_splt) > 6 && img_dir_splt[7] == "groups"
                # 6a1 - fspec groups folder
                img_kind_ordr = 20
                img_group = parse(Int, replace(img_name, "_fspec.png"=>""))
                img_title = "Power Spectra - group $img_group - $img_bin_time bt - $img_bin_size bs"
            else
                # 6a2 - not a group plot
                img_kind_ordr = 3
                img_title = "Power Spectra - $img_bin_time bt - $img_bin_size bs"
                img_group = 0
            end
        elseif img_kind == "lc"
            # 6b - lc has no bin size
            img_bin_size = missing
            if length(img_dir_splt) > 5 && img_dir_splt[6] == "groups"
                # 6b1 - lc groups folder
                img_kind_ordr = 10
                img_group = parse(Int, replace(img_name, "_lcurve.png"=>""))
                img_title = "Light Curve - group $img_group - $img_bin_time bt"
            else
                # 6b2 - not a group plot
                img_kind_ordr = 1
                img_title = "Light Curve - $img_bin_time bt"
                img_group = 0
            end
        elseif img_kind == "pgram"
            # 6c - pgram has no bin size
            img_bin_size = missing
            if length(img_dir_splt) > 5 && img_dir_splt[6] == "groups"
                # 6c1 - lc groups folder
                img_kind_ordr = 30
                img_group = parse(Int, replace(img_name, "_pgram.png"=>""))
                img_title = "Periodogram - group $img_group - $img_bin_time bt"
            else
                # 6c2 - not a group plot
                img_kind_ordr = 2
                img_title = "Periodogram - $img_bin_time bt"
                img_group = 0
            end
        elseif img_kind == "sgram"
            img_bin_size = img_dir_splt[6]
            # 6d2 - lc groups folder
            img_kind_ordr = 3
            img_group = 0
            img_title = "Spectrogram - $img_bin_time bt - $img_bin_size bs"
        elseif img_kind == "pulse"
            img_bin_size = img_dir_splt[6]
            if length(img_dir_splt) > 6 && img_dir_splt[7] == "groups"
                # 6a1 - pulses groups folder
                img_kind_ordr = 25
                img_group = parse(Int, replace(img_name, "_pulses.png"=>""))
                img_title = "Pulsations - group $img_group - $img_bin_time bt - $img_bin_size bs"
            else
                # 6a2 - not a group plot
                img_kind_ordr = 4
                img_group = 0
                img_title = "Pulsations - $img_bin_time bt - $img_bin_size bs"
            end
        end

        append!(img_bin_sizes, [img_bin_size])
        append!(img_groups, [img_group])
        append!(img_titles, [img_title])
        append!(img_kind_ordrs, img_kind_ordr)
    end

    image_path_df = DataFrame(
                                path=replace.(paths, JAXTAM_path=>"./JAXTAM/"),
                                bin_times=img_bin_times,
                                kinds=img_kinds,
                                bin_size=img_bin_sizes,
                                img_group=img_groups,
                                img_title=img_titles,
                                img_kind_ordr=img_kind_ordrs
                            )
end

function _webgen_results_body(obs_row; img_dict=Dict())
    images = []
    prev_title = first(img_dict)[2]
    for (title, link) in img_dict
        title = split(title, " - ")[1]
        if title != prev_title
            images = [images; hr()]
        end
        images = [images; img(src=link)]
        prev_title = title
    end

    node_body = div(
        hr(),
        h2("Plots"),
        images
        #[img(src=imgpair[2]) for imgpair in img_dict]
        # [(h4(imgpair[1]), img(src=imgpair[2])) for imgpair in img_dict]
    )
end

function _webgen_results_body_groups(obs_row, img_df)
    groups = unique(img_df[:img_group])

    group_container = Array{Hyperscript.Node{Hyperscript.HTMLSVG},1}()
    for group in groups
        group_images = filter(x->x[:img_group]==group, img_df)
        
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
    obs_dir  = _clean_path_dots(config(mission_name).path_obs(obs_row))
    obs_path = string(config(mission_name).path, obs_dir)
    obs_path = replace(obs_path, "//"=>"/")
    JAXTAM_path = joinpath(obs_path, "JAXTAM")
    
    results_page_dir = string(config(mission_name).path_web, obs_dir)
    results_page_dir = replace(results_page_dir, "//"=>"/")
    JAXTAM_path_web = joinpath(results_page_dir, "JAXTAM")

    img_details = _webgen_subpage_findimg(JAXTAM_path)

    img_details_overview = filter(x->x[:img_group] == 0, img_details)
    img_details_overview = sort(img_details_overview, (:img_group, :img_kind_ordr))

    img_details_groups   = filter(x->x[:img_group] != 0, img_details)
    img_details_groups   = sort(img_details_groups, (:img_group, :img_kind_ordr))

    img_tuple_overview   = [img[:img_title]=>img[:path] for img in DataFrames.eachrow(img_details_overview)]
    img_tuple_groups     = [img[:img_title]=>img[:path] for img in DataFrames.eachrow(img_details_groups)]

    img_dict_overview    = OrderedDict(img_tuple_overview)
    img_dict_groups      = OrderedDict(img_tuple_groups)

    html_out = html(
        _webgen_head(;title_in="$mission_name - $(obs_row[1, :name]) - $(obs_row[1, :obsid]) - Results"),
        _webgen_subpage_css(),
        _webpage_subgen_slider_js(),
        body(
            div(class="se-pre-con"),
            div(class="container",
                _webgen_results_intro(mission_name, obs_row, results_page_dir),
                _webgen_results_body(obs_row; img_dict=img_dict_overview),
                _webgen_results_body_groups(obs_row, img_details_groups),
                _webgen_subpage_footer()
            )
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
