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
  done

  for p in "${!fai_package_map[@]}"; do
    echo p="$p" v="${fai_package_map[${p}]}"
  done

}

_parse_yaml_conf_file_editor() {
  local yaml_file=$1

  local install_editor=no
  install_editor=$(_jq "${yaml_file}" .profiles[].editor)
  if [[ "${install_editor}" == "yes" ]]; then
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

  ## TODO tkj: if there's a 'packages:' stanza, can just set
  ## fai_package_enabled=1
  local configured_use_escenic_packages=
  configured_use_escenic_packages=$(_jq "${yaml_file}" .environment[].use_escenic_packages)
  if [[ "${configured_use_escenic_packages}" == "yes" ]]; then
    export fai_package_enabled=1
  fi
}

_parse_yaml_conf_file_presentation() {
  local yaml_file=$1

  local install_presentation=no
  install_presentation=$(_jq "${yaml_file}" .profiles[].presentation)
  if [[ "${install_presentation}" == "yes" ]]; then
    export fai_presentation_install=1
  fi
}

_parse_yaml_conf_file_search() {
  local yaml_file=$1

  local install_search=no
  install_search=$(_jq "${yaml_file}" .profiles[].search)
  if [[ "${install_search}" == "yes" ]]; then
    export fai_search_install=1
  fi
}

_parse_yaml_conf_file_cache() {
  local yaml_file=$1

  local install_cache=no
  install_cache=$(_jq "${yaml_file}" .profiles[].cache)
  if [[ "${install_cache}" == "yes" ]]; then
    export fai_cache_install=1
  fi
}

_parse_yaml_conf_file_db() {
  local yaml_file=$1

  local install_db=no
  install_db=$(_jq "${yaml_file}" .profiles[].db)
  if [[ "${install_db}" == "yes" ]]; then
    export fai_db_install=1
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
