# ece-install module for installing the database.

# Setting the correct URLs for the percona releas (bootstrap) RPM package.
percona_rpm_release_version=0.0-1
percona_rpm_release_package_name=percona-release-${percona_rpm_release_version}
percona_rpm_release_url=http://www.percona.com/downloads/percona-release/$percona_rpm_release_package_name.x86_64.rpm
if [[ $(uname -m) != "x86_64" ]]; then
  percona_rpm_release_url=http://www.percona.com/downloads/percona-release/$percona_rpm_release_package_name.i386.rpm
fi

function get_percona_supported_list() {
  curl -s http://repo.percona.com/apt/dists/ | \
    grep "DIR" | \
    sed -e 's#.*href=\"\(.*\)\">.*</a>.*#\1#' -e 's#/##g' | \
    grep -v apt
}

function set_up_percona_repository_if_possible() {
  if [ $on_debian_or_derivative -eq 1 -a ${fai_db_sql_only-0} -eq 0 ]; then
    local code_name=$(lsb_release -s -c)
    local supported_code_name=0
    local supported_list=$(get_percona_supported_list)
    
    for el in $supported_list; do
      if [[ $code_name == $el ]]; then
        supported_code_name=1
      fi
    done

    # some how, this is to install Percona 5.5
    if [ -e /var/lib/mysql/debian-*.flag ]; then
      run rm /var/lib/mysql/debian-*.flag
    fi

    if [ $supported_code_name -eq 1 ]; then
      print_and_log "Setting Up the Percona repository ..."

      if [ $(apt-key list| grep CD2EFD2A | wc -l) -lt 1 ]; then
        # this CANNOT be run in the run wrapper since it often fails,
        # see comment below.
        gpg --keyserver hkp://keys.gnupg.net:80 \
          --recv-keys 1C4CBDCDCD2EFD2A \
          1>>$log 2>>$log

        # There has been three times now, during six months, that the
        # key cannot be retrieved from keys.gnupg.net. Therefore,
        # we're checking if it failed and if yes, force the package
        # installation.
        if [ $? -gt 0 ]; then
          print_and_log "Failed retrieving the Percona key from keys.gnupg.net"
          print_and_log "Will install the Percona packages without the GPG key"
          force_packages=1
        else
          gpg --armor \
            -a \
            --export 1C4CBDCDCD2EFD2A | \
            apt-key add - \
            1>>$log 2>>$log
        fi

      fi

      add_apt_source "deb http://repo.percona.com/apt ${code_name} main"
      run apt-get update
      mysql_server_packages="percona-server-server"
      mysql_client_packages="percona-server-client"
      
      leave_trail "trail_db_vendor=percona"
    else
      print_and_log "The Percona APT repsository doesn't have packages"
      print_and_log "for your Debian (or derivative) version with code"
      print_and_log "name $code_name. "
      print_and_log "I will use vanilla MySQL instead."

      mysql_server_packages="mysql-server libmysqlclient16"
      mysql_client_packages="mysql-client libmysqlclient16"
      
      leave_trail "trail_db_vendor=mysql"
    fi
  elif [ $on_redhat_or_derivative -eq 1 ]; then
    print_and_log "Settnig up the Percona repository ..."

    if [ $(rpm -qa | grep $percona_rpm_release_package_name | wc -l) -lt 1 ]; then
      run rpm -Uhv $percona_rpm_release_url
    fi

    mysql_server_packages="Percona-Server-server-55 Percona-Server-shared-compat"
    mysql_client_packages="Percona-Server-client-55 Percona-Server-shared-compat"
  fi
}

function install_mysql_server_software() {
  set_up_percona_repository_if_possible

  if [ ${fai_db_sql_only-0} -eq 0 ]; then
    install_packages_if_missing $mysql_server_packages
    force_packages=0

    if [ $on_redhat_or_derivative -eq 1 ]; then
      run chkconfig --level 35 mysql on
      run /etc/init.d/mysql restart
    fi

    assert_pre_requisite mysqld
  else
    # when only running the SQL scripts, typically when using Amazon
    # RDS, we need the mysql-client.
    install_packages_if_missing $mysql_client_packages
  fi  
}

