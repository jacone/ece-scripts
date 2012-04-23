define util::templated_files($util_module_directory, $template_module_name, $template_directory){

	$template_subdirectories = split(generate("${util_module_directory}bin/list-templates-subdirectories.sh",$template_directory) , "\n")
	file { $template_subdirectories:
	    ensure => directory,
	}
	$erb_filepaths = split(generate("${util_module_directory}bin/list-templates-erb-files.sh", $template_directory), "\n")
	util::templated_file{$erb_filepaths: 
		module_name => $template_module_name,
	}

}
