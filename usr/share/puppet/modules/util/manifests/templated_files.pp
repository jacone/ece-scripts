define util::templated_files($pa_util_module_directory, $pa_template_module_name, $pa_template_directory){

	$template_subdirectories = split(generate("${pa_util_module_directory}bin/list-templates-subdirectories.sh",$pa_template_directory) , "\n")
	file { $template_subdirectories:
	    ensure => directory,
	}
	$erb_filepaths = split(generate("${pa_util_module_directory}bin/list-templates-erb-files.sh", $pa_template_directory), "\n")
	util::templated_file{$erb_filepaths: 
		tmodule_name => $pa_template_module_name,
	}

}
