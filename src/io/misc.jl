function unzip!(path)
    dir  = dirname(path)

    if Sys.is_windows()
        zip7 = string(Sys.BINDIR, "\\7z.exe")
        run(`$zip7 e $path -o$dir`)
    elseif Sys.is_linux()
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

function _datetime2mjd(human_time::Dates.DateTime)
    return Dates.datetime2julian(human_time) - 2400000.5
end

function _mjd2datetime(mjd_time::Number)
    return Dates.julian2datetime(mjd_time + 2400000.5)
end

function _mjd2datetime(mjd_time::Nothing)
    return missing
end