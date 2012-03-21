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
