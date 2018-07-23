struct FFTData
    mission::Symbol
    instrument::Symbol
    obsid::String
    bin_time::Real
    gti_index::Int
    gti_start_time::Real
    amps::Array
    freqs::Array
end

function _FFTData(gti, freqs, amps)

    return FFTData(gti.mission, gti.instrument, gti.obsid, gti.bin_time,
        gti.gti_index, gti.gti_start_time, amps, freqs)
end

function _fft(counts::Array{Int64,1}, times::Array, bin_time::Real; leahy=true)
    FFTW.set_num_threads(4)

    amps = abs.(rfft(counts))
    freqs = Array(rfftfreq(length(times), 1/bin_time))

    amps[1] = 0 # Zero the 0Hz amplitude

    if leahy
        amps = (2.*(amps.^2)) ./ sum(counts)
    end

    return freqs, amps
end

function _best_gti_pow2(gtis::Dict{Int64,JAXTAM.GTIData})
    gti_pow2s = [prevpow2(length(gti[2].counts)) for gti in gtis]
    min_pow2  = Int(median(gti_pow2s))
    exclude   = gti_pow2s .< min_pow2
    
    instrument = gtis[collect(keys(gtis))[1]].instrument


    info("$instrument median pow2 length is $min_pow2, excluded $(count(exclude)) gtis, ", 
        "$(length(gti_pow2s) - count(exclude)) remain")

    good_gtis = [gti for gti in gtis][.!exclude]

    return Dict(good_gtis)
end

function gtis_pow2(mission_name::Symbol, gtis::Dict{Symbol,Dict{Int64,JAXTAM.GTIData}})
    instruments = config(mission_name).instruments

    gtis_pow2 = Dict{Symbol,Dict{Int64,JAXTAM.GTIData}}()

    for instrument in instruments
        gtis_pow2[Symbol(instrument)] = _best_gti_pow2(gtis[Symbol(instrument)])
    end

    return gtis_pow2
end

function fspec(mission_name::Symbol, gtis::Dict{Symbol,Dict{Int64,JAXTAM.GTIData}})
    instruments = config(mission_name).instruments

    powspecs = Dict{Symbol,Any}()

    for instrument in instruments
        gti_ps = Dict{Int,Any}()
        for gti in values(gtis[Symbol(instrument)])
            freqs, amps = _fft(gti.counts, gti.times, gti.bin_time)
            gti_ps[gti.gti_index] = _FFTData(gti, freqs, amps)
        end

        powspecs[Symbol(instrument)] = gti_ps
    end

    return powspecs
end