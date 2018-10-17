function _log_gen(mission_name::Symbol, obs_row::DataFrames.DataFrame)
    save_path = joinpath(obs_row[1, :obs_path], "JAXTAM/obs_log.json")

    base_dict = Dict(
        "mission_name" => mission_name,
        "obsid"        => obs_row[1, :obsid],
    )

    base_json = JSON.json(base_dict, 4)

    write(save_path, base_json)

    return base_dict
end

function _log_read(mission_name::Symbol, obs_row::DataFrames.DataFrame; print=false)
    save_path = joinpath(obs_row[1, :obs_path], "JAXTAM/obs_log.json")

    if isfile(save_path)
        obs_log = JSON.parsefile(save_path)
    else
        @info "Generating obs_log.json"
        obs_log = _log_gen(mission_name, obs_row)
    end

    if print
        _pretty_print_log(obs_log)
    end

    return obs_log
end

function _log_append_recursive(mission_name::Symbol, obs_row::DataFrames.DataFrame,
        obs_log::Dict, obs_log_new::Dict)

    for (k, v) in obs_log_new
        if typeof(v) <: Dict
            if haskey(obs_log, k)
                _log_append_recursive(mission_name, obs_row, obs_log[k], obs_log_new[k])
            else
                obs_log[k] = obs_log_new[k]
                return obs_log
            end
        else
            merge!(obs_log, obs_log_new)
            return obs_log
        end
    end
    
    return obs_log
end

function _pretty_print_log(d::Dict, pre=1)
    todo = Vector{Tuple}()
    for (k,v) in d
        if typeof(v) <: Dict
            push!(todo, (k,v))
        else
            println(join(fill(" ", pre)) * "$(repr(k)) => $(repr(v))")
        end
    end

    for (k,d) in todo
        s = "$(repr(k)) => "
        println(join(fill(" ", pre)) * s)
        _pretty_print_log(d, pre+1+length(s))
    end
    nothing
end

function _log_append(mission_name::Symbol, obs_row::DataFrames.DataFrame, obs_log_new::Dict; print=false)
    save_path = joinpath(obs_row[1, :obs_path], "JAXTAM/obs_log.json")
    
    obs_log = _log_read(mission_name, obs_row)

    obs_log = _log_append_recursive(mission_name, obs_row, obs_log, obs_log_new)
    
    obs_json = JSON.json(obs_log, 4)

    write(save_path, obs_json)

    if print
        _pretty_print_log(obs_log)
    end

    return obs_log
end