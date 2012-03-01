# ece-install module for installing the memory cache

memcached_java_lib_url=http://img.whalin.com/memcached/jdk5/log4j/java_memcached-release_2.0.1.tar.gz

## $1: root directory of the publication
function memcached_create_publication_nursery_component() {
  if [ ! -d "$1" ]; then
    log $1 "doesn't exist"
    return
  fi

  print_and_log "Adding memcached wrapper to PresenationArticle in $1 ..."
  local dir=$1/WEB-INF/localconfig/neo/xredsys/presentation/cache
  make_dir $dir
  local file=$dir/PresentationArticleCache.properties
  
  if [[ -e $file && $(grep "\$class" $file | wc -l) -gt 0 ]]; then
    sed -i "s#\$class=.*#\$class=neo.util.cache.Memcached#g" $file
  else
    echo "\$class=neo.util.cache.Memcached" >> $file
  fi
  
  exit_on_error "sed on $file"
}

function install_memory_cache()
{
  print "Installing a distributed memory cache on $HOSTNAME ..."
  
  install_packages_if_missing "memcached"
  if [ $on_redhat_or_derivative -eq 1 ]; then
    run /etc/init.d/memcached restart
  fi
  
  assert_pre_requisite memcached
  
  run cd $download_dir
  run wget $wget_opts $memcached_java_lib_url

  local tmp_dir=$(mktemp -d)
  run cd $tmp_dir
  run tar xzf $download_dir/$(basename $memcached_java_lib_url)
  local name=$(get_base_dir_from_bundle $memcached_java_lib_url)
  make_dir ${escenic_root_dir}/assemblytool/lib
  run cp $name/$name.jar ${escenic_root_dir}/assemblytool/lib
  run rm -rf $tmp_dir
  
  memcached_set_up_common_nursery
  
  print_and_log "Configuring all publications for using memcached ..."
  for el in $(ls $escenic_root_dir/assemblytool/publications/*.properties \
    2>/dev/null); do
    local publication=$(basename $el .properties)
    dir=$tomcat_base/webapps/$publication
    make_dir $dir
    memcached_create_publication_nursery_component $dir
  done
  
  # fixing the deployed publications on host
  for el in $(
    find $tomcat_base/webapps/ \
      -mindepth 1 \
      -maxdepth 1 \
      -type d | \
      egrep -v "solr|webservice|escenic|escenic-admin|indexer-webservice" | \
      egrep -v "indexer-webapp|studio"
  ); do
    memcached_create_publication_nursery_component $el
  done
  
  # TODO inform the user that he/she might want to do tihs in the
  # publication tree as well.
}

function memcached_set_up_common_nursery() {
  local dir=$common_nursery_dir/com/danga
  make_dir $dir
  cat > $dir/SockIOPool.properties <<EOF
$class=com.danga.MemCached.SockIOPool
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
