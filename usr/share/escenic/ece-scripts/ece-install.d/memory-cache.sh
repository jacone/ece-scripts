# ece-install module for installing the memory cache

memcached_java_lib_url=http://img.whalin.com/memcached/jdk5/log4j/java_memcached-release_2.0.1.tar.gz

## $1: root directory of the publication
function memcached_create_publication_nursery_component() {
  if [ ! -d "$1" ]; then
    log $1 "doesn't exist"
    return
  fi

  log "Adding memcached wrapper to PresenationArticle in $1 ..."
  local dir=$1/webapp/WEB-INF/localconfig/neo/xredsys/presentation/cache
  make_dir $dir
  local file=$dir/PresentationArticleCache.properties
  sed -i "s#\$class=.*#\$class=neo.util.cache.Memcached#g" $file
  exit_on_error "sed on $file"
}

function install_memory_cache()
{
  install_packages_if_missing "memcached"
  assert_pre_requisite memcached
  
  run cd $download_dir
  run wget $wget_opts $memcached_java_lib_url
  local name=$(get_base_dir_from_bundle $memcached_java_lib_url)
  run cp $name/$name.jar $assemblytool_home/lib
  
  memcached_set_up_common_nursery
  
  log "Configuring all publications for using memcached ..."
  for el in $assemblytool_home/publications/*.properties; do
    local publication=$(basename $el .properties)
    
    if [[ $appserver == "tomcat" ]]; then
      dir=$tomcat_base/webapps/$publication
      make_dir $dir
      memcached_create_publication_nursery_component $dir
    fi
  done
  
  # fixing the deployed publications on host
  if [[ $appserver == "tomcat" ]]; then
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
    
  fi
  
  # TODO inform the user that he/she might want to do tihs in the
  # publication tree as well.
  assemble_deploy_and_restart_type_p
}

function memcached_set_up_common_nursery() {
  local dir=$common_nursery_dir/com/danga
  make_dir $dir
  cat > $dir/SockIOPool <<EOF
$class=com.danga.MemCached.SockIOPool
# fill in memcached servers here.
servers=${fai_memcached_node_list}

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

# using memcached
service.0.0-memcached-socket-pool=/com/danga/SockIOPool
EOF
}
