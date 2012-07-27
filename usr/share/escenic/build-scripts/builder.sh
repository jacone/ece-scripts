#! /usr/bin/env bash
################################################################################
#
# Script for managing "the builder"
#
################################################################################

# Common variables
ece_scripts_home=/usr/share/escenic/ece-scripts
log=/var/log/ece-builder.log
pid_file=/var/run/ece-builder.pid

# script dependencies
dependencies="tar
ant
sed
unzip
wget"

# available commands
setup_builder=0
add_user=0
add_artifact=0
add_artifact_list=0

# Add artifact variables
list_path=
artifact_path=

# Add user variables
user_name=
user_svn_path=
user_svn_username=
user_maven_username=
user_svn_password="CHANGE_ME"
user_maven_password="CHANGE_ME"

# Initialize builder variables
builder_user_name=builder
root_dir=/home/$builder_user_name
download_dir=$root_dir/.downloads
builder_engine_dir=$root_dir/engine
builder_plugins_dir=$root_dir/plugins
builder_conf_dir=$root_dir/.builder
builder_conf_file=$builder_conf_dir/builder.conf
artifact_conf_dir=.builder
artifact_conf_file=artifact.conf
skel_dir=$root_dir/.skel
subversion_dir=$skel_dir/.subversion
assemblytool_home=$skel_dir/assemblytool
m2_home=$skel_dir/.m2

##
function verify_root_privilege
{
  if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root!"
    exit 1
  fi
}

##
function set_pid 
{
  if [ -e $pid_file ]; then
    echo "Instance of $(basename $0) already running!"
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
function verify_dependencies
{
  for f in $dependencies
  do
    verify_command $f
  done
}

##
function get_user_options
{
  while getopts ":i:u:a:l:c:s:m:p:" opt; do
    case $opt in
      i)
        print_and_log "Setting up a new builder under /home/$builder_user_name ..."
        provided_conf_file=${OPTARG}
        setup_builder=1
        ;;
      u)
        print_and_log "Adding user ${OPTARG} ..."
        user_name=${OPTARG}
        add_user=1
        ;;
      a)
        print_and_log "Adding artifact ${OPTARG} ..."
        artifact_path=${OPTARG}
        add_artifact=1
        ;;
      l)
        print_and_log "Adding list of artifacts ${OPTARG} ..."
        list_path=${OPTARG}
        add_artifact_list=1
        ;;
      c)
        print_and_log "Using svn path: ${OPTARG}"
        user_svn_path=${OPTARG}
        ;;
      s)
        print_and_log "Using svn username: ${OPTARG}"
        user_svn_username=${OPTARG}
        ;;
      m)
        print_and_log "Using maven username: ${OPTARG}"
        user_maven_username=${OPTARG}
        ;;
      p)
        print_and_log "Using password file: ${OPTARG}"
        user_password_file=${OPTARG}
        if [ ! -e $user_password_file ]; then
          print_and_log "Provided password file does not exist, exiting!" >&2
          remove_pid_and_exit_in_error
        fi
        ;;
      \?)
        print_and_log "Invalid option: -$OPTARG" >&2
        remove_pid_and_exit_in_error
        ;;
      :)
        print_and_log "Option -$OPTARG requires an argument." >&2
        remove_pid_and_exit_in_error
        ;;
    esac
  done
}

##
function execute
{
  if [ $setup_builder -eq 1 ]; then
    verify_setup_builder
    verify_builder_conf
    setup_builder
  else
    verify_builder_exist
    read_builder_configuration
    verify_builder_conf
    if [ $add_user -eq 1 ]; then
      ensure_no_user_conflict
      verify_add_user
      add_user
    elif [ $add_artifact -eq 1 ]; then
      verify_add_artifact
      add_artifact
    elif [ $add_artifact_list -eq 1 ]; then
      verify_add_artifact_list
      add_artifact_list
    else
      print_and_log "No valid action chosen, exiting!" >&2
      remove_pid_and_exit_in_error
    fi
  fi
}

