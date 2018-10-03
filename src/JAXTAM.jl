__precompile__(false)

module JAXTAM

using DataFrames
using DelimitedFiles
using Dates
using FileIO
using JLD2
using FITSIO
using Arrow
using Feather
using DataStructures

using FFTW
using Statistics
using StatsBase
using OnlineStats
using DSP
using LinearAlgebra

using Hyperscript

using Measures
using Plots
gr()

abstract type JAXTAMData end

# @__DIR__ returns the location of this file
const __sourcedir__ = abspath(@__DIR__, "..")
const __configver__ = v"0.2.0"

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
include("science/gtis.jl")
include("science/fspec.jl")
include("science/pgram.jl")
include("science/plots.jl")
include("science/sgram.jl")
include("web/webgen.jl")
include("web/subgen.jl")

end
