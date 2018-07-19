function _master_download(master_path, master_url)
    info("Downloading latest master catalog")
    Base.download(master_url, master_path)

    if VERSION >= v"0.7.0" || Sys.is_linux()
        # Windows (used to) unzip .gz during download, unzip now if Linux
        unzip!(master_path)
    end
end

"""
    _master_read_tdat(master_path::String)

Reads a raw `.tdat` table from HEASARC mastertable archives,
parses the ASCII data, finds and stores column names, cleans punctuation,
converts to `DataFrame`, and finally returns cleaned table as `DataFrame`
"""
function _master_read_tdat(master_path::String)
    master_ascii = readdlm(master_path, '\n')

    data_start = Int(find(master_ascii .== "<DATA>")[1] + 1)
    data_end   = Int(find(master_ascii .== "<END>")[1] - 1)
    keys_line  = data_start - 2

    # Key names are given on the keys_line, split and make into symbols for use later
    key_names = Symbol.(split(master_ascii[keys_line][11:end])) # 11:end to remove 'line[1] = '
    no_cols   = length(key_names)
    key_obsid = find(key_names .== :obsid)[1]
    key_archv = find(key_names .== :processing_status)

    master_ascii_data = master_ascii[data_start:data_end]

    master_df = DataFrame(zeros(1, no_cols), key_names)

    deleterows!(master_df, 1) # Remove row, only made to get column names

    for (row_i, row) in enumerate(master_ascii_data)
        obs_values = split(row, "|")[1:end - 1] # Split row by | delims

        if length(obs_values) != no_cols # Some rows don't have the proper no. of columns, skip them
            warn("Skipped row $row_i due to malformed columns, ObsID: $(obs_values[key_obsid])")
            continue
        end

        df_tmp = DataFrame()

        for (itr, key) in enumerate(key_names) # Create DataFrame of key and val for row
            cleaned = replace(obs_values[itr], ",", ".. ") # Remove some punctuation, screw with CSV
            cleaned = replace(cleaned, ";", ".. ")

            if cleaned != ""
                if key in [:time, :end_time, :processing_date, :public_date]
                    cleaned = _mjd2datetime(parse(obs_values[itr]))
                end
            else
                cleaned = missing
            end

            df_tmp[key] = cleaned
        end

        master_df = [master_df; df_tmp] # Concat
    end

    sort!(master_df, :name)

    return master_df
end

"""
    _master_save(master_path_jld, master_data)

Saves the `DataFrame` master table to a `.jld` file, under the
key `master_data`
"""
function _master_save(master_path_jld, master_data)
    save(master_path_jld, Dict("master_data" => master_data))
end

function master_update(mission_name::Union{String,Symbol})
    mission = _config_key_value(mission_name)
    master_path_tdat = string(mission.path, "master.tdat")
    master_path_jld = string(mission.path, "master.jld2")

    if !isdir(mission.path)
        mkpath(mission.path)
    end

    _master_download(master_path_tdat, mission.url)

    info("Loading $(master_path_tdat)")
    master_data = _master_read_tdat(master_path_tdat)
    info("Saving $master_path_jld")
    _master_save(master_path_jld, master_data)
end

function master_update()
    mission_name = _config_key_value(:default)

    info("Using default mission: $mission_name")

    master_update(mission_name)
end

"""
    master(mission_name::Union{String,Symbol})

Reads in a previously created `.jld` master table for a specific `mission_name`
using a path provided by `_config_key_value(mission_name)`
"""
function master(mission_name::Union{String,Symbol})
    mission = _config_key_value(mission_name)
    master_path_tdat = string(mission.path, "master.tdat")
    master_path_jld = string(mission.path, "master.jld2")

    if !isfile(master_path_tdat) && !isfile(master_path_tdat)
        warn("No master file found, looked for: \n\t$master_path_tdat \n\t$master_path_jld")
        info("Download master files from `$(mission.url)`? (y/n)")
        response = readline(STDIN)
        if response=="y" || response=="Y"
            if !isdir(mission.path)
                mkpath(mission.path)
            end

            _master_download(master_path_tdat, mission.url)
        end
    end
    
    if isfile(master_path_jld)
        info("Loading $master_path_jld")
        return load(master_path_jld)["master_data"]
    elseif isfile(master_path_tdat)
        info("Loading $(master_path_tdat)")
        master_data = _master_read_tdat(master_path_tdat)
        info("Saving $master_path_jld")
        _master_save(master_path_jld, master_data)
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
        info("Using default mission - $(config_dict[:default])")
        return master(config_dict[:default])
    else
        error("Default mission not found, set with config(:default, :default_mission_name)")
    end
end


"""
    master_query(master_df::DataFrame, key_type::Symbol, key_value::Any)


Wrapper for a query, takes in an already loaded DataFrame `master_df`, a `key_type` to
search over (e.g. `obsid`), and a `key_value` to find (e.g. `0123456789`)

Returns the full row for any observations matching the search criteria
"""
function master_query(master_df::DataFrame, key_type::Symbol, key_value::Any)
    observations = @from row in master_df begin
        @where eval(Expr(:call, ==, getfield(row, key_type), key_value))
        @select row
        @collect DataFrame
    end

    if size(observations, 1) == 0
        warn("master_query returned no results for $key_type with $key_value search")
    end

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
    observations = @from row in master_df begin
        @where eval(Expr(:call, ==, getfield(row, key_type), key_value)) && row.public_date < now()
        @select row
        @collect DataFrame
    end

    if size(observations, 1) == 0
        warn("master_query_public returned no results for $key_type with $key_value search")
    end

    return observations
end

function master_query_public(master_df::DataFrame)
    observations = @from row in master_df begin
        @where row.public_date < now()
        @select row
        @collect DataFrame
    end

    return observations
end

function master_query_public(mission_name::Symbol)
    master_df = master_a(mission_name)

    return master_query_public(master_df)
end