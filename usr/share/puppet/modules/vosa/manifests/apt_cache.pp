# Installs an APT cache/proxy for other APT based machines can
# use. The hosts may use different APT based systems with different
# package pools. For instance, some hosts can run Ubuntu LTS, others
# Ubuntu 12.04 while others run Debian stable. The cache will handle
# all of this transparently.
package { 'apt-cacher': }

# would be great to use augeas here, but it currently doesn't support
# apt-cacher :-(
file { '/etc/apt-cacher/apt-cacher.conf':
  ensure => file,
  content => "
# This file has been configured by Puppet
admin_email=root@localhost
allowed_hosts=*
allowed_hosts_6=fec0::/16
cache_dir=/var/cache/apt-cacher
clean_cache=0
daemon_port=3142
debug=0
denied_hosts=
denied_hosts_6=
expire_hours=0
generate_reports=1
group=www-data
limit=0
logdir=/var/log/apt-cacher
offline_mode=0
use_proxy=0
use_proxy_auth=0
user=www-data
"
}

file { '/etc/default/apt-cacher':
  ensure => file,
  content => "
# This file has been configured by Puppet
AUTOSTART=1
"
}

  
service { 'apt-cacher':
  ensure => running,
  subscribe => File["/etc/apt-cacher/apt-cacher.conf"],
}
