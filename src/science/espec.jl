struct CMDRedirect
    command::String
    arguments::Array{String,1}
end

function _call_with_redirect(cmd_in::CMDRedirect)
    command = `$(cmd_in.command)`
    arg = join(cmd_in.arguments, "\\n")
    redirect_printf = `printf $arg`

    run(pipeline(redirect_printf, stdout=pipeline(`$command`)))
end 

function _xselect_cmd(mission_name::String, event_cl_path::String, out_basename::String="xselect_out.pi")
    if !isfile(event_cl_path)
        event_cl_path = string(event_cl_path, ".gz")
    end
    path_out = joinpath(dirname(event_cl_path), out_basename)

    session_name = split(tempname(), "/")[3]
    set_mission  = "set mission $(String(mission_name))"
    read_event   = [
        "read event",
        "$(dirname(event_cl_path))",
        "$(basename(event_cl_path))"
    ]
    extract_spec = "extract spectrum"
    save_spec    = "save spectrum $out_basename"

    if isfile(path_out)
        rm(path_out)
    end

    lines = vcat([
        session_name,
        set_mission,
        read_event,
        extract_spec,
        save_spec,
        "exit",
        "no"
    ]...)

    origina_dir = pwd()
    cd(dirname(event_cl_path))
    _call_with_redirect(CMDRedirect("xselect", lines))
    cd(origina_dir)
end

function _xselect_cmd(mission_name::Union{String,Symbol}, obs_row::DataFrames.DataFrame)
    return _xselect_cmd(String(mission_name), obs_row[1, :event_cl][1])
end

function _grppha_cmd(path_xselect_spec::String, out_basename::String="grppha_out.pi")
    input    = path_xselect_spec
    path_out   = joinpath(dirname(path_xselect_spec), out_basename)
    respfile = "chkey respfile $(joinpath(ENV["CALDB"], "data/nicer/xti/cpf/rmf/nixtiref20170601v001.rmf"))"
    ancrfile = "chkey ancrfile $(joinpath(ENV["CALDB"], "data/nicer/xti/cpf/arf/nixtiaveonaxis20170601v002.arf"))"
    grouping = "group min 20"

    if isfile(path_out)
        rm(path_out)
    end

    lines = [
        input,
        path_out,
        respfile,
        ancrfile,
        grouping,
        "exit"
    ]

    _call_with_redirect(CMDRedirect("grppha", lines))
end

function _grppha_cmd(mission_name::Union{String,Symbol}, obs_row::DataFrames.DataFrame)
    path_xselect_out = joinpath(dirname(obs_row[1, :event_cl][1]), "xselect_out.pi")
    return _grppha_cmd(path_xselect_out, "grppha_out.pi")
end

function _xspec_ldata_cmd(path_grppha_spec::String, e_min::Float64, e_max::Float64)
    plot_name = "plot_xspec_ldata_$(e_min)_$(e_max).gif"

    input    = "data $path_grppha_spec"
    plot_out = "cpd $plot_name/vgif"
    e_bound  = "ig 0.0-$e_min $e_max-**"
    set_e    = "setplot energy"
    plot_ld  = "plot ldata"

    lines = vcat([
        input,
        plot_out,
        e_bound,
        set_e,
        plot_ld,
        "exit"
    ]...)

    correct_path = "../../JAXTAM/images/$(e_min)_$(e_max)/espec/$plot_name"

    original_dir = pwd()
    cd(dirname(path_grppha_spec))
    _call_with_redirect(CMDRedirect("xspec", lines))
    rm(plot_name)
    mkpath(dirname(abspath(correct_path)))
    mv("$(plot_name)_2", correct_path; force=true)
    cd(original_dir)
    return(abspath(correct_path))
end

function _xspec_ldata_cmd(mission_name::Union{String,Symbol}, obs_row::DataFrames.DataFrame)
    path_grppha_out = joinpath(dirname(obs_row[1, :event_cl][1]), "grppha_out.pi")

    mission_config = JAXTAM.config(Symbol(mission_name))
    (e_min, e_max) = (Float64(mission_config.good_energy_min), Float64(mission_config.good_energy_max))

    plot_path = _xspec_ldata_cmd(path_grppha_out, e_min, e_max)
    plot_log  = JAXTAM._log_entry(; category=:images, e_range=(e_min, e_max), kind=:espec, file_name=basename(plot_path))
    JAXTAM._log_add(Symbol(mission_name), obs_row, plot_log)
end

function _xspec_eufspec_cmd(path_grppha_spec::String, e_min::Float64, e_max::Float64)
    plot_name = "plot_xspec_eufspec_$(e_min)_$(e_max).gif"

    input    = "data $path_grppha_spec"
    plot_out = "cpd $plot_name/vgif"
    e_bound  = "ig 0.0-$e_min $e_max-**"
    model    = [
        "model PowerLaw";
        repeat([""], 11); # Done to leave model parameters as defualts
        "newpar 1 1"
    ]
    set_e    = "setplot energy"
    plot_ld  = "plot eufspec"

    lines = vcat([
        input,
        plot_out,
        e_bound,
        model,
        set_e,
        plot_ld,
        "exit"
    ]...)

    correct_path = "../../JAXTAM/images/$(e_min)_$(e_max)/espec/$plot_name"

    original_dir = pwd()
    cd(dirname(path_grppha_spec))
    _call_with_redirect(CMDRedirect("xspec", lines))
    rm(plot_name)
    mkpath(dirname(abspath(correct_path)))
    mv("$(plot_name)_2", correct_path; force=true)
    cd(original_dir)
    return(abspath(correct_path))
end

function _xspec_eufspec_cmd(mission_name::Union{String,Symbol}, obs_row::DataFrames.DataFrame)
    path_grppha_out = joinpath(dirname(obs_row[1, :event_cl][1]), "grppha_out.pi")

    mission_config = JAXTAM.config(Symbol(mission_name))
    (e_min, e_max) = (Float64(mission_config.good_energy_min), Float64(mission_config.good_energy_max))

    plot_path = _xspec_eufspec_cmd(path_grppha_out, e_min, e_max)
    plot_log  = JAXTAM._log_entry(; category=:images, e_range=(e_min, e_max), kind=:espec, file_name=basename(plot_path))
    JAXTAM._log_add(Symbol(mission_name), obs_row, plot_log)
end

function _call_all_espec(mission_name::Union{String,Symbol}, obs_row::DataFrames.DataFrame)
    _xselect_cmd(mission_name, obs_row)

    _grppha_cmd(mission_name, obs_row)

    _xspec_ldata_cmd(mission_name, obs_row)

    _xspec_eufspec_cmd(mission_name, obs_row)
end