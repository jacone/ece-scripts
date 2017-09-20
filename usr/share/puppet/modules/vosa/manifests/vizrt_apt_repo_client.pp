class vosa::vizrt_apt_repo_client {
  file { '/etc/apt/sources.list.d/vizrt.list' :
    content => template('vosa2/etc/apt/sources.list.d/vizrt.list.erb')
  }
}
