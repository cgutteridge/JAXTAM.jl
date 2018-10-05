"""
    _build_append(master_df)

First step in creating append table, just returns the `obsid` column from
a missions master table
"""
function _build_append(master_df)
    return DataFrame(obsid=master_df[:obsid])
end

"""
    _add_append_publicity!(append_df, master_df)

Appends column of `Union{Bool,Missing}`, true if `public_date <=`now()`
"""
function _add_append_publicity!(append_df, master_df)
    append_publicity = Array{Union{Bool,Missing},1}(undef, size(append_df, 1))

    for (i, obsid) in enumerate(append_df[:obsid])
        append_publicity[i] = now() > convert(DateTime, master_df[i, :public_date])
    end

    return append_df[:publicity] = append_publicity
end

"""
    _add_append_obspath!(append_df, master_df, mission_name)

Appends column of `Union{String,Missing}`, with the **local** path to the observation
"""
function _add_append_obspath!(append_df, master_df, mission_name)
    obs_path_function = config(mission_name).path_obs
    mission_path = config(mission_name).path
    append_obspath = Array{Union{String,Missing},1}(undef, size(append_df, 1))

    for (i, obsid) in enumerate(append_df[:obsid])
        append_obspath[i] = abspath(string(mission_path, _clean_path_dots(obs_path_function(master_df[i, :]))))
    end

    return append_df[:obs_path] = append_obspath
end

"""
    _add_append_uf!(append_df, master_df, mission_name)

Appends column of Union{Tuple{String},Missing}, tuple of local paths to the uf files
"""
function _add_append_uf!(append_df, master_df, mission_name)
    append_uf = Array{Union{Tuple,Missing},1}(undef, size(append_df, 1))
    root_dir  = config(mission_name).path
    uf_path_function = config(mission_name).path_uf

    for (i, obsid) in enumerate(append_df[:obsid])
        append_uf[i] = uf_path_function(master_df[i, :], root_dir)
    end

    return append_df[:event_uf] = append_uf
end

"""
    _add_append_cl!(append_df, master_df, mission_name)

Appends column of `Union{Tuple{String},Missing}`, tuple of local paths to the cl files
"""
function _add_append_cl!(append_df, master_df, mission_name)
    append_cl = Array{Union{Tuple,Missing},1}(undef, size(append_df, 1))
    root_dir  = config(mission_name).path
    cl_path_function = config(mission_name).path_cl

    for (i, obsid) in enumerate(append_df[:obsid])
        append_cl[i] = cl_path_function(master_df[i, :], root_dir)
    end

    return append_df[:event_cl] = append_cl
end

"""
    _add_append_downloaded!(append_df, mission_name)

Appends column of `Union{Bool,Missing}`, true if all cl files exist
"""
function _add_append_downloaded!(append_df, mission_name)
    append_downloaded = Array{Union{Bool,Missing},1}(undef, size(append_df, 1))
    root_dir  = config(mission_name).path

    for (i, obspath) in enumerate(append_df[:obs_path])
        cl_files    = append_df[i, :event_cl]
        cl_files_gz = string.(append_df[i, :event_cl], ".gz")
        if all(isfile.(cl_files)) || all(isfile.(cl_files_gz))
            append_downloaded[i] = true
        else
            append_downloaded[i] = false
        end
    end

    return append_df[:downloaded] = append_downloaded
end

"""
    _add_append_analysed!(append_df, mission_name)

Appends column of `Union{Bool,Missing}`, true if the `JAXTAM` directory exists

TODO: Improve this function, currently an empty `JAXTAM` folder means it has been analysed
"""
function _add_append_analysed!(append_df, mission_name)
    append_analysed = Array{Union{Bool,Missing},1}(undef, size(append_df, 1))

    for (i, obspath) in enumerate(append_df[:obs_path])
        append_analysed[i] = isdir(joinpath(obspath, "JAXTAM"))
    end

    return append_df[:analysed] = append_analysed
end

"""
    _add_append_results!(append_df, mission_name)

Appends column of `String`, if the `results.html` file exists for an observation
the path to the file is returned, otherwise "NA" is returned
"""
function _add_append_results!(append_df, mission_name)
    append_resultspath = Array{String,1}(undef, size(append_df, 1))

    path_obs = config(mission_name).path
    path_web = config(mission_name).path_web

    for (i, obspath) in enumerate(append_df[:obs_path])
        results_page_dir = replace(obspath, path_obs => path_web)
        results_page_path = joinpath(results_page_dir, "result.html")
        if isfile(results_page_path)
            append_resultspath[i] = replace(results_page_path, path_web => "./")
        else
            append_resultspath[i] = "NA"
        end
        
    end

    return append_df[:results_path] = append_resultspath
end

"""
    _append_gen(mission_name, master_df)

Runs all the `_add_append` functions, returns the full `append_df`
"""
function _append_gen(mission_name, master_df)
    append_df = _build_append(master_df)

    _add_append_publicity!(append_df, master_df)
    _add_append_obspath!(append_df, master_df, mission_name)
    _add_append_uf!(append_df, master_df, mission_name)
    _add_append_cl!(append_df, master_df, mission_name)
    _add_append_downloaded!(append_df, mission_name)
    _add_append_analysed!(append_df, mission_name)
    _add_append_results!(append_df, mission_name)

    return append_df
