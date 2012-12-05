function create_publication() {
  print_and_log "Getting ready to create a new publication ..."
  
  if [ ! -e $escenic_root_dir/engine -o \
    ! -e $escenic_root_dir/assemblytool ]; then
    print_and_log "Please install ECE and an assembly environment before" \
      "running this installation profile again."
    remove_pid_and_exit_in_error
  fi

  create_publication_definition_and_war

  instance_list=$(get_instance_list)
  default_instance=$(echo ${instance_list} | cut -d' ' -f1)

  if [ $fai_enabled -eq 0 ]; then
    print "Which ECE instance do you wish to use to create it?"
    print "These instances are available: $instance_list"
    echo -n "Your choice [$default_instance]> "
    read instance_name
  else
    instance_name=$(get_conf_value fai_publication_use_instance)
  fi

  if [ -z "$instance_name" ]; then
    instance_name=$default_instance
  fi

  type=engine
  ensure_that_instance_is_running $instance_name
  create_publication_in_db $publication_war

  # don't set/introduce the deployment white list for profile=all
  if [ $install_profile_number -ne $PROFILE_ALL_IN_ONE ]; then
    add_publication_to_deployment_lists
  fi
  
  assemble_deploy_and_restart_type

  add_next_step "A new publication $publication_name has been created."
}

## $1 : publication name
function add_publication_to_deployment_lists() {
  if [ $fai_enabled -eq 0 ]; then
    print "On which ECE instances do you wish to deploy $publication_name"
    print "These instances are available: $instance_list"
    echo -n "Your choice [$default_instance]> "
    read update_instance_list
  else
    update_instance_list=${fai_publication_instance_list-${default_instance}}
  fi

  if [ -z $update_instance_list ]; then
    update_instance_list=$default_instance
  fi

  for el in $update_instance_list; do
    print "Adding $publication_name to instance ${el}'s deployment list ..."
    local file=$escenic_conf_dir/ece-${el}.conf
    if [ -e $file ]; then
      # don't want to source it as it'll pollute the variable name
      # space.
      local existing_value=$(
        grep deploy_webapp_white_list $file | cut -d'=' -f2 | sed 's#"##g'
      )
      set_conf_file_value \
        deploy_webapp_white_list \
        $publication_name $existing_value \
        $file
    fi
  done
}

function ensure_that_instance_is_running() {
  local ece_command="ece -i $1 -t $type status"
  if [ $(su - $ece_user -c "$ece_command" | grep UP | wc -l) -lt 1 ]; then
    ece_command="ece -i $1 -t $type start"
    su - $ece_user -c "$ece_command" 1>>$log 2>>$log
    # TODO improve this by adding a timed while loop
    sleep 60
  fi
}

# Based on Erik Mogensen's work:
# //depot/branches/personal/mogsie/fromscratch/create-publication.sh
function create_publication_in_db() {
  print_and_log "Creating ${publication_name} using $instance_name ..."

  ece_admin_uri=http://$HOSTNAME:${appserver_port}/escenic-admin
  
  cookie=$(curl ${curl_opts} -I ${ece_admin_uri}/ | \
    grep -i "^Set-Cookie" | \
    sed s/.*'JSESSIONID=\([^;]*\).*'/'\1'/)

  if [ "$cookie" == "" ] ; then
    print_and_log "Unable to get a session cookie."
    remove_pid_and_exit_in_error;
  fi

  run curl ${curl_opts} \
    -F "type=webapp" \
    -F "resourceFile=@${1}" \
    --cookie JSESSIONID="$cookie" \
    "${ece_admin_uri}/do/publication/resource"
  
  run curl ${curl_opts}  \
    -F "name=${publication_name}" \
    -F "publisherName=Escenic" \
    -F "adminPassword=admin" \
    -F "adminPasswordConfirm=admin" \
    --cookie JSESSIONID="$cookie" \
    "${ece_admin_uri}/do/publication/insert"
}

function create_publication_definition_and_war()
{
  publication_name=mypub

  if [ ${fai_enabled-0} -eq 0 ]; then
    print "What name do you wish to give your publication?"
    print "Press ENTER to accept ${publication_name}"
    echo -n "Your choice [${publication_name}]> "
    read publication_name
  else
    publication_name=$(get_conf_value fai_publication_name)
  fi

  if [ -z "$publication_name" ]; then
    publication_name=mypub
  fi

  print_and_log "Setting up the ${publication_name} publication ..."
  make_dir $escenic_root_dir/assemblytool/publications/
  run cd $escenic_root_dir/assemblytool/publications/
  cat > $escenic_root_dir/assemblytool/publications/${publication_name}.properties <<EOF
name: ${publication_name}
source-war: ${publication_name}.war
context-root: ${publication_name}
EOF

  publication_war=$escenic_root_dir/assemblytool/publications/${publication_name}.war
  if [[ $fai_enabled -eq 1 && -n "${fai_publication_war}" ]]; then
    print_and_log "Basing ${publication_name}.war on the one specified in $conf_file"
    run cp ${fai_publication_war} ${publication_war}
  elif [ -d $escenic_root_dir/widget-framework-core-* ]; then
    print_and_log "Basing ${publication_name}.war on Widget Framework Demo ..."
    # WF 1.x
    if [ -d $escenic_root_dir/widget-framework-core-*/publications/demo-core ]; then
      run cd $escenic_root_dir/widget-framework-core-*/publications/demo-core
      install_packages_if_missing "maven2"
      assert_commands_available mvn
      run mvn $maven_opts package
      run cp target/demo-core-*.war ${publication_war}
    # WF 2.x
    elif [ -e $escenic_root_dir/widget-framework-core-*/wars/wf-core-war-2*.war ]; then
      run cp $escenic_root_dir/widget-framework-core-*/wars/wf-core-war-2*.war \
        ${publication_war}
    fi
  else
    print_and_log "Basing your ${publication_name}.war on ECE/demo-clean ..."
    run cp $escenic_root_dir/engine/contrib/wars/demo-clean.war ${publication_war}
  fi

    # TODO add support for the community widgets
    #
    # 1 - add the core widgets to the
    # publications/demo-community/pom.xml
    # 
    # 2 - add the <ui:group name="core-widgets"/> definition for core
    # widgets in:
    # publications/demo-community/src/main/webapp/META-INF/escenic/publication-resources/escenic/content-type
}
