function _master_download(master_path, master_url)
    @info "Downloading latest master catalog"
    Base.download(master_url, master_path)

    # Windows (used to) unzip .gz during download, unzip now if Linux
    unzip!(master_path)
end

function _type_master_df!(master_df)
    pairs = Dict(:name=>string, :ra=>float, :dec=>float, :lii=>float, :bii=>float, :roll_angle=>float,
        :time=>Dates.DateTime, :end_time=>Dates.DateTime, :obsid=>string, :exposure=>float, :exposure_a=>float,
        :exposure_b=>float, :ontime_a=>float, :ontime_b=>float, :observation_mode=>string, :instrument_mode=>string,
        :spacecraft_mode=>string, :slew_mode=>string, :time_awarded=>float, :num_fpm=>Meta.parse,
        :processing_status=>string, :processing_date=>Dates.DateTime,:public_date=>Dates.DateTime,
        :processing_version=>string, :num_processed=>Meta.parse, :caldb_version=>String, :software_version=>string,
        :prnb=>string, :abstract=>string, :subject_category=>string, :category_code=>Meta.parse,:priority=>string,
        :country=>string, :data_gap=>Meta.parse, :nupsdout=>Meta.parse, :solar_activity=>string, :coordinated=>string,
        :issue_flag=>Meta.parse, :comments=>string, :satus=>string,  :pi_lname=>string, :pi_fname=>string,
        :cycle=>Meta.parse, :obs_type=>string, :title=>string, :remarks=>string)

    for (name, coltype) in pairs
        # if true in ismissing.(master_df[name])
        #     master_df[name] = Array{Union{Missing,}}
        # else
        # end
        try
            master_df[name] = coltype.(master_df[name])
        catch e
            @warn e
        end
    end

    return master_df
end

"""
    _master_read_tdat(master_path::String)

Reads a raw `.tdat` table from HEASARC mastertable archives,
parses the ASCII data, finds and stores column names, cleans punctuation,
converts to `DataFrame`, and finally returns cleaned table as `DataFrame`
"""
function _master_read_tdat(master_path::String)
    master_ascii = readdlm(master_path, '\n')

    data_start = Int(findfirst(master_ascii .== "<DATA>")[1] + 1)
    data_end   = Int(findfirst(master_ascii .== "<END>")[1] - 1)
    keys_line  = Int(findfirst(master_ascii .== "# Data Format Specification")[1] + 2)
    field_line = Int(findfirst(master_ascii .== "# Table Parameters")[1] + 2)

    # Key names are given on the keys_line, split and make into symbols for use later
    key_names = Symbol.(split(master_ascii[keys_line][11:end])) # 11:end to remove 'line[1] = '
    no_cols   = length(key_names)
    key_obsid = findfirst(key_names .== :obsid)[1]
    key_archv = findfirst(key_names .== :processing_status)

    key_types = [line[3] for line in split.(master_ascii[field_line:field_line+no_cols-1], " ")]

    master_ascii_data = master_ascii[data_start:data_end]

    master_df = DataFrame(zeros(1, no_cols), key_names)

    deleterows!(master_df, 1) # Remove row, only made to get column names

    for (row_i, row) in enumerate(master_ascii_data)
        obs_values = split(row, "|")[1:end - 1] # Split row by | delims

        if length(obs_values) != no_cols # Some rows don't have the proper no. of columns, skip them
            @warn "Skipped row $row_i due to malformed columns, ObsID: $(obs_values[key_obsid])"
            continue
        end

        df_tmp = DataFrame()

        for (itr, key) in enumerate(key_names) # Create DataFrame of key and val for row
            cleaned = replace(obs_values[itr], "," => ".. ") # Remove some punctuation, screw with CSV
            cleaned = replace(cleaned, ";" => ".. ")

            if cleaned != ""
                if key in [:time, :end_time, :processing_date, :public_date]
                    cleaned = _mjd2datetime(Meta.parse(obs_values[itr]))
                end
            else
                cleaned = missing
            end

            df_tmp[key] = cleaned
        end

        master_df = [master_df; df_tmp] # Concat
    end

    sort!(master_df, :name)

    _type_master_df!(master_df)

    return master_df
end

"""
    _master_save(master_path_feather, master_data)

Saves the `DataFrame` master table to a `.jld` file, under the
key `master_data`
"""
function _master_save(master_path_feather, master_data)
    Feather.write(master_path_feather, master_data)
