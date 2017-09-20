#!/bin/bash -e

echo "--- START : post install hook - restart tomcats ---"

ssh -F $2/ssh.conf ubuntu@guest  \
   sudo service ece restart

echo "--- END : post install hook - restart tomcats ---"
