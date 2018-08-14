__precompile__(false)

module JAXTAM

using DataFrames
using FileIO
using CSVFiles
using JLD2
using Compat
using FITSIO
using Feather
using StatsBase
using DSP
using Plots
gr()

abstract type JAXTAMData end

include("missions/mission_control.jl")
include("missions/default_missions.jl")
include("io/user_config.jl")
include("io/master_tables.jl")
include("io/master_append.jl")
include("io/misc.jl")
include("io/data_download.jl")
include("science/read_events.jl")
include("science/calibrate.jl")
include("science/lcurve.jl")
include("science/fspec.jl")
include("science/plots.jl")
#include("web/webgen.jl")
#include("web/subgen.jl")

end
