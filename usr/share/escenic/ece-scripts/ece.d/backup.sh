
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
  
   # TODO add support for backup_dir in ece.conf
  if [ -z "$backup_dir" ]; then
    backup_dir=/var/backups/escenic
  fi
  if [ ! -w $backup_dir ]; then
    print $backup_dir "must exist & be write-able for $USER"
    exit 1
  fi

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
    mysqldump -u ${db_user} \
      -p${db_password} \
      -h ${db_host} \
      -P ${db_port} ${db} | \
      gzip - \
      > $db_backup_file

    print "Database dumped: $db_backup_file"
  fi
  
  archive_file=$backup_dir/${type}-${instance}-backup-$(date --iso).tar
  possible_backup="
${escenic_conf_dir} 
/opt/escenic 
/etc/init.d/ece
/etc/default/ece
/etc/inti.d/rmi-hub
/var/lib/escenic
"
  actual_backup=""
  for el in $possible_backup; do
    if [ "$el" == "/opt/escenic" -a $backup_exclude_binaries -eq 1 ]; then
      continue
    elif [ -r "$el" ]; then
      actual_backup="$el $actual_backup"
    fi
  done

  if [ "$appserver" == "tomcat" -a "$backup_exclude_binaries" -eq 0 ]; then
    actual_backup="$(get_actual_file $tomcat_home) $tomcat_base $actual_backup"
  fi

  print "Creating snapshot ... (this will take a while)"
  run tar cf $archive_file \
    $actual_backup \
    $db_backup_file

  message="Backup ready: $archive_file"
  print $message
  log $message
  print "The backup arhcive includes:"
  print "- Database snapshot"
  print "- All Solr & Escenic data files from /var/lib/escenic"

  if [ "$backup_exclude_binaries" -eq 0 ]; then
    print "- All app servers in /opt"
    print "- All Escenic binaries & publication templates in /opt/escenic"
  fi
  
  print "- All configuration in ${escenic_conf_dir} and /etc/default/ece"
  print "- All bootstrap scripts from /etc/init.d"
  print "Enjoy!"
}
