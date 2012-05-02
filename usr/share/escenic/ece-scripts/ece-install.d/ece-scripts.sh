#! /usr/bin/env bash

# code for the ece-scripts themselves

function install_ece_scripts_with_apt() {
  curl -s http://apt.vizrt.com/archive.key 2>> $log | apt-key add -
  add_apt_source "deb http://apt.vizrt.com stable main"
  install_packages_if_missing escenic-content-engine-scripts
}

function install_ece_scripts_with_git() {
  run cd $download_dir
  if [ -d ece-scripts ]; then
    (
      run cd ece-scripts
      run git pull
    )
  else
    run git clone $ece_scripts_git_source
  fi
  
  run cp -r ece-scripts/usr/* /usr/
  run cp -r ece-scripts/etc/bash_completion.d/ece /etc/bash_completion.d/
  run cp -r ece-scripts/etc/init.d/* /etc/init.d/

  for el in ece-scripts/etc/default/*; do
    local file=/etc/default/$(basename $el)
    if [ -e $file ]; then
      print_and_log "$file already exists, not overwriting it"
      continue
    fi
    run cp $el /etc/default/
  done
  
  for el in ece-scripts/etc/escenic/*; do
    local file=/etc/escenic/$(basename $el)
    if [ -e $file ]; then
      print_and_log "$file already exists, not overwriting it"
      continue
    fi
    run cp $el /etc/escenic/
  done
}

function set_up_ece_scripts()
{
  print_and_log 'Setting up the ece UNIX scripts ...'

  if [ $on_debian_or_derivative -eq 1 ]; then
    install_ece_scripts_with_apt
  else
    install_ece_scripts_with_git
  fi
  
  local file=${escenic_conf_dir}/ece.conf
  set_conf_file_value assemblytool_home ${escenic_root_dir}/assemblytool $file
  set_conf_file_value backup_dir ${escenic_backups_dir} $file
  set_conf_file_value cache_dir ${escenic_cache_dir} ${file}
  set_conf_file_value data_dir ${escenic_data_dir} ${file}
  set_conf_file_value ece_home ${escenic_root_dir}/engine ${file}
  set_conf_file_value escenic_conf_dir ${escenic_conf_dir} ${file}
  set_conf_file_value heap_dump_dir ${escenic_crash_dir} ${file}
  set_conf_file_value java_home ${java_home} ${file}
  set_conf_file_value log_dir ${escenic_log_dir} ${file}
  set_conf_file_value pid_dir ${escenic_run_dir} ${file}
  set_conf_file_value rmi_hub_conf ${escenic_conf_dir}/rmi-hub ${file}
  set_conf_file_value solr_home ${escenic_data_dir}/solr ${file}
  set_conf_file_value ece_security_configuration_dir \
    ${escenic_conf_dir}/engine/common/security \
    ${file}

  run sed -i "s#/etc/escenic#${escenic_conf_dir}#g" /etc/bash_completion.d/ece
  run sed -i "s#/opt/escenic#${escenic_root_dir}#g" /etc/bash_completion.d/ece
}
