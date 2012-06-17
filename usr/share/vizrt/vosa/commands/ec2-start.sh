#!/bin/bash

# Boots an amazon instance.

# Expects two arguments, namely a directory or symlink to a directory which
# contains a "vosa" configuration, and a second directory,
# which is where statefiles can be stored.

# Usually this command is executed from "/usr/bin/vosa -i somevm start"
# or similar.

if [ -z "$EC2_START_BINARY" ] ; then
  EC2_START_BINARY=$(which 2>/dev/null ec2-start-instances) ||
  EC2_START_BINARY=$(which 2>/dev/null ec2start)
fi

if [ -z "$EC2_START_BINARY" -o ! -x $EC2_START_BINARY ] ; then
  echo "Unable to figure out where ec2-run-instances is installed."
  echo "export EC2_START_BINARY to make it work."
  exit 2
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


config=$1
image=$2

if [ -z "$image" -o -z "$config" ] ; then
  echo "You need to specify a config directory (e.g. /etc/vizrt/vosa/enabled.d/foo) "
  echo "and a place to hold the installation (e.g. /usr/lib/vizrt/vosa/images/foo)"
  echo "the former MUST exist and contain vosa configuration files"
  echo "the latter MUST also exist, and contain amazon.initialstate etc"
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


have_read_amazon_config=0
function read_amazon_config() {
  [[ $have_read_amazon_config -eq 1 ]] && return
  source $(dirname $0)/functions
  source $(dirname $0)/amazon_config_parser
  # Parse all amazon config items
  parse_config_file $1 amazon_config_

  unset AWS_COMMON_OPTIONS
  AWS_COMMON_OPTIONS="${AWS_COMMON_OPTIONS} --private-key $amazon_config_key "
  AWS_COMMON_OPTIONS="${AWS_COMMON_OPTIONS} --cert $amazon_config_certificate "
  AWS_COMMON_OPTIONS="${AWS_COMMON_OPTIONS} --region $amazon_config_region "
  have_read_amazon_config=1
}

function get_aws_instance() {
  bootstatefile=$image/amazon.initialstate
  aws_instance=$(awk < "$bootstatefile" -F '\t' '/^INSTANCE/ { print $2 }')
}


function boot_ec2() {

  decho 1 "Starting the machine"
  startupcmd=(
  $EC2_START_BINARY
  $AWS_COMMON_OPTIONS
  $aws_instance
  )
  echo "Command to start this EC2 instance:"
  echo "${startupcmd[@]}"
  "${startupcmd[@]}"
  local rc
  rc=$?
  if [ $rc != 0 ] ; then
    exitonerror $rc "Unable to start EC2 :-/"
  fi
}


read_amazon_config $1/amazon.conf
get_aws_instance
boot_ec2
