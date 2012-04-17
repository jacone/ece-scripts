package { 'reprepro': }
package { 'nginx': }
package { 'dpkg-sig': }

file { '/var/www': ensure=> directory, owner => www-data, group => www-data }
file { '/var/www/apt': ensure=> directory, owner => www-data, group => www-data }
file { '/var/www/apt/conf': ensure=> directory, owner => www-data, group => www-data }

file { '/var/www/apt/conf/distributions':
  ensure=> file,
  content=> "
Origin: Vizrt Online
Label: Vizrt Online APT repository
Codename: squeeze
Architectures: i386 amd64 source
Components: main
Description: Private APT repository for SAAS customer of Vizrt
SignWith: yes
",
}

file { '/var/www/apt/dists':
  ensure=> directory,
  owner =>
  www-data,
  group => www-data
}
file { '/var/www/apt/dists/stable':
  ensure => link,
  target => "/var/www/apt/dists/squeeze"
}
