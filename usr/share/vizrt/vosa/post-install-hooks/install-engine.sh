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

# ensure we have some ece-install*.conf file(s)
ece_install_conf_files=$(ls $1 | grep "^ece-install.*\\.conf$")
if [ -z "$ece_install_conf_files" ] ; then
  echo "No ece-install.conf files present in $1"
  exit 1;
fi

# ensure we have an ece-install image, download one.
if [ ! -r $2/ece-install ] ; then
  if [ -r $1/ece-install ] ; then
    cp $1/ece-install $2
  else
    wget "https://github.com/skybert/ece-scripts/tarball/master" -O $2/ece-install.tar.gz
  fi
fi

scp -F $2/ssh.conf $2/ece-install.tar.gz $1/ece-install*.conf root@guest:

ssh -F $2/ssh.conf root@guest tar xfz ece-install.tar.gz
for conf in $ece_install_conf_files ; do
  echo "Performing ece-install with -f $conf"
  ssh -F $2/ssh.conf root@guest bash *-ece-scripts-*/usr/sbin/ece-install -f "$conf" || exit $? 
  echo "---------8<-------------------------"
done

