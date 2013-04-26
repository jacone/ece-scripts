#!/bin/bash

# Boots a kvm instance.

# Expects two arguments, namely a directory or symlink to a directory which
# contains a "vosa" configuration, and a second directory,
# which is where the installation disks are held.

# Usually this command is executed from "/usr/bin/vosa -i somevm start"
# or similar.

if [ -z "$KVM_BINARY" ] ; then
  KVM_BINARY=$(which 2>/dev/null kvm) ||
  KVM_BINARY=$(which 2>/dev/null qemu-kvm) ||
  KVM_BINARY=/usr/libexec/qemu-kvm
fi

if [ -z "$KVM_BINARY" -o ! -x $KVM_BINARY ] ; then
  echo Unable to figure out where kvm is installed... export KVM_BINARY to make it work.
fi


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

function make_run_dir() {
  rundir=/var/run/vizrt/vosa/ 
  if [ "$(id -u)" != "0" ] ; then
    rundir=$HOME/.vizrt/vosa/
  fi
  decho 1 "Making var-run directory $rundir"
  mkdir -p $rundir || exitonerror $? "Unable to make the place where pidfiles are stored ($rundir)"
}

## Select a tap interface
## For now it selects a single tap interface at random, of the ones not
## listed in use by any other machines.
function select_tap_interface() {
  if [ -r $rundir/$hostname.network ] ; then
    rm -f $rundir/$hostname.network
  fi
  for try in 1 2 3 4 ; do 
    # Read the list of available networks we have
    declare -A availablenetworks
    local network
    for network in $rundir/*.availablenetwork ; do
      [[ -f $network ]] || continue
      # If we have a bridge preference, and it doesn't match the
      # contents of the network file, ignore it as an available
      # network.
      [[ "$boot_config_bridge" != "" ]] && [[ "$boot_config_bridge" != "$(cat "$network")" ]] && continue;

      # $network == tap4.availablenetwork.  Contains the name(s) of vm04's networks
      local tap
      tap=$(basename $network .availablenetwork)
      availablenetworks["$tap"]=1
    done

    echo "Available tap interfaces: ${!availablenetworks[@]}"

    # Read the list of used networks we have
    declare -A usednetworks
    for network in $rundir/*.network ; do
      [[ -f $network ]] || continue
      # $network == /.../vm04.network.  File contains a list of taps used by vm04
      local vm  # "vm04"
      vm=$(basename $network .network)
      local i
      for i in $(<$network) ; do
        usednetworks["$i"]=$vm  # e.g. usednetworks[tap3]=vm04
      done
    done

    echo "tap interfaces already in use : ${!usednetworks[@]}"

    for tap in ${!availablenetworks[@]} ; do
      if [ -z "${usednetworks["$tap"]}" ] ; then
        tapinterface=$tap
        # TODO: only exit when the desired number of network interfaces has been reached...
        echo $tap >> "${rundir}/${hostname}.network" && return
      fi
    done
  done
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

  $(id -un) ALL=(ALL) NOPASSWD: $KVM_BINARY

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

function configure_vnc_option() {
  if [ -z "$boot_config_vnc_port" -o "$boot_config_vnc_port" == "none" ] ; then 
    vncoption="-vnc none"
  else
    vncoption="-vnc :${boot_config_vnc_port}"
  fi
}


function boot_kvm() {
  if [ -z "$tapinterface" ] ; then
    echo "No tap interface available..."
  fi

  if [ ! -z "$boot_config_processor_affinity" ] ; then
    echo "Applying processor restriction to $boot_config_processor_affinity"
    taskset="taskset -c $boot_config_processor_affinity"
    cpulist=( ${boot_config_processor_affinity//,/ } )
    smpoption="-smp cores=${#cpulist[@]}"
  fi
  kernel=${image}/vmlinuz
  img=${image}/disk.img
  initrd=${image}/initrd
  if [ -e $initrd ] ; then
    initrd="-initrd $initrd"
  else
    initrd=""
  fi
  cloud_param="nocloud;h=${hostname};s=file:///var/lib/cloud/data/cache/nocloud/"

  # should _maybe_ be put in some other script?  Needed by e.g. vosa start too.
  decho 1 "Starting the machine"
  startupcmd=($sudo $taskset $KVM_BINARY
  -daemonize
  ${vncoption}
  -name "${hostname}",process=kvm/${hostname}
  -cpu "host"
  $smpoption
  -pidfile "${pidfile}"
  -m "${boot_config_memory}"
  $runas
  -enable-kvm
  -monitor unix:${rundir}/${hostname}.monitor,server,nowait
  -balloon "virtio"
  -drive "file=${img},if=virtio,cache=none,media=disk,format=raw"
  -kernel ${kernel}
  $initrd
  -device "virtio-net-pci,mac=${install_config_macaddr},netdev=net0"
  -netdev "tap,id=net0,ifname=$tapinterface,script=no,downscript=no,vhost=on")
  
#  -net "nic,model=virtio,macaddr=${install_config_macaddr}"
# http://dwdwwebcache.googleusercontent.com/search?q=cache:mEAjcA2zHosJ:kerneltrap.org/mailarchive/linux-kvm/2010/1/26/6257297/thread+qemu-kvm+acpi+shutdown&cd=1&hl=no&ct=clnk&gl=no
# http://kerneltrap.org/mailarchive/linux-kvm/2010/1/26/6257297/thread
# provide a monitor socket to talk to kvm.   /var/run?

  updates=${image}/updates.iso
  if [ -r "${updates}" ] ; then
    startupcmd=("${startupcmd[@]}" -drive "file=${updates},if=virtio")
    xupdate="xupdate=vdb:mnt"
  fi

  startupcmd=("${startupcmd[@]}" -append "root=/dev/vda noapic ro init=/usr/lib/cloud-init/uncloud-init ds=${cloud_param} ubuntu-pass=random $xupdate" )

  ps > /dev/null -fC "kvm/${hostname}" && {
    echo "This instance of KVM is already running.  Just see here:"
    ps -fC "kvm/${hostname}"
    exit 2
  }

  lsof > /dev/null ${img} && {
    echo "This instance of KVM seems to be in use by another process. Just see here:"
    lsof "${img}"
    exit 2
  }

  # actually execute kvm
  echo "Command to start this KVM:"
  echo "${startupcmd[@]}"
  "${startupcmd[@]}"; 
  local rc
  rc=$?
  if [ $rc != 0 ] ; then
    rm $pidfile
    exitonerror $rc "Unable to start kvm :-/"
  fi
}


check_sudo
make_run_dir
configure_vnc_option
select_tap_interface

touch_pid_file
boot_kvm
