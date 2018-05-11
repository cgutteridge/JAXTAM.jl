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
        obs_values = split(row, "|")[1:end-1] # Split row by | delims

        if length(obs_values) != no_cols # Some rows don't have the proper no. of columns, skip them
            warn("Skipped row $row_i due to malformed columns, ObsID: $(obs_values[key_obsid])")
            continue
        end

        df_tmp = DataFrame()

        for (itr, key) in enumerate(key_names) # Create DataFrame of key and val for row
            cleaned = replace(obs_values[itr], ",", ".. ") # Remove some punctuation, screw with CSV
            cleaned = replace(cleaned, ";", ".. ")

            df_tmp[key] = cleaned
        end

        master_df = [master_df; df_tmp] # Concat
    end

    sort!(master_df, :public_date)

    return master_df
end

function _master_save(master_path_jld2, master_data)
    save(master_path_jld2, Dict("master_data" => master_data))
end

function master_load(mission_name::Union{String,Symbol})
    mission_path = _config_mission_path(mission_name)
    master_path_tdat = string(mission_path, "master.tdat")
    master_patj_jld2 = string(mission_path, "master.jld2")

    if isfile(master_patj_jld2)
        info("Loading $master_patj_jld2")
        return load(master_patj_jld2)["master_data"]
    elseif isfile(master_path_tdat)
        info("Loading $(master_path_tdat))")
        master_data = _master_read_tdat(master_path_tdat)
        info("Saving $master_patj_jld2")
        _master_save(master_patj_jld2, master_data)
        return master_data
    end
end

function master_query(master_df::DataFrame, key_type::Symbol, key_value::Any)
    observations = @from row in master_df begin
        @where eval(Expr(:call, ==, getfield(row, key_type), key_value))
        @select row
        @collect DataFrame
    end

    return observations
end