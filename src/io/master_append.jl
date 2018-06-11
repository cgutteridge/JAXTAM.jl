function _build_append(master_df)
    return DataFrame(obsid=master_df[:obsid])
end

function _add_append(append_df, master_df, key_name, key_function)
    new_append = Array{Any,1}(size(append_df, 1))

    for (i, obsid) in enumerate(append_df[:obsid])
        new_append[i] = key_function(master_df, obsid)
    end

    append_df[Symbol(key_name)] = new_append

    return append_df
end

function _currently_public(obs_row)
    if _datetime2mjd(now()) > parse(obs_row[1, :public_date])
        return 0
    else
        return 1
    end
end

function _generic_append(append_df, master_df)
    obs_count  = size(master_df, 1)

    public     = Array{Int,1}(obs_count)
    downloaded = Array{Int,1}(obs_count)
    cleaned    = Array{Int,1}(obs_count)
    analysed   = Array{Int,1}(obs_count)
end