define util::templated_file($file_path = $title, $tmodule_name) {
    file { $file_path:
        ensure => file,
        content => template("${tmodule_name}${name}.erb"),
    }
}
