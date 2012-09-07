function get_info_for_type() {
  print "Current instance:    ${instance}"
  print "Instances available on $HOSTNAME: $(get_instance_list)"
  print "Conf files parsed: ${ece_conf_files_read[@]}"

  if [ -n "${ece_home}" ]; then
    print "ECE location: $ece_home"
  fi
  if [[ -n "${assemblytool_home}" && -e "${assemblytool_home}" ]]; then
    print "Assembly Tool location: $assemblytool_home"
  fi
  if [ -n "${java_home}" ]; then
    print "Java location: $java_home"
  fi

  print "Log files:"
  print "|-> System out log:" $log
  print "|-> App server log:" $(get_app_log)
  print "|-> Log4j log:     " $(get_log4j_log)
  print "|-> GC log:        " $(get_gc_log)

  if [ -n "${appserver}" ]; then
    print "Application server:"
    set_type_port
    set_type_pid
    print "|-> Status:" $(get_status)
    print "|-> Port:" $port

    if [ $(get_status | grep UP | wc -l) -gt 0 ]; then
      print "|-> PID:" $type_pid
      print "|-> Memory usage:" $(get_memory_summary_of_pid $type_pid)
    fi

    print "|-> Type: " $appserver

    case "$appserver" in
      tomcat)
        if [ -n "${tomcat_home}" ]; then
          print "|-> Tomcat home:" $tomcat_home
          print "|-> Tomcat base:" $tomcat_base
          print_tomcat_resources $tomcat_base
          print_deployed_webapps $tomcat_base
        fi
        ;;
      resin)
        if [ -n "${resin_home}" ]; then
          print "|-> Resin home:" $resin_home
          print_deployed_webapps $resin_home
        fi
        ;;
    esac
  fi

  print_deployment_state
}

function print_deployment_state() {
  local file=$data_dir/$instance.state
  if [ ! -r $file ]; then
    return
  fi

  print "Deployment state:"
  print "|-> Version:" $(grep ^version $file | cut -d'=' -f2-)
  print "|-> EAR used:" $(grep ^ear_used $file | cut -d'=' -f2-)
  print "|-> MD5 sum:" $(grep ^md5_sum $file | cut -d'=' -f2-)
  print "|-> Deployment date:" $(grep ^deployed_date $file | cut -d'=' -f2-)
}

## $1: dir
function print_deployed_webapps() {
  local webapps=""

  if [ ! -d $1/webapps ]; then
    return
  fi

  print "Deployed web applications:"
  for el in $(find $1/webapps -maxdepth 1 -type d | \
    grep -v webapps$); do
    print "|-> http://${HOSTNAME}:${port}/"$(basename $el)
  done

}

function print_tomcat_resources() {
  if [ "$(which xml_grep)x" == "x" ]; then
    log "Install xml_grep to get more 'ece info' details"
    return
  fi

  local file=$1/conf/context.xml
  if [ -r $file ]; then
    print "Application server resources:"
    xml_grep  --nowrap --cond Context/Environment \
      $file | \
      sed 's/^[ \t]//g' | \
      sed "s#><#>\n<#g" | \
      cut -d' ' -f2,5 |  \
      cut -d'"' -f2,4 | \
      while read line ; do
      local key=$(echo $line | cut -d'"' -f1)
      local value=$(echo $line | cut -d'"' -f2)
      print "|->" ${key}: ${value}
    done

    print "Database:"
    file=$tomcat_base/conf/server.xml
    xml_grep \
      --nowrap \
      --cond 'Server/GlobalNamingResources/Resource[@type="javax.sql.DataSource"]' \
      $file | \
      sed 's/^[ \t]//g' | \
      sed "s#><#>\n<#g" | \
      while read line ; do
        for el in $(echo $line | cut -d' ' -f1- ); do
          if [[ $el == "name"* || $el == "url"* || $el == "username"* ]]; then
            local key=$(echo $el | cut -d'"' -f1 | cut -d'=' -f1)
            local value=$(echo $el | cut -d'"' -f2)
            if [[ $value == "jdbc:mysql"* ]]; then
              value=${value:5}
            fi

            print "|->" ${key}: ${value}
          fi
        done
      done

    file=$tomcat_base/conf/server.xml
    local virtual_hosts="$(
      xml_grep \
      --nowrap \
      --cond 'Server/Service/Engine/Host/Alias' \
      $file
    )"

    if [ $(echo "$virtual_hosts" | wc -c) -gt 1 ]; then
      print "Virtual hosts:"
    fi

    echo "$virtual_hosts" | \
      sed 's#><#>\n<#g' | \
      sed 's#<Alias>\(.*\)</Alias>#\1#g' | while read line; do
      if [ -z "$line" ]; then
        continue
      fi
      print "|-> http://${line}"
    done

  else
    print "|-> user $USER cannot read $file"
  fi
}

## doesn't use /etc/services on purpose
function visualise_known_ports() {
  local the_host=$(echo $1 | cut -d':' -f1)
  local the_port=$(echo $1 | cut -d':' -f2)

  local nice_port=$(echo ${the_port} | \
    sed \
    -e 's/8080/ece/g' \
    -e 's/8081/eae/g' \
    -e 's/3306/mysql/g' \
    -e 's/22/ssh/g' \
    -e 's/11211/memcached/g')
  echo ${the_host}:${nice_port}
}
