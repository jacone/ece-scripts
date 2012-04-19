class util {

$engineTemplatesDirectory = "/etc/puppetlabs/puppet/modules/${name}/templates/etc/escenic/engine"

$engineTemplateDirectories = split(generate($shListTemplatesSubDirectories,$engineTemplatesDirectory) , "\n")
file { $engineTemplateDirectories:
    ensure => directory,
}

$erbFileNames = split(generate($shListTemplatesErbFiles, $engineTemplatesDirectory), "\n")
$moduleName = $name
templated_file{$erbFileNames:}

}