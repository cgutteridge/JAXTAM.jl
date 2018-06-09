
function _get_list_for_folder(ftp_folder, connection_context)
    list = ftp_command(connection_context, "NLST $ftp_folder")
    list = String(take!(list.body))
    list = split(list, "\n")[1:end-1]
    list = replace.(list, "\r", "")

    return list
end

function _get_list_for_folder_r(ftp_folder, connection_context)
    list = _get_list_for_folder(ftp_folder, connection_context)
    list2 = []

    for item in list
        if contains(basename(item), ".")
            append!(list2, [item])
        else
            append!(list2, _get_list_for_folder_r(item, connection_context))
        end
    end

    return list2
end

function _download_queue(mission_name::Union{String,Symbol}, master, obsid::String)
    ftp_folder = _ftp_folder(mission_name, master, obsid)

    ftp_init()

    options = RequestOptions(hostname="heasarc.gsfc.nasa.gov")

    connection = ftp_connect(options)
    connection_context = connection[1]

    list = _get_list_for_folder_r(ftp_folder, connection_context)

    ftp_close_connection(connection_context)
    ftp_cleanup()

    return list
end

function _download_queue(mission_name::Union{String,Symbol}, obsid::String)
    master_data = master(mission_name)

    return _download_queue(mission_name, master_data, obsid)
end

function download_queue(mission_name::Union{String,Symbol}, obsid::String)
    queue = _download_queue(mission_name, obsid)

    writedlm(string(config(mission_name).path, "/queues/download_$(string(mission_name))_$obsid.txt"), queue)

    return queue
end

function _filezilla_header()
    # Create XML Queue file for FileZilla
    # Header
    filezilla_xml = XMLDocument()

    fz_root = create_root(filezilla_xml, "FileZilla3")
    #set_attribute(fz_root, "version", "3.29.0")
    if is_windows()
        set_attribute(fz_root, "platform", "windows")
    elseif is_linux()
        set_attribute(fz_root, "platform", "*nix")
    end

    fz_queue = new_child(fz_root, "Queue")

    fz_server = new_child(fz_queue, "Server")

    fz_server_Host = new_child(fz_server, "Host")
        add_text(fz_server_Host, "heasarc.gsfc.nasa.gov")

    fz_server_Port = new_child(fz_server, "Port")
        add_text(fz_server_Port, "21")

    fz_server_Protocol = new_child(fz_server, "Protocol")
        add_text(fz_server_Protocol, "0")

    fz_server_Type = new_child(fz_server, "Type")
        add_text(fz_server_Type, "0")

    fz_server_Logontype = new_child(fz_server, "Logontype")
        add_text(fz_server_Logontype, "0")

    fz_server_TimezoneOffset = new_child(fz_server, "TimezoneOffset")
        add_text(fz_server_TimezoneOffset, "0")

    fz_server_PasvMode = new_child(fz_server, "PasvMode")
        add_text(fz_server_PasvMode, "MODE_DEFAULT")

    fz_server_MaximumMultipleConnections = new_child(fz_server, "MaximumMultipleConnections")
        add_text(fz_server_MaximumMultipleConnections, "0")

    fz_server_EncodingType = new_child(fz_server, "EncodingType")
        add_text(fz_server_EncodingType, "Auto")

    fz_server_BypassProxy = new_child(fz_server, "BypassProxy")
        add_text(fz_server_BypassProxy, "0")

    return filezilla_xml
end


function _ftp_folder_dir(mission_name::Union{String,Symbol}, ftp_folder)
    mission_dir = _config_load()["default"].path

    XML_out_dir = string(mission_dir, "filezilla_queue.xml")

    ftp_init()

    options = RequestOptions(hostname="heasarc.gsfc.nasa.gov")

    connection = ftp_connect(options)
    connection_context = connection[1]

    # 0x00000000000000e2 == FTP code 226, Requested file action successful
    if connection[2].code != 0x00000000000000e2
        println(connection)
        error("Connection failed")
    end

    # 229, Entering Extended Passive Mode
    if connection[2].headers[5][1:3] != "229"
        println(connection)
        error("Connection not in passive mode")
    else
        info("Connection established, passive mode")
    end

    info("Generating XML for FileZilla3")

    filezilla_xml = _filezilla_header()

    obs_parent_folders = _get_list_for_folder(ftp_folder, connection_context)

    files_done = 1
    for ObsID in ObsIDs
        list_auxil    = get_list_for_folder(ObsID, "auxil")
        list_hk       = get_list_for_folder(ObsID, "hk")
        list_event_uf = get_list_for_folder(ObsID, "event_uf")

        obs_caldb = parse(Int, numaster_df[:caldb_version][numaster_df[:obsid] .== ObsID][1])

        # If calibration is outdated, ignore cleaned files
        if obs_caldb < caldb_version
            download_list = [list_auxil; list_hk; list_event_uf]
        elseif obs_caldb >= caldb_version
            info("event_cl uses currentl caldb, downloading")
            list_event_cl = get_list_for_folder(ObsID, "event_cl")
            download_list = [list_auxil; list_hk; list_event_uf; list_event_cl]
        end

        info("Generating file list for $(ObsID) $(files_done)/$(length(ObsIDs)). Found $(length(download_list)) files")

        for (itr, file) in enumerate(download_list)
            fz_server_file = new_child(fz_server, "File")

            dir_name = dirname(file)
            dir_folder = split(dir_name, "/")[end]
            dir_folder_length = length(dir_folder)
            file_name = basename(file)

            fz_server_file_local = new_child(fz_server_file, "LocalFile")
            if is_windows()
                add_text(fz_server_file_local, replace(string(local_archive, file[24:end]), "/", "\\"))
            elseif is_linux()
                add_text(fz_server_file_local, string(local_archive, file[24:end]))
            end

            fz_server_file_remote = new_child(fz_server_file, "RemoteFile")
            add_text(fz_server_file_remote, file_name)

            fz_server_remote_path = new_child(fz_server_file, "RemotePath")
            remote_path_string = string("1 0 6 nustar 15 .nustar_archive 11 $(ObsID) $(dir_folder_length) $(dir_folder)")
            add_text(fz_server_remote_path, remote_path_string)

            fz_server_download_flag = new_child(fz_server_file, "Download")
            add_text(fz_server_download_flag, "1")

            fz_server_data_type = new_child(fz_server_file, "DataType")
            add_text(fz_server_data_type, "1")

            if verbose; info("Added $(file)"); end
        end

        files_done += 1
    end

    ftp_close_connection(connection_context)
    ftp_cleanup()

    info("Done, saving to $(XML_out_dir)")

    save_file(filezilla_xml, XML_out_dir)
end