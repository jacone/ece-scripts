# ece-install module for installing the memory cache

memcached_java_lib_url=https://github.com/downloads/gwhalin/Memcached-Java-Client/java_memcached-release_2.5.3.jar

function install_memory_cache()
{
  print "Installing a distributed memory cache on $HOSTNAME ..."
  
  install_packages_if_missing "memcached"
  if [ $on_redhat_or_derivative -eq 1 ]; then
    run /etc/init.d/memcached restart
  fi
  
  assert_commands_available memcached

  print_and_log "Downloading the memcached java library ..."
  download_uri_target_to_dir $memcached_java_lib_url $download_dir

  make_dir ${escenic_root_dir}/assemblytool/lib
  run cp $(basename $memcached_java_lib_url) ${escenic_root_dir}/assemblytool/lib
  memcached_set_up_common_nursery

  # ece deploy will set up the necessary in-publication Nursery
  # configuration, if needed.
}

function memcached_set_up_common_nursery() {
  local dir=$common_nursery_dir/com/danga
  make_dir $dir
  cat > $dir/SockIOPool.properties <<EOF
\$class=com.danga.MemCached.SockIOPool
# fill in memcached servers here.
servers=${fai_memcached_node_list-localhost:11211}

# how many connections to use
initConn = 10
minConn = 5
maxConn = 100
# idle time
maxIdle = 180000
maintSleep = 5000
# socket timeout
socketTO = 3000
failover = true
# a network lookup algorithm
nagle = false
EOF

  cat >> $common_nursery_dir/Initial.properties <<EOF

# using memcached, added by $(basename $0) @ $(date --iso)
service.0.0-memcached-socket-pool=/com/danga/SockIOPool
EOF
}
