#!/bin/bash

# A post installation script to set up a fully functional puppet master with
# the ability to prime puppet hosts.  

hostname=$(basename $2)

# First get newly installed packages to not auto-start on installation:
ssh -F $2/ssh.conf root@guest tee > /dev/null /usr/sbin/policy-rc.d  <<EOF
#!/bin/sh
exit 101
EOF
ssh -F $2/ssh.conf root@guest chmod +x /usr/sbin/policy-rc.d


# Install the puppet master package on the guest, and patch the configuration file
ssh -F $2/ssh.conf root@guest apt-get -y install puppetmaster || exit 2
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

# Name the certificate based on the hostname, to avoid conflicts.
# Usually this would be called "puppetmaster" or "puppet" but it could be "puppet-3"
# or whatever.
ssh -F $2/ssh.conf root@guest puppet cert --generate generic-$hostname-client || exit $2

# Allow future installations to auto-start their services...
ssh -F $2/ssh.conf root@guest rm -f /usr/sbin/policy-rc.d || exit $2





### Set up the host to be able to spawn puppet master clients:

# 1. Get the private key of the puppetmaster's certificate.  Store it to $2/puppet-$hostname.pem.

# 1. store a user-data-file in the /etc directory as "$hstname-client.sh"
# Note:
#    This needs to be propagated to other vosa servers that want to spawn clients from
#    this puppet master.  This might not be possible to handle using puppet, since puppet
#    requires this file (certificates) in order to work...
# This is designed to run as a postinst hook.


awk ' BEGIN { RS="" }
      FILENAME==ARGV[1] { r=$0 }
      FILENAME==ARGV[2] { sub("@@PRIVATE_KEY@@",r) ; print }
    ' $2/puppet-$hostname.pem /usr/share/vizrt/vosa/puppet/client-postinst-script.tmpl > /etc/vizrt/vosa/puppet/$hostname-client.sh  

/etc/vizrt/vosa/puppet/$hostname-client.sh  <<EOF
puppet:
  conf:
    agent:
      server: "puppetmaster"
      certname: "generic-$hostname-client"
      node_name_fact: "fqdn"
      runinterval: 15
      environment: production


ssh -F \$2/ssh.conf tee /var/lib/puppet/ssl/private_keys/generic-$hostname-client.pem <<EOF2
EOF



cat > /etc/vizrt/vosa/puppet/$hostname-client.sh  <<EOF
EOF2
EOF

   EOF
   cat > /var/lib/puppet/ssl/certs/generic-puppetmaster-client.pem <<EOF
   -----BEGIN CERTIFICATE-----
   MIICWjCCAcOgAwIBAgIBAzANBgkqhkiG9w0BAQUFADAiMSAwHgYDVQQDDBdQdXBw
   ZXQgQ0E6IHB1cHBldG1hc3RlcjAeFw0xMjAyMjAwOTU0MzVaFw0xNzAyMTkwOTU0
   MzVaMCYxJDAiBgNVBAMMG2dlbmVyaWMtcHVwcGV0bWFzdGVyLWNsaWVudDCBnzAN
   BgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAyROaA2bu67istk9t30mR/3R+OAjVGfUN
   e2e/ocKmWi+xcBs0RXI1DnQd0M8YKDVaI/Oj13Wzp1vHGN1iu9HxlafjXd69Tozl
   xinyTWL+XzlTil54JuLB94X/e318E0rPnOmtCUsGgsZUtICUeKF7O3kwQPZVsaec
   4VrDUDQN/NkCAwEAAaOBmzCBmDAMBgNVHRMBAf8EAjAAMDcGCWCGSAGG+EIBDQQq
   FihQdXBwZXQgUnVieS9PcGVuU1NMIEludGVybmFsIENlcnRpZmljYXRlMA4GA1Ud
   DwEB/wQEAwIFoDAdBgNVHQ4EFgQURTSO+mSf60ueGo9SZQeuoiXOz4wwIAYDVR0l
   AQH/BBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMA0GCSqGSIb3DQEBBQUAA4GBAAtQ
   AVZNhoUc6nhrUPGNAGUE83S3jMwjRRh8DP/fZFGtF9zBYkVCEtcEbjT/kX56b5MJ
   NtJlYASzJejggnqDCIy3HUP8Hdb/PPPelJzp/mYYpPPwh7+ZEV3OjB+Ff5CAz+RS
   n8evskKlDNakx3cY/t+ox0HjhvH8EK648oD2KfJg
   -----END CERTIFICATE-----
   EOF
   /etc/init.d/puppet restart

