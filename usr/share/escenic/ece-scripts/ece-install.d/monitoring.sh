# module for installing monitoring software, both server and client side.

MONITORING_VENDOR_NAGIOS=nagios
MONITORING_VENDOR_ICINGA=icinga

## Installs the Nagios monitoring server.
## $1 the nagios vendor/falvour, "nagios" and "icinga" are supported.
function install_nagios_monitoring_server()
{
  print "Installing an $1 server on $HOSTNAME ..."
  local monitoring_vendor=$1
  
  if [ $on_debian_or_derivative -eq 1 ]; then
    if [[ $monitoring_vendor == $MONITORING_VENDOR_NAGIOS ]]; then
      install_packages_if_missing apache2 nagios3 nagios-nrpe-plugin
    else
      install_packages_if_missing \
        apache2 icinga nagios-nrpe-plugin icinga-doc
    fi
  fi

  if [[ $monitoring_vendor == $MONITORING_VENDOR_ICINGA ]]; then
    print "Setting user/pass for icinga admin ..."
    local file=/etc/icinga/htpasswd.users
    run htpasswd -b -c $file icingaadmin \
      ${fai_monitoring_admin_password-admin}
  fi
  
    # enable remote commands
  if [[ $monitoring_vendor == $MONITORING_VENDOR_NAGIOS ]]; then
    local file=/etc/nagios3/nagios.cfg
  else
    local file=/etc/icinga/icinga.cfg
  fi
  
  dont_quote_conf_values=1
  set_conf_file_value check_external_commands 1 $file
  dont_quote_conf_values=0

  for el in $fai_monitoring_host_list; do
    set_up_monitoring_host_def $monitoring_vendor $el
  done

  if [[ $monitoring_vendor == $MONITORING_VENDOR_NAGIOS ]]; then
    file=/etc/nagios3/conf.d/hostgroups_nagios2.cfg
  else
    file=/etc/icinga/objects/hostgroups_icinga.cfg
  fi
  
  set_up_monitoring_host_group \
    $file \
    "ece-hosts" \
    'Hosts running one or more ECE' \
    ${fai_monitoring_ece_host_list}

  set_up_monitoring_host_group \
    $file \
    "search-hosts" \
    'Hosts running search instance(s) (Solr + indexer)' \
    ${fai_monitoring_search_host_list}

  if [[ $monitoring_vendor == $MONITORING_VENDOR_NAGIOS ]]; then
    run /etc/init.d/nagios3 restart
    add_next_step "Icinga monitoring interface: http://${HOSTNAME}/nagios3"
  else
    run /etc/init.d/icinga restart
    add_next_step "Icinga monitoring interface: http://${HOSTNAME}/icinga"
  fi
  
  run /etc/init.d/apache2 reload

}

## Sets up the definition file for a given monitoring host.
##
## $1 nagios flavour/vendor
## $2 <host name>:<ip>, e.g.: fire:192.168.1.100
function set_up_monitoring_host_def()
{
  local file=/etc/icinga/objects/${host_name}_icinga.cfg
  if [[ $1 == $MONITORING_VENDOR_NAGIOS ]]; then
    file=/etc/nagios3/conf.d/${host_name}_nagios2.cfg
  fi
  
  local old_ifs=$IFS
  IFS='#'
  read host_name ip <<< "$2"
  IFS=$old_ifs
  
  if [ $(grep "host_name $host_name" $file 2>/dev/null | wc -l) -gt 0 ]; then
    print "$1 host" $host_name "already defined, skipping it."
    return
  fi

    # TODO add more services based on what kind of host it is.
  cat >> $file <<EOF
define host {
  use generic-host
  host_name $host_name
  alias $host_name
  address $ip
}

define service {
  use generic-service
  host_name $host_name
  service_description CPU load
  check_command check_nrpe_1arg!check_load
}
EOF

}

