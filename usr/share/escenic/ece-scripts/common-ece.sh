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

webapps_in_standard_webapps_list="
  dashboard
  escenic
  escenic-admin
  indexer-webapp
  indexer-webservice
  inpage-ws
  solr
  studio
  webservice
"

## $1 :: the war file (or just the name of the war file, without the
##       file suffix)
function is_webapp_a_publication() {
  for el in $webapps_in_standard_webapps_list; do
    if [[ "$(basename $1 .war)" == $el ]]; then
      echo 0
      return
    fi
  done

  echo 1
}

## Will return the app base for the passwed WAR name.
##
## $1 :: the name of the war file
function get_app_base() {
  local war=$(basename $1 .war)

  # this is a list of web applications that are standard ECE related
  # web applications which should not live in their own webapp context
  # (i.e. not a publication).
  for el in $webapps_in_standard_webapps_list; do
    if [[ "$el" == "$war" ]]; then
      echo webapps
      return
    fi
  done

  echo webapps-${war}
}

## Returns a list of publications on the local host
## 
## $1 :: app server port. Optional, default is 8080.
function get_publication_list() {
  if [ $(which curl | wc -l) -lt 1 ]; then
    return ""
  fi
  
  curl --silent \
    --connect-timeout 20 \
    http://localhost:${1-8080}/escenic-admin/pages/publication/list.jsp | \
    grep '/escenic-admin/pages/publication/view.jsp' | \
    sed 's/.*name=\(.*\)".*/\1/g'
}
