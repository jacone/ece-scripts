#! /usr/bin/env bash
################################################################################
#
# Script for managing "the builder"
#
################################################################################

# Common variables
ece_scripts_home=/usr/share/escenic/ece-scripts
log=~/builder.log
pid_file=~/builder.pid
root_dir=~/

##
function fetch_configuration
{
  conf_file=~/builder.conf
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

function common_post_action {
  run rm $pid_file
}

##
function get_user_options
{
  while getopts ":a:l:u:" opt; do
    case $opt in
      a)
        echo "Add artifact ${OPTARG}!"
	add_artifact ${OPTARG}
        ;;
      l)
        echo "Add list of artifacts ${OPTARG}!"
        for f in $(cat ${OPTARG}); 
        do
          add_artifact $f
        done
        ;;
      u)
        echo "Add user ${OPTARG}!"
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
  if [[ "$1" == *\/engine-* ]]; then
    engine_found=1
    print ""
  fi
  for f in $escenic_plugin_indentifiers; do
    if [[ "$1" == *$f* ]]; then
      plugin_found=1
      plugin_pattern=$f
    fi
  done  
  if [ $engine_found -eq 1 ] && [ $plugin_found -eq 1 ]; then
    print "The requested resource $1 has been identified as both an engine and a plugin. Exiting!" >&2
    remove_pid_and_exit_in_error
  elif [ $engine_found -eq 1 ]; then
    run wget --http-user=$technet_user --http-password=$technet_password $1 -O $root_dir/downloads/unpack/resource.zip
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
    run wget --http-user=$technet_user --http-password=$technet_password $1 -O $root_dir/downloads/unpack/resource.zip
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
          test=`echo $1 | sed "s/.*-\(.*\)\.[a-zA-Z0-9]\{3\}$/\1/"`     
          echo "$plugin_pattern-$test"
          print_and_log "Resource $1 identified as a $plugin_pattern plugin, but failed the naming convention test after being unpacked, trying to recover..."
          if [ ! -d $root_dir/plugins/$plugin_pattern-$test ]; then
            run mv $f $root_dir/plugins/$plugin_pattern-$test
          fi
        fi
    done
  else
    print_and_log "No valid resource identified using $1, exiting!"
  fi
}

set_pid
fetch_configuration
init
print_and_log "Starting building @ $(date)"
get_user_options $@
common_post_action
