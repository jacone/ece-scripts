#!/bin/bash

# Boots an amazon instance.

# Expects three arguments, namely a directory or symlink to a directory which
# contains a "vosa" configuration, and a second directory,
# which is where statefiles can be stored, followed by the ec2 command
# that should be executed, and any additional arguments.

# Usually this command is executed from "/usr/bin/vosa -i somevm start"
# or similar.

cmd=$3

if [ -z "$cmd" ] ; then
  echo "Three parameters are required, of which the third one is the"
  echo "name of the ec2-prefixed command to run, minus the ec2-prefix"
  echo "for example 'run-instances' or 'describe-instances'."
  exit 3
fi

if [ -z "$EC2_BINARY" ] ; then
  EC2_BINARY=$(which 2>/dev/null ec2-$cmd)
fi

if [ -z "$EC2_BINARY" -o ! -x "$EC2_BINARY" ] ; then
  echo "Unable to figure out where ec2-$cmd is installed."
  echo "export EC2_BINARY to make it work."
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
    exit $rc
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
  if [ -r $bootstatefile ] ; then
    aws_instance=$(awk < "$bootstatefile" -F '\t' '/^INSTANCE/ { print $2 }')
  fi
}


function invoke_ec2() {

  decho 1 "Invoking $EC2_BINARY"
  local cmdline=(
  $EC2_BINARY
  $AWS_COMMON_OPTIONS
  "${@}"
  )
  rc=1
  echo "Command to run on ec2:"
  echo "${cmdline[@]}"
  echo "# date $(date --iso)" >> /var/log/vosa-$(basename "$image")-ec2.log
  echo "${cmdline[@]}" >> /var/log/vosa-$(basename "$image")-ec2.log
  laststate="$("${cmdline[@]}" 2>> /var/log/vosa-$(basename "$image")-ec2.log)" 
  rc=$?
  echo "# return code $rc, $(echo -n "$laststate" | wc -c) bytes output" >> /var/log/vosa-$(basename "$image")-ec2.log
  echo "${laststate}" | tee $image/amazon.laststate
  if [ $cmd == "run-instances" -a ! -e $bootstatefile ] ; then
    cp $image/amazon.laststate $bootstatefile
  fi
  if [ $rc != 0 ] ; then
    exitonerror $rc "$EC2_BINARY returned with error."
  fi
}


read_amazon_config $1/amazon.conf
get_aws_instance
shift
shift
shift
invoke_ec2 "${@/INSTANCE/$aws_instance}"

