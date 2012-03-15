# ece-install module for installing the database.

# Setting the correct URLs for the percona releas (bootstrap) RPM package.
percona_rpm_release_version=0.0-1
percona_rpm_release_package_name=percona-release-${percona_rpm_release_version}
percona_rpm_release_url=http://www.percona.com/downloads/percona-release/$percona_rpm_release_package_name.x86_64.rpm
if [[ $(uname -m) != "x86_64" ]]; then
  percona_rpm_release_url=http://www.percona.com/downloads/percona-release/$percona_rpm_release_package_name.i386.rpm
fi

function get_percona_supported_list() {
  echo $(
    curl -s http://repo.percona.com/apt/dists/ | \
      grep ^"<li><a href" | \
      cut -d'"' -f2 | \
      cut -d'/' -f1
  )
}

## $1: optional parameter, binaries_only. If passed, $1=binaries_only,
##     the ECE DB schema is not set up. 
function install_database_server()
{
  print_and_log "Installing database server on $HOSTNAME ..."

  source $(dirname $0)/drop-and-create-ecedb

  if [ $on_debian_or_derivative -eq 1 ]; then

    code_name=$(lsb_release -s -c)
    
    supported_code_name=0
    supported_list=$(get_percona_supported_list)
    for el in $supported_list; do
      if [ $code_name = $el ]; then
        supported_code_name=1
      fi
    done
    
    # some how, this is to install Percona 5.5
    if [ -e /var/lib/mysql/debian-*.flag ]; then
      run rm /var/lib/mysql/debian-*.flag
    fi
    
    if [ $supported_code_name -eq 1 ]; then
      print_and_log "Installing the Percona database ..."

      if [ $(apt-key list| grep CD2EFD2A | wc -l) -lt 1 ]; then
        gpg --keyserver hkp://keys.gnupg.net \
          --recv-keys 1C4CBDCDCD2EFD2A \
          1>>$log 2>>$log
        
        # There has been three times now, during six months, that the
        # key cannot be retrieved from keys.gnupg.net. Therefore,
        # we're checking if it failed and if yes, force the package
        # installation.
        if [ $? -gt 0 ]; then
          s="Failed retrieving the Percona key from keys.gnupg.net"
          print_and_log $s
          s="Will install the Percona packages without the GPG key"
          print_and_log $s
          force_packages=1
        else
          gpg --armor \
            -a \
            --export 1C4CBDCDCD2EFD2A | \
            apt-key add - \
            1>>$log 2>>$log
        fi

        run apt-get update
      fi
      
      add_apt_source "deb http://repo.percona.com/apt ${code_name} main"
      packages="percona-server-server percona-server-client libmysqlclient16"
    else
      print_and_log "The Percona APT repsository doesn't have packages" 
      print_and_log "for your Debian (or derivative) version with code"
      print_and_log "name $code_name. "
      print_and_log "I will use vanilla MySQL instead."

      packages="mysql-server mysql-client"
    fi
  elif [ $on_redhat_or_derivative -eq 1 ]; then
    print_and_log "Installing the Percona database ..."
    
    if [ $(rpm -qa | grep $percona_rpm_release_package_name | wc -l) -lt 1 ]; then
      run rpm -Uhv $percona_rpm_release_url
    fi
    
    packages="
      Percona-Server-shared-compat
      Percona-Server-server-55
      Percona-Server-client-55"
  fi
  
  install_packages_if_missing $packages
  force_packages=0

  if [ $on_redhat_or_derivative -eq 1 ]; then
    run chkconfig --level 35 mysql on
    run /etc/init.d/mysql restart
  fi

  assert_pre_requisite mysql
  assert_pre_requisite mysqld

  if [ -z "$1" ]; then
    download_escenic_components
    set_up_engine_and_plugins
    set_up_ecedb
  fi

  if [ $db_replication -eq 1 ]; then
    if [ $db_master -eq 1 ]; then
      create_replication_user
    fi
    configure_mysql_for_replication

    if [ $db_master -eq 0 ]; then
      set_slave_to_replicate_master
    fi
  fi
}

