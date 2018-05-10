#__precompile__() # Disable during dev

module JAXTAM

using DataFrames
using FileIO
using CSVFiles
using JLD2
using Query

# string("C:/Users/Robert/Desktop/temp_nicer/heasarc_nicermastr.csv")

include("io/master_tables.jl")
include("io/configmanage.jl")


end
