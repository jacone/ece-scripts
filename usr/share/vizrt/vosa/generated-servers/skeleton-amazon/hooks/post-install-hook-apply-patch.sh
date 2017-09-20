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

# cleanup all jar files not needed to run solr and analysis engine
ssh -F $2/ssh.conf root@guest  \
   'find /opt/tomcat-search1/escenic/lib/ -type f ! \( \
-name 'common-nursery-*' \
-o -name 'commons-codec-*' \
-o -name 'commons-httpclient-*' \
-o -name 'commons-io-*' \
-o -name 'commons-lang-*' \
-o -name 'commons-logging-*' \
-o -name 'common-util-*' \
-o -name 'log4j-*' \
-o -name 'twelvemonkeys-core-*' \
-o -name 'xom-*' \
\) -exec rm -rf {} \;'

# change ownership just to be sure
ssh -F $2/ssh.conf root@guest  \
   chown -R escenic: /opt/tomcat-*

echo "--- END : post install hook - apply patch ---"

