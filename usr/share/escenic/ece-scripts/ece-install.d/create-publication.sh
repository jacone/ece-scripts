## If the user has fai_publication_war_remove_file_list set, these
## files will, if present, be removed from the WAR file.
##
## $1 :: full path to the WAR file
function create_publication_prepare_war_file() {
  if [ -n "${fai_publication_war_remove_file_list}" ]; then
    local the_tmp_dir=$(mktemp -d)
    (
      cd $the_tmp_dir
      #run jar xf $1

      for el in $fai_publication_war_remove_file_list; do
        if [ -e $el ]; then
          print_and_log "Removing" $el "from" $(basename $1) "..."
          #run rm $el
          zip -d $1 $el
        fi
      done

      #run jar cf $1 .
    )
  fi
}

function create_publication() {
  print_and_log "Preparing publication creation ..."

  # figure out which WAR to use for the publication creation
  local publication_war=""
  if [ -n "${fai_publication_ear}" ]; then
    print_and_log "I will create all publications in" \
                  $fai_publication_ear "using the the domain mapping list ..."

    ensure_variable_is_set fai_publication_domain_mapping_list
    local the_tmp_dir=$(mktemp -d)

    # we're using the builder HTTP crendentials, if set, for
    # downloading the EAR.
    if [[ -n "${fai_builder_http_user}" && \
            -n "${fai_builder_http_password}" ]]; then
      wget_auth="
          --http-user $fai_builder_http_user
          --http-password $fai_builder_http_password
        "
    fi
    download_uri_target_to_dir $fai_publication_ear $download_dir
    (
      run cd $the_tmp_dir
      run jar xf $download_dir/$(basename $fai_publication_ear)
    )

    ensure_that_instance_is_running ${fai_publication_use_instance-$default_ece_intance_name}
    for el in ${fai_publication_domain_mapping_list}; do
      local old_ifs=$IFS
      # the entries in the fai_publication_domain_mapping_list are on
      # the form: <publication[,pub.war]>#<domain>[#<alias1>[,<alias2>]]
      IFS='#' read publication domain aliases <<< "$el"
      IFS=',' read publication_name publication_war publication_type <<< "$publication"
      IFS=$old_ifs

      # this is the default case were the WAR is called the same as
      # the publication name with the .war suffix.
      if [ -z "${publication_war}" ]; then
        publication_war=${publication_name}.war
      fi

      create_the_publication \
        $publication_name \
        $the_tmp_dir/$publication_war \
        $publication_type \
        "${domain}" \
        "${aliases}"
    done

    log "Cleaing up $the_tmp_dir ..."
    run rm -rf $the_tmp_dir
  else
    ensure_that_instance_is_running ${fai_publication_use_instance-$default_ece_intance_name}
    local publication_name=${fai_publication_name-mypub}
    local publication_type=${fai_publication_type-default}

    if [ -z "${fai_publication_war}" ]; then
      # if the user hasn't set the fai_publication_war, see if the
      # demo-clean.war is available on the system.
      local file=$(get_content_engine_dir)/contrib/wars/demo-clean.war
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

    create_the_publication $publication_name $publication_war $publication_type
  fi
}

## $1 :: publication name
## $2 :: publication war
## $3 :: publication type
## $4 :: publication domain, optional
## $5 :: publication aliases, optional
function create_the_publication() {
  local publication_name=$1
  local publication_war=$2
  local publication_type=$3
  local publication_domain=$4
  local publication_aliases=$5

  local the_instance=${fai_publication_use_instance-${default_ece_intance_name}}

  local ece_command="
    ece -i ${the_instance} \
        create-publication \
        --publication ${publication_name} \
        --update-app-server-conf \
        --update-nursery-conf \
        --update-ece-conf \
        --publication-type ${publication_type} \
        --file ${publication_war}
  "

  if [ -n "${publication_domain}" ]; then
    ece_command=${ece_command}" --publication-domain ${publication_domain}"
  fi
  if [ -n "${publication_aliases}" ]; then
    ece_command=${ece_command}" --publication-aliases ${publication_aliases}"
  fi

  su - "${ece_user}" -c "$ece_command" &>> "${log}"
  exit_on_error su - "${ece_user}" -c "$ece_command"
}

## $1 :: the instance name
function ensure_that_instance_is_running() {
  local ece_command="ece -i $1 -t $type status"
  if [ $(su - $ece_user -c "$ece_command" | grep UP | wc -l) -lt 1 ]; then
    ece_command="ece -i $1 -t $type start"
    su - $ece_user -c "$ece_command" 1>>$log 2>>$log
  fi

  # This is a hack, but this ensures that the ECE is bootstrapped
  # properly and can respond fast enough to the session setup for the
  # publication creation.
  ece_command="ece -i $1 -t $type versions"
  su - $ece_user -c "$ece_command" 1>>$log 2>>$log
  sleep 60
}

