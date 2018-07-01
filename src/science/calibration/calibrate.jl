function _read_calibration_rmf(rmf_file::Union{String,Symbol}=:default)
    if typeof(rmf_file) == Symbol
        rmf_file = config(rmf_file).rmf
    elseif typeof(rmf_file) == String
        if !isfile(rmf_string)
            error("Not found: $rmf_string")
        end
    end

    return rmf_file
end