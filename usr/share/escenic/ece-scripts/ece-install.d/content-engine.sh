# ece-install module Content Engine specific code.

function get_deploy_white_list() {
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

function get_publication_short_name_list() {
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
function install_ece_instance() {
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

    if [ $install_profile_number -ne $PROFILE_ANALYSIS_SERVER ]; then
      set_up_assembly_tool
    fi
  else
    verify_that_files_exist_and_are_readable \
      $ece_instance_ear_file \
      $ece_instance_conf_archive
  fi

  if [ $install_profile_number -ne $PROFILE_ANALYSIS_SERVER ]; then
    set_up_basic_nursery_configuration
    set_up_instance_specific_nursery_configuration
  fi
  
  set_up_app_server
  set_up_proper_logging_configuration

    # We set a WAR white list for all profiles except all in one
  if [ $install_profile_number -ne $PROFILE_ALL_IN_ONE -a \
    $install_profile_number -ne $PROFILE_ANALYSIS_SERVER ]; then
    local file=$escenic_conf_dir/ece-${instance_name}.conf
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

function set_up_engine_and_plugins() {
  if [ $ece_software_setup_completed -eq 1 ]; then
    return
  fi
  
  log "Setting up the Escenic Content Engine & its plugins ..."

  make_dir $escenic_root_dir
  cd $escenic_root_dir/

  for el in $technet_download_list; do
    if [ $(basename $el | \
      grep -E "^engine-[0-9]|^engine-trunk-SNAPSHOT|^engine-dist" | \
      wc -l) -gt 0 ]; then
      engine_dir=$(get_base_dir_from_bundle $download_dir/$(basename $el))
      engine_file=$(basename $el)
    fi
  done
  
  if [ -n "$engine_dir" -a ! -d "${engine_dir}" ]; then
    run unzip -q -u $download_dir/${engine_file}
    if [ -h engine ]; then
      run rm engine
    fi
    
    run ln -s ${engine_dir} engine
  else
    debug "${engine_dir} is already there, skipping to next step."
  fi

  # we now extract all the plugins. We extract them in $escenic_root_dir
  # as we want to re-use them between minor updates of ECE.
  cd $escenic_root_dir/
  for el in $download_dir/*.zip; do
    if [ $(basename $el | grep ^engine-.*.zip | wc -l) -gt 0 ]; then
      continue
    elif [ $(basename $el | grep ^assemblytool-.*.zip | wc -l) -gt 0 ]; then
      continue
    elif [ $(basename $el | grep ^jdk-.*.zip | wc -l) -gt 0 ]; then
      continue
    fi
    
    run unzip -q -u $el
  done

  ece_software_setup_completed=1
}

function set_up_assembly_tool() {
  log "Setting up the Assembly Tool ..."
  
  make_dir $escenic_root_dir/assemblytool/
  cd $escenic_root_dir/assemblytool/
  
  if [ -e $download_dir/assemblytool*zip ]; then
    run unzip -q -u $download_dir/assemblytool*zip
  fi

    # adding an instance layer to the Nursery configuration
  run cp -r $escenic_root_dir/engine/siteconfig/bootstrap-skeleton \
    $escenic_root_dir/assemblytool/conf
  run cd $escenic_root_dir/assemblytool/conf/
  run cp -r layers/host layers/instance
  cat > layers/instance/Files.properties <<EOF
\$class=neo.nursery.FileSystemDepot
fileSystemRoot = $escenic_conf_dir/engine/instance/\${com.escenic.instance}/
EOF
  echo "" >> Nursery.properties
  echo "layer.06 = /layers/instance/Layer" >> Nursery.properties

    # fixing the path to the Nursery configuration according to
    # escenic_conf_dir which may have been overridden by the user.
  for el in $(find $escenic_root_dir/assemblytool/conf -name Files.properties)
  do
    sed -i "s#/etc/escenic#${escenic_conf_dir}#g" $el
  done
  
    # set up which plugins to use
  cd $escenic_root_dir/assemblytool/
  make_dir plugins
  cd plugins
  find ../../ -maxdepth 1 -type d | \
    grep -v assemblytool | \
    while read directory; do
    if [ $directory = "../../" -o \
      $(echo $directory | grep widget-framework | wc -l) -gt 0 ]; then
      continue
    fi
    
        # nuisance to get the community engine and analysis engine,
        # but not the engine
    if [ $(echo $directory | \
      grep engine | \
      grep -v community | \
      grep -v analysis | \
      wc -l) -gt 0 ]; then
      continue
    fi

    make_ln $directory
  done

  run cd $escenic_root_dir/assemblytool/
  run ant -q initialize
  sed -i "s~#\ engine.root\ =\ \.~engine.root=${escenic_root_dir}/engine~g" \
    assemble.properties \
    1>>$log 2>>$log
  exit_on_error "sed on assemble.properties"
  
  sed -i "s~\#\# plugins\ =\ /path/to/plugins~plugins=${escenic_root_dir}/assemblytool/plugins~g" \
    assemble.properties \
    1>>$log 2>>$log
  exit_on_error "sed on assemble.properties"

  make_dir $escenic_root_dir/assemblytool/publications

    # set up user publication definitions
  if [ -n "${fai_publication_war_uri_list}" ]; then
    run cd $escenic_root_dir/assemblytool/publications
    
    for el in ${fai_publication_war_uri_list}; do
      if [[ $el == http* ]]; then
        run wget $wget_opts $el
      elif [[ $el == file://* ]]; then
        local file_with_path=$(echo $el | sed "s#file://##g")
        run cp $file_with_path .
      else
        run cp ${el} .
      fi
      
      if [ ! -e $(basename $el) ]; then
        print_and_log "Failed to get user publication $el."
        print_and_log "I will skip it and continue to the next one."
        continue
      fi

      local short_name=$(basename $el .war)
      cat > ${short_name}.properties <<EOF
name: ${short_name}
source-war: ${short_name}.war
context-root: ${short_name}
EOF
    done
  fi
}

function set_up_basic_nursery_configuration() {
  print_and_log "Setting up basic Nursery configuration ..."

    # we always copy the default plugin configuration (even if there
    # is an archive)
  for el in $escenic_root_dir/assemblytool/plugins/*; do
    if [ ! -d $el/misc/siteconfig/ ]; then
      continue
    fi
    run cp -r $el/misc/siteconfig/* $common_nursery_dir/
  done

    # Then we see if we're using configuration archives, if yes, use
    # the JAAS and Nursery configuraiton from here.
  if [ $(is_using_conf_archive) -eq 1 ]; then
    print_and_log "Using the supplied Nursery & JAAS configuration from" 
    print_and_log "bundle: $ece_instance_conf_archive"
    local a_tmp_dir=$(mktemp -d)
    
    if [ ! -d ${a_tmp_dir}/engine/security ]; then
      print "Archive $ece_instance_conf_archive doesn't have JAAS config,"
      print "I'll use standard JAAS (engine/security) instead."
      run cp -r $escenic_root_dir/engine/security/ $common_nursery_dir/
    fi
    
    run cd $a_tmp_dir
    run tar xzf $ece_instance_conf_archive
    run cp -r engine/siteconfig/config-skeleton/* $common_nursery_dir/
  else
    run cp -r $escenic_root_dir/engine/siteconfig/config-skeleton/* \
      $common_nursery_dir/
    run cp -r $escenic_root_dir/engine/security/ $common_nursery_dir/
  fi

  if [ -n "${a_tmp_dir}" ]; then
    run rm -rf ${a_tmp_dir}
  fi
  
  public_host_name=$HOSTNAME:${appserver_port}
  if [ $fai_enabled -eq 1 ]; then
    if [ -n "$fai_public_host_name" ]; then
      public_host_name=$fai_public_host_name
    fi
  else
    print "What is the public address of your website?"
    print "Press ENTER to use the default ($public_host_name)"
    echo -n "Your choice [$public_host_name]> "
    read user_host_name
  fi

  if [ -n "$user_host_name" ]; then
    public_host_name=$user_host_name
  fi
  
  cat > $common_nursery_dir/ServerConfig.properties <<EOF
databaseProductName=MySQL
filePublicationRoot=$escenic_data_dir/engine/
webPublicationRoot=http://${public_host_name}/

# These two LDAP settings can be ignored on systems with ECE >= 5.3
ldapProductName=OpenLdap
ldapProductVersion=2.2.26
EOF
  cat > $common_nursery_dir/neo/io/managers/ContentManager.properties <<EOF
readConnector=/connector/ReadConnector
updateConnector=/connector/UpdateConnector
EOF

  file=$common_nursery_dir/com/escenic/community/CommunityEngine.properties
  if [ -w ${file} ]; then
    sed -i 's/jdbc\/ecome/jdbc\/ECE_UPDATE_DS/g' $file
    exit_on_error "sed on $file"
  elif [ ! -e ${file} ]; then
    print_and_log "I Could not find an ECOME configuration file,"
    print_and_log "I assume you have not installed Community Engine."
  else
    print_and_log "Could not write to ${file},"
    print_and_log "Community Engine might not work because of this. "
    remove_pid_and_exit_in_error
  fi

  file=$common_nursery_dir/com/escenic/webstart/StudioConfig.properties
  cat >> $file <<EOF

# We set this to get around a missing feature in Varnish, see:
# https://www.varnish-cache.org/trac/wiki/Future_Feature#Chunkedencodingclientrequests
# For Escenic-ites, see: VF-3480
property.com.escenic.client.chunked=false
EOF
}

function set_up_instance_specific_nursery_configuration() {
  print_and_log "Setting up instance specific Nursery configuration ..."
  
  for el in $escenic_conf_dir/engine/instance/*; do
    i=$(( i + 1 ))
    if [ $(basename $el) = $instance_name ]; then
      rmi_port="8${i}23"
      run echo "port=$rmi_port" > $el/RMI.properties
    fi
  done

  nursery_context=neo/io/managers/HubConnectionManager.properties
  file=$escenic_conf_dir/engine/instance/$instance_name/$nursery_context
  make_dir $(dirname $file)
  
    # we don't touch it if the file already exists.
  if [ ! -e $file ]; then
    run echo "hostname=$HOSTNAME" >> $file
  fi
}

function set_up_proper_logging_configuration() {
  print_and_log "Setting up proper log4j & Java logging configuration ..."
  
  cat > $common_nursery_dir/trace.properties <<EOF
log4j.rootLogger=ERROR, ECELOG
log4j.appender.ECELOG=org.apache.log4j.DailyRollingFileAppender
log4j.appender.ECELOG.File=$escenic_log_dir/\${escenic.server}-messages
log4j.appender.ECELOG.layout=org.apache.log4j.PatternLayout
log4j.appender.ECELOG.layout.ConversionPattern=%d %5p [%t] %x (%c) %m%n
EOF
  cd $tomcat_base/lib/
  make_ln $common_nursery_dir/trace.properties
  run ln -sf trace.properties log4j.properies

    # since the solr webapp otherwise will pollute our logs, we ask
    # Tomcat specifically to make it log to dedicated logger.
  if [ $install_profile_number -eq $PROFILE_SEARCH_SERVER -o \
    $install_profile_number -eq $PROFILE_ALL_IN_ONE ]; then
    cat > $tomcat_base/conf/logging.properties <<EOF
handlers = 1catalina.org.apache.juli.FileHandler, 2localhost.org.apache.juli.FileHandler, java.util.logging.ConsoleHandler, 6localhost.org.apache.juli.FileHandler

.handlers = 1catalina.org.apache.juli.FileHandler, java.util.logging.ConsoleHandler

1catalina.org.apache.juli.FileHandler.level = FINE
1catalina.org.apache.juli.FileHandler.directory = \$\{catalina.base\}/logs
1catalina.org.apache.juli.FileHandler.prefix = catalina.

2localhost.org.apache.juli.FileHandler.level = FINE
2localhost.org.apache.juli.FileHandler.directory = \$\{catalina.base\}/logs
2localhost.org.apache.juli.FileHandler.prefix = localhost.

java.util.logging.ConsoleHandler.level = FINE
java.util.logging.ConsoleHandler.formatter = java.util.logging.SimpleFormatter

6localhost.org.apache.juli.FileHandler.level = FINE
6localhost.org.apache.juli.FileHandler.directory = $escenic_log_dir
6localhost.org.apache.juli.FileHandler.prefix = solr.

org.apache.solr.level=INFO
org.apache.solr.handlers=6localhost.org.apache.juli.FileHandler

org.apache.catalina.core.ContainerBase.[Catalina].[localhost].level = INFO
org.apache.catalina.core.ContainerBase.[Catalina].[localhost].handlers = 2localhost.org.apache.juli.FileHandler
EOF
  else
    run cp $tomcat_home/conf/logging.properties $tomcat_base/conf
  fi
}

# Installs third party packages needed by the ECE (i.e. Java related).
# Also see install_common_os_packages for packages common to all
# servers in the architecture.
function install_ece_third_party_packages
{
  run_hook install_ece_third_party_packages.preinst
  print_and_log "Installing 3rd party packages needed by $type instances"
  
  if [ $on_debian_or_derivative -eq 1 ]; then
    if [ $on_ubuntu -eq 1 ]; then
            # Sun Java was removed in Ubuntu in 11.10 and later also
            # from LTS 10.04, hence Hardy is the last one with these
            # packges now (2012-02-20 11:22)
      local version_needs_local_java_deb=1004
      local version=$(lsb_release -s -r | sed "s#\.##g")
      
      add_apt_source \
        "deb http://archive.canonical.com/ $(lsb_release -s -c) partner"
    elif [ $on_debian -eq 1 ]; then
      code_name=$(lsb_release -s -c)
      has_non_free=$(grep $(lsb_release -s -c) \
        /etc/apt/sources.list | \
        egrep -v "^#|deb-src" | \
        grep -v security | \
        grep non-free | \
        wc -l)
      if [ $has_non_free -eq 0 ]; then
        add_apt_source "deb http://ftp.${mirror_country_suffix}.debian.org/debian/ $(lsb_release -s -c) contrib non-free"
      fi

      # Sun Java will be removed in the next Debian stable,
      # wheezy (either 6.1 or 7.0 not announced yet, current in
      # squeeze/6.0, hence setting 6.1 here).
      local version_needs_local_java_deb=610
      local version=$(lsb_release -s -r | sed "s#\.##g")
    fi
    
    if [ $version -ge $version_needs_local_java_deb -a \
      $(has_sun_java_installed) -eq 0 ]; then
      create_java_deb_packages_and_repo
    fi
    
    echo "sun-java6-jdk shared/accepted-sun-dlj-v1-1 boolean true" | \
      debconf-set-selections

        # install sun-java6-jdk first so that ant doesn't pull down OpenJDK
    local packages="sun-java6-jdk"
    install_packages_if_missing $packages

    packages="
          ant
          ant-contrib
          ant-optional
          libapr1
          libtcnative-1
          libmysql-java
          memcached
          wget"
  elif [ $on_redhat_or_derivative -eq 1 ]; then
    packages="
        ant
        ant-contrib
        ant-nodeps
        apr
        memcached
        mysql-connector-java
        wget
    "

    # TODO no tomcat APR wrappers in official repositories
    install_sun_java_on_redhat
  fi
  
  install_packages_if_missing $packages
  
  for el in ant java; do
    assert_pre_requisite $el
  done
}