function set_up_ecedb()
{
  print_and_log "Setting up the ECE database schema ..."

  make_dir $escenic_root_dir/engine/plugins
  run cd $escenic_root_dir/engine/plugins
  
  find ../../ -maxdepth 1 -type d | \
    grep -v assemblytool | \
    while read directory; do
    if [ $directory = "../../" ]; then
      continue
    fi
    
          # nuisance to get the community engine, but not the engine
    if [ $(echo $directory | grep engine | wc -l) -gt 0 ]; then
      if [ $(echo $directory | grep community | wc -l) -lt 1 ]; then
        continue
      fi
    fi

    if [ ! -h $(basename $directory) ]; then
      run ln -s $directory
    fi
  done

  # the user may override standard DB settings in ece-install.conf
  set_db_settings_from_fai_conf
  set_db_defaults_if_not_set

  # the methods in drop-and-create-ecedb needs ece_home to be set
  ece_home=${escenic_root_dir}/engine
  pre_install_new_ecedb
  create_ecedb
  
  cd ~/
  run rm -rf $escenic_root_dir/engine/plugins

  add_next_step "DB is now set up on ${db_host}:${db_port}"
}

function set_db_settings_from_fai_conf()
{
  # Note: the port isn't fully supported. The user must himself
  # update the mysql configuration to run it on a non standard port.

  # if either the profile=analysis or the profile=db &&
  # fai_analysis_db_install is set, we try first to use the
  # fai_analysis_db_* variables.
  if [[ ( $install_profile_number -eq $PROFILE_DB_SERVER &&
          $(get_boolean_conf_value fai_analysis_db_install) -eq 1 ) ||
        $install_profile_number -eq $PROFILE_ANALYSIS_SERVER ]]; then

    # order of precedence:
    # 1) fai_analysis_db_*
    # 2) fai_db_*
    # 3) default_db_*
    db_port=${fai_analysis_db_port-${fai_db_port-${default_db_port}}}
    db_host=${fai_analysis_db_host-${fai_db_host-${default_db_host}}}
    db_user=${fai_analysis_db_user-${fai_db_user-${default_db_user}}}
    db_password=${fai_analysis_db_password-${fai_db_password-${default_db_password}}}
    db_schema=${fai_analysis_db_schema-${fai_db_schema-${default_db_schema}}}
  else
    db_port=${fai_db_port-${default_db_port}}
    db_host=${fai_db_host-${default_db_host}}
    db_user=${fai_db_user-${default_db_user}}
    db_password=${fai_db_password-${default_db_password}}
    db_schema=${fai_db_schema-${default_db_schema}}
  fi
  
  if [ -n "${fai_db_drop_old_db_first}" ]; then
    drop_db_first=${fai_db_drop_old_db_first}
    if [ $fai_db_drop_old_db_first -eq 1 ]; then
      print_and_log "$(yellow WARNING): I hope you know what you're doing!"
      print_and_log "$(yellow WARNING): fai_db_drop_old_db_first is 1 (true)"
    fi
  fi
  
  # replication is only available in FAI mode
  db_replication=${fai_db_replication-0}
  db_replication_user=${fai_db_replication_user-replicationuser}
  db_replication_password=${fai_db_replication_password-replicationpassword}
  
  db_master=${fai_db_master-0}
  db_master_host=${fai_db_master_host}
  db_master_log_file=${fai_db_master_log_file}
  db_master_log_position=${fai_db_master_log_position}
  
  # TODO assert set
}

