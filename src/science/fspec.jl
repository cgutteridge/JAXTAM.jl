struct FFTData
    mission::Symbol
    instrument::Symbol
    obsid::String
    bin_time::Real
    bin_size::Int
    gti_index::Int
    gti_start_time::Real
    amps::Array
    freqs::Array
end

function _FFTData(gti, freqs, amps, fspec_bin_size)

    return FFTData(gti.mission, gti.instrument, gti.obsid, gti.bin_time, fspec_bin_size,
        gti.gti_index, gti.gti_start_time, amps, freqs)
end

function _fft(counts::SparseVector{Int64,Int64}, times::StepRangeLen, bin_time::Real, fspec_bin_size; leahy=true)
    FFTW.set_num_threads(4)

    spec_no = Int(floor(length(counts)/fspec_bin_size))

    counts = counts[1:Int(spec_no*fspec_bin_size)]
    counts = reshape(counts, spec_no, fspec_bin_size)

    amps = abs.(rfft(counts, 2))
    freqs = Array(rfftfreq(fspec_bin_size, 1/bin_time))

    amps[:, 1] = 0 # Zero the 0Hz amplitude

    if leahy
        amps = (2.*(amps.^2)) ./ sum(counts, 2)
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

function fspec(mission_name::Symbol, gtis::Dict{Symbol,Dict{Int64,JAXTAM.GTIData}}, fspec_bin::Real; pow2=true, fspec_bin_type=:time)
    instruments = config(mission_name).instruments

    powspecs = Dict{Symbol,Any}()

    for instrument in instruments
        powspec = Dict{Int,Any}()

        first_gti = gtis[Symbol(instrument)][collect(keys(gtis[Symbol(instrument)]))[1]]

        if fspec_bin_type == :time
            fspec_bin_size = Int(fspec_bin/first_gti.bin_time)
        elseif fspec_bin_type == :length
            fspec_bin_size = Int(fspec_bin)
        end
        
        if !ispow2(fspec_bin_size)
            warn("fspec_bin_size not pow2: $fspec_bin_size, fspec_bin = $fspec_bin ($(1/fspec_bin)), bin_time: $(gti.bin_time) ($(1/gti.bin_time)")
        end

        for gti in values(gtis[Symbol(instrument)])
            if length(gti.counts) < fspec_bin_size
                warn(("Skipped gti $(gti.gti_index) as it is under the fspec_bin_size of $fspec_bin_size"))
                continue
            end

            freqs, amps = _fft(gti.counts, gti.times, gti.bin_time, fspec_bin_size)

            powspec[gti.gti_index] = _FFTData(gti, freqs, amps, fspec_bin_size)
        end

        powspecs[Symbol(instrument)] = powspec
    end

    return powspecs
end