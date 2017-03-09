# -*- mode: sh; sh-shell: bash; -*-

## imports
source "${BASH_SOURCE[0]%/*}/../common-os.sh"

## $1 :; YAML file
is_yaml() {
  local yaml_file=$1
  json_xs < "${yaml_file}" -f yaml -t json &> /dev/null || {
    return 1
  }

  return 0
}


## Will parse the YAML file and set the corresponding fai_ parameters
## that ece-install uses internally. Old ece-install.conf style files
## are still supported: if ece-install cannot recognoise the file as
## YAML it'll assume it's in the old format and will source it.
##
## $1 :: YAML file.
parse_yaml_conf_file_or_source_if_sh_conf() {
  assert_commands_available json_xs jq

  local yaml_file=$1
  if ! is_yaml "${yaml_file}"; then
    source "${yaml_file}"
    return
  fi

  _parse_yaml_conf_file_editor "${yaml_file}"
  _parse_yaml_conf_file_presentation "${yaml_file}"
  _parse_yaml_conf_file_search "${yaml_file}"
  _parse_yaml_conf_file_db "${yaml_file}"
  _parse_yaml_conf_file_cache "${yaml_file}"
  _parse_yaml_conf_file_credentials "${yaml_file}"
  _parse_yaml_conf_file_publications "${yaml_file}"
  _parse_yaml_conf_file_packages "${yaml_file}"
  _parse_yaml_conf_file_environment "${yaml_file}"
}

_parse_yaml_conf_file_credentials() {
  local yaml_file=$1
  local count=0
  count=$(_jq "${yaml_file}" ".credentials | length")
  for ((i = 0; i < count; i++)); do
    local user=
    local password=
    local site=
    site=$(_jq "${yaml_file}" .credentials["${i}"].site)
    user=$(_jq "${yaml_file}" .credentials["${i}"].user)
    password=$(_jq "${yaml_file}" .credentials["${i}"].password)
    if [[ "${site}" == maven.escenic.com ]]; then
      export technet_user=${user}
      export technet_password=${password}
    fi
  done

}

_parse_yaml_conf_file_publications() {
  local yaml_file=$1
  local count=0
  count=$(_jq "${yaml_file}" ".profiles.publications | length")

  fai_publication_domain_mapping_list=""

  for ((i = 0; i < count; i++)); do
    # If there are one or more publications defined in
    # 'publications', we assume the user wants to create these.
    export fai_publication_create=1

    local name=
    local war=
    local domain=
    local aliases=

    name=$(_jq "${yaml_file}" .profiles.publications["${i}"].name)
    war=$(_jq "${yaml_file}" .profiles.publications["${i}"].war)

    if [ -z "${war}" ]; then
      war=${name}.war
    fi

    domain=$(_jq "${yaml_file}" .profiles.publications["${i}"].domain)
    alias_count=$(_jq "${yaml_file}" ".profiles.publications[${i}].aliases | length")

    for ((j = 0; j < alias_count; j++)); do
      if [ -n "${aliases}" ]; then
        aliases="${aliases},"
      fi
      aliases=${aliases}$(_jq "${yaml_file}" .profiles.publications["${i}"].aliases["${j}"])
    done

    fai_publication_domain_mapping_list="
      ${fai_publication_domain_mapping_list}
      ${name},${war}#${domain}"

    if [ -n "${aliases}" ]; then
      fai_publication_domain_mapping_list=${fai_publication_domain_mapping_list}"#${aliases}"
    fi
  done

  export fai_publication_domain_mapping_list

}

## Populates the global variable fai_package_map with package names
## and (optionally) versions.
##
## Developer's note: This associative array is declared in this
## module, but if it for reason is unset by the caller, the caller
## must re-initialise it too (as is done in the unit tests).
_parse_yaml_conf_file_packages() {
  local yaml_file=$1
  local count=0
  count=$(_jq "${yaml_file}" ".packages | length")

  for ((i = 0; i < count; i++)); do
    local name=
    local version=
    name=$(_jq "${yaml_file}" .packages["${i}"].name)
    version=$(_jq "${yaml_file}" .packages["${i}"].version)
    fai_package_map[${name}]=${version}
    export fai_package_enabled=1
    export escenic_root_dir=/usr/share/escenic
  done
}

_parse_yaml_conf_file_editor() {
  local yaml_file=$1

  local install_editor=no
  install_editor=$(_jq "${yaml_file}" .profiles.editor.install)
  if [[ "${install_editor}" == "yes" ||
          "${install_editor}" == "true" ]]; then
    export fai_editor_install=1
  fi
}

_parse_yaml_conf_file_environment() {
  local yaml_file=$1

  local configured_java_home=
  configured_java_home=$(_jq "${yaml_file}" .environment[].java_home)
  if [[ -n "${configured_java_home}" ]]; then
    export java_home=${configured_java_home}
  fi
}

_parse_yaml_conf_file_presentation() {
  local yaml_file=$1

  local install_presentation=no
  install_presentation=$(_jq "${yaml_file}" .profiles.presentation.install)
  if [[ "${install_presentation}" == "yes" ||
          "${install_presentation}" == "true" ]]; then
    export fai_presentation_install=1
  fi
}

_parse_yaml_conf_file_search() {
  local yaml_file=$1

  local install_search=no
  install_search=$(_jq "${yaml_file}" .profiles.search.install)
  if [[ "${install_search}" == "yes" ||
          "${install_search}" == "true" ]]; then
    export fai_search_install=1
  fi
}

_parse_yaml_conf_file_cache() {
  local yaml_file=$1

  local install_cache=no
  install_cache=$(_jq "${yaml_file}" .profiles.cache.install)
  if [[ "${install_cache}" == "yes" ||
          "${install_cache}" == "true" ]]; then
    export fai_cache_install=1
  fi
}

_parse_yaml_conf_file_db() {
  local yaml_file=$1

  local install_db=no
  install_db=$(_jq "${yaml_file}" .profiles.db.install)
  if [[ "${install_db}" == "yes" ||
          "${install_db}" == "true" ]]; then
    export fai_db_install=1
  fi

  local install_db_user=
  install_db_user=$(_jq "${yaml_file}" .profiles.db.user)
  if [ -n "${install_db_user}" ]; then
    export fai_db_user=${install_db_user}
  fi

  local install_db_password=
  install_db_password=$(_jq "${yaml_file}" .profiles.db.password)
  if [ -n "${install_db_password}" ]; then
    export fai_db_password=${install_db_password}
  fi

  local install_db_schema=
  install_db_schema=$(_jq "${yaml_file}" .profiles.db.schema)
  if [ -n "${install_db_schema}" ]; then
    export fai_db_schema=${install_db_schema}
  fi

  local install_db_host=
  install_db_host=$(_jq "${yaml_file}" .profiles.db.host)
  if [ -n "${install_db_host}" ]; then
    export fai_db_host=${install_db_host}
  fi

  local install_db_port=
  install_db_port=$(_jq "${yaml_file}" .profiles.db.port)
  if [ -n "${install_db_port}" ]; then
    export fai_db_port=${install_db_port}
  fi
}

_jq() {
  local yaml_file=$1
  local key=$2

  local json=
  json=$(json_xs < "${yaml_file}" -f yaml -t json)
  jq --raw-output --exit-status <<< "${json}" "${key}" 2>/dev/null |
    grep -v null
}
