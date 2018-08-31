function _build_append(master_df)
    return DataFrame(obsid=master_df[:obsid])
end

function _add_append_publicity!(append_df, master_df)
    append_publicity = Array{Union{Bool,Missing},1}(undef, size(append_df, 1))

    for (i, obsid) in enumerate(append_df[:obsid])
        append_publicity[i] = now() > convert(DateTime, master_df[i, :public_date])
    end

    return append_df[:publicity] = append_publicity
end

function _add_append_obspath!(append_df, master_df, mission_name)
    obs_path_function = config(mission_name).path_obs
    mission_path = config(mission_name).path
    append_obspath = Array{Union{String,Missing},1}(undef, size(append_df, 1))

    for (i, obsid) in enumerate(append_df[:obsid])
        append_obspath[i] = abspath(string(mission_path, _clean_path_dots(obs_path_function(master_df[i, :]))))
    end

    return append_df[:obs_path] = append_obspath
end

function _add_append_uf!(append_df, master_df, mission_name)
    append_uf = Array{Union{Tuple,Missing},1}(undef, size(append_df, 1))
    root_dir  = config(mission_name).path
    uf_path_function = config(mission_name).path_uf

    for (i, obsid) in enumerate(append_df[:obsid])
        append_uf[i] = uf_path_function(master_df[i, :], root_dir)
    end

    return append_df[:event_uf] = append_uf
end

function _add_append_cl!(append_df, master_df, mission_name)
    append_cl = Array{Union{Tuple,Missing},1}(undef, size(append_df, 1))
    root_dir  = config(mission_name).path
    cl_path_function = config(mission_name).path_cl

    for (i, obsid) in enumerate(append_df[:obsid])
        append_cl[i] = cl_path_function(master_df[i, :], root_dir)
    end

    return append_df[:event_cl] = append_cl
end

function _add_append_downloaded!(append_df, mission_name)
    append_downloaded = Array{Union{Bool,Missing},1}(undef, size(append_df, 1))
    root_dir  = config(mission_name).path
    cl_path_function = config(mission_name).path_cl

    for (i, obspath) in enumerate(append_df[:obs_path])
        append_downloaded[i] = isdir(obspath)
    end

    return append_df[:downloaded] = append_downloaded
end

function _make_append(mission_name, master_df)
    append_df = _build_append(master_df)

    _add_append_publicity!(append_df, master_df)
    _add_append_obspath!(append_df, master_df, mission_name)
    _add_append_uf!(append_df, master_df, mission_name)
    _add_append_cl!(append_df, master_df, mission_name)
    _add_append_downloaded!(append_df, mission_name)

    return append_df
end

function _tuple2feather(append_df::DataFrames.DataFrame)
    columns = names(append_df)

    for col in columns
        if typeof(append_df[1, col]) <: Tuple
            tuple_length = length(append_df[1, col])
            tuple_count  = size(append_df[col], 1)

            if tuple_length > 9
                @warn "Tuples > 9 don't load properly, contact developer for fix"
            end

            tuple_new_cols = [Symbol("__tuple__$col$i") for i in 1:tuple_length]

            tuple_array = Array{String,2}(undef, tuple_count, tuple_length+1)

            for i in 1:tuple_count
                tuple_array[i, 1:tuple_length] = [i for i in append_df[i, col]]
                tuple_array[i, tuple_length+1] = append_df[i, :obsid]
            end

            tuple_df = DataFrame(tuple_array, [tuple_new_cols; :obsid])

            append_df = join(append_df, tuple_df, on=:obsid)

            append_df = append_df[:, setdiff(names(append_df), [col])]
        end
    end
    
    return append_df    
end

function _feather2tuple(append_df::DataFrames.DataFrame)
    columns = names(append_df)
    columns_tuple = columns[occursin.("__tuple__", string.(columns))]

    # Assumes maximum 9-length tuples
    tuple_names = unique([string(x)[10:end-1] for x in columns_tuple])

    for tuple_name in tuple_names
        cols = columns_tuple[occursin.(tuple_name, string.(columns_tuple))]

        tuple_df = DataFrame()
        tuple_df[Symbol(tuple_name)] = [tuple(convert(Array, x)...) for x in DataFrames.eachrow(append_df[:, cols])]
        tuple_df[:obsid]             = [convert(String, x) for x in append_df[:, :obsid]]

        append_df = join(append_df, tuple_df, on=:obsid)

        append_df = append_df[:, setdiff(names(append_df), cols)]
    end

    return append_df
end

function _make_append(mission_name)
    master_df = master(mission_name)
    append_df = _make_append(mission_name, master_df)

    return append_df
end

function _append_save(append_path_feather, append_df)
    append_df = _tuple2feather(append_df)

    Feather.write(append_path_feather, append_df)
end

function _append_load(append_path_feather)
    append_df = Feather.read(append_path_feather)
    
    return _feather2tuple(append_df)
end

function append(mission_name)
    append_path_feather = abspath(string(_config_key_value(mission_name).path, "append.feather"))

    if isfile(append_path_feather)
        @info "Loading $append_path_feather"
        return _append_load(append_path_feather)
    else
        master_df = master(mission_name)
        append_df = _make_append(mission_name, master_df)
        @info "Saving $append_path_feather"
        _append_save(append_path_feather, append_df)
        return append_df
    end
end

function append()
    config_dict = config()

    if :default in keys(config_dict)
        @info "Using default mission - $(config_dict[:default])"
        return append(config_dict[:default])
    else
        @warn "Default mission not found, set with config(:default, :default_mission_name)"
        throw(KeyError(:default))
    end
end

function append_update(mission_name)
    append_path_feather = abspath(string(_config_key_value(mission_name).path, "append.feather"))

    master_df = master(mission_name)
    append_df = _make_append(mission_name, master_df)
    @info "Saving $append_path_feather"
    _append_save(append_path_feather, append_df)
    return append_df
end


function master_a(mission_name)
    master_df = master(mission_name)
    append_df = append(mission_name)

    return join(master_df, append_df, on=:obsid)
end