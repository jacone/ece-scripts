#! /usr/bin/env bash

# by tkj@vizrt.com

# depends on common-bashing
common_bashing_is_loaded > /dev/null 2>&1 || source common-bashing.sh

# Can be used like this:
# common_io_is_loaded 2>/dev/null || source common-io.sh
function common_io_is_loaded() {
  echo 1
}

## Parameters:
## $1 is the property
## $2 ... to the (last - 1) is the value
## $n -1: The last argument is the file
##
## e.g.:
## set_conf_file_value \
##   mykey \
##   myvalue1 myvalue2 myvalue3 \
##   /etc/myfile.conf
function set_conf_file_value() {
  if [ $# -lt 3 ]; then
    return
  fi
  
  local file=${@:${#@}}
  local key=${@:1:1}
  local value_end_index=$(( $# - 2 ))
  local value=${@:2:${value_end_index}}

  local parent_dir=$(dirname $file)
  if [ ! -d ${parent_dir} ]; then
    print ${parent_dir} "doesn't exist, something is wrong :-("
    remove_pid_and_exit_in_error
  fi
  
  if [ -r $file ]; then
    if [ $(grep ^$1 $file | wc -l) -gt 0 ]; then
      if [ $dont_quote_conf_values -eq 0 ]; then
        sed -i "s~$key=.*~$key=\"$value\"~g" $file
      else
        sed -i "s~$key=.*~$key=$value~g" $file
      fi    
    else
      if [ $dont_quote_conf_values -eq 0 ]; then
        echo "$key=\"$value\"" >> $file
      else
        echo "$key=$value" >> $file
      fi
      
    fi
  else
    if [ $dont_quote_conf_values -eq 0 ]; then
      echo "$key=\"$value\"" >> $file
    else
      echo "$key=$value" >> $file
    fi
  fi
}

function make_dir() {
  if [ ! -d $1 ]; then
    run mkdir -p $1
  fi
}

function remove_dir() {
  if [ -d $1 ]; then
    run rmdir $1
  fi
}

function make_ln() {
  if [ $2 ]; then
    if [ -e $1 -a ! -h $2 ]; then
      run ln -s $1 $2
    elif [ ! -e $1 ]; then
      print_and_log "Tried to make a symlink to $1, but it doesn't exist"
      remove_pid_and_exit_in_error
    fi
  else
    if [ -e $1 -a ! -h $(basename $1) ]; then
      run ln -s $1
    elif [ ! -e $1 ]; then
      print_and_log "Tried to make a symlink to $1, but it doesn't exist"
      remove_pid_and_exit_in_error
    fi
  fi
}

## $1 : the URI, can be file:///tmp/file, http://server/file or
##      https://file. If $1 is a local file reference, it's used as it
##      is.
## $2 : the target dir
## returns : the local, downloaded file with absolute path
function download_uri_target_to_dir() {
  local uri=$1
  local target_dir=$2
  local file=""
  
  if [[ $uri == "http://"* || $uri == "https://"* ]]; then
    run cd $target_dir
    run wget $wget_opts $uri -O $(basename $uri)
    file=$target_dir/$(basename $uri)
  elif [[ $uri == "file://"* ]]; then
      # length of file:// is 7
    file=${file:7}
  else
    file=$uri
  fi

  echo $file
}

# verifies that the passed file(s) exist and are readable, depends on
# set_archive_files_depending_on_profile
function verify_that_files_exist_and_are_readable()
{
  debug "Verifying that the file(s) exist(s) and are readable: $@"
  
  for el in $@; do
    if [[ $el == http* ]]; then
      if [ $(curl -s -I $el | wc -l) -gt 0 ]; then
        continue
      else
        print_and_log "The URI $el doesn't exist, I will exit now."
        remove_pid_and_exit_in_error
      fi  
    fi
    
    if [ ! -e $el ]; then
      print_and_log "The file" $el "doesn't exist. I will exit now."
      remove_pid_and_exit_in_error
    elif [ ! -r $el ]; then
      print_and_log "The file" $el "isn't readable. I will exit now."
      remove_pid_and_exit_in_error
    fi
  done
}   

