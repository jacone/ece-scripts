#!/bin/bash

for a in $(seq 1 90) ; do
  ssh -q -F $2/ssh.conf root@guest id > /dev/null
  if [ $? == 0 ] ; then
    pid=1
    # Wait for existing apt-gets to complete.
    while [ ! -z "$pid" ] ;
    do
      pid=$(ssh -F $2/ssh.conf root@guest pidof apt-get)
      sleep 1;
    done
    exit 0
  fi
  sleep 1;
done

exit 1

