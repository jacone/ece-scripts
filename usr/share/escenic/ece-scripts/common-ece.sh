#! /usr/bin/env bash

# by tkj@vizrt.com

## If the system is installed using the recommended paths, the method
## will return a list of the instances configured in
## ${escenic_conf_dir}/ece-*.conf
function get_instance_list() {
  local allowed_types="engine analysis changelogd search rmi-hub"
  instance_list=""
  for el in $(\ls /etc/escenic/ece-*.conf 2>/dev/null); do
    
    local instance=$(basename $el .conf)
    instance=${instance##ece-}
    
    for ele in $allowed_types; do
      if [[ $instance == $ele ]]; then
        instance=""
        continue
      fi
      
      local away="${ele}-"
      instance=${instance##${away}}
    done
    instance_list="$instance_list $instance"
  done

  echo $instance_list
}

## Will return the app base for the passwed WAR name.
## 
## $1 :: the name of the war file
function get_app_base() {
  local war=$(basename $1 .war)
  local webapps_in_standard_webapps_list="
    escenic
    escenic-admin
    inpage-ws
    studio
    webservice
    dashboard
  "

  for el in $webapps_in_standard_webapps_list; do
    if [[ "$el" == "$war" ]]; then
      echo webapps
      return
    fi
  done

  echo webapps-${war}
}
