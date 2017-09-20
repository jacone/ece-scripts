#!/bin/bash -e

echo "--- START : post install hook - install ece install ---"

# install escenic scripts
ssh -F $2/ssh.conf guest 'sudo apt-get -y install libxml2-utils'
ssh -F $2/ssh.conf guest 'sudo apt-get update && sudo apt-get -y install escenic-content-engine-installer'
ssh -F $2/ssh.conf guest 'sudo apt-get update && sudo apt-get -y install escenic-content-engine-scripts'

echo "--- END : post install hook - install ece install ---"
