struct PgramData
    mission    :: Symbol
    instrument :: Symbol
    obsid      :: String
    bin_time   :: Real
    pg_type    :: Symbol
    powers     :: Array
    freqs      :: Array
    group      :: Int
end

function _pgram(counts, bin_time, pg_type=:Scargle)
    pg_plan = LombScargle.plan(1:length(counts), float(counts), 
        normalization=pg_type, maximum_frequency=0.5/bin_time)

    pg = lombscargle(pg_plan)

    freqs, powers = freqpower(pg)

    return freqs, powers
end

function _pgram(lc::BinnedData, pg_type, group)
    freqs, powers = _pgram(lc.counts, lc.bin_time, pg_type)

    return PgramData(lc.mission, lc.instrument, lc.obsid, lc.bin_time,
        pg_type, powers, freqs, group)
end

function _pgram_lc_group_pad(group_lc::Dict{Int64,JAXTAM.BinnedData})
    groups = keys(group_lc)
    longest_group = maximum([length(x.counts) for x in values(group_lc)])

    padded_groups = Dict{Int64,JAXTAM.BinnedData}()

    for group in groups
        mission    = group_lc[group].mission
        instrument = group_lc[group].instrument
        obsid      = group_lc[group].obsid
        bin_time   = group_lc[group].bin_time
        counts     = group_lc[group].counts
        times      = group_lc[group].times
        gtis       = group_lc[group].gtis

        if length(counts) < longest_group
            counts = [counts; zeros(longest_group-length(counts))]
        end

        padded_groups[group] = BinnedData(mission, instrument, obsid, bin_time, counts, times, gtis)
    end

    return padded_groups
end

function pgram(instrument_lc::Dict{Symbol,BinnedData}; pg_type=:Scargle, per_group=false)
    instruments = keys(instrument_lc)

    instrument_pgram = per_group ? Dict{Symbol,Dict{Int,PgramData}}() : Dict{Symbol,PgramData}()
    for instrument in instruments
        if per_group
            group_pgram = Dict{Int,PgramData}()

            lc_groups = _group_return(instrument_lc[instrument])
            #lc_groups = _pgram_lc_group_pad(lc_groups)
            groups = keys(lc_groups)

            for group in groups
                group_pgram[group] = _pgram(lc_groups[group], pg_type, group)
            end

            #group_pgram[-1] = PgramData(group_pgram[1].mission, group_pgram[1].instrument, group_pgram[1].obsid,
            #    group_pgram[1].bin_time, pg_type, mean([pgram.powers for pgram in values(group_pgram)]), group_pgram[1].freqs, -1)

            instrument_pgram[instrument] = group_pgram
        else
            instrument_pgram[instrument] = _pgram(instrument_lc[instrument], pg_type, 0)
        end
    end
    
    return instrument_pgram
end