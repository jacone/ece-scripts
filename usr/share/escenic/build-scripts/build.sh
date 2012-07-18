#! /usr/bin/env bash

################################################################################
#
# BUILDER - build server script
#
################################################################################

# Common variables
log=~/build.log
pid_file=~/build.pid
build_date=`date +%F_%H%M`
builder_root_dir=/home/builder
assemblytool_root_dir=~/assemblytool
assemblytool_pub_dir=$assemblytool_root_dir/publications
assemblytool_lib_dir=$assemblytool_root_dir/lib
svn_src_dir=~/src
release_dir=~/releases
plugin_dir=~/plugins
engine_root_dir=~/engine
ece_scripts_home=/usr/share/escenic/ece-scripts

##
function fetch_configuration
{
  conf_file=~/.build/build.conf
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
  # append a / if not present
  [[ $svn_base != */ ]] && svn_base="$svn_base"/
  ensure_variable_is_set svn_user
  ensure_variable_is_set svn_password
}

##
function verify_builder {
  if [ ! -d $assemblytool_root_dir ]; then
    print_and_log "$assemblytool_root_dir is required, but it doesn't exist!"
    remove_pid_and_exit_in_error
  fi
  if [ ! -d $assemblytool_pub_dir ]; then
    print_and_log "$assemblytool_pub_dir did not exist so it has been created."
    make_dir $assemblytool_pub_dir
  fi
  if [ ! -d $assemblytool_lib_dir ]; then
    print_and_log "$assemblytool_lib_dir did not exist so it has been created."
    make_dir $assemblytool_lib_dir
  fi
  if [ ! -d $release_dir ]; then
    print_and_log "$release_dir did not exist so it has been created."
    make_dir $release_dir
  fi
}

