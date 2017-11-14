#!/bin/bash -e

echo "--- START : post install hook - apply patch ---"

# copy all patch files
scp -F $2/ssh.conf -r $1/patch/* root@guest:/

# enable tomcat manager on engine1 
ssh -F $2/ssh.conf root@guest  \
   cp -R /opt/tomcat/webapps/manager /opt/tomcat-engine1/webapps/.

# enable tomcat mamanger on search1
ssh -F $2/ssh.conf root@guest  \
   cp -R /opt/tomcat/webapps/manager /opt/tomcat-search1/webapps/.

# change ownership just to be sure
ssh -F $2/ssh.conf root@guest  \
   chown -R escenic: /opt/tomcat-engine1

ssh -F $2/ssh.conf root@guest  \
   chown -R escenic: /opt/tomcat-search1

echo "--- END : post install hook - apply patch ---"