function install_mysql_client_software() {
  set_up_percona_repository_if_possible
  install_packages_if_missing $mysql_client_packages
  assert_pre_requisite mysql
}

## $1: optional parameter, binaries_only. If passed, $1=binaries_only,
##     the ECE DB schema is not set up.
function install_database_server() {
  print_and_log "Installing database server on $HOSTNAME ..."

  if [ ${fai_db_sql_only-0} -eq 0 ]; then
    install_mysql_server_software
    install_mysql_client_software
    force_packages=0

    if [ $on_redhat_or_derivative -eq 1 ]; then
      run chkconfig --level 35 mysql on
      run /etc/init.d/mysql restart
    fi

    assert_pre_requisite mysqld
  else
    # when only running the SQL scripts, typically when using Amazon
    # RDS, we need the mysql-client.
    install_mysql_client_software
   fi

  assert_pre_requisite mysql

  if [ -z "$1" ]; then
    download_escenic_components
    set_up_engine_and_plugins
    set_up_ecedb
  fi

  if [ ${db_replication-0} -eq 1 ]; then
    if [ $db_master -eq 1 ]; then
      create_replication_user
    fi
    configure_mysql_for_replication

    if [ $db_master -eq 0 ]; then
      set_slave_to_replicate_master
    fi
  fi

  leave_db_trails
}

function set_ecedb_conf() {
  # the user may override standard DB settings in ece-install.conf
  set_db_settings_from_fai_conf
  set_db_defaults_if_not_set
  ece_home=${escenic_root_dir}/engine
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

  set_ecedb_conf
  pre_install_new_ecedb
  create_ecedb

  run cd ~/
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

  if [ $db_master -eq 0 -a $db_replication -eq 1 ]; then
    ensure_variable_is_set fai_db_master_host

    if [ -z $fai_db_master_backup ]; then
      ensure_variable_is_set \
        fai_db_master_log_file \
        fai_db_master_log_position
    fi
  fi
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
  if [ $on_redhat_or_derivative -eq 1 ]; then
    file=/etc/my.cnf
  fi

  # On old versions of MySQL/Percona, this file isn't there by
  # default, although it's read from /etc/init.d/mysql
  if [ ! -e $file ]; then
    cat > $file <<EOF
[mysqld]
EOF
  fi

  set_common_replication_settings $file
  
  # replication log configuration of the master
  if [ $db_master -eq 1 ]; then
    old="#server-id.*=.*1"
    new="server-id=1"

    if [ $(grep ^"$old" $file | wc -l) -gt 0 ]; then
      sed -i "s~^$old~$new~g" $file
    elif [ $(grep ^"$new" $file | wc -l) -lt 1 ]; then
      echo "$new" >> $file
    fi

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
    old="#server-id.*= 1"
    new="server-id=2"

    if [ $(grep ^"$old" $file | wc -l) -gt 0 ]; then
      sed -i "s~^$old~$new~g" $file
    elif [ $(grep ^"$new" $file | wc -l) -lt 1 ]; then
      echo "$new" >> $file
    fi

  fi
  
  run /etc/init.d/mysql restart
}

## We set up mysql listening to the external servers and binary logs
## on both the master and slave since we want to be able easily fail
## over to the slave as master (and back again).
function set_common_replication_settings() {
  local file=$1
  
  local old="bind-address.*= 127.0.0.1"
  local new="# bind-address = 127.0.0.1"
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
}  

