#!/bin/bash

# Performs post installation tasks on a VM.

# Expects a single argument, namely a directory or symlink to a directory
# which contains a "vosa" configuration, and a second directory, which
# should exist which is where run-time files are kept / will be kept.

# This command will configure the VM as described by relevant files in the
# first directory.

# Usually this command is executed from "/usr/bin/vosa -i somevm postinst"
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

config=$1
image=$2

if [ -z "$image" -o -z "$config" ] ; then
  echo "You need to specify a config directory (e.g. /etc/vizrt/vosa/enabled.d/foo) "
  echo "and a place to hold the installation (e.g. /usr/lib/vizrt/vosa/images/foo)"
  echo "the former MUST exist and contain vosa configuration files"
  echo "the latter MUST exist and contain run-time files."
  exit 1
fi

# basic error checking
if [ ! -d "$config" ] ; then
  echo "Config directory $config isn't a directory."
  exit 1
fi

if [ ! -d "$image" -o ! -w "$image" ] ; then
  echo "image directory $image does not exist, or is not writable.  Can't continue."
  exit 1
fi

# todo: verify that basename and image don't end with slashes...

if [ "$(basename "$image")" != "$(basename "$config")" ] ; then
  echo "$image and $config appear to try to name different VMs. Try using $(basename $config) instead."
  exit 2
fi

hostname=$(basename "$image")

# Parse all install config items
parse_config_file $config/install.conf install_config_

function postinstall() {
  for o in "${install_config_postinstall[@]}" ; do
    echo "Executing postinstall $o"
    if [ "${o:0:2}" == "./" ] ; then
      local cmd="${config}/${o:2}"
    elif [ "${o:0:1}" == "/" ] ; then
      local cmd=$o
    else
      local cmd="$(dirname $0)/../post-install-hooks/$o"
    fi
    if [ ! -x "$cmd" ] ; then
      echo "Unable to execute non-executable post-install hook: $cmd"
      exit 1
    fi
    cmd=$(readlink -f "$cmd")
    $cmd "$config" "$image" || exitonerror $? "Postinstall script $cmd exited nonzero return code."
  done
}

postinstall

