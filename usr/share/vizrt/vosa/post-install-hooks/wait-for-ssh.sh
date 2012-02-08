#!/bin/bash

for a in $(seq 1 20) ; do
  ssh -q -F $2/ssh.conf root@guest id > /dev/null
  if [ $? == 0 ] ; then
    exit 0
  fi
  sleep 1;
done

exit 1

