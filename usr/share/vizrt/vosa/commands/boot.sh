#!/bin/bash

# Boots a kvm instance.

# Expects two arguments, namely a directory or symlink to a directory which
# contains a "vosa" configuration, and a second directory,
# which is where the installation disks are held.

# Usually this command is executed from "/usr/bin/vosa -i somevm start"
# or similar.

debug=3

function decho() {
  if [ $debug -ge $1 ] ; then
    echo "${@:2}"
  fi
}

function exitonerror() {
  rc=$1
  if [ "$rc" != "0" ] ; then
    echo "$2 (rc=$rc)"
    exit 2
  fi
}

source $(dirname $0)/functions
source $(dirname $0)/install_config_parser
source $(dirname $0)/boot_config_parser

config=$1
image=$2

if [ -z "$image" -o -z "$config" ] ; then
  echo "You need to specify a config directory (e.g. /etc/vizrt/vosa/enabled.d/foo) "
  echo "and a place to hold the installation (e.g. /usr/lib/vizrt/vosa/images/foo)"
  echo "the former MUST exist and contain vosa configuration files"
  echo "the latter MUST also exist, and contain disk images and kernels etc"
  exit 1
fi

# basic error checking
if [ ! -d "$config" ] ; then
  echo "Config directory $config isn't a directory."
  exit 1
fi

if [ ! -d "$image" ] ; then
  echo "image directory $image does not exist.  Can't continue."
  exit 1
fi

# todo: verify that basename and image don't end with slashes...

if [ "$(basename "$image")" != "$(basename "$config")" ] ; then
  echo "$image and $config appear to try to name different VMs. Try using $(basename $config) instead."
  exit 2
fi

# make the holding area.
hostname=$(basename "$image")

# Parse all install config items
parse_config_file $config/install.conf install_config_
parse_config_file $config/boot.conf boot_config_

make_run_dir() {
  rundir=/var/run/vizrt/vosa/ 
  if [ "$(id -u)" != "0" ] ; then
    rundir=$HOME/.vizrt/vosa/
  fi
  decho 1 "Making var-run directory $rundir"
  mkdir -p $rundir || exitonerror $? "Unable to make the place where pidfiles are stored ($rundir)"
}

function check_sudo() {
  sudo=''
  runas=''
  if [ "$(id -u)" != "0" ] ; then
    decho 1 "Checking if we have sudo access to kvm"
    sudo -n kvm --help > /dev/null 2>/dev/null
    if [ $? -ne 0 ] ; then
      cat <<EOF
$0: It seems I am not able to run kvm as root.  I will not be able to run kvm
with bridged networking.
To fix this, add the file /etc/sudoers.d/kvm with the line

  $(id -un) ALL=(ALL) NOPASSWD: /usr/bin/kvm

Exiting.
EOF
      exit 2
    fi

    sudo=sudo
    # drop priviledges after kvm starts if necessary.
    runas="-runas $(id -un)"
  fi
}

function touch_pid_file() {
  pidfile=$rundir/$hostname.pid
  touch "${pidfile}"
}

function touch_state_file() {
  statefile=$rundir/$hostname.state
  echo 'running' > $statefile
}

function configure_vnc_option() {
  if [ -z "$boot_config_vnc_port" -o "$boot_config_vnc_port" == "none" ] ; then 
    vncoption="-vnc none"
  else
    vncoption="-vnc :${boot_config_vnc_port}"
  fi
}


function boot_kvm() {
  kernel=${image}/vmlinuz
  img=${image}/disk.img
  cloud_param="nocloud;h=${hostname}"

  # should _maybe_ be put in some other script?  Needed by e.g. vosa start too.
  decho 1 "Starting the machine"
  startupcmd=($sudo kvm
  -daemonize
  ${vncoption}
  -name "${hostname}"
  -cpu "host"
  -pidfile "${pidfile}"
  -m "${boot_config_memory}"
  $runas
  -enable-kvm
  -monitor unix:${image}/monitor.sock,server,nowait
  -balloon "virtio"
  -drive "file=${img},if=virtio,cache=none"
  -kernel ${kernel}
  -net "nic,model=virtio,macaddr=${install_config_macaddr}"
  -net "tap,script=$(dirname $0)/qemu-ifup")
  
# http://dwdwwebcache.googleusercontent.com/search?q=cache:mEAjcA2zHosJ:kerneltrap.org/mailarchive/linux-kvm/2010/1/26/6257297/thread+qemu-kvm+acpi+shutdown&cd=1&hl=no&ct=clnk&gl=no
# http://kerneltrap.org/mailarchive/linux-kvm/2010/1/26/6257297/thread
# provide a monitor socket to talk to kvm.   /var/run?

  updates=${image}/updates.iso
  if [ -r "${updates}" ] ; then
    startupcmd=("${startupcmd[@]}" -drive "file=${updates},if=virtio")
    xupdate="xupdate=vdb:mnt"
  fi

  startupcmd=("${startupcmd[@]}" -append "root=/dev/vda ro init=/usr/lib/cloud-init/uncloud-init ds=${cloud_param} ubuntu-pass=random $xupdate" )

  # actually execute kvm
  echo "${startupcmd[@]}"
  "${startupcmd[@]}"; exitonerror $? "Unable to start kvm :-/" 
}


check_sudo
make_run_dir
configure_vnc_option

touch_pid_file  # should maybe be part of boot process?  dunno.
boot_kvm
touch_state_file
