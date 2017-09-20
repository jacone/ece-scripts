#!/bin/bash

pseudorandom_minute=$[ 0x$(basename $1 | md5sum - | cut -f 1 -d ' ') % 60]
if [ $pseudorandom_minute -lt 0 ] ; then
  pseudorandom_minute=$(( - $pseudorandom_minute ))
fi

ssh -F $2/ssh.conf root@guest update-rc.d -f puppet remove

echo "Installing cron job"
ssh -F $2/ssh.conf root@guest tee /etc/cron.d/vosa-puppet-agent <<EOF
# Installed by vosa on $(date --iso)

PATH=/sbin:/bin:/usr/sbin:/usr/bin

$pseudorandom_minute * * * * root puppet agent --no-daemonize --onetime
EOF


# Restarting cron for new time zone to take effect.
ssh -F $2/ssh.conf root@guest service cron restart
