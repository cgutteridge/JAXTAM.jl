function _log_entry(; kwargs...)
    template = OrderedDict(
        :category     => String,
        :e_range      => Union{String,Missing},
        :bin_time     => Union{String,Missing},
        :bin_size_sec => Union{Real,Missing},
        :kind         => Symbol,
        :kind_order   => Union{Int,Missing},
        :value        => Union{Any,Missing},
        :group        => Union{Int,Missing},
        :file_name    => Union{String,Missing},
        :path         => Union{String,Missing},
        :notes        => Union{String,Missing},
    )

    kind_order = Dict{Symbol,Int}(
        :lcurve => 1,
        :pgram  => 2,
        :fspec  => 3,
        :sgram  => 4,
        :pulsec => 5,
        :espec  => 6,
        :DELETE => 0,
    )

    t = Array{Type,1}(collect(values(template)))
    n = collect(keys(template))

    log_entry = DataFrame(t, n, 1)
    for col in names(log_entry)
        if haskey(kwargs, col)
            if col == :e_range
                v = "$(kwargs[:e_range][1])_$(kwargs[:e_range][2])"
            elseif col == :bin_time
                v = "2e$(Int(log2(kwargs[:bin_time])))"
            elseif col == :file_name
                if haskey(kwargs, :group)
                    v = string("groups/", kwargs[:group], "_", kwargs[:file_name])
                else
                    v = kwargs[:file_name]
                end
            else
                v = kwargs[col]
            end

            log_entry[col] = v
        elseif col == :kind_order
            log_entry[:kind_order] = kind_order[kwargs[:kind]]
        else
            log_entry[col] = missing
        end
    end

    if !haskey(kwargs, :path) && haskey(kwargs, :file_name)
        path = "./"
        [path=joinpath(path, string(v)) for (k, v) in zip(names(log_entry), convert(Array, log_entry)) if !in(k, [:kind_order, :value, :group, :path, :notes]) && !ismissing(v)]
        log_entry[:path] = path
    end

    return log_entry
end

function _log_gen(mission_name::Symbol, obs_row::DataFrames.DataFrame)
    path = joinpath(obs_row[1, :obs_path], "JAXTAM/obs_log.jld2")

    if !ispath(path)
        mkpath(dirname(path))
    end

    meta_info = Dict{Any,Any}(
        :obs_row => obs_row
    )

    save(path, Dict{Any,Any}("meta"=>meta_info))
end

function _log_read(mission_name::Symbol, obs_row::DataFrames.DataFrame)
    path = joinpath(obs_row[1, :obs_path], "JAXTAM/obs_log.jld2")

    if !isfile(path)
        _log_gen(mission_name, obs_row)
    end

    Dict{Any,Any}(load(path))
end

function _log_add(mission_name::Symbol, obs_row::DataFrames.DataFrame, category::String, entry::Pair{Symbol,T}) where T<:Any
    path = joinpath(obs_row[1, :obs_path], "JAXTAM/obs_log.jld2")

    log = _log_read(mission_name, obs_row)

    log_cat = log[category]

    if haskey(log_cat, entry[1])
        @warn "Overwriting log entry for $category => $(entry[1])"
    end

    log_cat[entry[1]] = entry[2]

    save(path, log)

    return log
end

function _log_add_recursive(mission_name::Symbol, obs_row::DataFrames.DataFrame,
    log::Dict, entry::Dict)

    for (k, v) in entry
        if typeof(v) <: Dict
            if haskey(log, k)
                _log_add_recursive(mission_name, obs_row, log[k], entry[k])
            else
                log[k] = entry[k]
                return log
            end
        else
            template_log = _log_entry(; category="DELETE", kind=:DELETE)
            deleterows!(template_log, 1)

            append!(template_log, log[k])
            append!(template_log, entry[k])
            unique!(template_log)    
            log[k] = template_log
            return log
        end
    end

    return log
end

function _log_add(mission_name::Symbol, obs_row::DataFrames.DataFrame, entry::Dict)
    log = _log_read(mission_name, obs_row)

    log_new = _log_add_recursive(mission_name, obs_row, log, entry)
    save(joinpath(obs_row[1, :obs_path], "JAXTAM/obs_log.jld2"), log_new)
    return log_new
end

function _log_add(mission_name::Symbol, obs_row::DataFrames.DataFrame, category::String=""; kwargs...)
    log_cat_entry = _log_entry(; kwargs...)

    log = _log_add(mission_name, obs_row, category; kwargs...)

    return log
end