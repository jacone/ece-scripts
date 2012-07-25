#! /usr/bin/env bash

################################################################################
#
# BUILDER - build server script
#
################################################################################

# Common variables
log=~/ece-build.log
pid_file=~/ece-build.pid
build_date=`date +%F_%H%M`
builder_root_dir=/home/builder
builder_engine_dir=$builder_root_dir/engine
builder_plugins_dir=$builder_root_dir/plugins
assemblytool_root_dir=~/assemblytool
assemblytool_pub_dir=$assemblytool_root_dir/publications
assemblytool_lib_dir=$assemblytool_root_dir/lib
svn_src_dir=~/src
maven_conf_file=~/.m2/settings.xml
project_assembly_dir=$svn_src_dir/project-assembly
project_assembly_target_dir=$project_assembly_dir/target
escenic_indentifiers="engine
forum
geocode
analysis-engine
xml-editor
menu-editor
dashboard
poll
lucy
widget-framework-core
widget-framework-common"
release_dir=~/releases
plugin_dir=~/plugins
engine_root_dir=~/engine
ece_scripts_home=/usr/share/escenic/ece-scripts
conf_file=~/.build/build.conf
dependencies="tar
sed
ant
svn
mvn
unzip
wget"

##
function set_pid {
  if [ -e $pid_file ]; then
    print "Instance of $(basename $0) already running!"
    exit 1
  else
    echo $BASHPID > $pid_file
  fi
}

##
function init
{
  init_failed=0
  if [ ! -d $ece_scripts_home ]; then
    init_failed=1
    error_message="The directory for ece-scripts $ece_scripts_home does not exist, exiting!"
  elif [ ! -e $ece_scripts_home/common-bashing.sh ]; then
    init_failed=1
    error_message="The script $ece_scripts_home/common-bashing.sh does not exist, exiting!"
  elif [ ! -e $ece_scripts_home/common-io.sh ]; then
    init_failed=1
    error_message="The script $ece_scripts_home/common-io.sh does not exist, exiting!"
  fi
  if [ $init_failed -eq 0 ]; then
    source $ece_scripts_home/common-bashing.sh
    source $ece_scripts_home/common-io.sh
  else
    echo "$error_message"
    exit 1
  fi
}

##
function enforce_variable
{
  if [ ! -n "$(eval echo $`echo $1`)" ]; then
    print_and_log "$2"
    remove_pid_and_exit_in_error
  fi
}

##
function verify_command {
  command -v $1 >/dev/null 2>&1 || { print >&2 "I require $1 but it's not installed, exiting!"; remove_pid_and_exit_in_error; }
}

##
function verify_java 
{
  if !dpkg-query -W sun-java6-jdk > /dev/null 2>&1; then
    print_and_log "Required package sun-java6-jdk is not installed, exiting!"
    remove_pid_and_exit_in_error
  fi
}

##
function verify_dependencies
{
  for f in $dependencies
  do
    verify_command $f
  done
}

##
function fetch_configuration
{
  if [ -e $conf_file ]; then
    source $conf_file
  else
    print_and_log "Your user is missing the $conf_file, exiting!"
    remove_pid_and_exit_in_error
  fi 
}

