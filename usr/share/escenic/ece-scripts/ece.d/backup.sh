function backup_type() {
  local message="Backing up the $instance instance of $type on $HOSTNAME ..."
  print_and_log $message

  if [ "$type" == "rmi-hub" ]; then
    ensure_that_required_fields_are_set $hub_required_fields
  elif [ "$type" == "search" ]; then
        # TODO trim & tun the default parameters for the search
        # instance.
    ensure_that_required_fields_are_set $engine_required_fields
  elif [ "$type" == "engine" ]; then
    ensure_that_required_fields_are_set $engine_required_fields
  elif [ "$type" == "analysis" ]; then
    ensure_that_required_fields_are_set $analysis_required_fields
  fi
  
  if [ -z "$backup_dir" ]; then
    backup_dir=/var/backups/escenic
  fi
  if [ ! -w $backup_dir ]; then
    print $backup_dir "must exist & be write-able for $USER"
    exit 1
  fi

  actual_backup=""

  if [ ${backup_exclude_db-0} -eq 0 ]; then
    backup_db
  else
    print "Skipping DB, not including the database dump"
  fi
  
  archive_file=$backup_dir/${type}-${instance}-backup-$(date --iso).tar
  possible_backup="
${data_dir}
${data_dir}/engine
${ece_home} 
${escenic_conf_dir} 
${solr_home}
${tomcat_base}/conf
/etc/default/ece
/etc/init.d/ece
/etc/init.d/rmi-hub
"
  for el in $possible_backup; do
    if [ "$el" == "${ece_home}" -a $backup_exclude_binaries -eq 1 ]; then
      print "Skpping software binaries, not including $ece_home"
      continue
    elif [ "$el" == "${escenic_conf_dir}" -a $backup_exclude_conf -eq 1 ]; then
      print "Skpping configuration, not including $escenic_conf_dir"
      continue
    elif [ "$el" == "/etc/default/ece" -a $backup_exclude_conf -eq 1 ]; then
      print "Skpping configuration, not including /etc/default/ece"
      continue
    elif [ $appserver == "tomcat" -a \
      "$el" == "$tomcat_base/conf" -a \
      $backup_exclude_conf -eq 1 ]; then
      print "Skpping configuration, not including $tomcat_base/conf"
      continue
    elif [ "$el" == "${data_dir}" ]; then
      # special handling of the data dir itself (it has a lot of data,
      # we handle engine and solr data seperately)

      if [ ${backup_exclude_state-0} -eq 0 ]; then
        actual_backup="$(ls $data_dir/*.state 2>/dev/null) $actual_backup"
      fi
    elif [ "$el" == "${solr_home}" -a $backup_exclude_solr -eq 1 ]; then
      print "Skipping Solr data files, not including $solr_home"
      continue
    elif [ "$el" == "${data_dir}/engine" \
      -a $backup_exclude_multimedia -eq 1 ]; then
      print "Skipping the multimedia archive, not including $data_dir/engine"
      continue
    elif [[ "$el" == "/etc/init.d/"* && $backup_exclude_init -eq 1 ]]; then
      print "Skipping the init.d scripts, not including $el"
      continue
    elif [ -r "$el" ]; then
      actual_backup="$el $actual_backup"
    fi
  done

  # tomcat binaries, both home and base.
  if [ "$appserver" == "tomcat" -a "$backup_exclude_binaries" -eq 0 ]; then
    for el in $(get_actual_file $tomcat_home) $tomcat_base; do
      if [ -d $el ]; then
        actual_backup="$el $actual_backup"
      fi
    done
  fi

  if [ -z "$actual_backup" ]; then
    print "You have excluded everything, $(red nothing to backup) :-("
    exit 0
  fi
  
  print "Creating snapshot ... (this may take a while)"
  run tar cf $archive_file \
    $actual_backup \
    --exclude $tomcat_base/work \
    --exclude $tomcat_base/temp

  local size=$(du -h $archive_file | cut -d'/' -f1)
  message="Backup ready: $archive_file size: $size"
  print $message
  log $message
  print "The backup arhcive includes:"
  
  if [ ${backup_exclude_db-0} -eq 0 ]; then
    print "- Database snapshot"
  fi

  if [ ${backup_exclude_solr-0} -eq 0 ]; then
    print "- All Solr in $solr_home"
  fi
  
  if [ ${backup_exclude_multimedia-0} -eq 0 ]; then
    print "- All Escenic data files in $data_dir/engine"
  fi
  
  if [ "${backup_exclude_binaries-0}" -eq 0 ]; then
    print "- All app servers in /opt"
    print "- All Escenic software binaries in $ece_home"
  fi
  
  if [ "${backup_exclude_conf-0}" -eq 0 ]; then
    print "- All configuration in ${escenic_conf_dir} and /etc/default/ece"
  fi
  
  if [ "${backup_exclude_init-0}" -eq 0 ]; then
    print "- All bootstrap scripts from /etc/init.d"
  fi
  
  if [ "${backup_exclude_state-0}" -eq 0 ]; then
    print "- All state files in $data_dir"
  fi
  
  print "Enjoy!"
}

function backup_db() {
  if [ "$appserver" == "tomcat" ]; then
    if [ ! -d $tomcat_base/conf ]; then
      print $tomcat_base/conf "doesn't exist :-("
      print "check your ece.conf the $instance instance of type $type"
      exit 1
    fi

    connect_string=$(find $tomcat_base/conf | xargs \
      grep jdbc | \
      grep url | \
      head -1 | \
      cut -d'"' -f2)
    db_port=$(echo $connect_string | cut -d':' -f4 | cut -d'/' -f1)
    db=$(echo $connect_string | cut -d'/' -f4 | cut -d'?' -f1)
    db_host=$(echo $connect_string | cut -d'/' -f3- | cut -d':' -f1)

    db_user=$(find $tomcat_base/conf -name "*.xml" | \
      grep -v tomcat-users.xml | xargs \
      grep username | \
      grep -v \<user | \
      head -1 | \
      cut -d'"' -f2)
    db_password=$(find $tomcat_base/conf -name "*.xml" | \
      grep -v tomcat-users.xml | xargs \
      grep password | \
      head -1 | \
      cut -d'"' -f2)

    db_backup_file=$backup_dir/${db}-$(date --iso).sql.gz
    
    # check DB credentials first.
    mysql -u ${db_user} \
      -p${db_password} \
      -h ${db_host} \
      -P ${db_port} ${db} \
      -e 'select 1;' \
      1>> $log 2>> $log
    if [ $? -gt 0 ]; then
      print "The DB credentials in $tomcat_base/conf seem to be wrong :-("
      print "See $log for further details. I will exit now."
      remove_pid_and_exit_in_error
    fi

    # then, go ahead with the dump, piping the output to gzip -9
    mysqldump -u ${db_user} \
      -p${db_password} \
      -h ${db_host} \
      -P ${db_port} ${db} | \
      gzip --rsyncable -9 \
      > $db_backup_file

    print "Database dumped: $db_backup_file"

    actual_backup="$db_backup_file $actual_backup"
  fi
}
