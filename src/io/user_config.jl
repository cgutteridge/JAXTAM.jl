function _config_gen(config_path=string(pwd(), "/user_configs.jld2"))
    if isfile(config_path)
        rm(config_path)
    end

    info("Creating config file at: $config_path")
    config_data = Dict("_config_edit_date" => string(Dates.DateTime(now())))

    save(config_path, Dict("config_data" => config_data))
end

function _config_load(config_path=string(pwd(), "/user_configs.jld2"))
    return load(config_path, "config_data")
end

function _config_edit(mission_name::String, mission_path::String;
        config_path=string(pwd(), "/user_configs.jld2"))

    if !isfile(config_path)
        _config_gen(config_path)
    end

    config_data = _config_load(config_path)

    config_data["_config_edit_date"] = string(Dates.DateTime(now()))
    config_data[mission_name] = mission_path

    save(config_path, Dict("config_data" => config_data))
end

function _config_rm(mission_name::String;
        config_path=string(pwd(), "/user_configs.jld2"))

    if !isfile(config_path)
        _config_gen(config_path)
    end

    config_data = _config_load(config_path)

    delete!(config_data, mission_name)
    config_data["_config_edit_date"] = string(Dates.DateTime(now()))

    save(config_path, Dict("config_data" => config_data))
end

function _config_mission_path(mission_name::Union{String,Symbol}, config_path=string(pwd(), "/user_configs.jld2"))
    config_data = _config_load(config_path)

    return config_data[string(mission_name)]
end

function config()
    return _config_load()
end

function config(mission_name::Union{String,Symbol}, mission_path::String)
    _config_edit(String(mission_name), mission_path)
    return _config_load()
end

function config(mission_name::Union{String,Symbol})
    return _config_load()[String(mission_name)]
end

function config_rm(mission_name::Union{String,Symbol})
    info("Removing \"$mission_name => $(_config_load()[String(mission_name)])\" from config file")
    _config_rm(String(mission_name))
    return _config_load()
end