## Module for the 'ece repackage' command.
##
## Repackages an EAR, which  probably will be deployed with 'ece deploy --file <ear>'.
##
## This command replaces the JARs inside the original EAR file with
## the corresponding JARs installed on the systme through APT/RPM.
##
## by torstein@escenic.com

USR_SHARE_DIR=/usr/share/escenic

get_installed_packages_war_list() {
  find "${USR_SHARE_DIR}/escenic-"* -maxdepth 1 -name "webapps" -type d | \
    while read -r webapps_dir; do
      find "${webapps_dir}" -name "*.war" -type f |
        grep -w -v webservice-extensions.war
    done
}

## $1 :: tmp dir with EAR contents
overwrite_webapps_that_are_included_in_installed_packages() {
  local tmp_dir=$1
  for d in $(get_installed_packages_war_list); do
    for package_war in $(find "${d}" -type f -name "*.war"); do
      for ear_war in "${tmp_dir}/"*.war; do
        if [[ $(basename "${ear_war}") == $(basename "${package_war}") ]]; then
          log "Replacing WAR in EAR, $(basename "${ear_war}"), with ${package_war}"
          run cp "${package_war}" "${ear_war}"
        fi
      done
    done
  done
}

## Normalises the file name so that we can compare two JARs of
## different versions.
##
## $1 :: file name
## $2 :: suffix
get_file_base() {
  basename "$1" "$2" |
    sed -r \
        -e 's#[-][0-9.-]+##' \
        -e 's#[-][a-z]+-SNAPSHOT##' \
        -e 's#[-][0-9]+.[0-9]+-SNAPSHOT##' \
        -e 's#[.]$##'
}

