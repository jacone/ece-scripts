#!/bin/bash

# Determines which IP to use to access a newly started or booted amazon instance.

# Expects two arguments, namely a directory or symlink to a directory which
# contains a "vosa" configuration, and a second directory,
# which is where statefiles can be stored, followed by the ec2 command
# that should be executed, and any additional arguments.

# Usually this command is executed from "/usr/bin/vosa -i somevm start"
# or similar.

config=$1
image=$2

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


read_amazon_config $config/amazon.conf


statefile="${image}/amazon.state"

if [ ! -w  "${image}" ] ; then
  echo "Unable to write to ${statefile}... aborting"
  exit 2
fi

if [ -r ${statefile} -a ! -w  "${statefile}" ] ; then
  echo "${statefile} exists but is not writable. aborting"
  exit 2
fi

for a in 1 2 3 4 5 6 7 8 9 10 ; do
  output="$($(dirname $0)/ec2-cmd.sh \
    "$config" \
    "$image" \
    "describe-instances" "INSTANCE")"

  if [ ! -z "$output" ] ; then
    echo "$output" > "$statefile"
  fi

  if [ "$amazon_config_ssh_access" == "public" ] ; then
    ip_address=$(awk < "$statefile" -F '\t' '/^INSTANCE/ { print $17 }')
  else
    ip_address=$(awk < "$statefile" -F '\t' '/^INSTANCE/ { print $18 }')
  fi
  if [ ! -z "$ip_address" ] ; then
    break;
  fi
  sleep 4;
  continue;
done

if [ -z "$ip_address" ] ; then
  echo "Unable to determine $amazon_config_ssh_access IP address for $(basename "$1")."
  exit 2
fi

cat > $image/ssh.conf <<EOF
Host guest
  IdentityFile $amazon_config_ssh_private_key
  HostName $ip_address
  User ubuntu
  BatchMode yes
  UserKnownHostsFile $image/ssh_known_hosts
  StrictHostKeyChecking no

EOF

