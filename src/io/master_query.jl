
"""
    master_query(master_df::DataFrame, key_type::Symbol, key_value::Any)

Wrapper for a query, takes in an already loaded DataFrame `master_df`, a `key_type` to
search over (e.g. `obsid`), and a `key_value` to find (e.g. `0123456789`)

Returns the full row for any observations matching the search criteria

TODO: Fix the DataValue bug properly
"""
function master_query(master_df::DataFrame, key_type::Symbol, key_value::Any)
    observations = filter(row -> row[key_type] == key_value, master_df)

    if size(observations, 1) == 0
        @warn "master_query returned no results for $key_type with $key_value search"
    end

    # Some DataFrames update changed the types of data to DataValue
    # screws with functions later on which convert the values to strings
    # use get here to get them out of the DataValue type, wrapped in try
    # for any cases where these columns don't exist in the master dataframe
    # try; observations[:obsid] = get(observations[:obsid][1]); catch; end
    # try; observations[:time] = get(observations[:time][1]); catch; end

    if size(observations, 1) == 1
        # Return DataFrameRow for single observation result
        observations = observations[1, :]
    end

    return observations
end

function master_query(mission::Mission, key_type::Symbol, key_value::Any)
    return master_query(master(mission), key_type, key_value)
end

"""
    _public_date_int(public_date)

Converts the public date to an integer, if that fails just returns the
arbitrary sort-of-far-away `2e10` date

TODO: Don't return 2e10 on Float64 parse error
"""
function _public_date_int(public_date)
    public_date = get(public_date)
    try
        return parse(Float64, public_date)
    catch
        return 2e10
    end
end

# """
#     master_query_public(master_df::DataFrame, key_type::Symbol, key_value::Any)

# Calls `master_query` for given query, but restricted to currently public observations
# """
# function master_query_public(master_df::DataFrame, key_type::Symbol, key_value::Any)
#     observations = filter(row -> row[key_type] == key_value, master_df)
#     observations = filter(row -> convert(DateTime, row[:public_date]) < now(), observations)
    
#     if size(observations, 1) == 0
#         @warn "master_query_public returned no results for $key_type with $key_value search"
#     end

#     return observations
# end

# """
#     master_query_public(mission_name::Symbol, key_type::Symbol, key_value::Any)

# Loads mission master table, then calls
# `master_query_public(master_df::DataFrame, key_type::Symbol, key_value::Any)`
# """
# function master_query_public(mission_name::Symbol, key_type::Symbol, key_value::Any)
#     master_df = master_a(mission_name)

#     return master_query_public(master_df, key_type, key_value)
# end

# """
#     master_query_public(master_df::DataFrame)

# Returns all the currently public observations in `master_df`
# """
# function master_query_public(master_df::DataFrame)
#     observations = filter(row -> convert(DateTime, row[:public_date]) < now(), master_df)

#     return observations
# end

# """
#     master_query_public(mission_name::Symbol)

# Loads master table for `mission_name`, calls `master_query_public(master_df::DataFrame)`
# returning all currently public observations
# """
# function master_query_public(mission_name::Symbol)
#     master_df = master_a(mission_name)

#     return master_query_public(master_df)
# end