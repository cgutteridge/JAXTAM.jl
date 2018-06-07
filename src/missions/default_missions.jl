"""
    _get_default_missions()

Function returning dictionary of some pre-set HEASARC missions,
using the `MissionDefinition` type. Name and heasarc url pre-set,
mission path is left as blank string
"""
function _get_default_missions()
    mission_nicer = MissionDefinition("nicer", "https://heasarc.gsfc.nasa.gov/FTP/heasarc/dbase/tdat_files/heasarc_nicermastr.tdat.gz", "")

    mission_nustar = MissionDefinition("nustar", "https://heasarc.gsfc.nasa.gov/FTP/heasarc/dbase/tdat_files/heasarc_numaster.tdat.gz", "")

    return Dict("nicer" => mission_nicer, "nustar" => mission_nustar)
end