"""
    unzip!(path)

Unzip function, using the bundled `7z.exe` for Windows, and `p7zip-full` for is_linux

Used to unzip the mastertables after download from HEASARC
"""
function unzip!(path)
    dir  = dirname(path)

    if Sys.iswindows()
        zip7 = string(Sys.BINDIR, "\\7z.exe")
        run(`$zip7 e $path -o$dir`)
    elseif Sys.islinux()
        try
            run(`7z e $path -o$dir`) # Assumes `p7zip-full` is installed
        catch error
            @warn "Is p7zip-full installed?"
            error(error)
        end
    end

    filename = split(basename(path), ".")[1]

    if isfile(path)
        rm(path)
        mv(string(dir, "/", filename), path)
    end
end

"""
    _datetime2mjd(human_time::Dates.DateTime)

Converts (human-readable) `DataTime` to MJD (Julian - 2400000.5) time
"""
function _datetime2mjd(human_time::Dates.DateTime)
    return Dates.datetime2julian(human_time) - 2400000.5
end

"""
    _mjd2datetime(mjd_time::Number)

Converts MJD (Julian - 2400000.5) time to (human-readable) `DataTime`
"""
function _mjd2datetime(mjd_time::Number)
    return Dates.julian2datetime(mjd_time + 2400000.5)
end

"""
    _mjd2datetime(mjd_time::Nothing)

Returns `missing` if the `mjd_time` is `Nothing`
"""
function _mjd2datetime(mjd_time::Nothing)
    return missing
end