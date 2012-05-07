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
ssh -F $2/ssh.conf root@guest test -x /usr/sbin/ece-install
rc=$?

if [ $rc == 0 ] ; then
  ECE_INSTALLER=/usr/sbin/ece-install
fi

if [ -z "$ECE_INSTALLER" ] ; then
  ssh -F $2/ssh.conf root@guest apt-cache show escenic-content-engine-installer > /dev/null &&
  echo "Attempting to install escenic-content-engine-installer packge" &&
  ssh -F $2/ssh.conf root@guest apt-get install -y -o DPkg::Options::=--force-confold \
      escenic-content-engine-installer
  if [ $? == 0 ] ; then
    ECE_INSTALLER=/usr/sbin/ece-install
  fi
fi

if [ -z "$ECE_INSTALLER" ] ; then
  wget "https://github.com/skybert/ece-scripts/tarball/master" -O $2/ece-install.tar.gz
  scp -F $2/ssh.conf $2/ece-install.tar.gz root@guest:
  ssh -F $2/ssh.conf root@guest tar xfz ece-install.tar.gz
  ECE_INSTALLER="bash *-ece-scripts-*/usr/sbin/ece-install"
fi

scp -F $2/ssh.conf $1/ece-install*.conf root@guest:

for conf in $ece_install_conf_files ; do
  echo "Performing $ECE_INSTALLER with -f $conf"
  ssh -F $2/ssh.conf root@guest $ECE_INSTALLER -f "$conf" || exit $? 
  echo "---------8<-------------------------"
done


