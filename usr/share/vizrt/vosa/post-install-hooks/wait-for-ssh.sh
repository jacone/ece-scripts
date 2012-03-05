#!/bin/bash

echo -n "Waiting for ssh access..."
for a in $(seq 1 90) ; do
  echo -n .
  ssh -q -F $2/ssh.conf root@guest id > /dev/null
  if [ $? == 0 ] ; then
    pid=1
    echo
    echo -n "Waiting for cloud-init to complete"
    # Wait for existing apt-gets to complete.
    # TODO: drop the boot confi
    while [ "$pid" != 0 ] ;
    do
      echo -n .
      ssh -q -F $2/ssh.conf root@guest ls /var/lib/cloud/instances/nocloud/boot-finished > /dev/null 2>&1
      pid=$?
      sleep 1;
    done
    echo
    exit 0
  fi
  sleep 1;
done

exit 1

