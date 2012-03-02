# ece-install module Content Engine specific code.

function get_deploy_white_list()
{
  local white_list="escenic-admin"
  
  if [ $install_profile_number -eq $PROFILE_PRESENTATION_SERVER \
    -a -n "${publication_name}" ]; then
    white_list="${white_list} ${publication_name} "
  elif [ $install_profile_number -eq $PROFILE_SEARCH_SERVER ]; then 
    white_list="${white_list} solr indexer-webapp"
  elif [ $install_profile_number -eq $PROFILE_PRESENTATION_SERVER ]; then
    white_list="${white_list} "$(get_publication_short_name_list)
  elif [ $install_profile_number -eq $PROFILE_EDITORIAL_SERVER ]; then
    white_list="${white_list} escenic studio indexer-webservice webservice"
    white_list="${white_list} "$(get_publication_short_name_list)
  fi

  echo ${white_list}
}

function get_publication_short_name_list()
{
  local short_name_list=""
  
  local publication_def_dir=${escenic_root_dir}/assemblytool/publications
  if [ $(ls ${publication_def_dir} | grep .properties$ | wc -l) -eq 0 ]; then
    echo ${short_name_list}
    return
  fi

  for el in $(find ${publication_def_dir} -maxdepth 1 -name "*.properties"); do
    local short_name=$(basename $el .properties)
    short_name_list="${short_name_list} ${short_name}"
  done

  echo ${short_name_list}
}

## $1=<default instance name>
function install_ece_instance()
{
  install_ece_third_party_packages
  
  ask_for_instance_name $1
  set_up_engine_directories
  set_up_ece_scripts

  set_archive_files_depending_on_profile
  
    # most likely, the user is _not_ installing from archives (EAR +
    # configuration bundle), hence the false test goes first.
  if [ $(is_installing_from_ear) -eq 0 ]; then
    download_escenic_components
    check_for_required_downloads
    set_up_engine_and_plugins
    set_up_assembly_tool
  else
    verify_that_files_exist_and_are_readable \
      $ece_instance_ear_file \
      $ece_instance_conf_archive
  fi
  
  set_up_basic_nursery_configuration
  set_up_instance_specific_nursery_configuration
  
  set_up_app_server
  set_up_proper_logging_configuration

    # We set a WAR white list for all profiles except all in one
  if [ $install_profile_number -ne $PROFILE_ALL_IN_ONE ]; then
    file=$escenic_conf_dir/ece-${instance_name}.conf
    print_and_log "Creating deployment white list in $file ..."
    set_conf_file_value \
      deploy_webapp_white_list \
      $(get_deploy_white_list) \
      $file
  fi

  if [ $install_profile_number -ne $PROFILE_ANALYSIS_SERVER -a \
    $install_profile_number -ne $PROFILE_SEARCH_SERVER ]; then
    install_memory_cache
    assemble_deploy_and_restart_type
  fi
  
  update_type_instances_to_start_up
  set_conf_file_value ece_unix_user $ece_user /etc/default/ece
  set_conf_file_value ece_unix_group $ece_group /etc/default/ece

  admin_uri=http://$HOSTNAME:${appserver_port}/escenic-admin/
  add_next_step "New ECE instance $instance_name installed."
  add_next_step "Admin interface: $admin_uri"
  add_next_step "View installed versions with:" \
    " ece -i $instance_name versions"
  add_next_step "Type 'ece help' to see all the options of this script"
  add_next_step "Read its guide: /usr/share/doc/escenic/ece-guide.txt"
  add_next_step "/etc/default/ece lists all instances started at boot time"
}

