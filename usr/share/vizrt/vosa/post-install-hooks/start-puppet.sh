#!/bin/bash

echo "Starting puppet agent"
ssh -F $2/ssh.conf root@guest /etc/init.d/puppet start || exit 2