function install_nagios_node()
{
  print "Installing a Nagios client on $HOSTNAME ..."
  if [ $on_debian_or_derivative -eq 1 ]; then
    install_packages_if_missing nagios-nrpe-server nagios-plugins
  else
    print_and_log "Nagios node installation not supported on your system"
    print_and_log "You will have to install it manually."
    return
  fi
  
  local file=/etc/nagios/nrpe.cfg
  dont_quote_conf_values=1
  set_conf_file_value \
    allowed_hosts \
    127.0.0.1,${fai_monitoring_server_ip} \
    $file
  dont_quote_conf_values=0

  run /etc/init.d/nagios-nrpe-server restart
  add_next_step "A Nagios NRPE node has been installed on ${HOSTNAME}"
}

function install_munin_node()
{
  print_and_log "Installing a Munin node on $HOSTNAME ..."

    # the IP of the monitoring server
  local default_ip=127.0.0.1
  if [ $fai_enabled -eq 1 ]; then
    if [ -n "fai_monitoring_server_ip" ]; then
      monitoring_server_ip=${fai_monitoring_server_ip}
    fi
  elif [ $install_profile_number -ne $PROFILE_MONITORING_SERVER ]; then
    print "What is the IP of your monitoring server? If you don't know"
    print "this, don't worry and just press ENTER"
    echo -n "Your choice [${default_ip}]> "
    read user_monitoring_server

    if [ -n "$user_monitoring_server" ]; then
      monitoring_server_ip=$user_monitoring_server
    fi
  fi

  if [ -z "$monitoring_server_ip" ]; then
    monitoring_server_ip=$default_ip
  fi
  
  if [ $on_debian_or_derivative -eq 1 ]; then
    packages="munin-node munin-plugins-extra"
    install_packages_if_missing $packages
  else
    print_and_log "Munin node installation not supported on your system"
    print_and_log "You will have to install it manually."
    return
  fi

  if [ -n "$monitoring_server_ip" ]; then
    escaped_munin_gather_ip=$(get_perl_escaped ${monitoring_server_ip})
    file=/etc/munin/munin-node.conf
    cat >> $file <<EOF

# added by ece-install $(date)
allow ${escaped_munin_gather_ip}
EOF
  fi
  
    # install the escenic_jstat munin plugin
  local file=/usr/share/munin/plugins/escenic_jstat_
  run wget $wget_opts \
    https://github.com/mogsie/escenic-munin/raw/master/escenic_jstat_ \
    -O $file
  run chmod 755 $file

  local instance_list=$(get_instance_list)
  if [ -z "${instance_list}" ]; then
    print_and_log "No ECE instances found on $HOSTNAME, so I'm not adding"
    print_and_log "additional Munin configuration"  

    if [ $on_debian_or_derivative -eq 1 ]; then
      run service munin-node restart
    fi

    add_next_step "A Munin node has been installed on $HOSTNAME"
    return
  fi
  
  local escenic_jstat_modules="_gc _gcoverhead _heap _uptime"
  for current_instance in $instance_list; do
    for module in $escenic_jstat_modules; do
	    cd /usr/share/munin/plugins/
	    make_ln escenic_jstat_ escenic_jstat_${current_instance}${module}
    done

        # we need to hack a bit since escenic_jstat_ looks for
        # instance PIDs in $escenic_run_dir ece-<instance>.pid. It's
        # now <type>-<instance>.pid
    file=$escenic_run_dir/$type-${instance_name}.pid
    if [ ! -e $file ]; then
      run touch $file
    fi

        # enabling the instance specific munin entries:
    for el in /usr/share/munin/plugins/escenic_jstat_[a-z]*; do
      run cd /etc/munin/plugins
      make_ln $el
    done
  done

    # TODO in which version(s) of munin is this directory called
    # client-conf.d?
  file=/etc/munin/plugin-conf.d/munin-node
  if [ -e $file ]; then
    cat >> $file <<EOF
[escenic*]
user $ece_user

EOF
  fi
  
  if [ $on_debian_or_derivative -eq 1 ]; then
    run service munin-node restart
  fi

  add_next_step "A Munin node has been installed on $HOSTNAME"
}