function set_slave_to_replicate_master() {
  print_and_log "Setting slave to replicate master DB @ $db_master_host ..."

  # basing the replication off a fresh master, no backup
  if [ -z ${fai_db_master_backup} ]; then
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
  else
    if [ ! -r ${fai_db_master_backup} ]; then
      print_and_log "Cannot set up slave" \
        $fai_db_master_backup \
        "doesn't exist"
      remove_pid_and_exit_in_error
    fi
    
    print_and_log "Setting up slave based on master backup"
    zcat ${fai_db_master_backup} | mysql ${db_schema}
    
    local file_and_pos=$(
      zcat ${fai_db_master_backup} | \
        head -n 30 | \
        grep ^CHANGE | \
        cut -d' ' -f4- | \
        sed 's/\;$//g'
    )

    print_and_log "Setting master back to $db_master_host ..."
    mysql ${db_schema} <<EOF
stop slave;

change master to
  master_host='${db_master_host}',
  master_user='${db_replication_user}',
  master_password='${db_replication_password}',
  ${file_and_pos}
;
start slave;
EOF

  fi
  
  add_next_step "DB on $HOSTNAME replicates master DB @ ${db_master_host}"
}

drop_db_first=0
db_user=ece5user
db_password=ece5password
db_schema=ece5db
db_host=localhost
ece_home=/opt/escenic/engine
db_product=mysql

# oracle specific settings
create_oracle_user=0
tablespace_data=ece5_data
tablespace_index=ece5_index
oracle_data_dir=/home/oracle/app/oracle/oradata/orcl

function create_oracle_ece_user() {
  sqlplus /nolog << EOF
      connect /as sysdba;
      create user $db_user
        identified by $db_password
        default tablespace $tablespace_data
        quota unlimited on $tablespace_data;
      grant connect to $db_user;
      grant resource to $db_user;
      grant create any view to $db_user;
      grant execute on ctx_ddl to $db_user;
EOF
}

## $1 is the file
function run_db_script_file() {
  log "Running $1 ..."
  local file=$1
  if [ $db_product = "oracle" ]; then
    sqlplus $db_user/$db_password @$file
  else
    mysql -u $db_user -p$db_password -h $db_host $db_schema < $file
  fi
}

function run_db_scripts() {
  for el in $db_fn_list; do
    local file=$1/$el.sql
    if [ -e $file ]; then
      run_db_script_file $file
    fi
    exit_on_error "running $el"
  done
}

function pre_install_new_ecedb() {
  set_ecedb_conf

  if [ $create_oracle_user -eq 1 ]; then
    create_oracle_ece_user
  fi

  if [ $drop_db_first -eq 1 ]; then
    log "dropping and re-creating $db_schema on $db_host ..."
    if [ $db_product = "mysql" ]; then
      mysql -h $db_host << EOF
drop database $db_schema;
EOF
    else
      sqlplus /nolog << EOF
connect /as sysdba;
drop tablespace $tablespace_data including contents;
drop tablespace $tablespace_index including contents;
EOF
    fi
  fi
}

function create_schema() {
    # we first create the DB (or, if drop_db_first is 1, we've just
    # dropped it above) before running the SQL scripts.
  if [ $db_product = "mysql" ]; then
    print_and_log "Creating DB $db_schema on $HOSTNAME ..."
    mysql -h $db_host << EOF
create database $db_schema character set utf8 collate utf8_general_ci;
grant all on $db_schema.* to $db_user@'%' identified by '$db_password';
grant all on $db_schema.* to $db_user@'localhost' identified by '$db_password';
EOF
    exit_on_error "create db"
  else
    sqlplus /nolog << EOF
connect /as sysdba;

create tablespace $tablespace_data
datafile '$oracle_data_dir/${tablespace_data}01.dbf'
size 200M reuse
autoextend on next 50M maxsize 2047M
extent management local autoallocate;

create tablespace $tablespace_index
datafile '$oracle_data_dir/${tablespace_index}01.dbf'
size 100M reuse
autoextend on next 50M maxsize 2047M
extent management local autoallocate;
EOF
  fi
}

db_fn_list="
tables
tables-stats
views
constants
constants-stats
constraints
indexes
history
"

