define util::templated_file_list($util_module_directory, $template_module_name, $template_directory){

	$template_subdirectory_list = split(generate("${util_module_directory}bin/list-templates-subdirectories.sh",$template_directory) , "\n")
	file { $template_subdirectory_list:
	    ensure => directory,
	}
	$erb_filepath_list = split(generate("${util_module_directory}bin/list-templates-erb-files.sh", $template_directory), "\n")
	util::templated_file{$erb_filepath_list: 
		module_name => $template_module_name,
	}

}
