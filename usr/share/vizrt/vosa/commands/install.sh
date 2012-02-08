#!/bin/bash

# Performs a full installation of a vm

# Expects a single argument, namely a directory or symlink to a directory which
# contains a "vosa" configuration, and a second directory, which should not exist
# which is where the installation will be held.

# This command will create the second directory and build a virtual machine image from
# scratch and configure it as described by relevant files in the first directory.

# Usually this command is executed from "/usr/bin/vosa -i somevm install"
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
  echo "the latter MUST NOT exist, and will be created as a result of this command"
  exit 1
fi

# basic error checking
if [ ! -d "$config" ] ; then
  echo "Config directory $config isn't a directory."
  exit 1
fi

if [ -d "$image" -o -r "$image" ] ; then
  echo "image directory $image already exist.  Can't continue."
  exit 1
fi

# todo: verify that basename and image don't end with slashes...

if [ "$(basename "$image")" != "$(basename "$config")" ] ; then
  echo "$image and $config appear to try to name different VMs. Try using $(basename $config) instead."
  exit 2
fi

# make the holding area.
mkdir $image
hostname=$(basename "$image")

# Parse all install config items
parse_config_file $config/install.conf install_config_
parse_config_file $config/boot.conf boot_config_

function make_temp_dir() {
  tempdir=/tmp/some-rundir
  if [ ! -z "${tempdir}" -a ! -d "${tempdir}" ] ; then
    mkdir "${tempdir}"
  fi
}

function cleanup_temp_dir() {
  if [ ! -z "${tempdir}" -a -d "${tempdir}" ] ; then
    rm -rf "${tempdir}"
  fi
}

make_run_dir() {
  rundir=/var/run/vizrt/vosa/ 
  if [ "$(id -u)" != "0" ] ; then
    rundir=$HOME/.vizrt/vosa/
  fi
  decho 1 "Making var-run directory $rundir"
  mkdir -p $rundir || exitonerror $? "Unable to make the place where pidfiles are stored ($rundir)"
}

function copy_original_image() {
  decho 1 "Copying original image file to image file"
  if [ -z "$install_config_original_image" -o ! -r "$install_config_original_image" ] ; then
    echo "Original image file $install_config_original_image does not exist. exiting."
    exit 2;
  fi
  img="$image/disk.img"
  kernel="$image/vmlinuz"
  cp "$install_config_original_image" "$img"
  cp "$install_config_kernel" "$kernel"
}

function resize_original_image() {
  if [ -z "${install_config_initial_disk_size}" ] ; then return; fi
  decho 1 "Resizing 'disk.img' to ${install_config_initial_disk_size}Gb"
  fsck.ext4 > /dev/null -p -f ${img}; exitonerror $? "fsck.ext4 failed before resize"
  resize2fs > /dev/null ${img} ${install_config_initial_disk_size}G; exitonerror $? "resize2fs failed"
  fsck.ext4 > /dev/null -n -f ${img}; exitonerror $? "fsck.ext4 failed after resize"
}

function generate_ssh_key() {
  decho 1 "generating SSH key"
  ssh-keygen -t dsa -N "" -f ${image}/id_dsa -b 1024 -C "kvm-one-time-key:$name" > /dev/null; exitonerror $? "Unable to generate ssh key"
}

function create_user_data_file() {
  cat >> ${tempdir}/user_data.txt <<EOF
#cloud-config
manage_etc_hosts: true
timezone: ${timezone}
apt_update: false
apt_upgrade: false
apt_mirror: ${mirror}
EOF
}

function postinstall() {
  echo "running all the postinstall scripts..."
  sleep 4;
}

copy_original_image
resize_original_image
generate_ssh_key

### functions below require tempdir

make_temp_dir
create_user_data_file
cleanup_temp_dir

# chain to boot.sh to actually start the image.
$(dirname $0)/boot.sh $1 $2

postinstall
