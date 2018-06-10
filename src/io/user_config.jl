"""
    _config_gen(config_path::String=string(pwd(), "/user_configs.jld"))

Generates a user configuration file at `config_path`,
by default, file is placed in the JAXTAM module dir.

Config file is `/user_configs.jld`, excluded from git.
"""
function _config_gen(config_path=string(Pkg.dir(), "/JAXTAM/user_configs.jld"))
    if isfile(config_path)
        rm(config_path)
    end

    info("Creating config file at: $config_path")
    config_data = Dict{String,Any}("_config_edit_date" => Dates.DateTime(now()))

    if !isdir(dirname(config_path))
        mkdir(dirname(config_path))
    end

    save(config_path, Dict("config_data" => config_data))
end

"""
    _config_load(config_path=string(Pkg.dir(), "/JAXTAM/user_configs.jld"))

Loads data from the configuration file.
"""
function _config_load(config_path=string(Pkg.dir(), "/JAXTAM/user_configs.jld"))
    if !isfile(config_path)
        warn("Config file not found!")
        _config_gen()
    end

    return load(config_path, "config_data")
end

"""
    _config_edit(key_name::String, key_value::String;
            config_path=string(Pkg.dir(), "/JAXTAM/user_configs.jld"))

Edit configuration file, automatically changes the `_config_edit_date`
value.
"""
function _config_edit(key_name::String, key_value;
        config_path=string(Pkg.dir(), "/JAXTAM/user_configs.jld"))

    if !isfile(config_path)
        _config_gen(config_path)
    end

    config_data = _config_load(config_path)

    config_data["_config_edit_date"] = Dates.DateTime(now())
    config_data[key_name] = key_value

    save(config_path, Dict("config_data" => config_data))
end


"""
    _config_rm(key_name::String;
            config_path=string(Pkg.dir(), "/JAXTAM/user_configs.jld"))

Removes a the key `key_name` from the configuration file,
then saves the changes.
"""
function _config_rm(key_name::String;
        config_path=string(Pkg.dir(), "/JAXTAM/user_configs.jld"))

    if !isfile(config_path)
        _config_gen(config_path)
    end

    config_data = _config_load(config_path)

    delete!(config_data, key_name)
    config_data["_config_edit_date"] = string(Dates.DateTime(now()))

    save(config_path, Dict("config_data" => config_data))
end

"""
    _config_key_value(key_name::Union{String,Symbol}, config_path=string(Pkg.dir(), "/JAXTAM/user_configs.jld"))
        config_data = _config_load(config_path)

Loads and returns the value for `key_name`
"""
function _config_key_value(key_name::Union{String,Symbol}, config_path=string(Pkg.dir(), "/JAXTAM/user_configs.jld"))
    config_data = _config_load(config_path)

    return config_data[string(key_name)]
end

"""
    config()

Returns the full configuration file data
"""
function config()
    return _config_load()
end

"""
    config(key_name::Union{String,Symbol}, key_value::Union{String,Symbol})
        _config_edit(String(key_name), String(key_value))

Adds `key_name` with `key_value` to the configuration file and saves
"""
function config(key_name::Union{String,Symbol}, key_value::Union{String,Symbol,MissionDefinition})
    if typeof(key_value) == MissionDefinition
        _config_edit(String(key_name), key_value)
    else
        defaults = _get_default_missions()

        if string(key_name) in keys(defaults)
            info("$key_name found in defaults\nUsing $key_value as path")
            mission = defaults[string(key_name)]
            mission.path = key_value

            _config_edit(String(key_name), mission)
        else
            info("$key_name not found in defaults, treated as a string")
            info("If $key_name is a mission, use config(key_name, MissionDefinition) to fully set up the mission variables")
            _config_edit(string(key_name), String(key_value))
        end
    end

    return _config_load()
end


"""
    config(key_name::Union{String,Symbol})

Returns the value of `key_name`
"""
function config(key_name::Union{String,Symbol})
    if key_name == "default" || key_name == :default
        return _config_load()[string( _config_load()["default"])]
    else
        return _config_load()[String(key_name)]
    end
end

"""
    config_rm(key_name::Union{String,Symbol})

Removes `key_name` from the configuration file and saves changes.
"""
function config_rm(key_name::Union{String,Symbol})
    info("Removing \"$key_name => $(_config_load()[String(key_name)])\" from config file")
    _config_rm(String(key_name))
    return _config_load()
end