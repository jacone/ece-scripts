function create_publication()
{
  if [ ! -e $escenic_root_dir/engine -o \
    ! -e $escenic_root_dir/assemblytool ]; then
    print_and_log "Please install ECE and an assembly environment before"
    print_and_log "running this installation profile again."
    remove_pid_and_exit_in_error
  fi

  print_and_log "Getting ready to create a new publication ..."
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
  add_publication_to_deployment_lists
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

function ensure_that_instance_is_running()
{
  local ece_command="ece -i $1 -t $type status"
  if [ $(su - $ece_user -c "$ece_command" | grep UP | wc -l) -lt 1 ]; then
    ece_command="ece -i $1 -t $type start"
    su - $ece_user -c "$ece_command" 1>>$log 2>>$log
    # TODO improve this by adding a timed while loop
    sleep 60
  fi
}
