function create_publication() {
  print_and_log "Getting ready to create a new publication ..."

  if [ ${fai_enabled-0} -eq 1 ]; then
    local publication_name=${fai_publication_name-mypub}

    # figure out which WAR to use for the publication creation
    local publication_war=""
    if [ -n "${fai_publication_ear}" ]; then
      print_and_log "Will try to find" ${fai_publication_name}.war \
        "inside" $fai_publication_ear 
    else
      if [ -z "${fai_publication_war}" ]; then
        # if the user hasn't set the fai_publication_war, see if the
        # demo-clean.war is available on the system.
        local file=$escenic_root_dir/engine/contrib/wars/demo-clean.war
        if [ -e $file ]; then
          publication_war=$file
        else
          # if neither fai_publication_war nor demo-clean.war are
          # available make the installation fail and inform the user
          # of the need to set fai_publication_war
          ensure_variable_is_set fai_publication_war
        fi
      else
        publication_war=$fai_publication_war
      fi
    fi

    local the_instance=${fai_publication_use_instance-$default_ece_intance_name}
    ensure_that_instance_is_running $the_instance
    create_publication_in_db $publication_name $publication_war $the_instance
    add_publication_to_deployment_lists $(basename $publication_war .war)

    add_next_step "A publication with name" $publication_name \
      "has been created using the publication resources in" \
      $publication_war "The WAR has been added to the deployment" \
      "white list, so that it will be included next time you do" \
      "ece -i ${the_instance} deploy"
  fi
}

## $1 : publication WAR name
function add_publication_to_deployment_lists() {
  run source /etc/default/ece
  local please_add=1
  
  for el in $engine_instance_list; do
    local file=/etc/escenic/ece-${el}.conf
    run source $file
    
    for ele in $deploy_webapp_white_list; do
      if [[ "$el" == "$1" ]]; then
        please_add=0
      fi
    done

    if [ $please_add -eq 1 ]; then
      print_and_log "Adding $1 to the deploy white list of" \
        "instance" $el
      deploy_webapp_white_list="$deploy_webapp_white_list $1"
    fi
    
    set_conf_file_value \
      deploy_webapp_white_list \
      $deploy_webapp_white_list \
      $file
  done
}

## $1 :: the instance name
function ensure_that_instance_is_running() {
  return
  
  local ece_command="ece -i $1 -t $type status"
  if [ $(su - $ece_user -c "$ece_command" | grep UP | wc -l) -lt 1 ]; then
    ece_command="ece -i $1 -t $type start"
    su - $ece_user -c "$ece_command" 1>>$log 2>>$log
    # TODO improve this by adding a timed while loop
    sleep 60
  fi
}

## $1 :: publication name
## $2 :: publication war
## $3 :: instance name
## 
## Based on Erik Mogensen's work:
## //depot/branches/personal/mogsie/fromscratch/create-publication.sh
function create_publication_in_db() {
  local publication_name=$1
  local publication_war=$2
  local instance_name=$3
  
  print_and_log "Creating publication" ${publication_name} \
    "using instance" $instance_name "..."
  
  # sourcing the instance's ECE configuration to get the app server
  # port.
  run source /etc/escenic/ece-${instance_name}.conf

  local ece_admin_uri=http://localhost:${appserver_port}/escenic-admin
  
  local cookie=$(curl ${curl_opts} -I ${ece_admin_uri}/ | \
    grep -i "^Set-Cookie" | \
    sed s/.*'JSESSIONID=\([^;]*\).*'/'\1'/)

  if [[ "$cookie" == "" ]] ; then
    print_and_log "Unable to get a session cookie from instance $instance_name"
    exit 1
  fi

  run curl ${curl_opts} \
    -F "type=webapp" \
    -F "resourceFile=@${publication_war}" \
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