##
function verify_builder_conf
{
  enforce_variable technet_user "Your builder configuration file is missing the variable technet_user, exiting!"
  enforce_variable technet_user "Your builder configuration file is missing the variable technet_password, exiting!"
  wget --http-user $technet_user --http-password $technet_password http://technet.escenic.com/ -qO /dev/null
  if [ $? -ne 0 ]; then
    print_and_log "Your user can't reach http://technet.escenic.com/, exiting!"
    remove_pid_and_exit_in_error
  fi
  enforce_variable escenic_plugin_indentifiers "You need to configure a list of supported plugins in you builder configuration file using the variable escenic_plugin_indentifiers, exiting!"
  enforce_variable unsupported_plugin_indentifiers "You need to configure a list of unsupported plugins in you builder configuration file using the variable unsupported_plugin_indentifiers, exiting!" 
}

##
function verify_setup_builder
{
  if [ ! -z "$(getent passwd $builder_user_name)" ]; then
    print_and_log "The user $builder_user_name already exist!"
    remove_pid_and_exit_in_error
  fi
  if [ -d /home/$builder_user_name ]; then
    print_and_log "The user $builder_user_name does not exist, but has a home folder!"
    remove_pid_and_exit_in_error
  fi
  if [ ! -e $provided_conf_file ]; then
    print_and_log "The provided configuration file does not exist, exiting!" >&2
    remove_pid_and_exit_in_error
  else
    provided_conf_file=$(readlink -f $provided_conf_file)
    run source $provided_conf_file
  fi
}

##
function setup_builder
{
  # create the builder user
  run useradd -m -s /bin/bash $builder_user_name

  # create skel dir for user creation
  if [ ! -d "$skel_dir" ]; then
    mkdir $skel_dir
  fi

  # setup assemblytool skel
  if [ ! -d "$assemblytool_home" ]; then
    mkdir $assemblytool_home
    run wget --http-user=$technet_user --http-password=$technet_password http://technet.escenic.com/downloads/assemblytool-2.0.2.zip -O $assemblytool_home/assemblytool.zip
    run cd $assemblytool_home
    run unzip assemblytool.zip
    run rm -f assemblytool.zip
    run ant -q initialize
    echo "engine.root = ../engine/
plugins = ../plugins" >> $assemblytool_home/assemble.properties
  fi

  # setup maven settings.xml skel
  if [ ! -d "$m2_home" ]; then
    mkdir $m2_home
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<settings xmlns=\"http://maven.apache.org/settings/1.0.0\"
          xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"
          xsi:schemaLocation=\"http://maven.apache.org/SETTINGS/1.0.0
                              http://maven.apache.org/xsd/settings-1.0.0.xsd\">
  <servers>
    <server>
      <id>vizrt-repo</id>
      <username>maven.username</username>
      <password>maven.password</password>
    </server>
  </servers>

  <profiles>
    <profile>
      <id>escenic-profile</id>
      <repositories>
        <repository>
          <id>vizrt-repo</id>
          <name>Vizrt Maven Repository</name>
          <url>http://maven.vizrt.com</url>
          <layout>default</layout>
        </repository>
      </repositories>
    </profile>
  </profiles>

  <activeProfiles>
    <activeProfile>escenic-profile</activeProfile>
    <activeProfile>builder</activeProfile>
  </activeProfiles>
</settings>" > $m2_home/settings.xml
  fi

  # setup subversion config skel
  if [ ! -d "$subversion_dir" ]; then
    run mkdir $subversion_dir
    echo "[groups]

[global]
# Password / passphrase caching parameters:
store-passwords = yes
store-plaintext-passwords = yes" > $subversion_dir/servers
  fi

  # setup .vim.rc skel 
  if [ ! -e "$skel_dir/.vimrc" ]; then
    echo "set background=dark
syntax on
set nocompatible
set backspace=2" > $skel_dir/.vimrc
  fi

  # setup .builder conf directory
  if [ ! -d $builder_conf_dir ]; then
    run mkdir $builder_conf_dir
  fi
  cat $provided_conf_file > $builder_conf_file

  # change owner to build user - TODO: root may be ok here
  run chown -R $builder_user_name:$builder_user_name /home/$builder_user_name
}

##
function verify_builder_exist 
{
  if [ ! -d $root_dir ]; then
    print_and_log "Builder has not been initialized, please run this script with the -i flag and provide a valid config file!"
    remove_pid_and_exit_in_error
  fi
}

##
function read_builder_configuration
{
  if [ -e $builder_conf_file ]; then
    run source $builder_conf_file
  else
    print_and_log "The configuration file $builder_conf_file is missing, exiting!" >&2
    remove_pid_and_exit_in_error
  fi
}