end

function master_update(mission_name::Union{String,Symbol})
    mission = _config_key_value(mission_name)
    master_path_tdat = string(mission.path, "master.tdat")
    master_path_feather = string(mission.path, "master.feather")

    if !isdir(mission.path)
        mkpath(mission.path)
    end

    _master_download(master_path_tdat, mission.url)

    @info "Loading $(master_path_tdat)"
    master_data = _master_read_tdat(master_path_tdat)
    @info "Saving $master_path_feather"
    _master_save(master_path_feather, master_data)
end

function master_update()
    mission_name = _config_key_value(:default)

    @info "Using default mission: $mission_name"

    master_update(mission_name)
end

"""
    master(mission_name::Union{String,Symbol})

Reads in a previously created `.feather` master table for a specific `mission_name`
using a path provided by `_config_key_value(mission_name)`
"""
function master(mission_name::Union{String,Symbol})
    mission = _config_key_value(mission_name)
    master_path_tdat = string(mission.path, "master.tdat")
    master_path_feather = string(mission.path, "master.feather")

    if !isfile(master_path_tdat) && !isfile(master_path_tdat)
        @warn "No master file found, looked for: \n\t$master_path_tdat \n\t$master_path_feather"
        @info "Download master files from `$(mission.url)`? (y/n)"
        response = readline(stdin)
        if response=="y" || response=="Y"
            if !isdir(mission.path)
                mkpath(mission.path)
            end

            _master_download(master_path_tdat, mission.url)
        elseif response=="n" || response=="N"
            @error "Master file not found"
        end
    end
    
    if isfile(master_path_feather)
        @info "Loading $master_path_feather"
        return Feather.read(master_path_feather)
    elseif isfile(master_path_tdat)
        @info "Loading $(master_path_tdat)"
        master_data = _master_read_tdat(master_path_tdat)
        @info "Saving $master_path_feather"
        _master_save(master_path_feather, master_data)
        return master_data
    end
end

"""
    master()

Loads a default mission, if one is set, otherwise throws error
"""
function master()
    config_dict = config()

    if :default in keys(config_dict)
        @info "Using default mission - $(config_dict[:default])"
        return master(config_dict[:default])
    else
        @warn "Default mission not found, set with config(:default, :default_mission_name)"
        throw(KeyError(:default))
    end
end


"""
    master_query(master_df::DataFrame, key_type::Symbol, key_value::Any)


Wrapper for a query, takes in an already loaded DataFrame `master_df`, a `key_type` to
search over (e.g. `obsid`), and a `key_value` to find (e.g. `0123456789`)

Returns the full row for any observations matching the search criteria
"""
function master_query(master_df::DataFrame, key_type::Symbol, key_value::Any)
    observations = filter(row -> row[key_type] == key_value, master_df)

    if size(observations, 1) == 0
        @warn "master_query returned no results for $key_type with $key_value search"
    end

    # Some DataFrames update changed the types of data to DataValue
    # screws with functions later on which convert the values to strings
    # use get here to get them out of the DataVakue type, wrapped in try
    # for any cases where these columns don't exist in the master dataframe
    try; observations[:obsid] = get(observations[:obsid][1]); catch; end
    try; observations[:time] = get(observations[:time][1]); catch; end

    return observations
end

function master_query(mission_name::Symbol, key_type::Symbol, key_value::Any)

    return master_query(master_a(mission_name), key_type, key_value)
end

function _public_date_int(public_date)
    public_date = get(public_date)
    try
        return parse(Float64, public_date)
    catch
        return 2e10
    end
end

function master_query_public(master_df::DataFrame, key_type::Symbol, key_value::Any)
    observations = filter(row -> row[key_type] == key_value, master_df)
    observations = filter(row -> convert(DateTime, row[:public_date]) < now(), observations)
    
    if size(observations, 1) == 0
        @warn "master_query_public returned no results for $key_type with $key_value search"
    end

    return observations
end

function master_query_public(mission_name::Symbol, key_type::Symbol, key_value::Any)
    master_df = master(mission_name)

    return master_query_public(master_df, key_type, key_value)
end

function master_query_public(master_df::DataFrame)
    observations = filter(row -> convert(DateTime, row[:public_date]) < now(), master_df)

    return observations
end

function master_query_public(mission_name::Symbol)
    master_df = master_a(mission_name)

    return master_query_public(master_df)
end