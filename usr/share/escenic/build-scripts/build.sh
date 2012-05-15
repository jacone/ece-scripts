#! /usr/bin/env bash

################################################################################
#
# VOSA - build server script - customer x
#
################################################################################

# Common variables
log=~/build.log
pid_file=~/build.pid
build_date=`date +%F_%H%M`
vosa_root_dir=/opt/vosa
assemblytool_root_dir=~/assemblytool
assemblytool_pub_dir=$assemblytool_root_dir/publications
assemblytool_lib_dir=$assemblytool_root_dir/lib
svn_src_dir=~/src
release_dir=~/releases
plugin_dir=~/plugins
engine_root_dir=~/engine

##
function fetch_configuration
{
  conf_file=~/build.conf
  source $conf_file
}

##
function init
{
  source $ece_scripts_home/common-bashing.sh
  source $ece_scripts_home/common-io.sh
}

## TODO - doc
function set_pid {
  if [ -e $pid_file ]; then
    print "Instance of $(basename $0) already running!"
    exit 1
  else
    echo $BASHPID > $pid_file
  fi
}

function common_post_build {
  run rm $pid_file
}

##
function get_user_options
{
  while getopts ":b:t:" opt; do
    case $opt in
      b)
        svn_path=branches/${OPTARG}
        release_label=branch-${OPTARG}
        ;;
      t)
        svn_path=tags/${OPTARG}
        release_label=tag-${OPTARG}
        ;;
      \?)
        print "Invalid option: -$OPTARG" >&2
        remove_pid_and_exit_in_error
        ;;
      :)
        print "Option -$OPTARG requires an argument." >&2
        remove_pid_and_exit_in_error
        ;;
    esac
  done

}

##
function verify_configuration {
  ensure_variable_is_set customer
  ensure_variable_is_set svn_base
  ensure_variable_is_set svn_user
  ensure_variable_is_set svn_password
}

##
function verify_vosa {
  if [ ! -d $assemblytool_root_dir ]; then
    print_and_log "$assemblytool_root_dir is required, but it doesn't exist!"
    remove_pid_and_exit_in_error
  fi
  if [ ! -d $release_dir ]; then
    print_and_log "$release_dir did not exist so it has been created."
    make_dir $release_dir
  fi
}

# clean up customer home
function home_preparation
{
  if [ -e "$plugin_dir" ]; then
    run rm -rf $plugin_dir
    make_dir $plugin_dir
  fi

  if [ -e "$engine_root_dir" ]; then
    run rm $engine_root_dir
  fi

  if [ -e "$assemblytool_pub_dir" ]; then
    run rm -rf $assemblytool_pub_dir
    make_dir $assemblytool_pub_dir
  fi

  if [ -e "$assemblytool_lib_dir" ]; then
    run rm -rf $assemblytool_lib_dir
    make_dir $assemblytool_lib_dir
  fi

  if [ -e "$svn_src_dir" ]; then
    run rm -rf $svn_src_dir
    make_dir $svn_src_dir
  fi
}

## TODO: make a place where everything common to all ears go.
function add_vosa_libs
{
  
  ln -s /opt/escenic/assemblytool/lib/java_memcached-release_2.0.1.jar ~/assemblytool/lib/
}


## Checkout customer project
function svn_checkout {

  if [ -z "$svn_path" ]; then
    svn_path=trunk
    release_label=$svn_path
    print_and_log "No svn path chosen! Will use 'trunk'!"
  fi
  print_and_log "Initiating svn checkout of $svn_path ..."
  #TODO run?
  svn checkout --username=$svn_user --password=$svn_password $svn_base$svn_path $svn_src_dir/.

}

# parse version based on property from src/pom.xml
function parse_version {
  run export $1=`sed "/<$2>/!d;s/ *<\/\?$2> *//g" $svn_src_dir/pom.xml | tr -d $'\r' `
}

# symlink component from /opt/vosa/.
function symlink_distribution {
  run ln -s $vosa_root_dir/$1 ~/$2
}

function symlink_ece_components {

  # Version - Escenic Content Engine
  parse_version ENGINE_VERSION vosa.engine.version
  symlink_distribution engine/engine-$ENGINE_VERSION engine

  # Version - Geo Code
  parse_version GEOCODE_VERSION vosa.geocode.version
  symlink_distribution plugins/geocode-$GEOCODE_VERSION plugins/geocode

  # Version - Poll
  parse_version POLL_VERSION vosa.poll.version
  symlink_distribution plugins/poll-$POLL_VERSION plugins/poll

  # Version - Menu Editor
  parse_version MENU_EDITOR_VERSION vosa.menu-editor.version
  symlink_distribution plugins/menu-editor-$MENU_EDITOR_VERSION plugins/menu-editor

  # Version - XML Editor
  parse_version XML_EDITOR_VERSION vosa.xml-editor.version
  symlink_distribution plugins/xml-editor-$XML_EDITOR_VERSION plugins/xml-editor

  # Version - Analysis Engine
  parse_version ANALYSIS_ENGINE_VERSION vosa.analysis-engine.version
  symlink_distribution plugins/analysis-engine-$ANALYSIS_ENGINE_VERSION plugins/analysis-engine

  # Version - Forum
  parse_version FORUM_VERSION vosa.forum.version
  symlink_distribution plugins/forum-$FORUM_VERSION plugins/forum

  # Version - Widget Framework Common
  parse_version WIDGET_FRAMEWORK_COMMON_VERSION vosa.widget-framework-common.version
  symlink_distribution plugins/widget-framework-common-$WIDGET_FRAMEWORK_COMMON_VERSION plugins/widget-framework-common

}

# symlink .war files from target/
function symlink_target {

  # global classpath
  for f in $(ls -d $svn_src_dir/vosa-assembly/target/lib/*);
    do run ln -s $f $assemblytool_lib_dir;
  done

  # publications
  for f in $(ls -d $svn_src_dir/vosa-assembly/target/wars/*);
    do ln -s $f $assemblytool_pub_dir;
  done

}

##
function release 
{

  home_preparation

  run svn_checkout

  revision=`svn info $svn_src_dir | grep -i Revision | awk '{print $2}'`
  
  if [ -z "$revision" ]; then
    print_and_log "Failed to fetch current revision number, exiting! :-("
    remove_pid_and_exit_in_error
  fi


  symlink_ece_components

  run cd $svn_src_dir
  run mvn clean package

  run cd $svn_src_dir/vosa-assembly/target
  run unzip vosa-assembly.zip

  symlink_target

  run cd $assemblytool_root_dir
  run ant -q clean ear -DskipRedundancyCheck=true

  resulting_ear=$customer-$release_label-rev$revision-$build_date.ear
  run cp $assemblytool_root_dir/dist/engine.ear $release_dir/$resulting_ear
  
  if [ ! -e "$release_dir/$resulting_ear" ]; then
    print_and_log "I'm done, but the .ear is still missing, exiting! :-("
    remove_pid_and_exit_in_error
  fi

}

##
function print_result
{
  print_and_log "BUILD SUCCESSFUL!"
  print_and_log "You'll find the release here: http://builder.vizrtsaas.com/$customer/releases/$resulting_ear"
}

set_pid
fetch_configuration
init
get_user_options $@
verify_configuration
home_preparation
verify_vosa
release
print_result
common_post_build
