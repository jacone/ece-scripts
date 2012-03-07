# module to install & configure network file systems, both server and
# client side.

default_nfs_export_list="/exports/multimedia"

function get_nfs_configuration() {
  nfs_export_list=${fai_nfs_export_list-$default_nfs_export_list}
  nfs_server_address=${fai_nfs_server_address}
  nfs_allowed_client_network=${fai_nfs_allowed_client_network}

  ensure_variable_is_set fai_nfs_server_address

  if [ $install_profile_number -eq $PROFILE_NFS_SERVER ]; then
    fai_nfs_allowed_client_network
  fi
}

function install_nfs_server() {
  print_and_log "Installing an NFS server on $HOSTNAME ..."
  install_packages_if_missing "portmap nfs-kernel-server nfs-common"
  get_nfs_configuration
  
  for el in $nfs_export_list; do
    local entry="$el ${nfs_allowed_client_network}(rw,sync)"
    if [ $(grep "$entry" /etc/exports | wc -l) -lt 1 ]; then
      cat >> /etc/exports <<EOF
# added by $(basename $0) @ $(date)
$el ${nfs_allowed_client_network}(rw,sync)
EOF
    fi
    
    make_dir $el
    run chown ${ece_user}:${ece_group} $el
  done

  run /etc/init.d/portmap restart
  run /etc/init.d/nfs-kernel-server restart

  add_next_step "An NFS server has been installed on ${HOSTNAME},"
  add_next_step "NFS exports: $nfs_export_list"
}

function install_nfs_client() {
  print_and_log "Installing an NFS client on $HOSTNAME ..."
  
  install_packages_if_missing "nfs-common"
  get_nfs_configuration

  local mount_point_list=""
  local file=/etc/fstab
  
  for el in $nfs_export_list; do
    local entry="${nfs_server_address}:$el /mnt/$(basename $0) nfs defaults 0 0"
    if [ $(grep "$entry" $file | wc -l) -lt 1 ]; then
      cat >> $file <<EOF
# added by $(basename $el) @ $(date)
${nfs_server_address}:$el /mnt/$(basename $el) nfs defaults 0 0
EOF
    fi

    local mount_point=/mnt/$(basename $el)
    make_dir $mount_point
    run mount $mount_point
    mount_point_list="$mount_point $mount_point_list"
  done

  add_next_step "An NFS client has been added to $HOSTNAME"
  add_next_step "NFS mount points: $mount_point_list"
}
