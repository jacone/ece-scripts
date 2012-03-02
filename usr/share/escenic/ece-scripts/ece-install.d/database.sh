# ece-install module for installing the database.

percona_rpm_release_version=0.0-1
percona_rpm_release_package_name=percona-release-${percona_rpm_release_version}
percona_rpm_release_url=http://www.percona.com/downloads/percona-release/$percona_rpm_release_package_name.x86_64.rpm
if [[ $(uname -m) != "x86_64" ]]; then
  percona_rpm_release_url=http://www.percona.com/downloads/percona-release/$percona_rpm_release_package_name.i386.rpm
fi

default_db_port=3306
default_db_host=localhost
default_db_user=ece5user
default_db_password=ece5password
default_db_schema=ece5db

## $1: optional parameter, binaries_only. If passed, $1=binaries_only,
##     the ECE DB schema is not set up. 
function install_database_server()
{
  print_and_log "Installing the database server on $HOSTNAME ..."

  source $(dirname $0)/drop-and-create-ecedb

  if [ $on_debian_or_derivative -eq 1 ]; then

    code_name=$(lsb_release -s -c)
    
    supported_code_name=0
    supported_list="lenny squeeze hardy lucid maverick"
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
        run gpg --keyserver hkp://keys.gnupg.net \
          --recv-keys 1C4CBDCDCD2EFD2A
        
        # There has been twice now, during six months, that
        # the key cannot be retrieved from
        # keys.gnupg.net. Therefore, we're checking if it
        # failed and if yes, force the package installation.
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
      packages="percona-server-server percona-server-client"
      force_packages=0
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

