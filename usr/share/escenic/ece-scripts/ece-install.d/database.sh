percona_rpm_release_version=0.0-1
percona_rpm_release_package_name=percona-release-${percona_rpm_release_version}
percona_rpm_release_url=http://www.percona.com/downloads/percona-release/$percona_rpm_release_package_name.x86_64.rpm
if [[ $(uname -m) != "x86_64" ]]; then
  percona_rpm_release_url=http://www.percona.com/downloads/percona-release/$percona_rpm_release_package_name.i386.rpm
fi

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
      install_packages_if_missing $packages
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
    run /etc/init.d/mysql start
  fi

  assert_pre_requisite mysql
  assert_pre_requisite mysqld

  if [ -z "$1" ]; then
    download_escenic_components
    set_up_engine_and_plugins
    set_up_ecedb
  fi
}

