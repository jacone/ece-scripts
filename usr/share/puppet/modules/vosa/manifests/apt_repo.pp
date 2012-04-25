package { 'reprepro': }
package { 'nginx': }
package { 'dpkg-sig': }

file { '/var/www':
  ensure=> directory,
  owner => www-data,
  group => www-data
}
file { '/var/www/apt':
  ensure=> directory,
  owner => www-data,
  group => www-data
}
file { '/var/www/apt/conf':
  ensure=> directory,
  owner => www-data,
  group => www-data
}
file { '/var/www/apt/conf/distributions':
  ensure=> file,
  content=> "
Origin: Vizrt Online
Label: Vizrt SaaS customer APT repository
Suite: stable
Codename: squeeze
Architectures: i386 amd64 source
Components: main non-free
Description: Vizrt SaaS customer APT repository
SignWith: yes

Origin: Vizrt Online
Label: Vizrt SaaS customer APT repository
Suite: unstable
Codename: sid
Architectures: i386 amd64 source
Components: main non-free
Description: Vizrt SaaS customer APT repository
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
