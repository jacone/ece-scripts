class issues {

$engineTemplatesDirectory = "/etc/puppetlabs/puppet/modules/${name}/templates/etc/escenic/engine"


$engineTemplateDirectories = split(generate($shListTemplatesSubDirectories,$engineTemplatesDirectory) , "\n")
file { $engineTemplateDirectories:
    ensure => directory,
}

$erbFileNames = split(generate($shListTemplatesErbFiles, $engineTemplatesDirectory), "\n")
$moduleName = $name
templated_file{$erbFileNames:}


# nginx
package { 'webserver':
    name => nginx,
    ensure => installed,
    before => File ['nginx-default'],
}

file { 'nginx-default':
  name => '/etc/nginx/sites-available/default',
  source => "puppet:///modules/issues/nginx-config/default",
}

user { 'jiraexplorer':
	ensure => present,
	managehome => true,
}

file { 'www':
  name => '/home/jiraexplorer/www/',
  ensure => directory,
  group => www-data,
  require => [File['nginx-default'],User['jiraexplorer']]
}
file { '/home/jiraexplorer/www/50x.html':
  source => "puppet:///modules/issues/nginx-config/50x.html",
  require => User['jiraexplorer'],
}

service { 'nginx':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    subscribe  => File['nginx-default'],
		require => File['nginx-default']
}


# feed publisher

file { 'jiraExplorer-1.0-jar':
	name => '/home/jiraexplorer/jiraExplorer-1.0-jar-with-dependencies.jar',
  source => "puppet:///modules/issues/jiraExplorer-1.0-jar-with-dependencies.jar",
  require => User['jiraexplorer']
}

file { 'RssToAtom.xsl':
  name => '/home/jiraexplorer/RssToAtom.xsl',
  source => "puppet:///modules/issues/RssToAtom.xsl",
  require => User['jiraexplorer']
}

file { 'JiraExplorerConfiguration.properties':
  name => '/home/jiraexplorer/JiraExplorerConfiguration.properties',
  source => "puppet:///modules/issues/JiraExplorerConfiguration.properties",
  require => User['jiraexplorer']
}
package { 'java':
    name => openjdk-6-jdk,
    ensure => installed,
}


# cron job to run feed publisher

cron { 'refresh-knownissues' :
	command => 'java -jar -DpropertyFilePath=/home/jiraexplorer/JiraExplorerConfiguration.properties /home/jiraexplorer/jiraExplorer-1.0-jar-with-dependencies.jar',
	user => root,
	minute => 0-59,
	require => [
		Package['java'], 
		File['JiraExplorerConfiguration.properties'], 
		File['RssToAtom.xsl'], 
		File['jiraExplorer-1.0-jar'],
		File['www'],
	]
}

}