# Method used both from interactive mode to set any missing values
# (defaults)
function set_db_defaults_if_not_set()
{
  if [ -z "$db_host" ]; then
    db_host=${default_db_host}
  fi
  
  if [ -z "$db_port" ]; then
    db_port=${default_db_port}
  fi
  
  if [ -z "$db_user" ]; then
    db_user=${default_db_user}
  fi
  
  if [ -z "$db_password" ]; then
    db_password=${default_db_password}
  fi
  
  if [ -z "$db_schema" ]; then
    db_schema=${default_db_schema}
  fi

}

function create_replication_user() {
  print_and_log "Creating replication user $db_replication_user ..."
  mysql ${db_schema} <<EOF
grant replication slave on *.* to '${db_replication_user}'@'%' identified by '${db_replication_password}';
flush privileges;
EOF
}

function configure_mysql_for_replication() {
  print_and_log "Configuring DB for replication ..."
  
  local file=/etc/mysql/my.cnf

  # On old versions of MySQL/Percona, this file isn't there by
  # default, although it's read from /etc/init.d/mysql
  if [ ! -e $file ]; then
    cat > $file <<EOF
[mysqld]
EOF
  fi

  # replication log configuration of the master
  if [ $db_master -eq 1 ]; then
    local old="#server-id.*= 1"
    local new="server-id = 1"
    
    if [ $(grep ^"$old" $file | wc -l) -gt 0 ]; then
      sed -i "s~^$old~$new~g" $file
    elif [ $(grep ^"$new" $file | wc -l) -lt 1 ]; then
      echo "$new" >> $file
    fi
  
    old="bind-address.*= 127.0.0.1"
    new="# bind-address = 127.0.0.1"
    if [ $(grep ^"${old}" $file | wc -l) -gt 0 ]; then
      sed -i "s~^${old}~$new~g" $file
    fi
    
    old="#log_bin.*= /var/log/mysql/mysql-bin.log"
    new="log_bin = /var/log/mysql/mysql-bin.log"
    if [ $(grep ^"$old" $file | wc -l) -gt 0 ]; then
      sed -i "s~^${old}~${new}~g" $file
    elif [ $(grep ^"$new" $file | wc -l) -lt 1 ]; then
      echo "$new" >> $file
    fi
      
    old="#binlog_do_db.*=.*"
    new="binlog_do_db = ${db_schema}"

    if [ $(grep ^"$old" $file | wc -l) -gt 0 ]; then
      sed -i "s~^${old}~${new}~g" $file
    elif [ $(grep ^"$new" $file | wc -l) -lt 1 ]; then
      echo "$new" >> $file
    fi
    
    run /etc/init.d/mysql restart

    # report the needed settings for a slave
    local master_status=$(mysql $db_schema -e "show master status" | tail -1)
    local file=$(echo $master_status | cut -d' ' -f1)
    local position=$(echo $master_status | cut -d' ' -f2)
    local slave_conf_file=$HOME/ece-install-db-slave.conf.add
    cat > $slave_conf_file <<EOF
fai_db_master_log_file=$file
fai_db_master_log_position=$position
EOF
    local message="See $slave_conf_file for settings needed for the slave DB(s)"
    log $message
    add_next_step $message
  else
    local old="#server-id.*= 1"
    local new="server-id = 2"
    
    if [ $(grep ^"$old" $file | wc -l) -gt 0 ]; then
      sed -i "s~^$old~$new~g" $file
    elif [ $(grep ^"$new" $file | wc -l) -lt 1 ]; then
      echo "$new" >> $file
    fi
    
    run /etc/init.d/mysql restart
  fi
}



function set_slave_to_replicate_master() {
  print_and_log "Setting slave to replicate master DB @ $db_master_host ..."
  mysql ${db_schema} <<EOF
stop slave;

change master to
  master_host='${db_master_host}',
  master_user='${db_replication_user}',
  master_password='${db_replication_password}',
  master_log_file='${db_master_log_file}',
  master_log_pos=${db_master_log_position}
;

start slave;
EOF

  add_next_step "DB on $HOSTNAME replicates master DB @ ${db_master_host}"
}

  