function install_munin_gatherer()
{
  print_and_log "Installing a Munin gatherer on $HOSTNAME ..."

  if [ $on_debian_or_derivative -eq 1 ]; then
    packages="munin"
    install_packages_if_missing $packages
  else
    print_and_log "Munin gatherer installation not supported on your"
    print_and_log "system :-( You will have to install it manually."
    return
  fi

  if [ $fai_enabled -eq 0 ]; then
    print "Which nodes shall this Munin monitor gather from?"
    print "Separate your hosts with a space, e.g.: 'editor01 db01 web01'"
    echo -n "Your choice> "
    read user_munin_nodes
    
    if [ -n "$user_munin_nodes" ]; then
      node_list=$user_munin_nodes
    fi
  else
    node_list=${fai_monitoring_munin_node_list}
  fi
  
  if [ -z "$node_list" ]; then
    return
  fi

  for el in $node_list; do
    print_and_log "Adding ${el} to the Munin gatherer on ${HOSTNAME} ..."
    local file=/etc/munin/munin-conf.d/escenic.conf
    cat >> $file <<EOF
    [${el}]
    address $(get_ip $el)
    use_node_name yes
EOF
  done

    # TODO add the priveleged network to the Allowed stanza (i.e. the
    # network wich will do the monitoring of the servers.
  local file=/etc/apache2/conf.d/munin
  if [ -n "$(get_privileged_hosts)" ]; then
    local privileged_hosts=$(
      echo $(get_privileged_hosts) | sed "s#\ #\\\ #g"
    )
    sed -i "s#Allow\ from\ localhost#Allow\ from\ ${privileged_hosts}\ localhost#g" \
      $file
    exit_on_error "Failed adding ${fai_privileged_hosts} to" \
      "Munin's allowed addresses."
    run /etc/init.d/apache2 reload
  fi

  add_next_step "Munin gatherer admin interface: http://${HOSTNAME}/munin"
  add_next_step "Make sure all nodes allows its IP to connect to them."
}

## $1 nagios vendor
function create_monitoring_server_overview()
{
  local file=/var/www/index.html
  cat > $file <<EOF
<html>
  <body>
    <h1>Welcome to the might monitoring server @ ${HOSTNAME}</h1>
    <ul>
EOF
  if [[ $1 == $MONITORING_VENDOR_NAGIOS ]]; then
    echo '<li><a href="/nagios3">Nagios</a></li>' \
      else
    echo '<li><a href="/icinga">Icinga</a> (an enhanced Nagios)</li>' \
      >> $file
  fi
  cat > $file <<EOF
      <li><a href="/munin">Munin</a></li>
    </ul>
  </body>
</html>
EOF
  add_next_step "Start page for all monitoring interfaces: http://${HOSTNAME}/"
}

function install_monitoring_server()
{
  local nagios_flavour=${fai_monitoring_nagios_flavour-$MONITORING_VENDOR_ICINGA}
  
  if [ "$(lsb_release -s -c 2>/dev/null)" = "lucid" ]; then
    log "Version $(lsb_release -s -c 2>/dev/null) of" \
      $(lsb_release -s -c 2>/dev/null) \
      "doesn't support Icinga, will use vanilla Nagios instead."
    nagios_flavour=$MONITORING_VENDOR_NAGIOS
  fi
  
  install_nagios_monitoring_server $nagios_flavour
  install_munin_gatherer
  create_monitoring_server_overview $nagios_flavour
}

## $1 configuration file name
## $2 host group name
## $3 host group alias
## $4..n host group members
function set_up_monitoring_host_group()
{
  local file=$1
  local host_group_name=$2
  local host_group_alias=$3
  # the remainding arguments passed to the methods is the member
  # list members
  local host_group_member_list=${@:4:$(( $# - 3 ))}

  # don't set up host groups for empty node lists, so we exit here if
  # the member list is empty.
  if [ -z "${host_group_member_list}" ]; then
    return
  fi

  if [ $(grep "hostgroup_name $host_group_name" $file | wc -l) -gt 0 ]; then
    print "Icinga group member" \
      $host_group_name \
      "already defined, skipping it."
    return
  fi
  
  cat >> $file <<EOF
define hostgroup {
  hostgroup_name $host_group_name
  alias $host_group_alias
EOF
  echo -n "  members" >> $file
  for el in $host_group_member_list; do
    echo -n " ${el}," >> $file
  done
  cat >> $file <<EOF

}
EOF
}
