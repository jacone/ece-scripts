function get_gc_log() {
  if [ -r $gc_log ]; then
    echo ${gc_log}
  fi
}

function get_deployment_log() {
  if [ -r $data_dir/${instance}-deployment.log ]; then
    echo $data_dir/${instance}-deployment.log
  fi
}

function get_log4j_log() {
  for el in $log4j_file_list; do
    if [ -r $el ]; then
      echo $el
      return
    fi
  done

  echo ""
}

function tail_messages_log() {
  log4j_log=$(get_log4j_log)
  print "tailing $log4j_log"
  tail -f $log4j_log
}

function tail_out_log() {
  tail_list=$log

  # if needs be, we can add more system out logs here. For now,
  # we're sticking with the default one.
  
  print "Tailing the system out log $tail_list"
  tail -f $tail_list
}

function get_app_log() {
  local app_log=""
  if [ "$appserver" == "tomcat" ]; then
    app_log=$log_dir/${instance}-tomcat
  elif [ "$appserver" == "resin" -a -e $resin_home/log/jvm-default.log ]; then
    app_log=$resin_home/log/jvm-default.log
  else
    print "I don't know where the logs for $appserver are."
    print "Ask support@escenic.com to add support for $appserver in "
    print "tail_app_log()"
    exit 1
  fi

  echo $app_log
}


function tail_app_log() {
  if [ "$type" == "rmi-hub" ]; then
    print "There is no application server log for $type"
    exit 1
  fi
  
  print "Tailing the application server log $(get_app_log)"
  tail -f $(get_app_log)
}

function show_all_log_paths() {
  if [ "$quiet" -eq 0 ]; then
    print "App server log: "$(get_app_log)
    if [[ $appserver == "tomcat" ]]; then
      print "App server out log:" $(get_catalina_out_file)
    fi
    print "Log4j log:  "$(get_log4j_log)
    print "GC log:  "$(get_gc_log)
    print "$(basename $0) script log: "$log
    print "Deployment log:" $(get_deployment_log)
  else
    echo $(get_app_log)
    if [[ $appserver == "tomcat" ]]; then
      echo $(get_catalina_out_file)
    fi
    echo $(get_log4j_log)
    echo $(get_gc_log)
    echo $log
    echo $(get_deployment_log)
  fi
}

function get_catalina_out_file() {
  echo $log_dir/${instance}-catalina.out
}
