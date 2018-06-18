function _build_append(master_df)
    return DataFrame(obsid=master_df[:obsid])
end

function _add_append_publicity!(append_df, master_df)
    append_publicity = Array{Union{Bool,Missing},1}(size(append_df, 1))

    for (i, obsid) in enumerate(append_df[:obsid])
        append_publicity[i] = now() > master_df[i, :public_date]
    end

    return append_df[:publicity] = append_publicity
end

function _add_append_obspath!(append_df, master_df, mission_name)
    obs_path_function = config(mission_name).path_obs
    mission_path = config(mission_name).path
    append_obspath = Array{Union{String,Missing},1}(size(append_df, 1))

    for (i, obsid) in enumerate(append_df[:obsid])
        append_obspath[i] = abspath(string(mission_path, _clean_path_dots(obs_path_function(master_df[i, :]))))
    end

    return append_df[:obs_path] = append_obspath
end

function _add_append_uf!(append_df, master_df, mission_name)
    append_uf = Array{Union{Tuple,Missing},1}(size(append_df, 1))
    root_dir  = config(mission_name).path
    uf_path_function = config(mission_name).path_uf

    for (i, obsid) in enumerate(append_df[:obsid])
        append_uf[i] = uf_path_function(master_df[i, :], root_dir)
    end

    return append_df[:event_uf] = append_uf
end

function _add_append_cl!(append_df, master_df, mission_name)
    append_cl = Array{Union{Tuple,Missing},1}(size(append_df, 1))
    root_dir  = config(mission_name).path
    cl_path_function = config(mission_name).path_cl

    for (i, obsid) in enumerate(append_df[:obsid])
        append_cl[i] = cl_path_function(master_df[i, :], root_dir)
    end

    return append_df[:event_cl] = append_cl
end

function _add_append_downloaded!(append_df, mission_name)
    append_downloaded = Array{Union{Bool,Missing},1}(size(append_df, 1))
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

function _make_append(mission_name)
    master_df = master(mission_name)
    append_df = _make_append(mission_name, master_df)

    return append_df
end

function _append_save(append_path_jld, append_df)
    save(append_path_jld, Dict("append_data" => append_df))
end

function append(mission_name)
    append_path_jld = abspath(string(_config_key_value(mission_name).path, "append.jld2"))

    if isfile(append_path_jld)
        info("Loading $append_path_jld")
        return load(append_path_jld)["append_data"]
    else
        master_df = master(mission_name)
        append_df = _make_append(mission_name, master_df)
        info("Saving $append_path_jld")
        _append_save(append_path_jld, append_df)
        return append_df
    end
end

function append()
    config_dict = config()

    if :default in keys(config_dict)
        info("Using default mission - $(config_dict[:default])")
        return append(config_dict[:default])
    else
        error("Default mission not found, set with config(:default, :default_mission_name)")
    end
end

function append_update(mission_name)
    append_path_jld = abspath(string(_config_key_value(mission_name).path, "append.jld2"))

    master_df = master(mission_name)
    append_df = _make_append(mission_name, master_df)
    info("Saving $append_path_jld")
    _append_save(append_path_jld, append_df)
    return append_df
end


function master_a(mission_name)
    master_df = master(mission_name)
    append_df = append(mission_name)

    return join(master_df, append_df, on=:obsid)
end