# clean up customer home
function home_preparation
{
  if [ -d "$plugin_dir" ]; then
    run rm -rf $plugin_dir
  fi

  if [ ! -d $plugin_dir ]; then
    run mkdir $plugin_dir
  fi

  if [ -h "$engine_root_dir" ]; then
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
function add_global_libs
{
  
  ln -s /opt/escenic/assemblytool/lib/java_memcached-release_2.0.1.jar $assemblytool_lib_dir/
  ln -s $builder_root_dir/lib/engine-backport-1.0-SNAPSHOT.jar $assemblytool_lib_dir/
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

# symlink component from $builder_root_dir/.
function symlink_distribution {
  run ln -s $builder_root_dir/$1 ~/$2
}

function symlink_ece_components {

  # Version - Escenic Content Engine
  parse_version ENGINE_VERSION escenic.engine.version
  if [ ! -z $ENGINE_VERSION ]; then
    symlink_distribution engine/engine-$ENGINE_VERSION engine
  fi

  # Version - Geo Code
  parse_version GEOCODE_VERSION escenic.geocode.version
  symlink_distribution plugins/geocode-$GEOCODE_VERSION plugins/geocode

  # Version - Poll
  parse_version POLL_VERSION escenic.poll.version
  symlink_distribution plugins/poll-$POLL_VERSION plugins/poll

  # Version - Menu Editor
  parse_version MENU_EDITOR_VERSION escenic.menu-editor.version
  symlink_distribution plugins/menu-editor-$MENU_EDITOR_VERSION plugins/menu-editor

  # Version - XML Editor
  parse_version XML_EDITOR_VERSION escenic.xml-editor.version
  symlink_distribution plugins/xml-editor-$XML_EDITOR_VERSION plugins/xml-editor

  # Version - Analysis Engine
  parse_version ANALYSIS_ENGINE_VERSION escenic.analysis-engine.version
  symlink_distribution plugins/analysis-engine-$ANALYSIS_ENGINE_VERSION plugins/analysis-engine

  # Version - Forum
  parse_version FORUM_VERSION escenic.forum.version
  symlink_distribution plugins/forum-$FORUM_VERSION plugins/forum

  # Version - Dashboard
  parse_version DASHBOARD_VERSION escenic.dashboard.version
  symlink_distribution plugins/dashboard-$DASHBOARD_VERSION plugins/dashboard

  # Version - Lucy
  parse_version LUCY_VERSION escenic.lucy.version
  symlink_distribution plugins/lucy-$LUCY_VERSION plugins/lucy
  
  # Version - Widget Framework Common
  parse_version WIDGET_FRAMEWORK_COMMON_VERSION escenic.widget-framework-common.version
  if [ ! -z $FRAMEWORK_COMMON_VERSION ]; then
    symlink_distribution plugins/widget-framework-common-$WIDGET_FRAMEWORK_COMMON_VERSION plugins/widget-framework-common
  fi

  # Version - Widget Framework
  parse_version WIDGET_FRAMEWORK_VERSION escenic.widget-framework.version
  symlink_distribution plugins/widget-framework-core-$WIDGET_FRAMEWORK_VERSION plugins/widget-framework

}

##
function verify_requested_versions 
{
  verification_failed=0
  
  if [ ! -d $engine_root_dir ]; then
    broken_link=`readlink $engine_root_dir` 
    print_and_log "The requested engine $broken_link does not exist on the plattform and must be added!"
    verification_failed=1
  fi
  
  for f in $(ls -d $plugin_dir/*);
  do
    if [ ! -d $f ]; then
      broken_link=`readlink $f`
      print_and_log "The requested plugin $broken_link does not exist on the plattform and must be added!"
      verification_failed=1
    fi
  done
  
  if [ $verification_failed -eq 1 ]; then
    print_and_log "You have broken symlinks indicating that some requested version(s) of engine and/or plugins are missing!"
    print_and_log "Build failed!"
    remove_pid_and_exit_in_error    
  fi
}

# symlink .war files from target/
function symlink_target {

  # global classpath
  if [ -e "$svn_src_dir/project-assembly/target/lib" ]; then
    for f in $(ls -d $svn_src_dir/project-assembly/target/lib/*);
      do run ln -s $f $assemblytool_lib_dir;
    done
  fi

  # publications
  if [ -e "$svn_src_dir/project-assembly/target/wars" ]; then
    for f in $(ls -d $svn_src_dir/project-assembly/target/wars/*);
      do ln -s $f $assemblytool_pub_dir;
    done
  fi
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

  verify_requested_versions

  run cd $svn_src_dir
  run mvn clean install

  run cd $svn_src_dir/project-assembly/target
  run unzip project-assembly.zip

  symlink_target

  add_global_libs

  add_dashboard_descriptor

  run cd $assemblytool_root_dir
  run ant -q clean ear -DskipRedundancyCheck=true

  resulting_ear=$customer-$release_label-rev$revision-$build_date.ear
  run cp $assemblytool_root_dir/dist/engine.ear $release_dir/$resulting_ear
  
  if [ ! -e "$release_dir/$resulting_ear" ]; then
    print_and_log "I'm done, but the .ear is still missing, exiting! :-("
    remove_pid_and_exit_in_error
  fi

}

function add_dashboard_descriptor() {
  if [ -d ${plugins/dashboard} ]; then
    print_and_log "Adding an assembly descriptor for Dashboard ..." 
    cat >> $assemblytool_root_dir/publications/dashboard.properties <<EOF
source-war: ../../plugins/dashboard/wars/dashboard-webapp.war
context-root: /dashboard
EOF
  else
    print_and_log "The Dashboard plugin is not available, not making descriptor for it."
  fi
}

##
function print_result
{
  print_and_log "Build SUCCESSFUL! @ $(date)"
  print_and_log "You'll find the release here: http://builder.vizrtsaas.com/$customer/releases/$resulting_ear"
}

set_pid
fetch_configuration
init
print_and_log "Starting building @ $(date)"
get_user_options $@
verify_configuration
home_preparation
verify_builder
release
print_result
common_post_build
