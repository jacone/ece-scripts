#!/bin/bash

# A post installation script to set up a fully functional puppet master with
# the ability to prime puppet hosts.  

hostname=$(basename $2)
ipaddress=$(ssh -F $2/ssh.conf root@guest hostname -I | cut -f 1 -d ' ')

# First get newly installed packages to not auto-start on installation:
ssh -F $2/ssh.conf root@guest tee > /dev/null /usr/sbin/policy-rc.d  <<EOF
#!/bin/sh
exit 101
EOF
ssh -F $2/ssh.conf root@guest chmod +x /usr/sbin/policy-rc.d


# Install the puppet master package + VIM & Emacs support for editing
# Puppet onfiguration files on the guest, and patch the configuration
# file
packages="puppetmaster emacs23-nox puppet-el vim-puppet"
ssh -F $2/ssh.conf root@guest apt-get -y install $packages || exit 2
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
+allow generic-$hostname-client

 # allow nodes to retrieve their own node definition
 path ~ ^/node/([^/]+)\$
EOF


ssh -F $2/ssh.conf root@guest tee > /dev/null /etc/puppet/puppet.conf <<EOF
[main]
logdir=/var/log/puppet
vardir=/var/lib/puppet
ssldir=/var/lib/puppet/ssl
rundir=/var/run/puppet
factpath=$vardir/lib/facter
templatedir=$confdir/templates
prerun_command=/etc/puppet/etckeeper-commit-pre
postrun_command=/etc/puppet/etckeeper-commit-post

[master]
# These are needed when the puppetmaster is run by passenger
# and can safely be removed if webrick is used.
ssl_client_header = SSL_CLIENT_S_DN 
ssl_client_verify_header = SSL_CLIENT_VERIFY

# Force the server to use an unqualified name as its certificate,
# as FQDNs make everything depend on a DNS Server providing a domain
# name that might cause problems in the future, if the domain name
# changes or DNS is unavailable.
certname=$hostname

EOF

# Name the certificate based on the hostname, to avoid conflicts.
# Usually this would be called "puppetmaster" or "puppet" but it could be "puppet-3"
# or whatever.
ssh -F $2/ssh.conf root@guest puppet cert --generate generic-$hostname-client || exit $2

# Allow future installations to auto-start their services...
ssh -F $2/ssh.conf root@guest rm -f /usr/sbin/policy-rc.d || exit $2





### Set up the host to be able to spawn puppet master clients:

# 1. Get the private key and signed certficate of the
# newly created puppetmaster's generic client.
# Store it inside $2

scp -F $2/ssh.conf \
   root@guest:/var/lib/puppet/ssl/ca/signed/generic-$hostname-client.pem \
   $2/generic-$hostname-client-certificate.pem || exit 2

scp -F $2/ssh.conf \
   root@guest:/var/lib/puppet/ssl/private_keys/generic-$hostname-client.pem \
   $2/generic-$hostname-client-private.pem || exit 2

# 2. store a user-data-file in the /etc directory as "$hostname-client.sh"
# Note:
#    This needs to be propagated to other vosa servers that want to spawn clients from
#    this puppet master.  This might not be possible to handle using puppet, since puppet
#    requires this file (certificates) in order to work...
# This is designed to run as a postinst hook.

mkdir -p /etc/vizrt/vosa/puppet/

awk ' BEGIN { RS="" }
      FILENAME==ARGV[1] { p=$0 }
      FILENAME==ARGV[2] { c=$0 }
      FILENAME==ARGV[3] { sub("@@PRIVATE_KEY@@",p); sub("@@CERTIFICATE@@",c); print }
    ' \
   $2/generic-$hostname-client-private.pem \
   $2/generic-$hostname-client-certificate.pem \
   /usr/share/vizrt/vosa/puppet/client-postinst-script.tmpl \
   | sed s/'@@HOSTNAME@@'/"$hostname"/g \
   | sed s/'@@IPADDRESS@@'/"$ipaddress"/g \
   > /etc/vizrt/vosa/puppet/$hostname-client.sh || exit 2

# Make private and executable to root only (since it contains the private keys of
# the SSL certificate.
chmod 0500 /etc/vizrt/vosa/puppet/$hostname-client.sh || exit 2

ssh -F $2/ssh.conf root@guest /etc/init.d/puppetmaster restart || exit 2

