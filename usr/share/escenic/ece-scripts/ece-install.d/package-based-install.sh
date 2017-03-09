# -*- mode: sh; sh-shell: bash; -*-

## Component handling package based installation of Escenic
## components. Code specific to install Escenic sofftware using APT,
## dpkg, YUM and or RPM goes here.
##
## author: torstein@escenic.com

## Since the updater package assumes a working ECE environment and we
## install it as a part of ece-install, it's a chicken and and egg
## problem. Therefore, we must here set up a few pre-requisites for
## the updater package to install smoothly.
_install_prerequisites_for_updater_package() {
  local the_tomcat_base=${appserver_parent_dir}/tomcat-${instance_name-engine1}
  set_ece_instance_conf java_home "${java_home}"
  set_ece_instance_conf tomcat_home "${appserver_parent_dir}/tomcat"
  set_ece_instance_conf tomcat_base "${the_tomcat_base}"

  make_dir "${the_tomcat_base}/webapps" \
           "${the_tomcat_base}/escenic/lib"
  run chown -R "${ece_user}:${ece_group}" "${the_tomcat_base}"
}

## Installs the configured escenic packages. If none were configured,
## just ECE will be installed.
install_configured_escenic_packages() {

  if [ "${on_debian_or_derivative}" -eq 1 ]; then
    local escenic_deb_packages=
    local package=
    for package in "${!fai_package_map[@]}"; do

      if [[ "${package}" =~ "escenic-content-engine-updater-"* ]]; then
        _install_prerequisites_for_updater_package
      fi

      local version=${fai_package_map[${package}]}
      if [ -n "${version}" ]; then
        escenic_deb_packages="${package}=${version} ${escenic_deb_packages}"
      else
        escenic_deb_packages="${package} ${escenic_deb_packages}"
      fi
    done

    run apt-get install ${apt_opts} \
        --assume-yes \
        --force-yes \
        ${escenic_deb_packages-escenic-content-engine}
  elif [ "${on_redhat_or_derivative}" -eq 1 ]; then
    :
  fi
}
