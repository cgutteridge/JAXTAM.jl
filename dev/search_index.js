var documenterSearchIndex = {"docs": [

{
    "location": "#",
    "page": "JAXTAM.jl",
    "title": "JAXTAM.jl",
    "category": "page",
    "text": ""
},

{
    "location": "#JAXTAM.jl-1",
    "page": "JAXTAM.jl",
    "title": "JAXTAM.jl",
    "category": "section",
    "text": "JAXTAM is Just Another X-ray Timing Analysis Module. The main aim of the project was to create an easy to use, friendly interface for basic at-a-glance timing analysis, to be used on data from missions adhering to the FITS file standard."
},

{
    "location": "#Contents-1",
    "page": "JAXTAM.jl",
    "title": "Contents",
    "category": "section",
    "text": "Pages = [\n    \"index.md\",\n    \"man/io.md\",\n    \"man/missions.md\",\n    \"man/science.md\"\n]"
},

{
    "location": "#Introduction-1",
    "page": "JAXTAM.jl",
    "title": "Introduction",
    "category": "section",
    "text": "Basic analysis can be performed from the Julia REPL, however the final product of JAXTAM is an automatically generated results page, containing some basic plots used in X-ray timing analysis, the default setup generates the following plots: lightcurves, Leahy normalised power spectra, periodograms, and spectrograms.note: Note\nCurrently, JAXTAM is set up to work with HEASARC missions, which have a mastertable available on the HEASARC servers. NICER is supported natively, and full NuSTAR support is coming (REPL plotting works, however functionality for saving/generating reports when two instruments are present hasn\'t been implemented yet)."
},

{
    "location": "#Basic-Usage-Guide-1",
    "page": "JAXTAM.jl",
    "title": "Basic Usage Guide",
    "category": "section",
    "text": ""
},

{
    "location": "#Config-Setup-1",
    "page": "JAXTAM.jl",
    "title": "Config Setup",
    "category": "section",
    "text": "JAXTAM handles everything from downloading the observation data from HEASARC servers, to performing timing analysis, plotting, generating a searchable summary page, and finally generating individual report pages for each observation.The first step is setting up a configuration file, which tells JAXTAM how to handle each mission individually. NICER and NuSTAR mission definitions are included by default, however setting up a custom mission is relatively easy. _get_default_missionsTo set up the configuration for one of the included default missions (NICER or NuSTAR) you must provide only the path to the directory used to store the mission data:julia> JAXTAM.config(:nicer, \"/example/path/to/nicer/\")\n┌ Info: nicer found in defaults\n└ Using /example/path/to/nicer/ as path\n[ Info: Creating config file at: /home/user/Projects/JAXTAM/user_configs.jld2\nDict{Any,Any} with 2 entries:\n  :nicer           => MissionDefinition(\"nicer\", \"https://heasarc.gsfc.nasa.gov/FTP/heasarc/dbase/tdat_files/heasarc_nicermastr.tdat…\n  :_config_version => v\"0.2.0\"This will automatically fill in all the information required for a complete MissionDefinition type. For the above example, this saves:julia> JAXTAM.config(:nicer)\nJAXTAM.MissionDefinition(\n        \"nicer\",\n        \"https://heasarc.gsfc.nasa.gov/FTP/heasarc/dbase/tdat_files/heasarc_nicermastr.tdat.gz\",\n        \"/example/path/to/nicer/\",\n        JAXTAM._nicer_observation_dir,\n        JAXTAM._nicer_cl_files,\n        JAXTAM._nicer_uf_files,\n        \"/home/user/Software/caldb/data/nicer/xti/cpf/rmf/nixtiref20170601v001.rmf\",\n        \"/example/path/to/nicer/web/\",\n        0.3,\n        12,\n        [\"XTI\"]\n    )More can be read about MissionDefinition at: MissionDefinition."
},

{
    "location": "#Master-Table-Setup-1",
    "page": "JAXTAM.jl",
    "title": "Master Table Setup",
    "category": "section",
    "text": "Once the configuration has been set up for a mission, the next step is running the setup for the master DataFrame, which contains information on each observation for the mission and is pulled from a HEASARC master table url (the second field in the MissionDefinition).To do this simply run JAXTAM.master(:mission_name):julia> JAXTAM.master(:nicer)\n┌ Warning: No master file found, looked for: \n│       /example/path/to/nicer/master.tdat \n│       /example/path/to/nicer/master.feather\n└ @ JAXTAM ~/Projects/JAXTAM/src/io/master_tables.jl:171\n[ Info: Download master files from `https://heasarc.gsfc.nasa.gov/FTP/heasarc/dbase/tdat_files/heasarc_nicermastr.tdat.gz`? (y/n)\ny\n[ Info: Downloading latest master catalog\n  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current\n                                 Dload  Upload   Total   Spent    Left  Speed\n100  450k  100  450k    0     0   121k      0  0:00:03  0:00:03 --:--:--  121k\n\n7-Zip [64] 9.20  Copyright (c) 1999-2010 Igor Pavlov  2010-11-18\np7zip Version 9.20 (locale=en_GB.UTF-8,Utf16=on,HugeFiles=on,8 CPUs)\n\nProcessing archive: /example/path/to/nicer/aster.tdat\n\nExtracting  master\n\nEverything is Ok\n\nSize:       3427684\nCompressed: 461261\n[ Info: Loading /example/path/to/nicer/aster.tdat\n[ Info: Saving /example/path/to/nicer/aster.featherThis will download, unzip, and parse the .tdat master file. To update, simply run JAXTAM.master_update(:mission_name). Some warnings are to be expected, but have been removed from the above example.A secondary table is also required, which can be generated with:julia> JAXTAM.append(:nicer)\n[ Info: Loading /example/path/to/nicer/master.feather\n[ Info: Saving /example/path/to/nicer/append.feather"
},

{
    "location": "#Filtering-Downloading-Observations-1",
    "page": "JAXTAM.jl",
    "title": "Filtering Downloading Observations",
    "category": "section",
    "text": "A basic filtering function has been included to help select observations, called master_query, which takes in a mission name, column name, and then a value to filter by:julia> JAXTAM.master_query(:nicer, :name, \"MAXI_J1535-571\")\n[ Info: Loading /example/path/to/nicer/master.feather\n[ Info: Loading /example/path/to/nicer/append.feather\n184×35 DataFrames.DataFrame. Omitted printing of 27 columns\n│ Row │ name           │ ra      │ dec      │ lii     │ bii      │ time                │ end_time            │ obsid      │\n│     │ String         │ Float64 │ Float64  │ Float64 │ Float64  │ Arrow…              │ Arrow…              │ String     │\n├─────┼────────────────┼─────────┼──────────┼─────────┼──────────┼─────────────────────┼─────────────────────┼────────────┤\n│ 1   │ MAXI_J1535-571 │ 233.84  │ -57.2389 │ 323.722 │ -1.13864 │ 2018-08-21T04:33:20 │ 2018-08-21T04:41:26 │ 1130360245 │\n│ 2   │ MAXI_J1535-571 │ 233.834 │ -57.2372 │ 323.72  │ -1.13527 │ 2018-06-05T05:03:40 │ 2018-06-05T05:26:02 │ 1130360189 │\n│ 3   │ MAXI_J1535-571 │ 233.839 │ -57.2359 │ 323.724 │ -1.13597 │ 2018-08-22T09:53:40 │ 2018-08-22T10:02:35 │ 1130360246 │\n⋮\n│ 181 │ MAXI_J1535-571 │ 233.83  │ -57.2267 │ 323.725 │ -1.12573 │ 2018-07-07T14:56:02 │ 2018-07-07T15:12:51 │ 1130360213 │\n│ 182 │ MAXI_J1535-571 │ 233.835 │ -57.2261 │ 323.727 │ -1.12659 │ 2018-07-08T14:05:42 │ 2018-07-08T20:22:19 │ 1130360214 │\n│ 183 │ MAXI_J1535-571 │ 233.83  │ -57.2246 │ 323.726 │ -1.12404 │ 2018-03-29T10:54:20 │ 2018-03-29T20:01:20 │ 1130360151 │\n│ 184 │ MAXI_J1535-571 │ 233.83  │ -57.2235 │ 323.727 │ -1.12316 │ 2018-05-18T22:41:50 │ 2018-05-18T22:52:00 │ 1130360180 │As typically we are interested only in public observations, a JAXTAM.master_query_public function also exists, which behaves the same but only returns observations which have been made public:julia> JAXTAM.master_query_public(:nicer, :name, \"MAXI_J1535-571\")\n[ Info: Loading /media/robert/8C08EB2F08EB16CC/Users/Robert/heasarc/nicer/master.feather\n178×35 DataFrames.DataFrame. Omitted printing of 20 columns\n│ Row │ name           │ ra      │ dec      │ lii     │ bii      │ time                │ end_time            │ obsid      │\n│     │ String         │ Float64 │ Float64  │ Float64 │ Float64  │ Arrow…              │ Arrow…              │ String     │\n├─────┼────────────────┼─────────┼──────────┼─────────┼──────────┼─────────────────────┼─────────────────────┼────────────┤\n│ 1   │ MAXI_J1535-571 │ 233.84  │ -57.2389 │ 323.722 │ -1.13864 │ 2018-08-21T04:33:20 │ 2018-08-21T04:41:26 │ 1130360245 │\n│ 2   │ MAXI_J1535-571 │ 233.834 │ -57.2372 │ 323.72  │ -1.13527 │ 2018-06-05T05:03:40 │ 2018-06-05T05:26:02 │ 1130360189 │\n│ 3   │ MAXI_J1535-571 │ 233.839 │ -57.2359 │ 323.724 │ -1.13597 │ 2018-08-22T09:53:40 │ 2018-08-22T10:02:35 │ 1130360246 │\n⋮\n│ 175 │ MAXI_J1535-571 │ 233.83  │ -57.2267 │ 323.725 │ -1.12573 │ 2018-07-07T14:56:02 │ 2018-07-07T15:12:51 │ 1130360213 │\n│ 176 │ MAXI_J1535-571 │ 233.835 │ -57.2261 │ 323.727 │ -1.12659 │ 2018-07-08T14:05:42 │ 2018-07-08T20:22:19 │ 1130360214 │\n│ 177 │ MAXI_J1535-571 │ 233.83  │ -57.2246 │ 323.726 │ -1.12404 │ 2018-03-29T10:54:20 │ 2018-03-29T20:01:20 │ 1130360151 │\n│ 178 │ MAXI_J1535-571 │ 233.83  │ -57.2235 │ 323.727 │ -1.12316 │ 2018-05-18T22:41:50 │ 2018-05-18T22:52:00 │ 1130360180 │Note how this time only 178 rows (observations) have been returned, whereas before 184 were returned, meaning 6 observations are not currently public.Additionally, running the function with just the mission and no arguments for filtering (e.g. JAXTAM.master_query_public(:mission_name)) will return all the currently public observations."
},

{
    "location": "#Downloading-Observations-1",
    "page": "JAXTAM.jl",
    "title": "Downloading Observations",
    "category": "section",
    "text": ""
},

{
    "location": "man/io/#",
    "page": "IO Operations",
    "title": "IO Operations",
    "category": "page",
    "text": ""
},

{
    "location": "man/io/#JAXTAM._config_edit",
    "page": "IO Operations",
    "title": "JAXTAM._config_edit",
    "category": "function",
    "text": "_config_edit(key_name::String, key_value::String;\n        config_path=string(__sourcedir__, \"user_configs.jld2\"))\n\nEdits (or adds) key_name to key_value in the config file\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._config_gen",
    "page": "IO Operations",
    "title": "JAXTAM._config_gen",
    "category": "function",
    "text": "_config_gen(string(__sourcedir__, \"user_configs.jld2\"))\n\nGenerates a user configuration file at config_path, by default, file is placed in the JAXTAM module dir\n\nConfig file is /user_configs.jld2, excluded from git\n\nAlso used to overwrite the old config file\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._config_key_value",
    "page": "IO Operations",
    "title": "JAXTAM._config_key_value",
    "category": "function",
    "text": "_config_key_value(key_name::Symbol,\n    config_path=string(__sourcedir__, \"user_configs.jld2\"))\n\nLoads and returns the value for key_name\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._config_load",
    "page": "IO Operations",
    "title": "JAXTAM._config_load",
    "category": "function",
    "text": "_config_load(config_path=string(__sourcedir__, \"user_configs.jld2\"))\n\nLoads data from the configuration file\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._config_rm",
    "page": "IO Operations",
    "title": "JAXTAM._config_rm",
    "category": "function",
    "text": "_config_rm(key_name::String;\n        config_path=string(__sourcedir__, \"user_configs.jld2\"))\n\nRemoves a the key key_name from the configuration file\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.config-Tuple{Symbol,Union{Function, String, Symbol, MissionDefinition}}",
    "page": "IO Operations",
    "title": "JAXTAM.config",
    "category": "method",
    "text": "config(key_name::Union{String,Symbol}, key_value::Union{String,Symbol})\n    _config_edit(String(key_name), String(key_value))\n\nAdds key_name with key_value to the configuration file and saves\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.config-Tuple{Symbol}",
    "page": "IO Operations",
    "title": "JAXTAM.config",
    "category": "method",
    "text": "config(key_name::Union{String,Symbol})\n\nReturns the value of key_name\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.config-Tuple{}",
    "page": "IO Operations",
    "title": "JAXTAM.config",
    "category": "method",
    "text": "config()\n\nReturns the full configuration file data\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.config_rm-Tuple{Symbol}",
    "page": "IO Operations",
    "title": "JAXTAM.config_rm",
    "category": "method",
    "text": "config_rm(key_name::Union{String,Symbol})\n\nRemoves key_name from the configuration file and saves changes.\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._master_download-Tuple{Any,Any}",
    "page": "IO Operations",
    "title": "JAXTAM._master_download",
    "category": "method",
    "text": "_master_download(master_path, master_url)\n\nDownloads (and unzips) a master table from HEASARC given its url and a destination path\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._master_read_tdat-Tuple{String}",
    "page": "IO Operations",
    "title": "JAXTAM._master_read_tdat",
    "category": "method",
    "text": "_master_read_tdat(master_path::String)\n\nReads a raw .tdat table from HEASARC mastertable archives, parses the ASCII data, finds and stores column names, cleans punctuation, converts to DataFrame, strongly types the columsn, and finally returns cleaned table as DataFrame\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._master_save-Tuple{Any,Any}",
    "page": "IO Operations",
    "title": "JAXTAM._master_save",
    "category": "method",
    "text": "_master_save(master_path_feather, master_data)\n\nSaves the DataFrame master table to a .feather file\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._public_date_int-Tuple{Any}",
    "page": "IO Operations",
    "title": "JAXTAM._public_date_int",
    "category": "method",
    "text": "_public_date_int(public_date)\n\nConverts the public date to an integer, if that fails just returns the arbitrary sort-of-far-away 2e10 date\n\nTODO: Don\'t return 2e10 on Float64 parse error\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._type_master_df!-Tuple{Any}",
    "page": "IO Operations",
    "title": "JAXTAM._type_master_df!",
    "category": "method",
    "text": "_type_master_df!(master_df)\n\nSlightly janky way to strongly type columns in the master table, this needs to be done to ensure the .feather file is saved/read correctly\n\nTODO: Make this less... stupid\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.master-Tuple{Union{String, Symbol}}",
    "page": "IO Operations",
    "title": "JAXTAM.master",
    "category": "method",
    "text": "master(mission_name::Union{String,Symbol})\n\nReads in a previously created .feather master table for a specific mission_name using a path provided by _config_key_value(mission_name)\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.master-Tuple{}",
    "page": "IO Operations",
    "title": "JAXTAM.master",
    "category": "method",
    "text": "master()\n\nLoads a default mission, if one is set, otherwise throws error\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.master_query-Tuple{DataFrames.DataFrame,Symbol,Any}",
    "page": "IO Operations",
    "title": "JAXTAM.master_query",
    "category": "method",
    "text": "master_query(master_df::DataFrame, key_type::Symbol, key_value::Any)\n\nWrapper for a query, takes in an already loaded DataFrame master_df, a key_type to search over (e.g. obsid), and a key_value to find (e.g. 0123456789)\n\nReturns the full row for any observations matching the search criteria\n\nTODO: Fix the DataValue bug properly\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.master_query-Tuple{Symbol,Symbol,Any}",
    "page": "IO Operations",
    "title": "JAXTAM.master_query",
    "category": "method",
    "text": "master_query(mission_name::Symbol, key_type::Symbol, key_value::Any)\n\nCalls master_query(master_df::DataFrame, key_type::Symbol, key_value::Any) by loading the master and append tables for mission_name\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.master_query_public-Tuple{DataFrames.DataFrame,Symbol,Any}",
    "page": "IO Operations",
    "title": "JAXTAM.master_query_public",
    "category": "method",
    "text": "master_query_public(master_df::DataFrame, key_type::Symbol, key_value::Any)\n\nCalls master_query for given query, but restricted to currently public observations\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.master_query_public-Tuple{DataFrames.DataFrame}",
    "page": "IO Operations",
    "title": "JAXTAM.master_query_public",
    "category": "method",
    "text": "master_query_public(master_df::DataFrame)\n\nReturns all the currently public observations in master_df\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.master_query_public-Tuple{Symbol,Symbol,Any}",
    "page": "IO Operations",
    "title": "JAXTAM.master_query_public",
    "category": "method",
    "text": "master_query_public(mission_name::Symbol, key_type::Symbol, key_value::Any)\n\nLoads mission master table, then calls master_query_public(master_df::DataFrame, key_type::Symbol, key_value::Any)\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.master_query_public-Tuple{Symbol}",
    "page": "IO Operations",
    "title": "JAXTAM.master_query_public",
    "category": "method",
    "text": "master_query_public(mission_name::Symbol)\n\nLoads master table for mission_name, calls master_query_public(master_df::DataFrame) returning all currently public observations\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.master_update-Tuple{Union{String, Symbol}}",
    "page": "IO Operations",
    "title": "JAXTAM.master_update",
    "category": "method",
    "text": "master_update(mission_name::Union{String,Symbol})\n\nDownloads mastertable from HEASARC and overwrites old conerted tables\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.master_update-Tuple{}",
    "page": "IO Operations",
    "title": "JAXTAM.master_update",
    "category": "method",
    "text": "master_update()\n\nCalls master_update(mission_name::Union{String,Symbol}) using the :default mission\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._add_append_analysed!-Tuple{Any,Any}",
    "page": "IO Operations",
    "title": "JAXTAM._add_append_analysed!",
    "category": "method",
    "text": "_add_append_analysed!(append_df, mission_name)\n\nAppends column of Union{Bool,Missing}, true if the JAXTAM directory exists\n\nTODO: Improve this function, currently an empty JAXTAM folder means it has been analysed\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._add_append_cl!-Tuple{Any,Any,Any}",
    "page": "IO Operations",
    "title": "JAXTAM._add_append_cl!",
    "category": "method",
    "text": "_add_append_cl!(append_df, master_df, mission_name)\n\nAppends column of Union{Tuple{String},Missing}, tuple of local paths to the cl files\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._add_append_downloaded!-Tuple{Any,Any}",
    "page": "IO Operations",
    "title": "JAXTAM._add_append_downloaded!",
    "category": "method",
    "text": "_add_append_downloaded!(append_df, mission_name)\n\nAppends column of Union{Bool,Missing}, true if all cl files exist\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._add_append_obspath!-Tuple{Any,Any,Any}",
    "page": "IO Operations",
    "title": "JAXTAM._add_append_obspath!",
    "category": "method",
    "text": "_add_append_obspath!(append_df, master_df, mission_name)\n\nAppends column of Union{String,Missing}, with the local path to the observation\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._add_append_publicity!-Tuple{Any,Any}",
    "page": "IO Operations",
    "title": "JAXTAM._add_append_publicity!",
    "category": "method",
    "text": "_add_append_publicity!(append_df, master_df)\n\nAppends column of Union{Bool,Missing}, true if public_date <=now()`\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._add_append_results!-Tuple{Any,Any}",
    "page": "IO Operations",
    "title": "JAXTAM._add_append_results!",
    "category": "method",
    "text": "_add_append_results!(append_df, mission_name)\n\nAppends column of String, if the results.html file exists for an observation the path to the file is returned, otherwise \"NA\" is returned\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._add_append_uf!-Tuple{Any,Any,Any}",
    "page": "IO Operations",
    "title": "JAXTAM._add_append_uf!",
    "category": "method",
    "text": "_add_append_uf!(append_df, master_df, mission_name)\n\nAppends column of Union{Tuple{String},Missing}, tuple of local paths to the uf files\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._append_gen-Tuple{Any,Any}",
    "page": "IO Operations",
    "title": "JAXTAM._append_gen",
    "category": "method",
    "text": "_append_gen(mission_name, master_df)\n\nRuns all the _add_append functions, returns the full append_df\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._append_gen-Tuple{Any}",
    "page": "IO Operations",
    "title": "JAXTAM._append_gen",
    "category": "method",
    "text": "_append_gen(mission_name)\n\nGenerates the append file for a mission\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._append_load-Tuple{Any}",
    "page": "IO Operations",
    "title": "JAXTAM._append_load",
    "category": "method",
    "text": "_append_load(append_path_feather)\n\nLoads a saved append_df, runs _feather2tuple() and returns the DataFrame\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._append_save-Tuple{Any,Any}",
    "page": "IO Operations",
    "title": "JAXTAM._append_save",
    "category": "method",
    "text": "_append_save(append_path_feather, append_df)\n\nRuns _tuple2feather() on append_df then saves to the save path\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._build_append-Tuple{Any}",
    "page": "IO Operations",
    "title": "JAXTAM._build_append",
    "category": "method",
    "text": "_build_append(master_df)\n\nFirst step in creating append table, just returns the obsid column from a missions master table\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._feather2tuple-Tuple{DataFrames.DataFrame}",
    "page": "IO Operations",
    "title": "JAXTAM._feather2tuple",
    "category": "method",
    "text": "_feather2tuple(append_df::DataFrames.DataFrame)\n\nFunction that takes in a DataFrame which has been run through _tuple2feather() and joins the split tuples together\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._tuple2feather-Tuple{DataFrames.DataFrame}",
    "page": "IO Operations",
    "title": "JAXTAM._tuple2feather",
    "category": "method",
    "text": "_tuple2feather(append_df::DataFrames.DataFrame)\n\nFeather.jl, and probably Feather files in general, can\'t save Tuples, this function selects and columns in the DataFrame of type Tuple, then it splits the tuples up into a DataFrame, with column names of the original column name with __tuple__$col$i appended to the end\n\nOnly works if all the tuples in a column are of the same length\n\nTODO: Make edge cases of tuples with over 9 elements work, test methods to allow tuples of different lengths to be split and saved as well\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.append-Tuple{Any}",
    "page": "IO Operations",
    "title": "JAXTAM.append",
    "category": "method",
    "text": "append(mission_name)\n\nIf no append file exists, crates one using the _append_gen() function, then saves the file with _append_save()\n\nIf the append file exists, loads via _append_load()\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.append-Tuple{}",
    "page": "IO Operations",
    "title": "JAXTAM.append",
    "category": "method",
    "text": "append()\n\nCalld append(mission_name) with the default mission config_dict[:default] if one exists\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.append_update-Tuple{Any}",
    "page": "IO Operations",
    "title": "JAXTAM.append_update",
    "category": "method",
    "text": "append_update(mission_name)\n\nRe-generates the append file\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.master_a-Tuple{Any}",
    "page": "IO Operations",
    "title": "JAXTAM.master_a",
    "category": "method",
    "text": "master_a(mission_name)\n\nJoins the master_df (raw, unedited HEASARC master table) and the append_df DataFrames together on :obsid, returns the joined tables\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._clean_path_dots-Tuple{Any}",
    "page": "IO Operations",
    "title": "JAXTAM._clean_path_dots",
    "category": "method",
    "text": "_clean_path_dots(dir)\n\nFTP directories use hidden dot folders frequentyl, function removes from a path for local use\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._ftp_dir-Tuple{Symbol,DataFrames.DataFrame,String}",
    "page": "IO Operations",
    "title": "JAXTAM._ftp_dir",
    "category": "method",
    "text": "_ftp_dir(mission_name::Symbol, master::DataFrames.DataFrame, obsid::String)\n\nSame as _ftp_dir(mission_name::Symbol, obsid::String), takes in master as argument to avoid running master() to load the master table each time\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._ftp_dir-Tuple{Symbol,DataFrames.DataFrame}",
    "page": "IO Operations",
    "title": "JAXTAM._ftp_dir",
    "category": "method",
    "text": "_ftp_dir(mission_name::Symbol, obs_row::DataFrames.DataFrame)\n\nReturns the HEASARC FTP server path to an observation using the  mission defined path_obs function\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._ftp_dir-Tuple{Symbol,String}",
    "page": "IO Operations",
    "title": "JAXTAM._ftp_dir",
    "category": "method",
    "text": "_ftp_dir(mission_name::Symbol, obsid::String)\n\nUses master_query to get obs_row for obsid, calls _ftp_dir(mission_name::Symbol, obs_row::DataFrames.DataFrame)\n\nCalls master(mission_name) each time\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.download-Tuple{Symbol,Array}",
    "page": "IO Operations",
    "title": "JAXTAM.download",
    "category": "method",
    "text": "download(mission_name::Symbol, obsids::Array; overwrite=false)\n\nCalls master(mission_name), then download(mission_name::Symbol, master::DataFrames.DataFrame, obsids::Array; overwrite=false)\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.download-Tuple{Symbol,DataFrames.DataFrame,Array}",
    "page": "IO Operations",
    "title": "JAXTAM.download",
    "category": "method",
    "text": "download(mission_name::Symbol, master::DataFrames.DataFrame, obsids::Array; overwrite=false)\n\nCalls download(mission_name::Symbol, master::DataFrames.DataFrame, obsid::String; overwrite=false) with  an array of multiple obsids\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.download-Tuple{Symbol,DataFrames.DataFrame,String}",
    "page": "IO Operations",
    "title": "JAXTAM.download",
    "category": "method",
    "text": "download(mission_name::Symbol, master::DataFrames.DataFrame, obsid::String; overwrite=false)\n\nFinds the FTP server-side path via _ftp_dir, downloads folder using lftp, currently excludes the uf files assuming calibrations are up to date. Saves download folder to local, dot-free, path\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.download-Tuple{Symbol,String}",
    "page": "IO Operations",
    "title": "JAXTAM.download",
    "category": "method",
    "text": "download(mission_name::Symbol, obsid::String; overwrite=false)\n\nCalls master(mission_name), then calls download(mission_name::Symbol, master::DataFrames.DataFrame, obsid::String; overwrite=false)\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._datetime2mjd-Tuple{Dates.DateTime}",
    "page": "IO Operations",
    "title": "JAXTAM._datetime2mjd",
    "category": "method",
    "text": "_datetime2mjd(human_time::Dates.DateTime)\n\nConverts (human-readable) DataTime to MJD (Julian - 2400000.5) time\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._mjd2datetime-Tuple{Nothing}",
    "page": "IO Operations",
    "title": "JAXTAM._mjd2datetime",
    "category": "method",
    "text": "_mjd2datetime(mjd_time::Nothing)\n\nReturns missing if the mjd_time is Nothing\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM._mjd2datetime-Tuple{Number}",
    "page": "IO Operations",
    "title": "JAXTAM._mjd2datetime",
    "category": "method",
    "text": "_mjd2datetime(mjd_time::Number)\n\nConverts MJD (Julian - 2400000.5) time to (human-readable) DataTime\n\n\n\n\n\n"
},

{
    "location": "man/io/#JAXTAM.unzip!-Tuple{Any}",
    "page": "IO Operations",
    "title": "JAXTAM.unzip!",
    "category": "method",
    "text": "unzip!(path)\n\nUnzip function, using the bundled 7z.exe for Windows, and p7zip-full for is_linux\n\nUsed to unzip the mastertables after download from HEASARC\n\n\n\n\n\n"
},

{
    "location": "man/io/#IO-Operations-1",
    "page": "IO Operations",
    "title": "IO Operations",
    "category": "section",
    "text": "Modules = [JAXTAM]\nPages   = [\n    \"user_config.jl\",\n    \"master_tables.jl\",\n    \"master_append.jl\",\n    \"data_download.jl\",\n    \"misc.jl\"\n]\nOrder   = [:function, :type]"
},

{
    "location": "man/io/#Mission-Definitions-1",
    "page": "IO Operations",
    "title": "Mission Definitions",
    "category": "section",
    "text": "A mutable struct is used for the mission definition:mutable struct MissionDefinition\n    name            ::String\n    url             ::String\n    path            ::String\n    path_obs        ::Function\n    path_cl         ::Function\n    path_uf         ::Function\n    path_rmf        ::String\n    path_web        ::String\n    good_energy_max ::Number\n    good_energy_min ::Number\n    instruments     ::Array\nendname simply defines the mission name.url contains the url to the HEASARC mastertable.path contains the local path to the main mission folder.path_obs, path_cl, and path_uf are three functions, which take in a row from a master table, and return the HEASARC server-sice path to the pbservation, cleaned files, and unfiltered files.path_rmf is a local path to the mission RMF files in caldb.path_web is the local path to the folder where the report pages will be saved.good_energy_max and good_energy_min are the energies the instrument has been rated for.instruments is an array of symbols of instrument names."
},

{
    "location": "man/missions/#",
    "page": "Missions",
    "title": "Missions",
    "category": "page",
    "text": ""
},

{
    "location": "man/missions/#JAXTAM._read_fits_event-Tuple{String}",
    "page": "Missions",
    "title": "JAXTAM._read_fits_event",
    "category": "method",
    "text": "_read_fits_event(fits_path::String)\n\nReads the standard columns for timing analysis (\"TIME\", \"PI\", \"GTI\") from a FITS file,  returns InstrumentData type filled with the relevant data\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM._read_fits_hdu-Tuple{FITSIO.FITS,String}",
    "page": "Missions",
    "title": "JAXTAM._read_fits_hdu",
    "category": "method",
    "text": "_read_fits_hdu(fits_file::FITS, hdu_id::String; cols=\"auto\")\n\nReads the HDU hdu_id from the loaded FITS file fits_file, returns the HDU data\n\nCannot read BitArray type columns due to FITSIO limitations\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM._save_cl_feather-Tuple{String,Union{String, Symbol},DataFrames.DataFrame,DataFrames.DataFrame,DataFrames.DataFrame}",
    "page": "Missions",
    "title": "JAXTAM._save_cl_feather",
    "category": "method",
    "text": "_save_cl_feather(feather_dir::String, instrument_name::Union{String,Symbol},\n    fits_events_df::DataFrame, fits_gtis_df::DataFrame, fits_meta_df::DataFrame)\n\nDue to Feather file restrictions, cannot save all the event and GTI data in one, so  they are split up into three files: events, gtis, and meta. The meta file contains  just the mission name, obsid, and observation start and stop times\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM.read_cl-Tuple{Symbol,DataFrames.DataFrame,String}",
    "page": "Missions",
    "title": "JAXTAM.read_cl",
    "category": "method",
    "text": "read_cl(mission_name::Symbol, append_df::DataFrames.DataFrame, obsid::String; overwrite=false)\n\nCalls master_query() to get the obs_row, then calls readcl(missionname::Symbol, obs_row::DataFrames.DataFrame; overwrite=false)\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM.read_cl-Tuple{Symbol,DataFrames.DataFrame}",
    "page": "Missions",
    "title": "JAXTAM.read_cl",
    "category": "method",
    "text": "read_cl(mission_name::Symbol, obs_row::DataFrames.DataFrame; overwrite=false)\n\nAttempts to read saved (feather) data, if none is found then the read_cl_fits function is ran  and the data is saved with _save_cl_feather for future use\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM.read_cl-Tuple{Symbol,String}",
    "page": "Missions",
    "title": "JAXTAM.read_cl",
    "category": "method",
    "text": "read_cl(mission_name::Symbol, obsid::String; overwrite=false)\n\nCalls master_a(), then calls read_cl(mission_name::Symbol, append_df::DataFrames.DataFrame, obsid::String; overwrite=false)\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM.read_cl_fits-Tuple{Symbol,DataFrames.DataFrame}",
    "page": "Missions",
    "title": "JAXTAM.read_cl_fits",
    "category": "method",
    "text": "read_cl_fits(mission_name::Symbol, obs_row::DataFrames.DataFrame)\n\nReads in FITS data for an observation, returns a Dict{Symbol,InstrumentData}, with the  symbol as the instrument name. So instrument_data[:XTI] works for NICER, and either  instrument_data[:FPMA] or instrument_data[:FPMB] work for NuSTAR\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM._group_return-Tuple{JAXTAM.BinnedData}",
    "page": "Missions",
    "title": "JAXTAM._group_return",
    "category": "method",
    "text": "_group_return(data::BinnedData)\n\nUses the _group_select function to find the group each GTI belongs in\n\nUsing these groups, splits sections of light curve up into an group, then  creates a new BinnedData for just the lightcurve of that one group, finally  returns a Dict{Int64,JAXTAM.BinnedData} where each Int64 is for a different group\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM._group_select-Tuple{JAXTAM.BinnedData}",
    "page": "Missions",
    "title": "JAXTAM._group_select",
    "category": "method",
    "text": "_group_select(data::BinnedData)\n\nChecks the differennce in time between GTIs, if the difference is under  a group_period (128 [sec] by default) then the GTIs are in the same group\n\nDone as data frequently has small breaks between GTIs, even though there is no  significant gap in the lightcurve. Groups are used during plotting, periodograms,  and when grouping/averaging together power spectra\n\nReturns GTIs with an extra :group column added in\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM._lc_bin-Tuple{Array{Float64,1},Union{Float64, Int64},Union{Float64, Int64},Union{Float64, Int64}}",
    "page": "Missions",
    "title": "JAXTAM._lc_bin",
    "category": "method",
    "text": "_lc_bin(event_times::Array{Float64,1}, bin_time::Union{Float64,Int64}, time_start::Union{Float64,Int64}, time_stop::Union{Float64,Int64})\n\nBins the event times to bins of bin_time [sec] lengths\n\nPerforms binning out of memory for speed via OnlineStats.jl Hist function\n\nReturns a range of times, with associated counts per time\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM._lc_filter_energy-Tuple{Array{Float64,1},Array{Float64,1},Float64,Float64}",
    "page": "Missions",
    "title": "JAXTAM._lc_filter_energy",
    "category": "method",
    "text": "_lc_filter_energy(event_times::Array{Float64,1}, event_energies::Array{Float64,1}, good_energy_max::Float64, good_energy_min::Float64)\n\nOptionally filters events by a custom energy range, not just that given in the RMF files for a mission\n\nReturns filtered event times and energies\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM._lc_read-Tuple{String,Symbol,Any}",
    "page": "Missions",
    "title": "JAXTAM._lc_read",
    "category": "method",
    "text": "_lc_read(lc_dir::String, instrument::Symbol, bin_time)\n\nReads the split files saved by _lcurve_save, combines them to return a single BinnedData type\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM._lcurve-Tuple{JAXTAM.InstrumentData,Union{Float64, Int64}}",
    "page": "Missions",
    "title": "JAXTAM._lcurve",
    "category": "method",
    "text": "_lcurve(instrument_data::InstrumentData, bin_time::Union{Float64,Int64})\n\nTakes in the InstrumentData and desired bin_time\n\nRuns functions to perform extra time (_lcurve_filter_time) and energy (_lc_filter_energy) filtering\n\nRuns the binning (_lc_bin) function, then finally _group_select to append group numbers to each GTI\n\nReturns a BinnedData lightcurve\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM._lcurve_filter_time",
    "page": "Missions",
    "title": "JAXTAM._lcurve_filter_time",
    "category": "function",
    "text": "_lcurve_filter_time(event_times::Arrow.Primitive{Float64}, event_energies::Arrow.Primitive{Float64},\n\nLargely not used, as the GTI filtering is enough to deal with out-of-time-range events, and  manually filtering those events out early is computationally intensive\n\nFunction takes in event times and energies, then filters any events outside of the start and stop times\n\nOptionally performs early filtering to remove low count (under 1/sec) GTIs, disabled by default as this is  performed later anyway\n\nReturns array of filtered times, enegies, and GTIs\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM._lcurve_save-Tuple{JAXTAM.BinnedData,String}",
    "page": "Missions",
    "title": "JAXTAM._lcurve_save",
    "category": "method",
    "text": "_lcurve_save(lightcurve_data::BinnedData, lc_dir::String)\n\nTakes in BinnedData and splits the information up into three files, meta, gtis, and data\n\nSaves the files in a lightcurve directory (/JAXTAM/lc/$bin_time/*) per-instrument\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM.lcurve-Tuple{Symbol,DataFrames.DataFrame,Number}",
    "page": "Missions",
    "title": "JAXTAM.lcurve",
    "category": "method",
    "text": "lcurve(mission_name::Symbol, obs_row::DataFrame, bin_time::Number; overwrite=false)\n\nMain function, handles all the lightcurve binning\n\nRuns binning functions if no files are found, then saves the generated BinnedData\n\nLoads saved files if they exist\n\nReturns Dict{Symbol,BinnedData}, with the instrument as a symbol, e.g. lc[:XTI] for NICER,  lc[:FPMA]/lc[:FPMB] for NuSTAR\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM.lcurve-Tuple{Symbol,String,Number}",
    "page": "Missions",
    "title": "JAXTAM.lcurve",
    "category": "method",
    "text": "lcurve(mission_name::Symbol, obsid::String, bin_time::Number; overwrite=false)\n\nRuns master_query to find the desired obs_row for the observation\n\nCalls main lcurve(mission_name::Symbol, obs_row::DataFrame, bin_time::Number; overwrite=false) function\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM._read_calibration-Tuple{Union{Primitive{Int16}, Array},String}",
    "page": "Missions",
    "title": "JAXTAM._read_calibration",
    "category": "method",
    "text": "_read_calibration(pis::Union{Array,Arrow.Primitive{Int16}}, path_rmf::String)\n\nLoads the RMF calibration data, creates PI channels for energy conversion\n\nChannel bounds are the average of the min and max energy range\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM._read_calibration-Tuple{Union{Primitive{Int16}, Array},Symbol}",
    "page": "Missions",
    "title": "JAXTAM._read_calibration",
    "category": "method",
    "text": "_read_calibration(pis::Union{Array,Arrow.Primitive{Int16}}, mission_name::Symbol)\n\nLoads the RMF path from the mission configuration file, then calls  _read_calibration(pis::Union{Array,Arrow.Primitive{Int16}}, path_rmf::String)\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM._read_rmf-Tuple{String}",
    "page": "Missions",
    "title": "JAXTAM._read_rmf",
    "category": "method",
    "text": "_read_rmf(path_rmf::String)\n\nReads an RMF calibration file (from HEASARC caldb), loads in energy bands and PI channels  for use when filtering events out of a good energy range\n\nReturns the PI channels, and the min/max good energy ranges\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM._read_rmf-Tuple{Symbol}",
    "page": "Missions",
    "title": "JAXTAM._read_rmf",
    "category": "method",
    "text": "_read_rmf(mission_name::Symbol)\n\nCalls _read_rmf(path_rmf) using the path_rmf loaded from a mission configuration file\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM.calibrate-Tuple{Symbol,DataFrames.DataFrame,String}",
    "page": "Missions",
    "title": "JAXTAM.calibrate",
    "category": "method",
    "text": "calibrate(mission_name::Symbol, append_df::DataFrames.DataFrame, obsid::String)\n\nCalls master_query to load in the relevant obs_row\n\nCalls and returns calibrate(mission_name::Symbol, obs_row::DataFrames.DataFrame)\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM.calibrate-Tuple{Symbol,DataFrames.DataFrame}",
    "page": "Missions",
    "title": "JAXTAM.calibrate",
    "category": "method",
    "text": "calibrate(mission_name::Symbol, obs_row::DataFrames.DataFrame)\n\nLoads in the calibrated event data, as well as the mission calibration RMF file,  then filters the events by the energy ranges/PI channels in the RMF file\n\nSaves the calibrated files as a calib.feather if none exists\n\nLoads calib.feater file if it does exist\n\nReturns a calibrated (filtered to contain only good energies) InstrumentData type\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM.calibrate-Tuple{Symbol,String}",
    "page": "Missions",
    "title": "JAXTAM.calibrate",
    "category": "method",
    "text": "calibrate(mission_name::Symbol, obsid::String)\n\nCalls master_a to load in the master table\n\nCalls and returns calibrate(mission_name::Symbol, append_df::DataFrames.DataFrame, obsid::String)\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM._gtis-Tuple{JAXTAM.BinnedData}",
    "page": "Missions",
    "title": "JAXTAM._gtis",
    "category": "method",
    "text": "_gtis(lc::BinnedData)\n\nCalls _lc_filter_gtis using BinnedData input\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM._gtis_load-Tuple{Any,Any,Any}",
    "page": "Missions",
    "title": "JAXTAM._gtis_load",
    "category": "method",
    "text": "_gtis_load(gti_dir, instrument, bin_time)\n\nLoads and parses the _meta and _gti files, puts into a GTIData constructor, returns Dict{Int,GTIData}\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM._gtis_save-Tuple{Any,String}",
    "page": "Missions",
    "title": "JAXTAM._gtis_save",
    "category": "method",
    "text": "_gtis_save(gtis, gti_dir::String)\n\nSplits up the GTI data into a _meta.feather file containing non-array variables for each GTI (index, start/stop times, etc...)  and multiple _gti.feather files for each GTI containing the counts and times\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM._lc_filter_gtis-Tuple{StepRangeLen,Array{Int64,1},DataFrames.DataFrame,Symbol,Symbol,String}",
    "page": "Missions",
    "title": "JAXTAM._lc_filter_gtis",
    "category": "method",
    "text": "_lc_filter_gtis(binned_times::StepRangeLen, binned_counts::Array{Int,1}, gtis::DataFrames.DataFrame, mission::Symbol, instrument::Symbol, obsid::String; min_gti_sec=16)\n\nSplits the lightcurve (count) data into GTIs\n\nFirst, removes GTIs under min_gti_sec, then puts the lightcurve data  into a Dict{Int,GTIData}, with the key as the index of the GTI\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM.gtis-Tuple{Symbol,DataFrames.DataFrame,Number}",
    "page": "Missions",
    "title": "JAXTAM.gtis",
    "category": "method",
    "text": "gtis(mission_name::Symbol, obs_row::DataFrames.DataFrame, bin_time::Number; overwrite=false)\n\nHandles file management, checks to see if GTI files exist already and loads them, if files do not  exist then the _gits function is ran, then the data is saved\n\n\n\n\n\n"
},

{
    "location": "man/missions/#JAXTAM.gtis-Tuple{Symbol,String,Number}",
    "page": "Missions",
    "title": "JAXTAM.gtis",
    "category": "method",
    "text": "gtis(mission_name::Symbol, obsid::String, bin_time::Number; overwrite=false)\n\nRuns master_query to load the obs_row for a given obsid, runs main gits function\n\n\n\n\n\n"
},

{
    "location": "man/missions/#Missions-1",
    "page": "Missions",
    "title": "Missions",
    "category": "section",
    "text": "Modules = [JAXTAM]\nPages   = [\n    \"read_events.jl\",\n    \"lcurve.jl\",\n    \"calibrate.jl\",\n    \"gtis.jl\",\n    \"fspec.jl\",\n    \"pgram.jl\",\n    \"sgram.jl\"\n]\nOrder   = [:function, :type]"
},

{
    "location": "man/science/#",
    "page": "Science",
    "title": "Science",
    "category": "page",
    "text": ""
},

{
    "location": "man/science/#Science-1",
    "page": "Science",
    "title": "Science",
    "category": "section",
    "text": "Modules = [JAXTAM]\nPages   = [\n    \"calibrate.jl\",\n    \"fspec.jl\",\n    \"gtis.jl\",\n    \"lcurve.jl\",\n    \"pgram.jl\",\n    \"plots.jl\"\n]\nOrder   = [:function, :type]"
},

]}
