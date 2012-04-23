define util::templated_file($file_path = $title, $module_name) {
	notice($file_path)
	notice("${module_name}${title}.erb")
    file { $file_path:
        ensure => file,
        content => template("${module_name}${title}.erb"),
    }
}
