# JAXTAM.jl

JAXTAM is Just Another X-ray Timing Analysis Module. The main aim of the project was to create an easy to use, friendly interface for basic at-a-glance timing analysis, to be used on data from missions adhering to the FITS file standard.

## Contents

```@contents
Pages = [
    "index.md",
    "man/io.md",
    "man/missions.md",
    "man/science.md"
]
```

## Introduction

Basic analysis can be performed from the Julia REPL, however the final product of JAXTAM is an automatically generated results page, containing some basic plots used in X-ray timing analysis, the default setup generates the following plots: lightcurves, Leahy normalised power spectra, periodograms, and spectrograms.

!!! note

    Currently, JAXTAM is set up to work with HEASARC missions, which have a mastertable available on the HEASARC servers. NICER is supported natively, and full NuSTAR support is coming (REPL plotting works, however functionality for saving/generating reports when two instruments are present hasn't been implemented yet).

# Basic Usage Guide

## Config Setup

JAXTAM handles everything from downloading the observation data from HEASARC servers, to performing timing analysis, plotting, generating a searchable summary page, and finally generating individual report pages for each observation.

The first step is setting up a configuration file, which tells JAXTAM how to handle each mission individually. NICER and NuSTAR mission definitions are included by default, however setting up a custom mission is relatively easy. [`_get_default_missions`](@ref)

To set up the configuration for one of the included default missions (NICER or NuSTAR) you must provide only the path to the directory used to store the mission data:

```julia
julia> JAXTAM.config(:nicer, "/example/path/to/nicer/")
┌ Info: nicer found in defaults
└ Using /example/path/to/nicer/ as path
[ Info: Creating config file at: /home/user/Projects/JAXTAM/user_configs.jld2
Dict{Any,Any} with 2 entries:
  :nicer           => MissionDefinition("nicer", "https://heasarc.gsfc.nasa.gov/FTP/heasarc/dbase/tdat_files/heasarc_nicermastr.tdat…
  :_config_version => v"0.2.0"
```

This will automatically fill in all the information required for a complete `MissionDefinition` type. For the above example, this saves:

```julia
julia> JAXTAM.config(:nicer)
JAXTAM.MissionDefinition(
        "nicer",
        "https://heasarc.gsfc.nasa.gov/FTP/heasarc/dbase/tdat_files/heasarc_nicermastr.tdat.gz",
        "/example/path/to/nicer/",
        JAXTAM._nicer_observation_dir,
        JAXTAM._nicer_cl_files,
        JAXTAM._nicer_uf_files,
        "/home/user/Software/caldb/data/nicer/xti/cpf/rmf/nixtiref20170601v001.rmf",
        "/example/path/to/nicer/web/",
        0.3,
        12,
        ["XTI"]
    )
```

More can be read about `MissionDefinition` at: [`MissionDefinition`](@ref).

## Master Table Setup

Once the configuration has been set up for a mission, the next step is running the setup for the master DataFrame, which contains information on each observation for the mission and is pulled from a HEASARC master table url (the second field in the `MissionDefinition`).

To do this simply run `JAXTAM.master(:mission_name)`:

```julia
julia> JAXTAM.master(:nicer)
┌ Warning: No master file found, looked for: 
│       /example/path/to/nicer/master.tdat 
│       /example/path/to/nicer/master.feather
└ @ JAXTAM ~/Projects/JAXTAM/src/io/master_tables.jl:171
[ Info: Download master files from `https://heasarc.gsfc.nasa.gov/FTP/heasarc/dbase/tdat_files/heasarc_nicermastr.tdat.gz`? (y/n)
y
[ Info: Downloading latest master catalog
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  450k  100  450k    0     0   121k      0  0:00:03  0:00:03 --:--:--  121k

7-Zip [64] 9.20  Copyright (c) 1999-2010 Igor Pavlov  2010-11-18
p7zip Version 9.20 (locale=en_GB.UTF-8,Utf16=on,HugeFiles=on,8 CPUs)

Processing archive: /example/path/to/nicer/aster.tdat

Extracting  master

Everything is Ok

Size:       3427684
Compressed: 461261
[ Info: Loading /example/path/to/nicer/aster.tdat
[ Info: Saving /example/path/to/nicer/aster.feather
```

This will download, unzip, and parse the `.tdat` master file. To update, simply run `JAXTAM.master_update(:mission_name)`. Some warnings are to be expected, but have been removed from the above example.

A secondary table is also required, which can be generated with:

```julia
julia> JAXTAM.append(:nicer)
[ Info: Loading /example/path/to/nicer/master.feather
[ Info: Saving /example/path/to/nicer/append.feather
```

## Filtering Observations

A basic filtering function has been included to help select observations, called [`master_query`](@ref), which takes in a mission name, column name, and then a value to filter by:

```julia
julia> JAXTAM.master_query(:nicer, :name, "MAXI_J1535-571")
[ Info: Loading /example/path/to/nicer/master.feather
[ Info: Loading /example/path/to/nicer/append.feather
184×35 DataFrames.DataFrame. Omitted printing of 27 columns
│ Row │ name           │ ra      │ dec      │ lii     │ bii      │ time                │ end_time            │ obsid      │
│     │ String         │ Float64 │ Float64  │ Float64 │ Float64  │ Arrow…              │ Arrow…              │ String     │
├─────┼────────────────┼─────────┼──────────┼─────────┼──────────┼─────────────────────┼─────────────────────┼────────────┤
│ 1   │ MAXI_J1535-571 │ 233.84  │ -57.2389 │ 323.722 │ -1.13864 │ 2018-08-21T04:33:20 │ 2018-08-21T04:41:26 │ 1130360245 │
│ 2   │ MAXI_J1535-571 │ 233.834 │ -57.2372 │ 323.72  │ -1.13527 │ 2018-06-05T05:03:40 │ 2018-06-05T05:26:02 │ 1130360189 │
│ 3   │ MAXI_J1535-571 │ 233.839 │ -57.2359 │ 323.724 │ -1.13597 │ 2018-08-22T09:53:40 │ 2018-08-22T10:02:35 │ 1130360246 │
⋮
│ 181 │ MAXI_J1535-571 │ 233.83  │ -57.2267 │ 323.725 │ -1.12573 │ 2018-07-07T14:56:02 │ 2018-07-07T15:12:51 │ 1130360213 │
│ 182 │ MAXI_J1535-571 │ 233.835 │ -57.2261 │ 323.727 │ -1.12659 │ 2018-07-08T14:05:42 │ 2018-07-08T20:22:19 │ 1130360214 │
│ 183 │ MAXI_J1535-571 │ 233.83  │ -57.2246 │ 323.726 │ -1.12404 │ 2018-03-29T10:54:20 │ 2018-03-29T20:01:20 │ 1130360151 │
│ 184 │ MAXI_J1535-571 │ 233.83  │ -57.2235 │ 323.727 │ -1.12316 │ 2018-05-18T22:41:50 │ 2018-05-18T22:52:00 │ 1130360180 │
```

As typically we are interested only in public observations, a `JAXTAM.master_query_public` function also exists, which behaves the same but only returns observations which have been made public:

```julia
julia> JAXTAM.master_query_public(:nicer, :name, "MAXI_J1535-571")
[ Info: Loading /media/robert/8C08EB2F08EB16CC/Users/Robert/heasarc/nicer/master.feather
178×35 DataFrames.DataFrame. Omitted printing of 20 columns
│ Row │ name           │ ra      │ dec      │ lii     │ bii      │ time                │ end_time            │ obsid      │
│     │ String         │ Float64 │ Float64  │ Float64 │ Float64  │ Arrow…              │ Arrow…              │ String     │
├─────┼────────────────┼─────────┼──────────┼─────────┼──────────┼─────────────────────┼─────────────────────┼────────────┤
│ 1   │ MAXI_J1535-571 │ 233.84  │ -57.2389 │ 323.722 │ -1.13864 │ 2018-08-21T04:33:20 │ 2018-08-21T04:41:26 │ 1130360245 │
│ 2   │ MAXI_J1535-571 │ 233.834 │ -57.2372 │ 323.72  │ -1.13527 │ 2018-06-05T05:03:40 │ 2018-06-05T05:26:02 │ 1130360189 │
│ 3   │ MAXI_J1535-571 │ 233.839 │ -57.2359 │ 323.724 │ -1.13597 │ 2018-08-22T09:53:40 │ 2018-08-22T10:02:35 │ 1130360246 │
⋮
│ 175 │ MAXI_J1535-571 │ 233.83  │ -57.2267 │ 323.725 │ -1.12573 │ 2018-07-07T14:56:02 │ 2018-07-07T15:12:51 │ 1130360213 │
│ 176 │ MAXI_J1535-571 │ 233.835 │ -57.2261 │ 323.727 │ -1.12659 │ 2018-07-08T14:05:42 │ 2018-07-08T20:22:19 │ 1130360214 │
│ 177 │ MAXI_J1535-571 │ 233.83  │ -57.2246 │ 323.726 │ -1.12404 │ 2018-03-29T10:54:20 │ 2018-03-29T20:01:20 │ 1130360151 │
│ 178 │ MAXI_J1535-571 │ 233.83  │ -57.2235 │ 323.727 │ -1.12316 │ 2018-05-18T22:41:50 │ 2018-05-18T22:52:00 │ 1130360180 │
```

Note how this time only 178 rows (observations) have been returned, whereas before 184 were returned, meaning 6 observations are not currently public.

Additionally, running the function with just the mission and no arguments for filtering (e.g. `JAXTAM.master_query_public(:mission_name)`) will return all the currently public observations.

## Downloading Observations

Downloading data can be done using a number of functions with different arguments, the two main methods are `download(mission_name::Symbol, obsid::String)` and `download(mission_name::Symbol, obs_rows::DataFrames.DataFrame)`.

This means that combining query and download commands is relatively easy:

```julia
julia> download_queue = JAXTAM.master_query_public(:nicer, :name, "MAXI_J1535-571");

julia> JAXTAM.download(:nicer, download_queue)
```

Downloads are handled by the `lftp` package. The data is downloaded to the mission path specified in the relevant `MissionDefinition` stored in the configuration file, and the folder structure is identical to that of the FTP server, however the dot `.` denoting a hidden folders/files is stripped out.

## 

# Todo

Look into using filter functions instead of masks

Look into moving to pipeline syntax for analysis, such as:

```julia
julia> "cl_file_path.fits" |> read_fits |> calibrate(energy_range) |> lcurve(bin_time) |> fspec |> ...
```

Add in a count rate column to the append table, since low count rate sources are basically useless, might as well filter them out at the start