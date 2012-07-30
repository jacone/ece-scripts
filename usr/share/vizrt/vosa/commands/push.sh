#! /usr/bin/env bash

# vosa module which pushes instance changes (setting files mostly) to
# the given instance

# easy for now, this must be set by the callee
instance=$1
files_dir=/var/lib/vizrt/vosa/files
lock_file=/var/lock/$(basename $0 .sh).lock
outgoing=1

tmp_known_hosts_file=$(mktemp)
rsync_opts="
--recursive
--links
--perms
--group
--owner
--compress
--itemize-changes
--ignore-times
--checksum
--cvs-exclude
"
rsync_additional_outgoing_opts="
--dry-run
--verbose
"

rsync_ssh_opts="-o BatchMode=yes \
-o UserKnownHostsFile=${tmp_known_hosts_file} \
-o StrictHostKeyChecking=no"


function pre_push_changes() {
  if [ -e $lock_file ];then
    echo $lock_file "exists, I will exit :-("
    exit 1
  else
    touch $lock_file
  fi
}

function push_changes() {
  for el in common $instance; do
    if [ $outgoing -eq 0 ]; then
      rsync $rsync_opts -e "ssh $rsync_ssh_opts" $files_dir/$el/ ${instance}:/
    else
      rsync $rsync_opts \
        $rsync_additional_outgoing_opts \
        -e "ssh $rsync_ssh_opts" \
        $files_dir/$el/ \
        ${instance}:/
    fi

  done
}

function post_push_changes() {
  if [ -e $tmp_known_hosts_file ]; then
    rm $tmp_known_hosts_file
  fi

  if [ -e $lock_file ]; then
    rm $lock_file
  fi
}

function set_etc_hosts() {
  if [ ! -d $files_dir/common/etc/hosts.d ]; then
    return
  fi

  local tmp_file=$(mktemp)
  cat > $tmp_file <<EOF
###################################################################
## Generated default /etc/hosts header by $(basename $0) @ $(date)
###################################################################
127.0.0.1	localhost
127.0.1.1	${instance}

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
###################################################################

EOF

  cat $tmp_file \
    ${files_dir}/common/etc/hosts.d/* \
    ${files_dir}/${instance}/etc/hosts.d/* | \
    ssh ${rsync_ssh_opts} ${instance} "cat > /etc/hosts"
  
  rm $tmp_file
}

# the callee needs to to do:
#
# pre_push_changes
# push_changes
# post_push_changes
