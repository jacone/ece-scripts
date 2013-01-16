#!/bin/bash -e

echo "--- START : post install hook - add vizrt repo ---"

# add archive key for apt.vizrt.com
curl -s http://apt.vizrt.com/archive.key | ssh -F $2/ssh.conf guest 'sudo apt-key add -'

# add repo to sources list
echo "deb http://apt.vizrt.com unstable main" | ssh -F $2/ssh.conf guest 'sudo tee > /dev/null /etc/apt/sources.list.d/vizrt.list'

echo "--- END : post install hook - add vizrt repo ---"
