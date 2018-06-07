#__precompile__() # Disable during dev

module JAXTAM

using DataFrames
using FileIO
using CSVFiles
using JLD
using Query

include("io/user_config.jl")
include("io/master_tables.jl")

end
