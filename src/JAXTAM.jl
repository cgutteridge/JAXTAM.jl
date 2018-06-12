#__precompile__() # Disable during dev

module JAXTAM

using DataFrames
using FileIO
using CSVFiles
using JLD
using Query
using FTPClient
using LightXML
using Compat
using FITSIO
using Feather

include("missions/mission_control.jl")
include("missions/default_missions.jl")
include("io/user_config.jl")
include("io/master_tables.jl")
include("io/master_append.jl")
include("io/misc.jl")
include("io/data_download.jl")
include("io/read_events.jl")

end
