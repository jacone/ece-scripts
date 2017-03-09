#! /usr/bin/env bash
## author: torstein@escenic.com

test_can_parse_yaml_conf_db() {
  local yaml_file=
  yaml_file=$(mktemp)
  local db_user=foodbuser
  local db_password=foodbpassword
  local db_schema=foodbdb
  local db_host=foodbhost
  local db_port=foodbport
  local db_install=yes

  cat > "${yaml_file}" <<EOF
---
profiles:
  db:
    install: ${db_install}
    user: ${db_user}
    password: ${db_password}
    schema: ${db_schema}
    host: ${db_host}
    port: ${db_port}
EOF

  unset fai_db_install
  unset fai_db_user
  unset fai_db_password
  unset fai_db_schema
  unset fai_db_host
  unset fai_db_port

  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"

  assertNotNull "Should set fai_db_install" "${fai_db_install}"
  assertEquals "Should set fai_db_install" 1 "${fai_db_install}"

  assertNotNull "Should set fai_db_user" "${fai_db_user}"
  assertEquals "Should set fai_db_user" "${db_user}" "${fai_db_user}"

  assertNotNull "Should set fai_db_password" "${fai_db_password}"
  assertEquals "Should set fai_db_password" "${db_password}" "${fai_db_password}"

  assertNotNull "Should set fai_db_schema" "${fai_db_schema}"
  assertEquals "Should set fai_db_schema" "${db_schema}" "${fai_db_schema}"

  assertNotNull "Should set fai_db_host" "${fai_db_host}"
  assertEquals "Should set fai_db_host" "${db_host}" "${fai_db_host}"

  assertNotNull "Should set fai_db_port" "${fai_db_port}"
  assertEquals "Should set fai_db_port" "${db_port}" "${fai_db_port}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_credentials() {
  local yaml_file=
  yaml_file=$(mktemp)
  local escenic_download_user=foouser
  local escenic_download_password=barpassword

  cat > "${yaml_file}" <<EOF
---
credentials:
  - site: maven.escenic.com
    user: ${escenic_download_user}
    password: ${escenic_download_password}
EOF

  unset technet_user
  unset technet_password
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Should set technet_user" "${technet_user}"
  assertEquals "Should set technet_user" "${escenic_download_user}" "${technet_user}"

  assertNotNull "Should set technet_password" "${technet_password}"
  assertEquals "Should set technet_password" "${escenic_download_password}" "${technet_password}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_create_publication() {
  local yaml_file=
  yaml_file=$(mktemp)
  local publication1_name=foopub
  local publication1_war=pub.war
  local publication1_domain=foo.example.com
  local publication1_alias1=fooalias1.example.com
  local publication1_alias2=fooalias2.example.com

  cat > "${yaml_file}" <<EOF
---
profiles:
   publication:
     - name: ${publication1_name}
       war: ${publication1_war}
       domain: ${publication1_domain}
       aliases:
         - ${publication1_alias1}
         - ${publication1_alias2}
EOF

  unset fai_publication_domain_mapping_list
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertEquals "Having pubs defined, sets enabled flag" \
               1 \
               "${fai_publication_create}"


  assertNotNull "Able to parse info for creating publications" \
                "${fai_publication_domain_mapping_list}"
  for el in ${fai_publication_domain_mapping_list}; do
    IFS='#' read -r publication domain aliases <<< "${el}"
    IFS=',' read -r name war <<< "$publication"
    assertEquals "publication name from map" \
                 "${publication1_name}" \
                 "${name}"
    assertEquals "publication war from map" \
                 "${publication1_war}" \
                 "${war}"
    assertEquals "publication domain from map" \
                 "${publication1_domain}" \
                 "${domain}"
    assertEquals "publication aliases from map" \
                 "${publication1_alias1},${publication1_alias2}" \
                 "${aliases}"
  done

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_publication() {
  local yaml_file=
  yaml_file=$(mktemp)
  local publication1_name=foopub
  local publication1_war=pub.war
  local publication1_domain=foo.example.com
  local publication1_alias1=fooalias1.example.com
  local publication1_alias2=fooalias2.example.com
  local publication1_aliases=${publication1_alias1},${publication1_alias2}

  local publication2_name=barpub
  local publication2_war=bar.war
  local publication2_domain=bar.example.com
  local publication2_alias1=baralias1.example.com
  local publication2_alias2=baralias2.example.com
  local publication2_aliases=${publication2_alias1},${publication2_alias2}

  cat > "${yaml_file}" <<EOF
---
profiles:
   publications:
     - name: ${publication1_name}
       war: ${publication1_war}
       domain: ${publication1_domain}
       aliases:
         - ${publication1_alias1}
         - ${publication1_alias2}
     - name: ${publication2_name}
       war: ${publication2_war}
       domain: ${publication2_domain}
       aliases:
          - ${publication2_alias1}
          - ${publication2_alias2}
EOF

  unset fai_publication_domain_mapping_list
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Able to parse info for creating publications" \
                "${fai_publication_domain_mapping_list}"
  for el in ${fai_publication_domain_mapping_list}; do
    IFS='#' read -r publication domain aliases <<< "${el}"
    IFS=',' read -r name war <<< "$publication"

    if [[ "${name}" == "${publication1_name}" ]]; then
      found_publication1_name=1
    elif [[ "${name}" == "${publication2_name}" ]]; then
      found_publication2_name=1
    fi
    if [[ "${war}" == "${publication1_war}" ]]; then
      found_publication1_war=1
    elif [[ "${war}" == "${publication2_war}" ]]; then
      found_publication2_war=1
    fi
    if [[ "${domain}" == "${publication1_domain}" ]]; then
      found_publication1_domain=1
    elif [[ "${domain}" == "${publication2_domain}" ]]; then
      found_publication2_domain=1
    fi
    if [[ "${aliases}" == "${publication1_aliases}" ]]; then
      found_publication1_aliases=1
    elif [[ "${aliases}" == "${publication2_aliases}" ]]; then
      found_publication2_aliases=1
    fi
  done

  assertEquals "Can configure both pubs, name" 1 "${found_publication1_name}"
  assertEquals "Can configure both pubs, name" 1 "${found_publication2_name}"
  assertEquals "Can configure both pubs, war" 1 "${found_publication1_war}"
  assertEquals "Can configure both pubs, war" 1 "${found_publication2_war}"
  assertEquals "Can configure both pubs, domain" 1 "${found_publication1_domain}"
  assertEquals "Can configure both pubs, domain" 1 "${found_publication2_domain}"
  assertEquals "Can configure both pubs, aliases" 1 "${found_publication1_aliases}"
  assertEquals "Can configure both pubs, aliases" 1 "${found_publication2_aliases}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_packages() {
  local yaml_file=
  yaml_file=$(mktemp)
  local package_name=escenic-content-engine
  local package_version=6.1.0-2

  cat > "${yaml_file}" <<EOF
---
packages:
  - name: ${package_name}
    version: ${package_version}
EOF
  unset fai_package_map
  declare -A fai_package_map
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"

  for name in "${!fai_package_map[@]}"; do
    local version=${fai_package_map[${name}]}
    assertEquals "Should have parsed package name" "${package_name}" "${name}"
    assertEquals "Should have parsed package version" "${package_version}" "${version}"
  done

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_packages_multiple() {
  local yaml_file=
  yaml_file=$(mktemp)

  local package_name=escenic-content-engine
  local package_version=6.1.0-2
  local package_name_without_version=escenic-video

  cat > "${yaml_file}" <<EOF
---
packages:
  - name: ${package_name}
    version: ${package_version}
  - name: ${package_name_without_version}
EOF
  unset fai_package_map
  declare -A fai_package_map
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"

  for name in "${!fai_package_map[@]}"; do
    local version=${fai_package_map[${name}]}

    if [[ "${name}" == "${package_name_without_version}" ]]; then
      assertNull "Package without version should have no version" \
                 "${version}"
    else
      assertEquals "Should have parsed package version" "${package_version}" "${version}"
    fi
  done

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_java_home() {
  local yaml_file=
  yaml_file=$(mktemp)
  local foo_java_home=/usr/lib/jvm/foo-java-sdk

  cat > "${yaml_file}" <<EOF
---
environment:
  - java_home: ${foo_java_home}
EOF

  unset java_home
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Should set java_home" "${java_home}"
  assertEquals "Should set java_home" "${foo_java_home}" "${java_home}"
  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_use_escenic_packages() {
  local yaml_file=
  yaml_file=$(mktemp)
  local foo_java_home=/usr/lib/jvm/foo-java-sdk

  cat > "${yaml_file}" <<EOF
---
packages:
  foo: 1
EOF

  unset fai_package_enabled
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Should set fai_package_enabled" "${fai_package_enabled}"
  assertEquals "Should set fai_package_enabled" 1 "${fai_package_enabled}"

  # no packages: block means don't use packages
  cat > "${yaml_file}" <<EOF
---
foo:
EOF

  unset fai_package_enabled
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNull "Should NOT set fai_package_enabled" "${fai_package_enabled}"
  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_presentation_install() {
  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
---
profiles:
  presentation:
    install: yes
EOF

  unset fai_presentation_install
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Should set fai_presentation_install" "${fai_presentation_install}"
  assertEquals "Should set fai_presentation_install" 1 "${fai_presentation_install}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_search_install() {
  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
---
profiles:
  search:
    install: yes
EOF

  unset fai_search_install
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Should set fai_search_install" "${fai_search_install}"
  assertEquals "Should set fai_search_install" 1 "${fai_search_install}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_editor_install() {
  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
---
profiles:
  editor:
    install: yes
    port: 8080
    name: engine1
EOF

  unset fai_editor_install
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Should set fai_editor_install" "${fai_editor_install}"
  assertEquals "Should set fai_editor_install" 1 "${fai_editor_install}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_editor_install_multi_profiles() {
  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
profiles:
  editor:
    install: yes
  search:
    install: yes
  db:
    install: no
EOF

  unset fai_editor_install
  unset fai_search_install
  unset fai_db_install

  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Should set fai_editor_install" "${fai_editor_install}"
  assertEquals "Should set fai_editor_install" 1 "${fai_editor_install}"
  assertEquals "Should set fai_search_install" 1 "${fai_search_install}"
  assertNull "Should not have set fai_db_install" "${fai_db_install}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_db_install() {
  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
---
profiles:
  db:
    install: yes
EOF

  unset fai_db_install
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Should set fai_db_install" "${fai_db_install}"
  assertEquals "Should set fai_db_install" 1 "${fai_db_install}"

  # now, try to set it to true
  cat > "${yaml_file}" <<EOF
---
profiles:
  db:
    install: true
EOF
  unset fai_db_install
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Should set fai_db_install" "${fai_db_install}"
  assertEquals "Should set fai_db_install" 1 "${fai_db_install}"

  # now, try to set it to false
  cat > "${yaml_file}" <<EOF
---
profiles:
  db:
    install: false
EOF
  unset fai_db_install
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNull "Should not have set fai_db_install" "${fai_db_install}"

  rm -rf "${yaml_file}"
}

test_can_parse_yaml_conf_cache_install() {
  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
---
profiles:
  cache:
    install: yes
EOF

  unset fai_cache_install
  parse_yaml_conf_file_or_source_if_sh_conf "${yaml_file}"
  assertNotNull "Should set fai_cache_install" "${fai_cache_install}"
  assertEquals "Should set fai_cache_install" 1 "${fai_cache_install}"

  rm -rf "${yaml_file}"
}

test_can_recognise_a_yaml_conf_file() {
  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
---
foo: bar
EOF

  local expected=0
  is_yaml "${yaml_file}" && actual=$? || actual=$?
  assertEquals "${expected}" "${actual}"

  rm -rf "${yaml_file}"
}

test_can_recognise_a_conf_file_thats_not_yaml_xml() {
  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
<foo>bar</foo>
EOF

  local expected=1
  is_yaml "${yaml_file}" && actual=$? || actual=$?
  assertEquals "${expected}" "${actual}"

  rm -rf "${yaml_file}"
}

test_can_recognise_a_conf_file_thats_not_yaml_conf() {
  local yaml_file=
  yaml_file=$(mktemp)
  cat > "${yaml_file}" <<EOF
<foo>bar</foo>
EOF

  local expected=1
  is_yaml "${yaml_file}" && actual=$? || actual=$?
  assertEquals "${expected}" "${actual}"

  rm -rf "${yaml_file}"
}

## @override shunit2
setUp() {
  source "$(dirname "$0")/../../../share/escenic/ece-scripts/ece-install.d/conf-file-reader.sh"
}

## @override shunit2
tearDown() {
  :
}

main() {
  . "$(dirname "$0")"/shunit2/source/2.1/src/shunit2
}

main "$@"
