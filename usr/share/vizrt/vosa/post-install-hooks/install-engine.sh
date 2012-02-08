# Only argument is the "vm name" as provided on the command line,
# which is a directory path of a VOSA vm definition:
#
# e.g. /etc/vosa/available.d/vm03

# The VM is assumed to be booted and ready for SSH using the passwordless
# key in the vm03 directory, as the XXX user (ubuntu?)

cat > /dev/null <<EOF
ece-install is copied in to /root
so is a conf file (probably located in /etc/vosa/available.d/vm03
ece-install is called
return code is ! 0 if ece-install is ! 0...
EOF

# What's needed: A tool to extract interesting information about a VM
# at run-time, programmatically.
# e.g. give me the IP address of a running VM by name "vm04"
# e.g. give me the 