##
function ensure_no_user_conflict
{
  if [ ! -z "$(getent passwd $user_name)" ]; then
    print_and_log "User $user_name already exist!"
    remove_pid_and_exit_in_error
  fi
  if [ -d /home/$user_name ]; then
    print_and_log "User $user_name does not exist, but has a home folder!"
    remove_pid_and_exit_in_error
  fi
  if [ -d /var/www/$user_name ]; then
    print_and_log "User $user_name does not exist, but has a web root under /var/www/$user_name"
    remove_pid_and_exit_in_error
  fi
}

##
function verify_add_user 
{  
  enforce_variable user_name "You need to provide your username using the -u flag."
  enforce_variable user_svn_path "You need to provide your svn path using the -c flag."
  enforce_variable user_svn_username "You need to provide your svn username using the -s flag."
  enforce_variable user_maven_username "You need to provide your maven username using the -m flag."
  if [ -e "$user_password_file" ]; then
    source $user_password_file
    enforce_variable svn_password "The variable svn_password needs to be present in $user_password_file."
    enforce_variable maven_password "The variable maven_password needs to be present in $user_password_file."
    user_svn_password=$svn_password
    user_maven_password=$maven_password
  else
    print_and_log "You must provide a password file using the -p flag."
    remove_pid_and_exit_in_error
  fi
}

##
function add_user
{
  run useradd -m -s /bin/bash $user_name
  run mkdir /home/$user_name/.build
  echo "customer=$user_name
svn_base=$user_svn_path
svn_user=$user_svn_username
svn_password=$user_svn_password" > /home/$user_name/.build/build.conf
  run chown $user_name:$user_name /home/$user_name/.build/build.conf
  run rsync -av $skel_dir/ /home/$user_name
  run sed -i "s/maven.username/$user_maven_username/" /home/$user_name/.m2/settings.xml
  run sed -i "s/maven.password/$user_maven_password/" /home/$user_name/.m2/settings.xml
  run chown -R $user_name:$user_name /home/$user_name
  if [ ! -d /var/www/$user_name ]; then
    make_dir /var/www/$user_name
    run chown www-data:www-data /var/www/$user_name  
  else
    print_and_log "Failed to add web root /var/www/$user_name"
    remove_pid_and_exit_in_error
  fi
  if [ ! -h /var/www/$user_name/releases ]; then
    run ln -s /home/$user_name/releases /var/www/$user_name/releases
  else
    print_and_log "Failed to add symlink for /var/www/$user_name/releases"
    remove_pid_and_exit_in_error
  fi
}

##
function verify_add_artifact
{
  enforce_variable artifact_path "You need to provide a valid artifact URL using the -a flag."
}

##
function detect_duplicate_artifact
{
  if [ $engine_found -eq 1 ] && [ -d $builder_engine_dir/engine-$artifact_version ]; then
    duplicate_found=1
  elif [ $plugin_found -eq 1 ] && [ -d $builder_plugins_dir/$plugin_pattern-$artifact_version ]; then
    duplicate_found=1
  fi
}

##
function add_artifact 
{
  # action flags
  engine_found=0
  plugin_found=0
  unsupported_plugin_found=0
  artifact_version=`echo $artifact_path | sed "s/.*-\(.*\)\.[a-zA-Z0-9]\{3\}$/\1/"`
  duplicate_found=0  

  if [ ! -d $builder_engine_dir ]; then
    run mkdir $builder_engine_dir
    print_and_log "NOTE - The directory $builder_engine_dir did not exist so it has been created."
  fi

  if [ ! -d $builder_plugins_dir ]; then
    run mkdir $builder_plugins_dir
    print_and_log "NOTE - The directory $builder_plugins_dir did not exist so it has been created."
  fi

  # clean up download directory
  if [ -d $download_dir ]; then
    run rm -rf $download_dir
  fi

  # create download directory structure
  run mkdir -p $download_dir/unpack

  # is request artifact an engine?
  if [[ "$artifact_path" == *\/engine-* ]]; then
    engine_found=1
  fi

  # is requested artifact a plugin?
  for f in $escenic_plugin_indentifiers; do
    if [[ "$artifact_path" == *$f* ]]; then
      plugin_found=1
      plugin_pattern=$f
    fi
  done

  # is requested artifact a plugin, but unsupported?
  for f in $unsupported_plugin_indentifiers; do
    if [[ "$artifact_path" == *$f* ]]; then
      unsupported_plugin_found=1
      plugin_pattern=$f
    fi
  done  

  # fail early on duplicate
  detect_duplicate_artifact

  if [ $engine_found -eq 1 ] && [ $plugin_found -eq 1 ]; then
    print_and_log "ERROR - The requested resource $artifact_path has been identified as both an engine and a plugin, exiting!" >&2
    remove_pid_and_exit_in_error
  elif [ $duplicate_found -eq 1 ]; then
    print_and_log "SKIPPED - The requested resource $artifact_path already exists." 
  elif [ $engine_found -eq 1 ] || [ $plugin_found -eq 1 ]; then
    process_artifact
  elif [ $unsupported_plugin_found -eq 1 ]; then
    print_and_log "UNSUPPORTED - The requested resource $artifact_path is a plugin, but currently unsupported by the platform."
  else
    print_and_log "SKIPPED - No valid resource identified using $artifact_path!"
  fi   
}

