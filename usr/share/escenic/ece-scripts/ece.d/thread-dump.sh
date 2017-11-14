function make_thread_dump() {

  if [ -n "$type_pid" ]; then
    print "Thread dump (PID" $type_pid") written to system out log."
    print "Type 'ece -t $type -i $instance outlog' to see it or view"
    print $log "directly."

    if [ -x $java_home/bin/jstack ]; then
      jstack -l $type_pid >> $log
    else
      kill -QUIT $type_pid >> $log
    fi
  else
    print "$(get_status)"
  fi
}
