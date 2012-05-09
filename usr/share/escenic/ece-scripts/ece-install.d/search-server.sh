# ece-install module for installing the search server

function install_search_server()
{
  print_and_log "Installing a search server on $HOSTNAME ..."
  type=search
  install_ece_instance "search1" 0
  
  # TODO update instead of append
  local dir=$common_nursery_dir/com/escenic/framework/search/solr
  make_dir $dir
  echo "solrServerURI=http://${search_host}:${search_port}/solr" \
    >>  $dir/SolrSearchEngine.properties
  
  dir=$common_nursery_dir/com/escenic/webservice/search
  make_dir $dir
  echo "solrURI=http://${search_host}:${search_port}/solr/select" \
    >> $dir/DelegatingSearchEngine.properties

  dir=$common_nursery_dir/com/escenic/lucy
  make_dir $dir
  echo "solrURI=http://${search_host}:${search_port}/solr" \
    >> $dir/LucySearchEngine.properties

  dir=$common_nursery_dir/com/escenic/forum/search/lucy
  make_dir $dir
  echo "solrURI=http://${search_host}:${search_port}/solr" \
    >> $dir/SearchEngine.properties

  set_up_solr
  assemble_deploy_and_restart_type
}

function set_up_solr()
{
  run_hook set_up_solr.preinst
  
  print_and_log "Setting up Solr ..."
  if [ ! -d $escenic_conf_dir/solr ]; then
    if [ $(is_using_conf_archive) -eq 1 ]; then
      print_and_log "Using the supplied Solr configuration from" 
      print_and_log "bundle: $ece_instance_conf_archive"
      local a_tmp_dir=$(mktemp -d)
      local file=$(
        download_uri_target_to_dir \
          $ece_instance_conf_archive \
          $a_tmp_dir
      )
      run cd $a_tmp_dir
      run tar xzf $(basename $ece_instance_conf_archive) engine/solr/conf
      run cp -r engine/solr/conf $escenic_conf_dir/solr
      run rm -r $a_tmp_dir
    else
      print_and_log "Installing default Solr conf shipped with ECE ..."
      run cp -r $escenic_root_dir/engine/solr/conf $escenic_conf_dir/solr
    fi
  else
    print_and_log "$escenic_conf_dir/solr already exists, not touching it."
  fi

  make_dir $escenic_data_dir/solr/
  run cd $escenic_data_dir/solr/
  if  [ ! -h conf ]; then
    run ln -s $escenic_conf_dir/solr conf
  fi

  local editorial_search_instance=${fai_search_for_editor-0}
  local file=$escenic_conf_dir/solr/solrconfig.xml
  if [ $editorial_search_instance -eq 1 ]; then
    run sed -i "s#<maxTime>[0-9]*</maxTime>#<maxTime>5000</maxTime>#g" $file
  else
    run sed -i "s#<maxTime>[0-9]*</maxTime>#<maxTime>60000</maxTime>#g" $file
  fi

  run_hook set_up_solr.postinst
}
