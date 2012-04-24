define util::templated_file($file_path = $title, $module_name) {
    file { $file_path:
        ensure => file,
        content => template("${module_name}${title}.erb"),
    }
}
