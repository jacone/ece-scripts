#!/bin/bash

# A post installation script to set up a fully functional puppet master with
# the ability to prime puppet hosts.  

# First get newly installed packages to not auto-start on installation:
ssh -F $2/ssh.conf root@guest tee > /dev/null /usr/sbin/policy-rc.d  <<EOF
#!/bin/sh
exit 101
EOF
ssh -F $2/ssh.conf root@guest chmod +x /usr/sbin/policy-rc.d


ssh -F $2/ssh.conf root@guest ssh -F apt-get -y install puppetmaster
ssh -F $2/ssh.conf root@guest patch /etc/puppet/auth.conf <<EOF
--- /etc/puppet/auth.conf    2011-06-27 16:50:51.000000000 +0200
+++ /etc/puppet/auth.conf.orig       2012-02-21 07:26:54.361610001 +0100
@@ -51,7 +51,9 @@
 # allow nodes to retrieve their own catalog (ie their configuration)
 path ~ ^/catalog/([^/]+)\$
 method find
-allow \$1
+#allow \$1
+# allow the generic cert to retrieve any node's catalog
+allow generic-puppetmaster-client

 # allow nodes to retrieve their own node definition
 path ~ ^/node/([^/]+)\$
EOF
ssh -F $2/ssh.conf root@guest puppet cert --generate generic-puppetmaster-client

# Allow future installations to auto-start their se
ssh -F $2/ssh.conf root@guest rm -f /usr/sbin/policy-rc.d
