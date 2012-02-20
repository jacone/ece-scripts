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

