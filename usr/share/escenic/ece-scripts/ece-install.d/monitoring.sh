# module for installing monitoring software, both server and client side.


## Installs and sets up self-reporting of the current host
function install_system_info() {
  # we don't support RedHat right now
  if [ $on_redhat_or_derivative -eq 1 ]; then
    return
  fi

  print_and_log "Setting up a self-reporting module on $HOSTNAME ..."

  install_packages_if_missing lighttpd escenic-common-scripts
  assert_commands_available lighttpd

  local port=${fai_reporting_port-5678}
  local dir=${fai_reporting_dir-/var/www/system-info}
  make_dir $dir

  # configure the web server
  local file=/etc/lighttpd/lighttpd.conf

  # set the port
  local property=server.port
  if [ $(grep ^server.port $file | wc -l) -eq 0 ]; then
    echo "${property} = \"${port}\"" >> $file
  else
    run sed -i "s~^${property}.*=.*$~${property}=\"${port}\"~g" $file
  fi

  # disable the hackish IPv6 listener on port 80
  local ipv6_pl='include_shell "/usr/share/lighttpd/use-ipv6.pl"'
  run sed -is "s~^${ipv6_pl}~#${ipv6_pl}~g" $file

  # set the document root
  property=server.document-root
  run sed -i "s~^${property}.*=.*\"/var/www\"$~${property}=\"$dir\"~g" $file

  # make the web server start
  run /etc/init.d/lighttpd restart

  # set system-info to be run every minute on the host
  local command="system-info -f html -u $ece_user > $dir/index.html"
  if [ $(grep -v ^# /etc/crontab | grep "$command" | wc -l) -lt 1 ]; then
    echo '* *     * * *   root    '$command >> /etc/crontab
  fi

  # doing a first run of system-info since cron will take a minute to start
  eval $command

  # creating symlinks like:
  # /var/www/system-info/var/log/escenic -> /var/log/escenic
  # /var/www/system-info/etc/escenic -> /etc/escenic
  local dir_list="
    $escenic_log_dir
    $escenic_conf_dir
    $escenic_data_dir
    $tomcat_base/logs
  "
  for source_dir in $dir_list; do
    if [ ! -d $source_dir ]; then
      continue
    fi

    local target_dir=$dir/$source_dir
    make_dir $(dirname $target_dir)
    
    if [ ! -h $target_dir ]; then
      run ln -s $source_dir $target_dir
    fi
    
    # thttpd doesn't serve files if they've got the execution bit set
    # (it then think it's a misnamed CGI script). Hence, we must
    # ensure the execute bit is not set.
    find $source_dir -type f | egrep ".(conf|properties|log|diff|report|out)$" | \
      while read f; do
      run chmod 644 $f
    done
  done

  add_next_step "Always up to date system info: http://$HOSTNAME:$port/" \
    "you can also see system-info in the shell, type: system-info"
}

## Returns the privileged hosts. This will include both the IP(s) the
## logged in user conduction the ece-install is coming from, as well
## as any IPs defined in fai_monitoring_privileged_hosts.
function get_privileged_hosts() {
  local privileged_hosts=${fai_monitoring_privileged_hosts}

  log fai_monitoring_privileged_hosts=$fai_monitoring_privileged_hosts
  
  for ip in $(
    w -h  | \
      grep pts | \
      grep -v ":0.0" | \
      sed "s#.*pts/[0-9]*[ ]*\(.*\)#\1#" | \
      cut -d' ' -f1 | \
      cut -d':' -f1 | \
      sort | \
      uniq
  ); do
    privileged_hosts=${privileged_hosts}" "${ip}
  done

  log privileged_hosts=$privileged_hosts
  
  echo ${privileged_hosts}
}

