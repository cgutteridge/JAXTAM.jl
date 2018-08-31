struct PgramData
    mission    :: Symbol
    instrument :: Symbol
    obsid      :: String
    bin_time   :: Real
    pg_type    :: Symbol
    powers     :: Array
    freqs      :: Array
end

function _pgram(counts, bin_time, pg_type=:mt)
    if pg_type == :mt
        pg_result = mt_pgram(counts, fs=1/bin_time)
    elseif pg_type == :pgram
        pg_result = periodogram(counts, fs=1/bin_time)
    elseif pg_type == :welch
        pg_result = welch_pgram(counts, fs=1/bin_time)
    end

    freqs, powers = pg_result.freq, pg_result.power

    return freqs, powers
end

function _pgram(lc::BinnedData, pg_type)
    freqs, powers = _pgram(lc.counts, lc.bin_time, pg_type)

    return PgramData(lc.mission, lc.instrument, lc.obsid, lc.bin_time,
        pg_type, powers, freqs)
end

function _pgram_lc_orbit_pad(orbit_lc::Dict{Int64,JAXTAM.BinnedData})
    orbits = keys(orbit_lc)
    longest_orbit = maximum([length(x.counts) for x in values(orbit_lc)])

    padded_orbits = Dict{Int64,JAXTAM.BinnedData}()

    for orbit in orbits
        mission    = orbit_lc[orbit].mission
        instrument = orbit_lc[orbit].instrument
        obsid      = orbit_lc[orbit].obsid
        bin_time   = orbit_lc[orbit].bin_time
        counts     = orbit_lc[orbit].counts
        times      = orbit_lc[orbit].times
        gtis       = orbit_lc[orbit].gtis

        if length(counts) < longest_orbit
            counts = [counts; zeros(longest_orbit-length(counts))]
        end

        padded_orbits[orbit] = BinnedData(mission, instrument, obsid, bin_time, counts, times, gtis)
    end

    return padded_orbits
end

function pgram(instrument_lc::Dict{Symbol,BinnedData}; pg_type=:pgram, per_orbit=false)
    instruments = keys(instrument_lc)

    instrument_pgram = per_orbit ? Dict{Symbol,Dict{Int,PgramData}}() : Dict{Symbol,PgramData}()
    for instrument in instruments
        if per_orbit
            orbit_pgram = Dict{Int,PgramData}()

            lc_orbits = _orbit_return(instrument_lc[instrument])
            lc_orbits = _pgram_lc_orbit_pad(lc_orbits)
            orbits = keys(lc_orbits)

            for orbit in orbits
                orbit_pgram[orbit] = _pgram(lc_orbits[orbit], pg_type)
            end

            orbit_pgram[-1] = PgramData(orbit_pgram[1].mission, orbit_pgram[1].instrument, orbit_pgram[1].obsid,
                orbit_pgram[1].bin_time, pg_type, mean([pgram.powers for pgram in values(orbit_pgram)]), orbit_pgram[1].freqs)

            instrument_pgram[instrument] = orbit_pgram
        else
            instrument_pgram[instrument] = _pgram(instrument_lc[instrument], pg_type)
        end
    end
    
    return instrument_pgram
end