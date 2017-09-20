#!/bin/bash -e

echo "--- START : post install hook - install java ---"

# copy .deb packages for java to the image
scp -F $2/ssh.conf /usr/share/java-debs/*.deb root@guest:/tmp

# install java dependencies
ssh -F $2/ssh.conf guest 'sudo apt-get -y install unixodbc defoma java-common'

# install .deb packages for java
ssh -F $2/ssh.conf guest 'sudo dpkg -i /tmp/*.deb'

# clean up
ssh -F $2/ssh.conf guest 'sudo rm /tmp/*.deb'

echo "--- END : post install hook - install java ---"
