# = Defined type: util::templated_file_list
#
# This type declares a directory of templates to be deployed to a node
#
# == Parameters:
#
#	$title::								  The name of the declaration: It should start with a slash and point to the subdirectory in the 
#														{module}/templates directory that needs to be deployed.
#
# $util_module_directory::  This parameter must point to the directory where 
#														https://github.com/skybert/ece-scripts/tree/master/usr/share/puppet/modules/util
#                   				is deployed on your puppet master
#														default: "/etc/puppet/modules/util/"
#
# $template_module_name::  The module that has the templates in its templates folder.
#
# $module_template_directory::  The directory where the source module has its template root: 
#																for instance: "/home/thomas/ece-scripts/usr/share/puppet/modules/escenic/templates/"
#
# == Actions:
#   ensures that all files like {file}.{ext}.erb are run through the erb engine and deployed to the node as {file}.{ext}
#
# == Requires:
#  all directories must have a slash at the end
#
# == Sample Usage:
# 
#			util::templated_file_list{'/etc/escenic/engine/':
#				template_module_name => "escenic",
#				module_template_directory => "/etc/puppet/modules/escenic/templates/",
#				util_module_directory => "/etc/puppet/modules/util/",
#			}
#
#			or better:
#
#			util::templated_file_list{'/etc/escenic/engine/':
#				template_module_name => "escenic",
#				module_template_directory => "/etc/puppet/modules/escenic/templates/",
#			}
#
define util::templated_file_list($util_module_directory = "/etc/puppet/modules/util/", $template_module_name, $module_template_directory){

	$template_directory = "${module_template_directory}${title}"

	$template_subdirectory_list = split(generate("${util_module_directory}bin/list-templates-subdirectories.sh",$template_directory) , "\n")
	file { $template_subdirectory_list:
	    ensure => directory,
	}
	$erb_filepath_list = split(generate("${util_module_directory}bin/list-templates-erb-files.sh", $template_directory), "\n")
	util::templated_file{$erb_filepath_list: 
		module_name => $template_module_name,
	}

}
