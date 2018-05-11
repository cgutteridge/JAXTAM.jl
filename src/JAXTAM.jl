#__precompile__() # Disable during dev

module JAXTAM

using DataFrames
using FileIO
using CSVFiles
using JLD2
using Query

include("io/user_config.jl")
include("io/master_tables.jl")

end