##
function verify_configuration {
  enforce_variable customer "Your $conf_file is missing the variable 'customer', exiting!"
  enforce_variable svn_base "Your $conf_file is missing the variable 'svn_base', exiting!"
  enforce_variable svn_user "Your $conf_file is missing the variable 'svn_base', exiting!"
  enforce_variable svn_password "Your $conf_file is missing the variable 'svn_password', exiting!"
  # append a / to svn_base if not present
  [[ $svn_base != */ ]] && svn_base="$svn_base"/
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
function verify_assemblytool
{
  if [ ! -d $assemblytool_root_dir ]; then
    print_and_log "$assemblytool_root_dir is required, but it doesn't exist!"
    remove_pid_and_exit_in_error
  fi
  if [ ! -d $assemblytool_pub_dir ]; then
    make_dir $assemblytool_pub_dir
    print_and_log "$assemblytool_pub_dir did not exist so it has been created."
  fi
  if [ ! -d $assemblytool_lib_dir ]; then
    make_dir $assemblytool_lib_dir
    print_and_log "$assemblytool_lib_dir did not exist so it has been created."
  fi
  if [ ! -d $release_dir ]; then
    make_dir $release_dir
    print_and_log "$release_dir did not exist so it has been created."
  fi
}

## 
function clean_customer_home
{
  if [ -d "$plugin_dir" ]; then
    run rm -f $plugin_dir/*
  fi
  if [ ! -d $plugin_dir ]; then
    make_dir $plugin_dir
  fi
  if [ -h "$engine_root_dir" ]; then
    run rm -f $engine_root_dir
  fi
  if [ -e "$assemblytool_pub_dir" ]; then
    run rm -f $assemblytool_pub_dir/*
  fi
  if [ ! -d $assemblytool_pub_dir ]; then
    make_dir $assemblytool_pub_dir
  fi
  if [ -e "$assemblytool_lib_dir" ]; then
    run rm -f $assemblytool_lib_dir/*
  fi
  if [ ! -d $assemblytool_lib_dir ]; then
    make_dir $assemblytool_lib_dir
  fi
  if [ -e "$svn_src_dir" ]; then
    run rm -rf $svn_src_dir
  fi
  if [ ! -d $svn_src_dir ]; then
    make_dir $svn_src_dir
  fi
}

##
function add_global_libs
{
  if [ -e $builder_root_dir/lib/java_memcached-release_2.0.1.jar ]; then
    run ln -s $builder_root_dir/lib/java_memcached-release_2.0.1.jar $assemblytool_lib_dir/
  else
    print_and_log "The global library $builder_root_dir/lib/java_memcached-release_2.0.1.jar is missing, exiting!"
    remove_pid_and_exit_in_error
  fi
  if [ -e $builder_root_dir/lib/engine-backport-1.0-SNAPSHOT.jar ]; then
    run ln -s $builder_root_dir/lib/engine-backport-1.0-SNAPSHOT.jar $assemblytool_lib_dir/
  else
    print_and_log "The global library $builder_root_dir/lib/engine-backport-1.0-SNAPSHOT.jar is missing, exiting!"
    remove_pid_and_exit_in_error
  fi
}

##
function svn_fail_early
{
  if [ -z "$svn_path" ]; then
    svn_path=trunk
    release_label=$svn_path
    log "No svn path chosen, will use 'trunk'."
  fi
  run svn checkout --non-interactive --depth empty --username $svn_user  --password $svn_password $svn_base$svn_path $svn_src_dir/.
}

##
function svn_verify_assembly
{
  run svn update --non-interactive --set-depth infinity $svn_src_dir/pom.xml $svn_src_dir/project-assembly 
  if [ ! -d $project_assembly_dir ]; then
    print_and_log "Your project does not contain the project-assembly module and is thereby not certified to use the ece-builder, exiting!"
    remove_pid_and_exit_in_error
  elif [ ! -e $project_assembly_dir/src/main/assembly/assembly.xml ]; then
    print_and_log "Your project does not have a $project_assembly_dir/src/main/assembly/assembly.xml and is thereby not certified to use the ece-builder, exiting!"
    remove_pid_and_exit_in_error
  fi
}

##
function symlink_ece_components
{
  for f in $escenic_indentifiers
  do
    version=`sed "/<escenic.$f.version>/!d;s/ *<\/\?escenic.$f.version> *//g" $svn_src_dir/pom.xml | tr -d $'\r' `
    if [[ ! $version = "" ]]; then
      if [[ "$f" = "engine" ]]; then
        run ln -s $builder_engine_dir/$f-$version $engine_root_dir 
      else
        run ln -s $builder_plugins_dir/$f-$version $plugin_dir/$f 
      fi
    fi
  done
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
    print_and_log "BUILD FAILED!"
    remove_pid_and_exit_in_error
  fi
}

##
function verify_maven_proxy
{
  if [ -e $maven_conf_file ]; then
    maven_user=`sed "/<username>/!d;s/ *<\/\?username> *//g" $maven_conf_file | tr -d $'\r' `
    maven_password=`sed "/<password>/!d;s/ *<\/\?password> *//g" $maven_conf_file | tr -d $'\r' `
    if [[ $maven_user = "" ]] || [[ $maven_password = "" ]]; then
      print_and_log "Your $maven_conf_file is missing the username and/or the password for the maven proxy, exiting!"
      remove_pid_and_exit_in_error
    else
      wget --http-user $maven_user --http-password $maven_password http://maven.vizrt.com -qO /dev/null
      RETVAL=$?
      if [ $RETVAL -ne 0 ]; then
        print_and_log "Your user can't reach http://maven.vizrt.com, exiting!"
        remove_pid_and_exit_in_error
      fi
    fi
  else
    print_and_log "Your user does not have a ~/.m2/settings.xml, exiting!"
    remove_pid_and_exit_in_error
  fi
}

## 
function svn_checkout
{
  run svn update --non-interactive --set-depth infinity $svn_src_dir
  revision=`svn info $svn_src_dir | grep -i Revision | awk '{print $2}'`
  if [[ $revision = "" ]]; then    
    print_and_log "Failed to fetch current revision number, exiting!"
    remove_pid_and_exit_in_error
  fi
}

##
function maven_build
{
  run cd $svn_src_dir
  run mvn clean install
}

##
function symlink_project_assembly
{
  run cd $project_assembly_target_dir
  run unzip project-assembly.zip
  # global classpath
  if [ -e "$project_assembly_target_dir/lib" ]; then
    for f in $(ls -d $project_assembly_target_dir/lib/* | grep .jar);
    do 
      run ln -s $f $assemblytool_lib_dir;
    done
  fi
  # publications
  if [ -e "$project_assembly_target_dir/wars" ]; then
    for f in $(ls -d $project_assembly_target_dir/wars/* | grep .war);
    do
      ln -s $f $assemblytool_pub_dir;
    done
  fi
}

##
function generate_publication_properties
{
  for f in $(ls $assemblytool_pub_dir | grep .war)
  do
    echo "source-war:$f
context-root:/${f%.war}" > $assemblytool_pub_dir/${f%.war}.properties
  done
  if [ -d ${plugins/dashboard} ]; then
    print_and_log "Adding an assembly descriptor for Dashboard ..."
    echo "source-war: ../../plugins/dashboard/wars/dashboard-webapp.war
context-root: /dashboard" > $assemblytool_pub_dir/dashboard.properties
  fi
}

##
function ant_build
{
  run cd $assemblytool_root_dir
  run ant -q clean ear -DskipRedundancyCheck=true
}

##
function publish_ear 
{
  resulting_ear=$customer-$release_label-rev$revision-$build_date.ear
  if [ -e $assemblytool_root_dir/dist/engine.ear ]; then 
    run cp $assemblytool_root_dir/dist/engine.ear $release_dir/$resulting_ear
  else
    print_and_log "I'm done, but the .ear is still missing, exiting!"
    remove_pid_and_exit_in_error
  fi
}

##
function print_result
{
  print_and_log "BUILD SUCCESSFUL! @ $(date)"
  print_and_log "You'll find the release here: http://builder.vizrtsaas.com/$customer/releases/$resulting_ear"
}

##
function common_post_build {
  run rm $pid_file
}

##
function phase_startup {
  set_pid
  init
}

##
function phase_verify_plattform
{
  verify_dependencies
  verify_java
}

##
function phase_verify_user
{
  verify_maven_proxy
  fetch_configuration
  verify_configuration
  verify_assemblytool
}

##
function phase_clean_up
{
  clean_customer_home
}

##
function phase_verify_project
{
  svn_fail_early
  add_global_libs
  svn_verify_assembly
  symlink_ece_components
  verify_requested_versions
  
}

##
function phase_release
{
  svn_checkout
  maven_build
  generate_publication_properties
  ant_build
  publish_ear
  print_result
}

##
function phase_shutdown
{
  common_post_build
}

## ece-build execution
phase_startup
print_and_log "Starting release creation! @ $(date)"
print_and_log "Additional output can be found in $log"
phase_verify_plattform
phase_verify_user
phase_clean_up
get_user_options $@
phase_verify_project
phase_release
phase_shutdown
