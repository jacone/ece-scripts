# module to install & configure network file systems

default_nfs_export_list="/exports/multimedia"

function get_nfs_configuration() {
  nfs_export_list=${fai_nfs_export_list-$default_nfs_export_list}
  nfs_server=${fai_nfs_server}
}


function install_nfs_server() {
  print "Installing an NFS server on $HOSTNAME ..."
  install_packages_if_missing "portmap nfs-kernel-server nfs-common"
  get_nfs_configuration
  
  for el in $nfs_export_list; do
    cat >> /etc/exports <<EOF
$el ${nfs_allowed_network}(rw,sync)
EOF

    make_dir $el
    run chown ${ece_user}:${ece_group} $el
  done

  run /etc/init.d/portmap restart
  run /etc/init.d/nfs-kernel-server restart
  run /etc/init.d/nfs-common restart
}

function install_nfs_client() {
  print "Installing an NFS client on $HOSTNAME ..."
  
  install_packages_if_missing "nfs-common"
  get_nfs_configuration

  for el in $nfs_export_list; do
    make_dir /mnt/${basename $el}

    cat >> /etc/fstab <<EOF
# added by $(basename $el) @ $(date)
${nfs_server}:$el /mnt/$(basename $el) nfs defaults 0 0
EOF

    run mount /mnt/$(basename $el)
  done
  
}
