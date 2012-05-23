function flush_caches() {
  if [ "${type}" != "engine" ]; then
    print "You cannot flush the caches of a ${type} instance"
    return
  fi
  
  print "Flushing all of ${instance}'s caches on $HOSTNAME"
  local url=$(get_escenic_admin_url)/do/publication/clearallcaches
  wget $wget_auth \
    -O - \
    --post-data='confirm=Confirm' \
    $url \
    1>>$log 2>>$log
}
