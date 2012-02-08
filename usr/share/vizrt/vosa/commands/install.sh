#!/bin/bash

# Performs a full installation of a vm

# Expects a single argument, namely a directory or symlink to a directory which
# contains a "vosa" configuration, and a second directory, which should not exist
# which is where the installation will be held.

# This command will create the second directory and build a virtual machine image from
# scratch and configure it as described by relevant files in the first directory.

# Usually this command is executed from "/usr/bin/vosa -i somevm install"
# or similar.

source $(dirname $0)/functions
source $(dirname $0)/install_config_parser

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

# make the holding area.
mkdir $image

# Parse all install config items
parse_config_file $config/install.conf install_config_


echo $ip_address





