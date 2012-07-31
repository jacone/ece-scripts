function set_up_app_server()
{
  print_and_log "Setting up the application server ..."

  if [ $fai_enabled -eq 0 ]; then
    print "On which ports do you wish to run the app server on?"
    print "Press ENTER to accept the default ports"
    print "or enter: <port> <shutdown port> <redirect port>:"
    echo -n "Your choice [8080 8005 8443]> "
    read user_ports
    
    if [ -n "$user_ports" ]; then
      read appserver_port shutdown_port redirect_port <<< $user_ports
    fi
  else
    if [ $install_profile_number -eq $PROFILE_EDITORIAL_SERVER ]; then
      appserver_port=${fai_editor_port-8080}
      shutdown_port=${fai_editor_shutdown-8005}
      redirect_port=${fai_editor_redirect-8443}
    elif [ $install_profile_number -eq $PROFILE_PRESENTATION_SERVER ]; then
      appserver_port=${fai_presentation_port-8080}
      shutdown_port=${fai_presentation_shutdown-8005}
      redirect_port=${fai_presentation_redirect-8443}
    elif [ $install_profile_number -eq $PROFILE_SEARCH_SERVER ]; then
      appserver_port=${fai_search_port-8080}
      shutdown_port=${fai_search_shutdown-8005}
      redirect_port=${fai_search_redirect-8443}
    elif [ $install_profile_number -eq $PROFILE_ANALYSIS_SERVER ]; then
      appserver_port=${fai_analysis_port-8080}
      shutdown_port=${fai_analysis_shutdown-8005}
      redirect_port=${fai_analysis_redirect-8443}
    fi
  fi

  if [ -z "$appserver_port" ]; then
    appserver_port=8080
  fi
  if [ -z "$shutdown_port" ]; then
    shutdown_port=8005
  fi
  if [ -z "$redirect_port" ]; then
    redirect_port=8443
  fi
  
  if [ $fai_enabled -eq 0 ]; then
    print "Another question: Where does the database run?"
    print "Press ENTER to accept the default " \
      "($HOSTNAME:${default_db_port}:${default_db_schema})"
    print "Or enter: <host>:<port>:<schema>, e.g.: 'db1:${default_db_port}:mydb'"
    echo -n "Your choice [$HOSTNAME:${default_db_port}:${default_db_schema}]> "
    read user_database

    db_host=$(echo $user_database | cut -d':' -f1)
    db_port=$(echo $user_database | cut -d':' -f2)
    db_schema=$(echo $user_database | cut -d':' -f3)
  else
    set_db_settings_from_fai_conf
  fi

  set_db_defaults_if_not_set

  if [ $fai_enabled -eq 0 ]; then
    print "Awfully sorry to bug you with so many questions, but:"
    print "What's the URI to the indexer-webservice? (this is typically"
    print "something like http://editor1/indexer-webservice/index/)"
    echo -n "Your choice [http://${HOSTNAME}:8080/indexer-webservice/index/]> "
    read user_indexer_ws_uri
  else
    user_indexer_ws_uri=${fai_search_indexer_ws_uri}
  fi

  if [ -n "$user_indexer_ws_uri" ]; then
    indexer_ws_uri=$user_indexer_ws_uri
  else
    indexer_ws_uri=http://${HOSTNAME}:${appserver_port}/indexer-webservice/index/
  fi
  
  
  if [ $fai_enabled -eq 0 ]; then
    print "Last question, I promise!: Where does the search instance run?"
    print "Press ENTER to accept the default ($HOSTNAME:8080)"
    print "or enter: <host>:<port>, e.g.: 'search1:8080'"
    print "If you're in doubt, just press ENTER :-)"
    echo -n "Your choice [$HOSTNAME:8080]> "
    read user_search
  else
    user_search=$(get_conf_value fai_search_host)
    if [ -n "${user_search}" ]; then
      user_search=${user_search}":"$(get_conf_value fai_search_port)
    fi
  fi

  if [ -z "$user_search" ]; then
    search_host=$HOSTNAME
    search_port=8080
  else
    search_host=$(echo $user_search | cut -d':' -f1)
    search_port=$(echo $user_search | cut -d':' -f2)
  fi

  download_tomcat $download_dir
  local tomcat_archive=$(
    find $download_dir \
      -name "apache-tomcat*.tar.gz" | \
      tail -1
  )
  tomcat_dir=$(get_base_dir_from_bundle $tomcat_archive)
  
  run cd $appserver_parent_dir
  run tar xzf $download_dir/${tomcat_dir}.tar.gz

  if [ -e tomcat ]; then
    run rm tomcat
  fi
  run ln -sf ${tomcat_dir} tomcat
  
  tomcat_home=${appserver_parent_dir}/tomcat   
  tomcat_base=${appserver_parent_dir}/tomcat-${instance_name}
  make_dir $tomcat_base

  run cp -r ${appserver_parent_dir}/${tomcat_dir}/conf $tomcat_base
  for el in bin escenic/lib lib work logs temp webapps; do
    make_dir $tomcat_base/$el
  done

  set_ece_instance_conf tomcat_base $tomcat_base   
  set_ece_instance_conf tomcat_home $tomcat_home
  set_ece_instance_conf appserver_port $appserver_port
  set_appropriate_jvm_heap_sizes
  
  run cd $tomcat_base/lib
  make_ln $jdbc_driver

  # it's important to append (and not pre-pend) the ECE libraries so
  # that things put it in the standard loader behaves as expected,
  # such as log4j configuration put in ${tomcat.base}/lib.
  file=$tomcat_base/conf/catalina.properties
  common_loader=$(grep ^common.loader $file)
  escaped_common_loader=$(get_escaped_bash_string ${common_loader})
  escenic_loader=",$\{catalina.base\}/escenic/lib/*.jar"
  old=$(get_escaped_bash_string ${common_loader})
  new=${escaped_common_loader}$(get_escaped_bash_string ${escenic_loader})
  run sed -i "s#${old}#${new}#g" $file 
  
  cat > $tomcat_base/conf/server.xml <<EOF
<?xml version='1.0' encoding='utf-8'?>
<Server port="$shutdown_port" shutdown="SHUTDOWN">
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
  <Listener className="org.apache.catalina.core.JasperListener" />
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
  <Listener className="org.apache.catalina.mbeans.ServerLifecycleListener" />
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />

  <GlobalNamingResources>
    <Resource name="UserDatabase"
              auth="Container"
              type="org.apache.catalina.UserDatabase"
              description="User database that can be updated and saved"
              factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
              pathname="conf/tomcat-users.xml"
    />
EOF
  if [ $install_profile_number -ne $PROFILE_ANALYSIS_SERVER \
    -a $install_profile_number -ne $PROFILE_SEARCH_SERVER ]; then
    cat >> $tomcat_base/conf/server.xml <<EOF
    <Resource
        name="jdbc/ECE_READ_DS"
        auth="Container"
        type="javax.sql.DataSource"
        maxActive="400"
        maxIdle="8"
        maxWait="2000"
        initialSize="20"
        username="${db_user}"
        password="${db_password}"
        driverClassName="com.mysql.jdbc.Driver"
        url="jdbc:mysql://${db_host}:${db_port}/${db_schema}?autoReconnect=true&amp;useUnicode=true&amp;characterEncoding=UTF-8&amp;characterSetResults=UTF-8"
        removeAbandoned="true"
        removeAbandonedTimeout="120"
        logAbandoned="true"
        testOnBorrow="false"
        testOnReturn="false"
        timeBetweenEvictionRunsMillis="60000"
        numTestsPerEvictionRun="5"
        minEvictableIdleTimeMillis="30000"
        testWhileIdle="true"
        validationQuery="select now()"
    />
    <Resource
        name="jdbc/ECE_UPDATE_DS"
        auth="Container"
        type="javax.sql.DataSource"
        maxActive="100"
        maxIdle="8"
        maxWait="2000"
        initialSize="20"
        username="${db_user}"
        password="${db_password}"
        driverClassName="com.mysql.jdbc.Driver"
        url="jdbc:mysql://${db_host}:${db_port}/${db_schema}?autoReconnect=true&amp;useUnicode=true&amp;characterEncoding=UTF-8&amp;characterSetResults=UTF-8"
        removeAbandoned="true"
        removeAbandonedTimeout="120"
        logAbandoned="true"
        testOnBorrow="false"
        testOnReturn="false"
        timeBetweenEvictionRunsMillis="60000"
        numTestsPerEvictionRun="5"
        minEvictableIdleTimeMillis="30000"
        testWhileIdle="true"
        validationQuery="select now()"
    />
EOF
  elif [ $install_profile_number -eq $PROFILE_ANALYSIS_SERVER ]; then
    cat >> $tomcat_base/conf/server.xml <<EOF
    <Resource
        name="jdbc/eae-qs/qs"
        auth="Container"
        type="javax.sql.DataSource"
        maxActive="400"
        maxIdle="8"
        maxWait="2000"
        initialSize="20"
        username="${db_user}"
        password="${db_password}"
        driverClassName="com.mysql.jdbc.Driver"
        url="jdbc:mysql://${db_host}:${db_port}/${db_schema}?autoReconnect=true&amp;useUnicode=true&amp;characterEncoding=UTF-8&amp;characterSetResults=UTF-8"
        removeAbandoned="true"
        removeAbandonedTimeout="120"
        logAbandoned="true"
        testOnBorrow="false"
        testOnReturn="false"
        timeBetweenEvictionRunsMillis="60000"
        numTestsPerEvictionRun="5"
        minEvictableIdleTimeMillis="30000"
        testWhileIdle="true"
        validationQuery="select now()"
    />
    <Resource
        name="jdbc/eae-logger/logger"
        auth="Container"
        type="javax.sql.DataSource"
        maxActive="100"
        maxIdle="8"
        maxWait="2000"
        initialSize="20"
        username="${db_user}"
        password="${db_password}"
        driverClassName="com.mysql.jdbc.Driver"
        url="jdbc:mysql://${db_host}:${db_port}/${db_schema}?autoReconnect=true&amp;useUnicode=true&amp;characterEncoding=UTF-8&amp;characterSetResults=UTF-8"
        removeAbandoned="true"
        removeAbandonedTimeout="120"
        logAbandoned="true"
        testOnBorrow="false"
        testOnReturn="false"
        timeBetweenEvictionRunsMillis="60000"
        numTestsPerEvictionRun="5"
        minEvictableIdleTimeMillis="30000"
        testWhileIdle="true"
        validationQuery="select now()"
    />
EOF
  fi
  
  cat >> $tomcat_base/conf/server.xml <<EOF
  </GlobalNamingResources>

  <Service name="Catalina">
    <Connector port="${appserver_port}"
               protocol="HTTP/1.1" 
               connectionTimeout="20000" 
               URIEncoding="UTF-8"
               compression="on"
               redirectPort="${redirect_port}"
    />
    <Engine name="Catalina" defaultHost="localhost" jvmRoute="jvm1">
      <Valve className="org.apache.catalina.valves.AccessLogValve"
             prefix="access."
             suffix=".log"
             pattern="common"/>
      <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
             resourceName="UserDatabase"/>
      <Host name="localhost"
            appBase="webapps"
            unpackWARs="true"
            autoDeploy="true"
            xmlValidation="false"
            xmlNamespaceAware="false">
      </Host>
EOF
  if [[ ($install_profile_number == $PROFILE_EDITORIAL_SERVER || \
    $install_profile_number == $PROFILE_PRESENTATION_SERVER || \
    $install_profile_number == $PROFILE_ALL_IN_ONE) && \
    -n "$fai_publication_domain_mapping_list" ]]; then

    for el in ${fai_publication_domain_mapping_list}; do
      local old_ifs=$IFS
      # the entries in the fai_publication_domain_mapping_list are on
      # the form: <publication>#<domain>
      IFS='#'
      read publication domain <<< "$el"
      IFS=$old_ifs

      ensure_domain_is_known_to_local_host ${domain}
      
      cat >> $tomcat_base/conf/server.xml <<EOF
      <Host name="${domain}" appBase="webapps" autoDeploy="false">
        <Context displayName="${domain}"
                 docBase="${publication}"
                 path=""
        />
      </Host>
EOF
      leave_trail "trail_virtual_host_${publication}=${domain}:${appserver_port}"
    done
  fi
  
  cat >> $tomcat_base/conf/server.xml <<EOF
    </Engine>
  </Service>
</Server>
EOF

  cat > $tomcat_base/conf/context.xml <<EOF
<?xml version='1.0' encoding='utf-8'?>
<Context>
  <WatchedResource>WEB-INF/web.xml</WatchedResource>
EOF

  if [ $install_profile_number -ne $PROFILE_ANALYSIS_SERVER -a \
    $install_profile_number -ne $PROFILE_SEARCH_SERVER ]; then
    cat >> $tomcat_base/conf/context.xml <<EOF
  <ResourceLink
      global="jdbc/ECE_READ_DS"
      name="jdbc/ECE_READ_DS"
      type="javax.sql.DataSource"
  />
  <ResourceLink
      global="jdbc/ECE_UPDATE_DS"
      name="jdbc/ECE_UPDATE_DS"
      type="javax.sql.DataSource"
  />
EOF
  fi

  if [ $install_profile_number -ne $PROFILE_ANALYSIS_SERVER ]; then
    cat >> $tomcat_base/conf/context.xml <<EOF
  <Environment
      name="escenic/solr-base-uri"
      value="http://${search_host}:${search_port}/solr/"
      type="java.lang.String"
      override="false"
  />
EOF
  fi

  if [ $install_profile_number -eq $PROFILE_SEARCH_SERVER -o \
    $install_profile_number -eq $PROFILE_ALL_IN_ONE ]; then
    cat >> $tomcat_base/conf/context.xml <<EOF
  <Environment
      name="escenic/indexer-webservice"
      value="${indexer_ws_uri}"
      type="java.lang.String"
      override="false"
  />
  <Environment
      name="escenic/index-update-uri"
      value="http://${search_host}:${search_port}/solr/update/"
      type="java.lang.String"
      override="false"
  />
  <Environment
      name="escenic/head-tail-storage-file"
      value="$escenic_data_dir/engine/head-tail.index"
      type="java.lang.String"
      override="false"
  />
  <Environment
      name="escenic/failing-documents-storage-file"
      value="$escenic_data_dir/engine/failures.index"
      type="java.lang.String"
      override="false"
  />
</Context>
EOF
  elif [ $install_profile_number -eq $PROFILE_ANALYSIS_SERVER ]; then
    cat >> $tomcat_base/conf/context.xml <<EOF
  <ResourceLink
      global="jdbc/eae-logger/logger"
      name="jdbc/eae-logger/logger"
      type="javax.sql.DataSource"
  />
  <ResourceLink
      global="jdbc/eae-qs/qs"
      name="jdbc/eae-qs/qs"
      type="javax.sql.DataSource"
  />
</Context>
EOF
  else 
    cat >> $tomcat_base/conf/context.xml <<EOF
</Context>
EOF
  fi
}

function set_appropriate_jvm_heap_sizes() {
  # in MB
  local heap_size=2048
  local percent=70
  local total_size=$(get_total_memory_in_mega_bytes)
  
  if [ $total_size -lt $heap_size ]; then
    local warning="$(yellow WARNING)"
    print_and_log "$warning $HOSTNAME only has $total_size MBs of memory, I will"
    print_and_log "$warning use ${percent}% of this for the JVM heap sizes, but you"
    print_and_log "$warning should really consider adding more RAM so that"
    print_and_log "$warning the $instance_name instance gets 2GBs"

    heap_size=$(echo "$total_size * 0.${percent}" | bc | cut -d'.' -f1)
  fi
  
  set_ece_instance_conf min_heap_size "${heap_size}m"
  set_ece_instance_conf max_heap_size "${heap_size}m"
}
