class vosa::apt_cache_client {
  file { '/etc/apt/apt.conf.d/90apt-proxy' :
    content => template('vosa2/etc/apt/apt.conf.d/90apt-proxy.erb')
  }
}