##
function process_artifact
{
  # identify type
  if [ $engine_found -eq 1 ]; then
    artifact_pattern=engine
    target_path=$builder_engine_dir
  elif [ $plugin_found -eq 1 ]; then
    artifact_pattern=$plugin_pattern
    target_path=$builder_plugins_dir
  fi

  # fetch and unpack resource
  run wget --http-user $technet_user --http-password $technet_password $artifact_path -O $download_dir/unpack/artifact.zip
  run cd $download_dir/unpack
  run unzip $download_dir/unpack/artifact.zip
  
  # analyze unpacked resource
  for f in $(ls -d $download_dir/unpack/*);
  do
    skip_artifact=0
    artifact_filename=$(basename "$f")
    echo "$artifact_filename" | grep '[0-9]' | grep -q "$artifact_pattern"
    if [ $? = 0 ]; then
      log "The resulting directory contains numbers and \"$artifact_pattern\" so it is most likely valid."
    else
      echo "$artifact_filename" | grep -q "$artifact_pattern"
      if [ $? = 0 ]; then
        log "$artifact_path was identified as $artifact_pattern, but failed the naming convention test after being unpacked, trying to recover..."
        if [ ! -d $target_path/$artifact_pattern-$artifact_version ]; then
          log "$artifact_path was recovered as a $artifact_pattern and will be added as $artifact_pattern-$artifact_version"
        else
          log "$artifact_path was identified as $artifact_pattern, but $artifact_pattern-$artifact_version already exists so it will not be added."
          skip_artifact=1
        fi
      else
        log "$f is not a valid artifact, ignoring."
        skip_artifact=1
      fi
    fi
    if [ $skip_artifact -eq 0 ]; then
      run mv $f $target_path/$artifact_pattern-$artifact_version
      if [ ! -d $target_path/$artifact_pattern-$artifact_version/$artifact_conf_dir ]; then
        run mkdir $target_path/$artifact_pattern-$artifact_version/$artifact_conf_dir
      fi
      # workaround for assemblytool writing into the engine directory
      if [ $engine_found -eq 1 ] && [ ! -d $target_path/$artifact_pattern-$artifact_version/patches ]; then
        run mkdir $target_path/$artifact_pattern-$artifact_version/patches
      fi
      echo "artifact_uri=$artifact_path" > $target_path/$artifact_pattern-$artifact_version/$artifact_conf_dir/$artifact_conf_file
      print_and_log "ADDED - $artifact_pattern-$artifact_version sucessfully added."
    fi
  done
}

##
function verify_add_artifact_list
{
  enforce_variable list_path "You need to provide a valid path to your artifact list file using the -l flag."
  if [ ! -e $list_path ]; then
    print_and_log "The file $list_path does not exist!, exiting!" >&2
    remove_pid_and_exit_in_error
  fi
  run source $list_path
  enforce_variable escenic_releases "You need to specify your releases with full URLs in a escenic_releases variable!"
}

##
function add_artifact_list
{
  for f in $escenic_releases;
  do
    artifact_path=$f
    add_artifact
    artifact_path=
  done
}

##
function common_post_build {
  run rm $pid_file
}

##
function phase_startup {
  verify_root_privilege
  set_pid
  init
  verify_dependencies
}

##
function phase_execute
{
  execute
}

##
function phase_shutdown
{
  common_post_build
}

#####################################################
# Run commands
#####################################################
phase_startup
print_and_log "Starting process @ $(date)"
print_and_log "Additional output can be found in $log"
get_user_options $@
phase_execute
print_and_log "Success! @ $(date)"
phase_shutdown
