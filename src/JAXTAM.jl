__precompile__(false)

module JAXTAM

using DataFrames
using DelimitedFiles
using Dates
using FileIO
using JSON
using JLD2
using FITSIO
using Arrow
using Feather
using DataStructures

using FFTW
using Statistics
using StatsBase
using OnlineStats
using LombScargle
using DSP
using LinearAlgebra

using Hyperscript

using Measures
using Plots
gr()

# Fix loading JLD2 files not finding types in workspace
export DataFrames
export Dates
export Arrow

abstract type JAXTAMData end

# @__DIR__ returns the location of this file
const __sourcedir__ = abspath(@__DIR__, "..")

include("missions/mission_dispatch.jl")
include("utils/logging.jl")
include("utils/errors.jl")
include("io/master_tables.jl")
include("io/master_query.jl")
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
include("science/espec.jl")
include("web/webgen.jl")
include("web/subgen.jl")
include("web/reports.jl")
include("web/autoreport.jl")

end
