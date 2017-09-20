#!/bin/bash

echo "Applying the initial puppet configuration, once."
ssh -F $2/ssh.conf root@guest puppet agent --verbose --no-daemonize --onetime || exit 2
sleep 1;
echo "Reapplying puppet, to ensure all changes are in, and that puppet still works!"
ssh -F $2/ssh.conf root@guest puppet agent --verbose --no-daemonize --onetime || exit 2


