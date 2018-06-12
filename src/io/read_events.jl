function _read_fits_hdu(fits_file, hdu_id)
    fits_cols_events = FITSIO.colnames(fits_file[hdu_id])

    fits_hdu_data = DataFrame()

    for col in fits_cols_events
        try
            fits_col_data = read(fits_file[hdu_id], col)

            if ndims(fits_col_data) == 1
                fits_hdu_data[Symbol(col)] = fits_col_data
            end
        catch
            warn("$col not supported by FITSIO, skipped")
        end
    end

    return fits_hdu_data
end

function _read_fits_event(fits_path)
    info("Loading $fits_path")
    fits_file   = FITS(fits_path)

    fits_events_df = _read_fits_hdu(fits_file, 2)

    fits_gti_df = _read_fits_hdu(fits_file, 3)

    close(fits_file)

    return fits_events_df, fits_gti_df
end

function _save_fits_feather(feather_dir, instrument_name, fits_events_df, fits_gti_df)
    Feather.write(joinpath(feather_dir, "$instrument_name\_events.feather"), fits_events_df)
    Feather.write(joinpath(feather_dir, "$instrument_name\_gtis.feather"), fits_gti_df)
end

function process_fits_event(obsid)
end