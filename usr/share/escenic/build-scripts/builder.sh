#! /usr/bin/env bash
################################################################################
#
# Script for managing "the builder"
#
################################################################################

# Common variables
ece_scripts_home=/usr/share/escenic/ece-scripts
log=/var/log/builder.log
pid_file=/var/run/ece-builder.pid

# Commands
add_user=0
add_artifact=0
add_artifact_list=0
setup_builder=0

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
skel_dir=$root_dir/skel
subversion_dir=$skel_dir/.subversion
assemblytool_home=$skel_dir/assemblytool
m2_home=$skel_dir/.m2

##
function init
{
  init_failed=0
  error_message=""
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
function set_pid 
{
  if [ -e $pid_file ]; then
    print_and_log "Instance of $(basename $0) already running!"
    exit 1
  else
    echo $BASHPID > $pid_file
  fi
}

##
function verify_root_privilege
{
  if [ "$(id -u)" != "0" ]; then
    print_and_log "This script must be run as root"
    remove_pid_and_exit_in_error
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
    print_and_log "User $user_name does not exist, but has a web root under /var/www/$user_name !"
    remove_pid_and_exit_in_error
  fi
}

##
function verify_builder_exist 
{
  if [ ! -d $root_dir ]; then
    print_and_log "Builder has not been initialized, please run this script with the -i flag!"
    remove_pid_and_exit_in_error
  fi
}

##
function common_post_action {
  run rm $pid_file
}

##
function get_user_options
{
  while getopts ":a:l:u:c:s:m:p:i" opt; do
    case $opt in
      a)
        print_and_log "Adding artifact ${OPTARG}..."
	add_artifact=1
        artifact_path=${OPTARG}
        ;;
      l)
        print_and_log "Adding list of artifacts ${OPTARG}..."
        add_artifact_list=1
        list_path=${OPTARG}
        ;;
      u)
        print_and_log "Adding user ${OPTARG}..."
        add_user=1          
        user_name=${OPTARG}
	ensure_no_user_conflict
        ;;
      c)
        print_and_log "Using svn path: ${OPTARG}."
        user_svn_path=${OPTARG}
        ;;
      s)
        print_and_log "Using svn username: ${OPTARG}!"
        user_svn_username=${OPTARG}
        ;;
      m)
        print_and_log "Using maven username: ${OPTARG}!"
        user_maven_username=${OPTARG}
        ;;
      p)
        print_and_log "Using password file: ${OPTARG}!"
        user_password_file=${OPTARG}
        if [ ! -e $user_password_file ]; then
          print_and_log "Provided password file does not exist, exiting!" >&2
          remove_pid_and_exit_in_error
        fi
        ;;
      i)
        print_and_log "Setting up a new builder under /home/$builder_user_name"
        setup_builder=1
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
    setup_builder
  elif [ $add_user -eq 1 ]; then
    verify_builder_exist
    verify_add_user
    add_user
  elif [ $add_artifact -eq 1 ]; then
    verify_builder_exist
    verify_add_artifact
    add_artifact
  elif [ $add_artifact_list -eq 1 ]; then
    verify_builder_exist
    verify_add_artifact_list
    add_artifact_list
  else
    print_and_log "No valid action chosen, exiting!" >&2
    remove_pid_and_exit_in_error
  fi
}

function setup_builder
{
  if [ ! -z "$(getent passwd $builder_user_name)" ]; then
    print_and_log "The user $builder_user_name already exist!"
    remove_pid_and_exit_in_error
  fi
  if [ -d /home/$builder_user_name ]; then
    print_and_log "The user $builder_user_name does not exist, but has a home folder!"
    remove_pid_and_exit_in_error
  fi
  run useradd -m -s /bin/bash $builder_user_name
  run ln -s /usr/share/escenic/build-scripts/builder.sh /home/$builder_user_name/builder.sh

  if [ ! -d "$skel_dir" ]; then
    mkdir $skel_dir
  fi

  if [ ! -d "$assemblytool_home" ]; then
    mkdir $assemblytool_home
    run wget --http-user=download --http-password=download http://technet.escenic.com/downloads/assemblytool-2.0.2.zip -O $assemblytool_home/assemblytool.zip
    run cd $assemblytool_home
    run unzip assemblytool.zip
    run rm -f assemblytool.zip
    run ant -q initialize
    echo "engine.root = ../engine/
plugins = ../plugins" >> $assemblytool_home/assemble.properties
  fi

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
    <activeProfile>vosa</activeProfile>
  </activeProfiles>
</settings>" > $m2_home/settings.xml
  fi

  if [ ! -d "$subversion_dir" ]; then
    mkdir $subversion_dir
    echo "[groups]

[global]
# Password / passphrase caching parameters:
store-passwords = yes
store-plaintext-passwords = yes" > $subversion_dir/servers
  fi

  if [ ! -e "$skel_dir/.vimrc" ]; then
    echo "set background=dark
syntax on
set nocompatible
set backspace=2" > $skel_dir/.vimrc
  fi

  run chown -R $builder_user_name:$builder_user_name /home/$builder_user_name

}

##
function verify_add_user 
{
  
  enforce_variable user_name "You need to provide your username using the -u flag."
  ensure_no_user_conflict
  enforce_variable user_svn_path "You need to provide your svn path using the -c flag."
  enforce_variable user_svn_username "You need to provide your svn username using the -s flag."
  enforce_variable user_maven_username "You need to provide your maven username using the -m flag."
  if [ -e "$user_password_file" ]; then
    source $user_password_file
    enforce_variable svn_password "The variable svn_password needs to be present in $user_password_file."
    enforce_variable maven_password "The variable maven_password needs to be present in $user_password_file."
    user_svn_password=$svn_password
    user_maven_password=$maven_password
  fi
}