## $1 :: tmp dir with EAR contents
overwrite_libs_included_in_installed_packages() {
  local tmp_dir=$1
  find "${USR_SHARE_DIR}/escenic-"* -maxdepth 1 -name "lib" -type d | \
    while read -r d; do
      for package_jar in "${d}"/*.jar; do
        package_jar_base=$(get_file_base "${package_jar}" jar)

        for ear_jar in "${tmp_dir}/lib/"*.jar; do
          ear_jar_base=$(get_file_base "${ear_jar}" jar)
          if [[ "${ear_jar_base}" == "${package_jar_base}" ]]; then
            debug "Replacing JAR in EAR, $(basename "${ear_jar}"), with ${package_jar}"
            run rm "${ear_jar}"
            run cp "${package_jar}" "$(dirname "${ear_jar}")"
          fi
        done
      done
    done
}

## $1 :: tmp dir with WAR contents
overwrite_publication_webapp_libs_included_in_installed_packages() {
  local tmp_dir=$1

  for pub_war_jar in "${tmp_dir}/WEB-INF/lib/"*.jar; do
    pub_war_jar_base=$(get_file_base "${pub_war_jar}" jar)
    debug "${FUNCNAME[0]}
      Checking pub_war_jar=$pub_war_jar
      pub_war_jar_base=$pub_war_jar_base"

    for package_dir in "${USR_SHARE_DIR}/"*; do
      local template_lib_dir="${package_dir}/template/WEB-INF/lib"
      if [ ! -d "${template_lib_dir}" ]; then
        # ECE and its plugins put their publication specific libraries
        # in different directory structures.
        template_lib_dir="${package_dir}/publication/webapp/WEB-INF/lib"
        if [ ! -d "${template_lib_dir}" ]; then
          continue
        fi
      fi

      find "${template_lib_dir}" -name "*.jar" -type f | \
        while read -r package_jar; do
          package_jar_base=$(get_file_base "${package_jar}" jar)

          if [[ "${pub_war_jar_base}" == "${package_jar_base}" ]]; then
            debug " -> Replacing ${pub_war_jar} with ${package_jar}"
            run rm "${pub_war_jar}"
            run cp "${package_jar}" "$(dirname "${pub_war_jar}")"
          fi
        done
    done
  done
}

## $1 :: the dir where the new EAR will be present
## $2 :: the dir whose contents will form the contents of the new EAR
## $3 :: the old EAR name or HASH
create_new_ear_in_dir() {
  local result_dir=$1
  local dir=$2
  local old_ear=$3

  local new_ear=
  new_ear="${result_dir}/$(date --iso)-$(date +%s)-repackaged-${old_ear}-created-on-${HOSTNAME}.zip"
  (
    run cd "${dir}"
    run zip --quiet --recurse-paths "${new_ear}" .
  )

  log "The new EAR is ready!: ${new_ear}
       You can deploy it with:
       ece -i ${instance} --file ${new_ear} stop deploy start"

  echo "${new_ear}"
}

## Overwrite the JAR libraries inside the EAR specific webapps,
## most/all of which will be publication webapps.
##
## $1 :: the dir in which the extracted EAR resides
overwrite_publication_webapp_libs() {
  local dir=$1
  local installed_package_war_list=
  installed_package_war_list=$(get_installed_packages_war_list)

  for war in ${dir}/*.war; do
    if [[ $(echo "${installed_package_war_list}" | grep -c "$(basename "${war}")") -gt 0 ]]; then
      log "Don't need to fix $(basename "${war}") (it's provided by a package)"
    else
      local start=
      local tmp_dir=
      tmp_dir=$(mktemp -d)

      log "Fixing $(basename "${war}"), extracting it to ${tmp_dir} ..."
      run unzip -q "${war}" -d "${tmp_dir}"

      start=$(date +%s)
      overwrite_publication_webapp_libs_included_in_installed_packages "${tmp_dir}"
      log "Fixing $(basename "${war}") took $(( $(date +%s) - start)) seconds ..."

      # to be sure it's prestine, we delete the old war
      run rm "${war}"
      (
        cd "${tmp_dir}"
        run zip --recurse-paths --quiet "${war}" .
      )

      run rm -rf "${tmp_dir}"
    fi
  done
}

## In case no local or URI reference to an EAR is passed, the method
## will try to find a sane, local EAR file to use for the repackaging.
##
## The method reads and writes the variables:
##   - file_or_uri and
##   - ear_name_or_hash
##
## $1 :: The file or URI to an EAR, as passed to the 'ece' command
##       with --uri or --file.
ensure_ear_reference_and_lineage_sanity() {
  if [ -n "${file_or_uri}" ]; then
    ear_name_or_hash=$(basename "${file_or_uri}")
    return
  fi

  # this is the fallback ear
  local default_cached_engine_ear=${cache_dir}/engine.ear

  # The deployment log is updated whenever 'ece deploy' is used.
  local deployment_log=
  deployment_log=$(get_deployment_log)

  if [ -r "${deployment_log}" ]; then
    local last_deployed_ear=
    last_deployed_ear=$(awk '{print $7;}' "${deployment_log}" | tail -1)
    ear_name_or_hash=$(awk '{print $8;}' "${deployment_log}" | tail -1)
    file_or_uri=${cache_dir}/${last_deployed_ear}
  elif [ -r "${default_cached_engine_ear}" ]; then
    file_or_uri=${default_cached_engine_ear}
    ear_name_or_hash=$(basename "${default_cached_engine_ear}")
  else
    print_and_log "
      You must either specify an EAR to be repackaged
      using --file <ear> or --uri <ear>, or the previously
      deployed EAR must be available in ${cache_dir}."
    exit 1
  fi
}

## $1 :: file_or_uri
get_local_ear_reference() {
  local file_or_uri=$1

  if [ -f "${file_or_uri}" ]; then
    echo "${file_or_uri}"
  else
    export wget_auth=${wget_builder_auth}

    local file_name=
    file_name=$(basename "${file_or_uri}")

    download_uri_target_to_dir "${file_or_uri}" "${cache_dir}" "${file_name}"

    echo "${cache_dir}/${file_name}"
  fi
}

## $1 :: EAR file or URI
repackage() {
  local ear=
  local file_or_uri=$1

  ensure_ear_reference_and_lineage_sanity "${file_or_uri}"
  ear=$(get_local_ear_reference "${file_or_uri}")

  local tmp_dir=
  tmp_dir=$(mktemp -d)

  print "Repackaging ${ear} with OS package installed JARs and WARs ..."
  start_time=$(date +%s)
  extract_archive "${ear}" "${tmp_dir}"
  overwrite_webapps_that_are_included_in_installed_packages "${tmp_dir}"
  overwrite_libs_included_in_installed_packages "${tmp_dir}"
  overwrite_publication_webapp_libs "${tmp_dir}"

  # The ${file} variable is used by deploy.sh::deploy()
  export file=$(
    create_new_ear_in_dir \
      /tmp \
      "${tmp_dir}" \
      "${ear_name_or_hash}")

  log "Deleting ${tmp_dir} ..."
  run rm -rf "${tmp_dir}"

  local took=
  took=$(($(date +%s) - start_time))
  print_and_log "Repackaging ${ear} took ${took} seconds,
                 new EAR created: ${file}"
}
