function get_vip_configuration() {
  # TODO add interactive mode if it's needed/requested

  # dependant on the running ece-install process/host
  vip_address=${fai_vip_address}
  vip_interface=${fai_vip_interface}
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
  install_packages_if_missing heartbeat
  set_kernel_vip_parameters
  create_ha_auth_keys
  set_up_ha_conf
  set_up_ha_resources
  propagate_ha_settings

  run /etc/init.d/heartbeat restart
  
  add_next_step "Heartbeat installed on $HOSTNAME to provide VIP $vip"
  add_next_step "be sure that $node2_name gets similar setup as $HOSTNAME."
}

function set_kernel_vip_parameters() {
  local file=/etc/sysctl.conf

  if [ $(grep "net.ipv4.ip_nonlocal_bind=1" $file | wc -l) -gt 0 ]; then
    return
  fi
  
  cat >> $file <<EOF
# needed to bind to VIP, added by $(basename $0) @ $(date)
net.ipv4.ip_nonlocal_bind=1
EOF

  print "Re-loading $(uname -s) kernel configuration ..."
  run sysctl -p

  # TODO
  # print "Making sure the kernel parameters are loaded at boot time"
}

function propagate_ha_settings() {
  run /usr/share/heartbeat/ha_propagate
}

function set_up_ha_resources() {
  local file=/etc/ha.d/haresources
  
  cat > $file <<EOF
# <primary node> <virtual IP (VIP)>
$vip_primary_node_name $vip_address $vip_service_list
EOF
}

function assure_vip_hosts_are_resolvable() {
  local keep_off_etc_hosts=${fai_keep_off_etc_hosts-0}
  if [ $keep_off_etc_hosts -eq 1 ]; then
    return
  fi
  
  if [ $(grep $vip_primary_node_name /etc/hosts | wc -l) -lt 1 ]; then
    cat >> /etc/hosts <<EOF

# added by $(basename $0) @ $(date)
$vip_primary_node_name $vip_primary_node_ip
EOF
  fi
  
  if [ $(grep $vip_secondary_node_name /etc/hosts | wc -l) -lt 1 ]; then
    cat >> /etc/hosts <<EOF

# added by $(basename $0) @ $(date)
$vip_secondary_node_name $vip_secondary_node_ip
EOF
  fi
}

function set_up_ha_conf() {
  local file=/etc/ha.d/ha.cf
  
  cat > $file <<EOF
###############################
# logging
debugfile ${vip_log_file}

###############################
# communication
autojoin none
udpport 694
# the other node                                                               
ucast $vip_interface $vip_sibling_ip
udp $vip_interface

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

  (echo -ne "auth 1\n1 sha1 "; \
    dd if=/dev/urandom bs=512 count=1 | openssl md5) \
    > $file
  run chmod 0600 $file
}