end

"""
    _tuple2feather(append_df::DataFrames.DataFrame)

`Feather.jl`, and probably Feather files in general, can't save Tuples, this
function selects and columns in the `DataFrame` of type `Tuple`, then it splits
the tuples up into a `DataFrame`, with column names of the original column name
with `__tuple__\$col\$i` appended to the end

Only works if all the tuples in a column are of the same length

TODO: Make edge cases of tuples with over 9 elements work, test methods to allow
tuples of different lengths to be split and saved as well
"""
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

"""
    _feather2tuple(append_df::DataFrames.DataFrame)

Function that takes in a `DataFrame` which has been run through `_tuple2feather()`
and joins the split tuples together
"""
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

"""
    _append_gen(mission_name)

Generates the append file for a mission
"""
function _append_gen(mission_name)
    master_df = master(mission_name)
    append_df = _append_gen(mission_name, master_df)

    return append_df
end

"""
    _append_save(append_path_feather, append_df)

Runs `_tuple2feather()` on `append_df` then saves to the save path
"""
function _append_save(append_path_feather, append_df)
    append_df = _tuple2feather(append_df)

    Feather.write(append_path_feather, append_df)
end

"""
    _append_load(append_path_feather)

Loads a saved `append_df`, runs `_feather2tuple()` and returns the `DataFrame`
"""
function _append_load(append_path_feather)
    append_df = Feather.read(append_path_feather)
    
    return _feather2tuple(append_df)
end

"""
    append(mission_name)

If no append file exists, crates one using the `_append_gen()` function, then
saves the file with `_append_save()`

If the append file exists, loads via `_append_load()`
"""
function append(mission_name)
    append_path_feather = abspath(string(_config_key_value(mission_name).path, "append.feather"))

    if isfile(append_path_feather)
        @info "Loading $append_path_feather"
        return _append_load(append_path_feather)
    else
        master_df = master(mission_name)
        append_df = _append_gen(mission_name, master_df)
        @info "Saving $append_path_feather"
        _append_save(append_path_feather, append_df)
        return append_df
    end
end

"""
    append()

Calld `append(mission_name)` with the default mission `config_dict[:default]` if one exists
"""
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

"""
    append_update(mission_name)

Re-generates the append file
"""
function append_update(mission_name)
    append_path_feather = abspath(string(_config_key_value(mission_name).path, "append.feather"))

    master_df  = master(mission_name)
    old_append = append(mission_name)
    
    append_df  = _append_gen(mission_name, master_df)
    if haskey(old_append, :countrate)
        @warn "append_update does not update countrates, run append_countrate if required"
        old_countrate = old_append[:countrate]
        append_df[:countrate] = old_countrate
    end

    @info "Saving $append_path_feather"
    _append_save(append_path_feather, append_df)
    return append_df
end

function _add_append_countrate!(append_df, mission_name)
    if !haskey(append_df, :countrate) # If countrate col exists, don't make a new one with 0's
        append_countrate = zeros(size(append_df, 1))
        append_df[:countrate] = append_countrate
    end

    downloaded = filter(x->x[:downloaded], append_df)

    for i in 1:size(append_df,1)
        obs_row = view(append_df, i, :) # Use view to mutate dataframe in-place
        if !obs_row[1, :downloaded] # Skip not-downloaded data
            continue
        end

        if obs_row[1, :countrate] == 0.0
            data = try
                JAXTAM.calibrate(mission_name, obs_row[:]) # Require `obs_row[:]` to pass DataFrame not SubDataFrame
            catch e
                if occursin("error uncompressing image", e.msg)
                    @warn "FITS could not be uncompressed"
                    continue
                else
                    throw(e)
                end
            end
            instruments = keys(data)

            countrate = 0.0
            for instrument in instruments
                gtis = data[instrument].gtis

                total_gti_time    = sum(gtis[:STOP] .- gtis[:START])
                total_event_count = size(data[instrument].events, 1)
                countrate        += total_event_count/total_gti_time
            end
            countrate = countrate/length(instruments) # Average count rate over instruments

            print(" - Countrate $countrate")

            obs_row[:countrate] = countrate
        end
    end

    return append_df
end

function append_countrate(mission_name)
    append_path_feather = abspath(string(_config_key_value(mission_name).path, "append.feather"))

    append_df = append_update(mission_name)

    append_df = _add_append_countrate!(append_df, mission_name)

    @info "Saving $append_path_feather"
    _append_save(append_path_feather, append_df)

    return append_df
end

"""
    master_a(mission_name)

Joins the `master_df` (raw, unedited HEASARC master table) and the `append_df`
`DataFrame`s together on `:obsid`, returns the joined tables
"""
function master_a(mission_name)
    master_df = master(mission_name)
    append_df = append(mission_name)

    return join(master_df, append_df, on=:obsid)
end