#!/bin/bash

# Two arguments are passed:
# the "vm name" as provided on the command line,
# which is a directory path of a VOSA vm definition:
#
# e.g. /etc/vosa/available.d/vm03
#
# and the image directory, which holds generated files
# which stick across reboots, but not reinstalls.
#
# e.g. /var/lib/vosa/image/vm03

# The VM is assumed to be booted and ready for SSH using the passwordless
# key referenced by the $2/ssh.conf file, as the ubuntu or root users.

# ensure we have an ece-install image.
if [ ! -r $2/ece-install ] ; then
  if [ -r $1/ece-install ] ; then
    cp $1/ece-install $2
  else
    wget "https://raw.github.com/skybert/ece-scripts/master/usr/sbin/ece-install" -O $2/ece-install
  fi
fi
chmod +x $2/ece-install
if [ ! -r $1/ece-install.conf ] ; then
  echo "No ece-install.conf file present in $1"
  exit 1;
fi

scp -F $2/ssh.conf $2/ece-install $1/ece-install.conf root@guest:

ssh -F $2/ssh.conf root@guest ./ece-install

