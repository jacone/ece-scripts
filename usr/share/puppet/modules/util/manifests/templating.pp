
$puppet_bin = "/etc/puppetlabs/puppet/bin/"
$shListTemplatesErbFiles = "${puppet_bin}listTemplatesErbFiles.sh"
$shListTemplatesSubDirectories = "${puppet_bin}listTemplatesSubDirectories.sh"


define templated_file() {
    file { $name:
        ensure => file,
        content => template("${moduleName}${name}.erb"),
    }
}
                        

