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

    if [ $(get_status | cut -d' ' -f1) == "UP" ]; then
      print "|-> PID:" $type_pid
    fi
    
    print "|-> Type: " $appserver
    
    case "$appserver" in
      tomcat)
        if [ -n "${tomcat_home}" ]; then
          print "|-> Tomcat home:" $tomcat_home
          print "|-> Tomcat base:" $tomcat_base
          print_tomcat_resources
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

print_deployment_state() {
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

  print "Application server resources:"

  local file=$tomcat_base/conf/context.xml
  if [ -r $file ]; then
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
  else
    print "|-> user $USER cannot read $file"
  fi
  
  print "Database:"
  file=$tomcat_base/conf/server.xml
  if [ -r $file ]; then
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
  else
    print "|-> user $USER cannot read $file"
  fi
}
