# code to do the dry run.

function perform_dry_run_if_applicable() {
  if [ ${fai_dry_run-0} -eq 0 ]; then
    return
  fi

  print_and_log "Performing a dry-run as you requested."
  download_escenic_components

  if [[ ${fai_editor_install-0} -eq 1 || \
    ${fai_presentation_install-0} -eq 1 || \
    ${fai_analysis_install-0} -eq 1 || \
    ${fai_search_install-0} -eq 1 || \
    ${fai_all_install-0} -eq 1 ]]; then
    download_tomcat
  fi
  
  if [[ ${fai_db_install-0} -eq 1 || \
    ${fai_all_install-0} -eq 1 ]]; then
    install_mysql_server_software
    install_mysql_client_software
  fi
  if [[ ${fai_cache_install-0} -eq 1 || \
    ${fai_all_install-0} -eq 1 ]]; then
    install_varnish_software
  fi
  
  # if dry run is requested, ece-install will NOT proceed with the
  # installation profiles, even if they're defined in the
  # ece-install.conf
  print_and_log "I've downloaded as much software as I could, I will now exit."
  run rm $pid_file
  exit 0
}

