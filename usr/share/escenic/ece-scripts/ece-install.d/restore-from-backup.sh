function remove_directory_contents_if_exists() {
  if [ -z $1 ]; then
    return
  elif [ ! -d $1 ]; then
    return
  fi

  print_and_log "Restore preparations: removing all files in $1 ..."
  run rm -rf ${1}/*
}

## remove generated files of various sorts, to make the slate as clean
## as possible before restoring a backup
function wipe_the_slate_clean() {
  if [ ${fai_restore_pre_wipe_solr-0} -eq 1 \
    -o ${fai_restore_pre_wipe_all-0} -eq 1 ]; then
    remove_directory_contents_if_exists ${escenic_data_dir}/solr/data
  fi
  if [ ${fai_restore_pre_wipe_logs-0} -eq 1 \
    -o ${fai_restore_pre_wipe_all-0} -eq 1 ]; then
    remove_directory_contents_if_exists ${escenic_log_dir}
  fi
  if [ ${fai_restore_pre_wipe_cache-0} -eq 1 \
    -o ${fai_restore_pre_wipe_all-0} -eq 1 ]; then
    remove_directory_contents_if_exists ${escenic_cache_dir}
  fi
  if [ ${fai_restore_pre_wipe_crash-0} -eq 1 \
    -o ${fai_restore_pre_wipe_all-0} -eq 1 ]; then
    remove_directory_contents_if_exists ${escenic_crash_dir}
  fi
}

function restore_from_backup()
{
  local restore_all=0
  local restore_db=0
  local restore_binaries=0
  local restore_data_files=0
  local restore_conf=0
  local backup_file=""
  local backup_dir=$escenic_backups_dir

  wipe_the_slate_clean
  
  if [ $(get_boolean_conf_value fai_enabled) -eq 1 -a \
    $(get_boolean_conf_value fai_restore_from_backup) -eq 1 ]; then
    print_and_log "Restoring from backup on $HOSTNAME ..."
    
    backup_file=${fai_restore_from_file}

    if [ -z "$backup_file" ]; then
      print_and_log "You must specifify fai_restore_from_file"
      remove_pid_and_exit_in_error
    fi

    if [ $(get_boolean_conf_value fai_restore_all) -eq 1 ]; then
      restore_all=1
    elif [ $(get_boolean_conf_value fai_restore_db) -eq 1 ]; then
      restore_db=1
    elif [ $(get_boolean_conf_value fai_restore_data_files) -eq 1 ]; then
      restore_data_files=1
    elif [ $(get_boolean_conf_value fai_restore_software_binaries) -eq 1 ]
    then
      restore_binaries=1
    elif [ $(get_boolean_conf_value fai_restore_configuration) -eq 1 ]; then
      restore_conf=1
    fi
  elif [ $(get_boolean_conf_value fai_enabled) -eq 0 ]; then
    print "From which dataset do you wish to restore?"
    if [ ! -d $backup_dir ]; then
      print_and_log "Directory $backup_dir doesn't exist or isn't readable"
      remove_pid_and_exit_in_error
    fi

    if [ $(ls $backup_dir | grep ".tar$" | wc -l) -lt 1 ]; then
      print_and_log "No backup files (.tar) found in $backup_dir, exiting."
      exit 0
    fi
    
    local tarball_array=($(ls -t $backup_dir/*.tar))
    
    for (( i = 0; i <${#tarball_array[@]}; i++ )); do
      echo "   " $(( ${i} + 1 )) "-" $(basename  ${tarball_array[$i]})
    done
    
    print "Enter the number next to the tarball, from 1 to $i"
    echo -n "Your choice [1]> "
    read user_tarball

    if [ -z "$user_tarball" ]; then
      user_tarball=1
    fi

    backup_file=${tarball_array[$(( ${user_tarball} - 1 ))]}

    print "Which part of the system do you wish to restore?"
    restore_profiles=(
      "The database"
      "The Solr and ECE data files (multimedia archive)"
      "The ECE configuration files"
      "The Escenic and Tomcat software binaries + publication templates"
      "Restore everything of the above"
    )
    for (( i = 0; i <${#restore_profiles[@]}; i++ )); do
      echo "   " $(( ${i} + 1 )) "-" ${restore_profiles[$i]}
    done
    
    print "Enter the number next to the tarball, from 1 to $i"
    echo -n "Your choice [1]> "
    read user_restore_profile

    if [ -z "$user_restore_profile" ]; then
      user_restore_profile=1
    fi

    if [ $user_restore_profile -eq 1 ]; then
      restore_db=1
    elif [ $user_restore_profile -eq 2 ]; then
      restore_data_files=1
    elif [ $user_restore_profile -eq 3 ]; then
      restore_conf=1
    elif [ $user_restore_profile -eq 4 ]; then
      restore_binaries=1
    elif [ $user_restore_profile -eq 5 ]; then
      restore_all=1
    fi
  fi

  if [ ! -r "$backup_file" ]; then
    print_and_log "$backup_file either doesn't exist or cannot be read." \
      "I cannot restore from it :-("
    remove_pid_and_exit_in_error
  fi
  
  local dir=$(mktemp -d)
  
  if [ $restore_db -eq 1 -o $restore_all -eq 1 ]; then
    install_database_server "binaries_only"
    print_and_log "Restoring the database contents on $HOSTNAME ..."
    run cd $dir
    run tar xf $backup_file --wildcards var/backups/escenic/*.sql.gz
        # picking the DB backup file to restore
    sql_file=$(ls -tra var/backups/escenic/*.sql.gz | tail -1)
    print_and_log "Selecting database dump: $(basename $sql_file)"

    # methods in database.sh to set up the database schema & user
    pre_install_new_ecedb
    create_schema

    # db_schema is defined in database.sh
    gunzip < $sql_file | mysql $db_schema
    exit_on_error "restoring from $sql_file"
    
    add_next_step "$(green Successfully) restored DB from $sql_file"
  fi
  
  if [ $restore_data_files -eq 1 -o $restore_all -eq 1 ]; then
    print_and_log "Restoring the Solr & ECE data files on $HOSTNAME ..."
    run cd $dir
    run tar -C / -xf $backup_file var/lib/escenic
    add_next_step "$(green Successfully) restored Solr & ECE data files" \
      "Backup file used:  $(basename $backup_file)" \
      "Check $escenic_data_dir to verify they're all there."
  fi
  
  if [ $restore_conf -eq 1 -o $restore_all -eq 1 ]; then
    print_and_log "Restoring the ECE configuration files on $HOSTNAME ..."
    run cd $dir
    run tar -C / -xf $backup_file etc
    add_next_step "$(green Successfully) restored ECE configuration files" \
      "Backup file used: $(basename $backup_file)" \
      "Check /etc to verify that they're all there."
  fi
  
  if [ $restore_binaries -eq 1 -o $restore_all -eq 1 ]; then
    print_and_log "Restoring the Escenic & Tomcat binaries on $HOSTNAME ..."
    run cd $dir
    run tar -C / -xf $backup_file opt
    add_next_step "$(green Successfully) restored Escenic & Tomcat binaries" \
      "Backup file used: $(basename $backup_file)" \
      "Check ${appserver_parent_dir} to verify that they're all there".
    install_ece_third_party_packages
    set_up_engine_directories

    # doing some educated guessing on which tomcat_base/home as well
    # as UNIX user/group to use for this.
    file=/etc/default/ece
    if [ -r $file ]; then
      ece_user=$(grep ^ece_unix_user $file | \
        cut -d'=' -f2 | \
        sed -e "s/'//g" -e 's/"//g'
      )
      ece_group=$(grep ^ece_unix_group $file | \
        cut -d'=' -f2 | \
        sed -e "s/'//g" -e 's/"//g'
      )
      create_user_and_group_if_not_present $ece_user $ece_group
      
      if [ -d $escenic_conf_dir -a \
        $(ls $escenic_conf_dir/ | grep ^ece- | wc -l) -gt 0 -a \
        $(grep ^tomcat_base $escenic_conf_dir/ece*.conf | wc -l) -gt 0 ]; then
        directories=$(grep ^tomcat_base $escenic_conf_dir/ece*.conf | \
          cut -d'=' -f2 | \
          sed -e "s/'//g" -e 's/"//g'
        )
        s="Setting file permissions according to /etc/default/ece"
        print_and_log $s
        s="and $escenic_conf_dir/ece*.conf"
        print_and_log $s
        for el in ${directories}; do
          if [ ! -d $el ]; then
            continue
          fi
          run chown -R ${ece_user}:${ece_group} ${el}
        done  
      fi
    fi
  fi
}
