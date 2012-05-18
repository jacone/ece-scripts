function get_gc_log() {
  echo ${gc_log}
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

function tail_messages_log()
{
  log4j_log=$(get_log4j_log)
  print "tailing $log4j_log"
  tail -f $log4j_log
}

function tail_out_log()
{
  tail_list=$log

    # if needs be, we can add more system out logs here. For now,
    # we're sticking with the default one.
  
  print "Tailing the system out log $tail_list"
  tail -f $tail_list
}

function get_app_log()
{
  local app_log=""
  if [ "$appserver" == "tomcat" ]; then
    app_log=$tomcat_base/logs/localhost.`date +%F`.log
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


function tail_app_log()
{
  if [ "$type" == "rmi-hub" ]; then
    print "There is no application server log for $type"
    exit 1
  fi
  
  print "Tailing the application server log $(get_app_log)"
  tail -f $(get_app_log)
}
