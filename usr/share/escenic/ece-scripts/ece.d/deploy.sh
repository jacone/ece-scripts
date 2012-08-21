# Module for the 'ece deploy' command.

function get_state_file() {
  echo $data_dir/${instance}.state
}

## $1 : local EAR file
function get_version_from_ear_file() {
  local version=$(basename $1 .ear | sed 's/^engine-//g')

  # if this is emtpy, it means it was called just engine.ear, in which
  # case we generate a nice version string.
  if [[ -z "$version" || "$version" == "engine" ]]; then
    version=$(date +%Y%m%d.%H%M)
  fi
  
  echo $version
}

## $1 : local EAR file
function update_deployment_state_file() {
  local state_file=$(get_state_file)

  if [ ! -w $(dirname $state_file) ]; then
    print_and_log "I cannot write to $(dirname state_file), I will exit :-("
    exit 1
  fi

  if [ -n "${file}" ]; then
    echo "ear_used=$file" > $state_file
  else
    echo "ear_used=$1" > $state_file
  fi
  
  cat >> $state_file <<EOF
version=$(get_version_from_ear_file $1)
md5_sum=$(md5sum $1 | cut -d' ' -f1)
deployed_date=$(date)
EOF

  print_and_log "Deployment state file updated: $state_file"
}

function deploy() {
  local ear=$cache_dir/engine.ear

  if [ -n "$file" ]; then
    print_and_log "Deploying $file on $instance ..."
    wget_auth=$wget_builder_auth
    ear=$(download_uri_target_to_dir $file $cache_dir)
    
    if [ ! -e "$ear" ]; then
      print_and_log "The EAR $ear_uri specified in $file could"
      print_and_log "not be retrieved. I will exit now. :-("
      exit 1
    fi
  fi
  
  if [ ! -e "$ear" ]; then
    print_and_log "$ear does not exist. "
    print_and_log "Did you run '"`basename $0`" -i" $instance "assemble'?"
    exit 1
  fi

  if [ $(is_archive_healthy $ear) -eq 0 ]; then
    print_and_log "$ear is faulty, I cannot deploy it :-("
    exit 1
  fi
  
  # extract EAR to a temporary area
  local dir=$(mktemp -d)
  (
    run mkdir -p $dir
    run cd $dir
    run jar xf $ear
  )

  print "Deploying $ear on $appserver ..."
  
  case $appserver in
    tomcat)
      # We do not want the Escenic jars to share the same classloader
      # folder as tomcat does We thereby want clients to use a
      # separate escenic classloader to avoid strange upgrade problems
      # i.e wrong versions of certain libraries.
      if [ -d $tomcat_base/escenic/lib ]; then
        if [ `ls $tomcat_base/escenic/lib | grep .jar | wc -l` -gt 0 ]; then
          run rm $tomcat_base/escenic/lib/*.jar
        fi
        run cp $dir/lib/*.jar $tomcat_base/escenic/lib
        remove_unwanted_libraries $tomcat_base/escenic/lib
      else
        print "Could not find $tomcat_base/escenic/lib. Exiting."
        print "Also make sure that you have defined this directory in"
        print "  $tomcat_base/conf/catalina.properties"
        print "see sample configuration in the engine distribution"
        print "  contrib/appserver/tomcat/catalina-sample.properties"
        exit 1
      fi
      
      run rm -rf $tomcat_base/work/*

      for war in $dir/*.war ; do
        if [ -d $tomcat_base/webapps/`basename $war .war` ] ; then
          run rm -rf $tomcat_base/webapps/`basename $war .war`
        fi
      done

      # this scenario is likely when running many minimal instances of
      # tomcat and some of these are not properly initialised.
      if [ ! -d $tomcat_base/webapps ]; then
        print $tomcat_base/webapps "doesn't exist, exiting."
        exit 1
      fi
      
      if [ -n "$deploy_webapp_white_list" ]; then
        deploy_this_war=0
        message="Deployment white list active, only deploying: "
        message=$message"$deploy_webapp_white_list"
        print $message
        log $message
      fi
      
      for war in $dir/*.war ; do
        name=`basename $war .war`

        deploy_this_war=1
        if [ -n "$deploy_webapp_white_list" ]; then
          deploy_this_war=0

          for el in $deploy_webapp_white_list; do
            if [ "$el" == $name ]; then
              debug "found $war in white list, will deploy it"
              deploy_this_war=1
            fi
          done
        fi

        if [ "$deploy_this_war" -eq 0 ]; then
          continue
        fi
        
        (cd $tomcat_base/webapps &&
          mkdir $name &&
          cd $name &&
          jar xf $war \
            1>>$log \
            2>>$log)
        exit_on_error "extracting $war to $tomcat_base/webapps/"
        
        if [ ${enable_memcached_support-1} -eq 1 ]; then
          add_memcached_support $tomcat_base/webapps/$name
        fi
      done
      ;;
    
    resin)
      if [ ! -d $resin_home/deploy ]; then
        mkdir -p $resin_home/deploy \
          1>>$log \
          2>>$log
      fi
      cp $ear $resin_home/deploy \
        1>>$log \
        2>>$log
      ;;
    *)
      print "Deployment is only implemented for Resin and Tomcat so far."
      ;;
  esac

  run rm -rf ${dir}
  update_deployment_state_file $ear
}

## $1 : dir of the webapp 
function add_memcached_support() {
  if [[ "$do_not_add_memcached_support" == "1" ]]; then
    return
  fi

  if [ ! -d "$1" ]; then
    log $1 "doesn't exist"
    return
  fi

  local exempt_from_memcached_list="
      escenic escenic-admin indexer-webservice indexer-webapp studio
      inpage-ws dashboard
    "

  for el in $exempt_from_memcached_list; do
    if [[ $(basename $1) == "$el" ]]; then
      return
    fi
  done

  log "Adding memcached support in $1 ..."
  local dir=$1/WEB-INF/localconfig/neo/xredsys/presentation/cache
  run mkdir -p $dir
  local file=$dir/PresentationArticleCache.properties

  if [[ -e $file && $(grep "\$class" $file | wc -l) -gt 0 ]]; then
    sed -i "s#\$class=.*#\$class=neo.util.cache.Memcached#g" $file
  else
    echo "\$class=neo.util.cache.Memcached" >> $file
  fi

  exit_on_error "sed on $file"
}

## Removes unwanted JARs. e.g. if type=search, we remove the
## engine-config.jar
##
## $1 :: the directory to check
function remove_unwanted_libraries() {
  if [ ! $1 ]; then
    return
  elif [ ! -d $1 ]; then
    return
  elif [ $type != "search" ]; then
    return
  fi
  
  log "Removing $1/engine-config-*.jar since this is a search instance"
  run rm $1/engine-config-*.jar
}
