"""
    _config_gen(config_path::String=string(pwd(), "/user_configs.jld2"))

Generates a user configuration file at `config_path`,
by default, file is placed in the JAXTAM module dir.

Config file is `/user_configs.jld2`, excluded from git.
"""
function _config_gen(config_path::String=string(pwd(), "/user_configs.jld2"))
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

function _config_edit(key_name::String, key_value::String;
        config_path=string(pwd(), "/user_configs.jld2"))

    if !isfile(config_path)
        _config_gen(config_path)
    end

    config_data = _config_load(config_path)

    config_data["_config_edit_date"] = string(Dates.DateTime(now()))
    config_data[key_name] = key_value

    save(config_path, Dict("config_data" => config_data))
end

function _config_rm(key_name::String;
        config_path=string(pwd(), "/user_configs.jld2"))

    if !isfile(config_path)
        _config_gen(config_path)
    end

    config_data = _config_load(config_path)

    delete!(config_data, key_name)
    config_data["_config_edit_date"] = string(Dates.DateTime(now()))

    save(config_path, Dict("config_data" => config_data))
end

function _config_key_value(key_name::Union{String,Symbol}, config_path=string(pwd(), "/user_configs.jld2"))
    config_data = _config_load(config_path)

    return config_data[string(key_name)]
end

function config()
    return _config_load()
end

function config(key_name::Union{String,Symbol}, key_value::Union{String,Symbol})
    _config_edit(String(key_name), String(key_value))
    return _config_load()
end

function config(key_name::Union{String,Symbol})
    return _config_load()[String(key_name)]
end

function config_rm(key_name::Union{String,Symbol})
    info("Removing \"$key_name => $(_config_load()[String(key_name)])\" from config file")
    _config_rm(String(key_name))
    return _config_load()
end