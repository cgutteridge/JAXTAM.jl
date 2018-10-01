# IO Operations

```@autodocs
Modules = [JAXTAM]
Pages   = [
    "user_config.jl",
    "master_tables.jl",
    "master_append.jl",
    "data_download.jl",
    "misc.jl"
]
Order   = [:function, :type]
```

### Mission Definitions

A mutable struct is used for the mission definition:

```@example
mutable struct MissionDefinition
    name            ::String
    url             ::String
    path            ::String
    path_obs        ::Function
    path_cl         ::Function
    path_uf         ::Function
    path_rmf        ::String
    path_web        ::String
    good_energy_max ::Number
    good_energy_min ::Number
    instruments     ::Array
end
```

`name` simply defines the mission name.

`url` contains the url to the HEASARC mastertable.

`path` contains the local path to the main mission folder.

`path_obs`, `path_cl`, and `path_uf` are three functions, which take in a row from a master table, and return the HEASARC server-sice path to the pbservation, cleaned files, and unfiltered files.

`path_rmf` is a local path to the mission RMF files in caldb.

`path_web` is the local path to the folder where the report pages will be saved.

`good_energy_max` and `good_energy_min` are the energies the instrument has been rated for.

`instruments` is an array of symbols of instrument names.