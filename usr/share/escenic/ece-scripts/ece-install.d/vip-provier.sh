function get_vip_configuration() {
  # TODO add interactive mode if it's needed/requested

  # dependant on the running ece-install process/host
  vip_address=${fai_vip_address}
  vip_interface=${fai_vip_interface-eth0}
  vip_log_file=${fai_vip_log-/var/log/ha-debug}
  vip_sibling_ip=${fai_vip_sibling_ip}
  vip_service_list=${fai_vip_service_list}

  # common to both VIP nodes, node names must be what $(uname -n)
  # returns.
  vip_primary_node_name=${fai_vip_primary_node_name}
  vip_primary_node_ip=${fai_vip_primary_node_ip}
  vip_secondary_node_name=${fai_vip_secondary_node_name}
  vip_secondary_node_ip=${fai_vip_secondary_node_ip}
}

function install_vip_provider() {
  print_and_log "Installing a VIP provider on $HOSTNAME"
  install_packages_if_missing heartbeat
  get_vip_configuration
  assure_vip_hosts_are_resolvable
  set_kernel_vip_parameters
  create_ha_auth_keys
  set_up_ha_conf
  set_up_ha_resources
  propagate_ha_settings

  print_and_log "Restarting hearbeat to activate new configuration ..."
  run /etc/init.d/heartbeat restart
  
  add_next_step "Heartbeat installed on $HOSTNAME to provide VIP ${vip_address},"
  add_next_step "be sure that $vip_sibling_ip gets similar setup as $HOSTNAME."
}

function set_kernel_vip_parameters() {
  local file=/etc/sysctl.conf
  local entry="net.ipv4.ip_nonlocal_bind=1"
  if [ $(grep "$entry" $file | wc -l) -gt 0 ]; then
    return
  fi
  
  cat >> $file <<EOF
# needed to bind to VIP, added by $(basename $0) @ $(date)
$entry
EOF

  print_and_log "Re-loading ${HOSTNAME}'s kernel configuration ..."
  run sysctl -p

  # TODO
  # print "Making sure the kernel parameters are loaded at boot time"
}

function propagate_ha_settings() {
  run /usr/share/heartbeat/ha_propagate
}

function set_up_ha_resources() {
  local file=/etc/ha.d/haresources
  local entry="$vip_primary_node_name $vip_address $vip_service_list"

  if [ $(grep "$entry" $file | wc -l) -lt 1 ]; then
    cat > $file <<EOF
# <primary node> <virtual IP (VIP)>
$entry
EOF
  fi
}

function assure_vip_hosts_are_resolvable() {
  local keep_off_etc_hosts=${fai_keep_off_etc_hosts-0}
  if [ $keep_off_etc_hosts -eq 1 ]; then
    return
  fi

  local file=/etc/hosts
  local entry="$vip_primary_node_name $vip_primary_node_ip"
  if [ $(grep "$entry" $file | wc -l) -lt 1 ]; then
    cat >> $file <<EOF

# added by $(basename $0) @ $(date)
$entry
EOF
  fi

  entry="$vip_secondary_node_name $vip_secondary_node_ip"
  if [ $(grep "$entry" $file | wc -l) -lt 1 ]; then
    cat >> $file <<EOF

# added by $(basename $0) @ $(date)
$entry
EOF
  fi
}

function set_up_ha_conf() {
  local file=/etc/ha.d/ha.cf

  print_and_log "Setting up HA/heartbeat configuration in $file ..."
  
  cat > $file <<EOF
###############################
# logging
debugfile ${vip_log_file}

###############################
# communication
autojoin none
udpport 694
auto_failback on
# the other node                                                               
ucast $vip_interface $vip_sibling_ip
bcast $vip_interface

###############################
# thresholds
warntime 5
deadtime 15
initdead 60
keepalive 2

###############################
# nodes
node $vip_primary_node_name
node $vip_secondary_node_name
EOF
}

function create_ha_auth_keys() {
  local file=/etc/ha.d/authkeys
  print_and_log "Creating HA/heartbeat keys in $file ..."

  (echo -ne "auth 1\n1 sha1 "; \
    dd if=/dev/urandom bs=512 count=1 | openssl md5) \
    > $file
  run chmod 0600 $file
}