##
function add_user
{
  run useradd -m -s /bin/bash $user_name
  run ln -s /usr/share/escenic/build-scripts/build.sh /home/$user_name/build.sh
  echo "customer=$user_name
svn_base=$user_svn_path
svn_user=$user_svn_username
svn_password=$user_svn_password
ece_scripts_home=/usr/share/escenic/ece-scripts" > /home/$user_name/build.conf
  run chown $user_name:$user_name /home/$user_name/build.conf
  run rsync -av /home/vosa/skel/ /home/$user_name
  run sed -i "s/maven.username/$user_maven_username/" /home/$user_name/.m2/settings.xml
  run sed -i "s/maven.password/$user_maven_password/" /home/$user_name/.m2/settings.xml
  run chown -R $user_name:$user_name /home/$user_name
  if [ ! -d /var/www/$user_name ]; then
    make_dir /var/www/$user_name
    run chown www-data:www-data /var/www/$user_name  
  else
    print_and_log "Failed to add web root /var/www/$user_name !"
    remove_pid_and_exit_in_error
  fi
  if [ ! -h /var/www/$user_name/releases ]; then
    run ln -s /home/$user_name/releases /var/www/$user_name/releases
  else
    print_and_log "Failed to add symlink for /var/www/$user_name/releases !"
    remove_pid_and_exit_in_error
  fi
}

##
function verify_add_artifact
{
  enforce_variable artifact_path "You need to provide a valid artifact URL using the -a flag."
}

##
function add_artifact 
{
  engine_found=0
  plugin_found=0
  plugin_pattern=""
  if [ -e "$root_dir/downloads" ]; then
    run rm -rf $root_dir/downloads
    make_dir $root_dir/downloads
    make_dir $root_dir/downloads/unpack
  fi
  if [[ "$artifact_path" == *\/engine-* ]]; then
    engine_found=1
    print ""
  fi
  for f in $escenic_plugin_indentifiers; do
    if [[ "$artifact_path" == *$f* ]]; then
      plugin_found=1
      plugin_pattern=$f
    fi
  done  
  if [ $engine_found -eq 1 ] && [ $plugin_found -eq 1 ]; then
    print_and_log "The requested resource $artifact_path has been identified as both an engine and a plugin. Exiting!" >&2
    remove_pid_and_exit_in_error
  elif [ $engine_found -eq 1 ]; then
    run wget --http-user=$technet_user --http-password=$technet_password $artifact_path -O $root_dir/downloads/unpack/resource.zip
    run cd $root_dir/downloads/unpack
    run unzip $root_dir/downloads/unpack/resource.zip
    for f in $(ls -d $root_dir/downloads/unpack/*);
      do
        filename=$(basename "$f")
        echo "$filename" | grep '[0-9]' | grep -q 'engine'
        if [ $? = 0 ]; then
          echo "Directory contains numbers and \"engine\" so it is most likely valid!"
          if [ ! -d "$root_dir/engine/$filename" ]; then
            run mv $f $root_dir/engine/.
          else
            print_and_log "$root_dir/engine/$filename already exists and will be ignored!"
          fi 
        fi
    done
  elif [ $plugin_found -eq 1 ]; then
    run wget --http-user=$technet_user --http-password=$technet_password $artifact_path -O $root_dir/downloads/unpack/resource.zip
    run cd $root_dir/downloads/unpack
    run unzip $root_dir/downloads/unpack/resource.zip
    run rm -f $root_dir/downloads/unpack/resource.zip
    for f in $(ls -d $root_dir/downloads/unpack/*);
      do
        filename=$(basename "$f")
        echo "$filename" | grep '[0-9]' | grep -q "$plugin_pattern"
        if [ $? = 0 ]; then
          echo "Directory contains numbers and \"$plugin_pattern\" so it is most likely valid!"
          if [ ! -d "$root_dir/plugins/$filename" ]; then
            run mv $f $root_dir/plugins/.
          else
            print_and_log "$root_dir/plugins/$filename already exists and will be ignored!"
          fi
        else
          test=`echo $artifact_path | sed "s/.*-\(.*\)\.[a-zA-Z0-9]\{3\}$/\1/"`     
          echo "$plugin_pattern-$test"
          print_and_log "Resource $artifact_path identified as a $plugin_pattern plugin, but failed the naming convention test after being unpacked, trying to recover..."
          if [ ! -d $root_dir/plugins/$plugin_pattern-$test ]; then
            run mv $f $root_dir/plugins/$plugin_pattern-$test
          fi
        fi
    done
  else
    print_and_log "No valid resource identified using $artifact_path, exiting!"
  fi
}

##
function verify_add_artifact_list
{
  enforce_variable list_path "You need to provide a valid path to your artifact list file using the -l flag."
  if [ ! -e $list_path ]; then
    print_and_log "The file $list_path does not exist!, exiting!" >&2
    remove_pid_and_exit_in_error
  fi
}

##
function add_artifact_list
{
  for f in $(cat $list_path);
  do
    add_artifact $f
  done
}

#####################################################
# Run commands
#####################################################
init
set_pid
verify_root_privilege
print_and_log "Starting process @ $(date)"
print_and_log "Additional output can be found in $log"
get_user_options $@
execute
print_and_log "Done! @ $(date)"
common_post_action
