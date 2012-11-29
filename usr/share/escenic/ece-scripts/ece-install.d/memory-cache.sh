# ece-install module for installing the memory cache

memcached_java_lib_url=http://img.whalin.com/memcached/jdk5/log4j/java_memcached-release_2.0.1.tar.gz

function install_memory_cache()
{
  print "Installing a distributed memory cache on $HOSTNAME ..."
  
  install_packages_if_missing "memcached"
  if [ $on_redhat_or_derivative -eq 1 ]; then
    run /etc/init.d/memcached restart
  fi
  
  assert_commands_available memcached
  
  run cd $download_dir
  run wget $wget_opts $memcached_java_lib_url

  local tmp_dir=$(mktemp -d)
  run cd $tmp_dir
  run tar xzf $download_dir/$(basename $memcached_java_lib_url)
  local name=$(get_base_dir_from_bundle $memcached_java_lib_url)
  make_dir ${escenic_root_dir}/assemblytool/lib
  run cp $name/$name.jar ${escenic_root_dir}/assemblytool/lib
  run rm -rf $tmp_dir
  run cd ~/
  
  memcached_set_up_common_nursery

  # ece deploy will set up the necessary in-publication Nursery
  # configuration, if needed.
  
  # TODO inform the user that he/she might want to do this in the
  # publication tree as well.
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