function create_ecedb() {
  if [ ${fai_db_sql_only-0} -eq 0 ]; then
    create_schema
  fi

  if [ ${fai_db_schema_only-0} -eq 1 ]; then
    print_and_log "Not running the ECE & plugin SQL files as you requested."
    return
  fi

  run_db_scripts $ece_home/database/$db_product

  if [ -e $ece_home/plugins ]; then
    for el in `find -L $ece_home/plugins -name $db_product`; do
      run_db_scripts $el
    done
  fi

  run_eae_scripts_if_available

  log "${id} ${db_product}://${db_host}/${db_schema} is now ready for ${db_user}/${db_password}"
}

## will run the EAE scripts if they are availabe.
function run_eae_scripts_if_available() {
      
  for el in $(find $escenic_root_dir -name eae-${db_product}.sql | \
    grep -v upgrade | \
    sort -r | \
    head -1); do
    work_around_eae_bug_stats-76 $el
    run_db_script_file $el
  done
}

## Workaround for: https://jira.vizrt.com/browse/STATS-76
## 
## $1 is the SQL file
function work_around_eae_bug_stats-76() {
  print_and_log "Fixing $1 ..."
  grep -i -v ^'drop index' $1 > $1.tmp
  mv $1.tmp $1
}

function leave_db_trails() {
  leave_trail "trail_db_host=${HOSTNAME}"
  leave_trail "trail_db_port=${db_port-${default_db_port}}"

  if [ ${db_master-0} -eq 1 ]; then
    leave_trail "trail_db_master_host=${fai_db_master_host-${default_db_host}}"
    leave_trail "trail_db_master_port=${fai_db_master_port-${default_db_port}}"
  elif [ ${fai_db_replication-0} -eq 1 ]; then
    leave_trail "trail_db_slave_host=${fai_db_host-${default_db_host}}"
    leave_trail "trail_db_slave_port=${fai_db_port-${default_db_port}}"
  else
    leave_trail "trail_db_master_host=${fai_db_host-${default_db_host}}"
    leave_trail "trail_db_master_port=${fai_db_master_port-${default_db_port}}"
  fi
}

## Yes, calling the method name is a bit over the top, but it's
## because it's an own installation profile (and everything that
## *sounds* grand *is* grand, right?)
function install_db_backup_server() {
  install_mysql_client_software
  assert_pre_requisite mysqldump
  make_dir ${escenic_backups_dir}
  local file=/etc/cron.daily/${db_schema}-backup
  cat > $file <<EOF
#! /usr/bin/env bash

## Backup of the $db_schema DB
## Set up by $(basename $0) @ $(date)

fn=\$(date --iso)-\${HOSTNAME}-${db_schema}.sql.gz
log=/var/log/\$(basename \$0).log

# (1) make backup

# we must run as the root user here, hence not using user and regular
# password:
#  -u $db_user \\
#  -p$db_password \\

mysqldump \\
  --master-data \\
  --single-transaction \\
  -h $db_host \\
  $db_schema | \\
  gzip -9 - \\
  > ${escenic_backups_dir}/\${fn}

# (2) make sure the backup went OK 
# copy of pipe status since it's volatile
pipe_status=(\${PIPESTATUS[@]})

for (( i = 0; i < \${#pipe_status[@]}; i++ )); do
  if [ \${pipe_status[\$i]} -ne 0 ]; then
    echo "Command #\$(( \${i} + 1 )) in \$0 had exit code \${pipe_status[\$i]} :-(" >> \$log
    exit 1
  fi
done

# (3) make a symlink to the latest backup to make it easy for
# monitoring & operators to know what's the latest backup without
# using any brain power.
(
  cd ${escenic_backups_dir}
  ln -sf \${fn} latest-\${HOSTNAME}-\${db_schema}-backup.sql.gz
)
EOF

  run chmod 700 $file
  add_next_step "Daily backup of the $db_schema DB is provided by $file"

  leave_trail "trail_db_daily_backup_host=${HOSTNAME}"
}
