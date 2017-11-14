#!/bin/bash -e

echo "--- START : post install hook - install java ---"

# check if java exists
ssh -F $2/ssh.conf guest which > /dev/null java && exit 0

# copy .deb packages for java to the image
scp -F $2/ssh.conf /var/local/oab/deb/sun-java6*precise*.deb guest:/tmp

# install java dependencies
ssh -F $2/ssh.conf guest 'sudo apt-get -y install unixodbc defoma java-common'

# install .deb packages for java
ssh -F $2/ssh.conf guest 'sudo dpkg -i /tmp/*.deb'

# clean up
ssh -F $2/ssh.conf guest 'sudo rm /tmp/*.deb'

echo "--- END : post install hook - install java ---"
