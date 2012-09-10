#! /usr/bin/env bash

# Platform/OS specific methods.
# 
# by tkj@vizrt.com

# depends on common-bashing
common_bashing_is_loaded > /dev/null 2>&1 || source $(pwd)/common-bashing.sh

## Only used if the Tomcat download mirror couldn't be determined
fallback_tomcat_url="http://mirrorservice.nomedia.no/apache.org/tomcat/tomcat-6/v6.0.35/bin/apache-tomcat-6.0.35.tar.gz"

wget_opts="--continue --inet4-only --quiet"

# Can be used like this:
# common_io_os_loaded 2>/dev/null || source common-os.sh
function common_os_is_loaded() {
  echo 1
}

## Method which will try its best to find the home diretory of
## existing users and probable home directories of new users.
##
## (1) On Darwin/Mac OS X, it will return /Users/<user>
## (2) On systems using /etc/passwd, it will search there to find the
##     home dir of existing users.
## (3) For new users, it will check the configuration of adduser (if
##     present).
## (4) If all of thes above fails, it will return /home/<user>
##
## Arguments:
## $1 : the user name, can either be an existing user or a non-yet
## created user.
function get_user_home_directory() {
  if [ $(uname -s) = "Darwin" ]; then
    echo /Users/$1
  elif [ $(grep $1 /etc/passwd | wc -l) -gt 0 ]; then
    grep $1 /etc/passwd | cut -d':' -f6
  elif [ -r /etc/adduser.conf ]; then
    local dir=$(grep DHOME /etc/adduser.conf | grep -v ^# | cut -d'=' -f2)
    echo $dir/$1
  else
    echo "/home/$1"
  fi
}

function has_sun_java_installed() {
  if [[ -x /usr/lib/jvm/java-6-sun/bin/java || \
    $(java -version 2>&1 > /dev/null | grep HotSpot | wc -l) -gt 0 ]]; then
    echo 1
  else
    echo 0
  fi
}

## $1 user name
## $2 group name
function create_user_and_group_if_not_present() {
  local user=$1
  local group=$1
  
  if [ $(grep $user /etc/passwd | wc -l) -lt 1 ]; then
    print_and_log "Creating UNIX user $user ..."

    if [ $on_debian_or_derivative -eq 1 ]; then
      run adduser $user \
        --disabled-password \
        --gecos "Escenic-user,Room,Work,Home,Other"
    fi
    
    if [ $on_redhat_or_derivative -eq 1 ]; then
      run useradd $user \
        --comment "Escenic-user,Room,Work,Home,Other"
    fi
    
    add_next_step "I created a new UNIX user called $user"
    add_next_step "and you must set a password using: passwd $user"
  fi
  
  if [ $(grep $group /etc/group | wc -l) -lt 1 ]; then
    print_and_log "Creating UNIX group $group ..."
    run addgroup $group
  fi
}

## Will return the IP of the host name. If not found, the host name
## passed to the function will be returned.
## 
## Parameters: $1 the host name
function get_ip() {
  local ip=$(ping -c 1 $1 2>/dev/null | \
    grep "bytes from" | \
    cut -d'(' -f2 | \
    cut -d ')' -f1)
  
  if [ -z "$ip" ]; then
    echo $1
  fi

  echo $ip
}

## Asserts that the passed command/program is indeed accessible in the
## current context. If it is not, the program aborts and removes the
## PID.
##
## $1: the binary/executable/program
function assert_pre_requisite() {
  if [ $(which $1 2>/dev/null | wc -l) -lt 1 ]; then
    print_and_log "Please install $1 and then run $(basename $0) again."
    remove_pid_and_exit_in_error
  fi
}

function get_tomcat_download_url() {
  local url=$(
    curl -s http://tomcat.apache.org/download-60.cgi | \
      grep tar.gz | \
      head -1 | \
      cut -d'"' -f2
  )

  if [ -z $url ]; then
    url=$fallback_tomcat_url
    log "Failed to get Tomcat mirror URL, will use fallback URL $url"
  fi

  echo $url
}


## Downloads Tomcat from the regional mirror
##
## $1: target directory
function download_tomcat() {
  local url=$(get_tomcat_download_url)
  
  print_and_log "Downloading Tomcat from $url ..."
  run cd $1
  run wget $wget_opts $url
}

function get_free_memory_in_mega_bytes() {
  if [ $(uname -s) == "Linux" ]; then
    local free_in_kb=$(
      grep  MemFree /proc/meminfo | \
        cut -d: -f2- | \
        sed 's/^[ ]*//g' | \
        cut -d' ' -f1
    )
    echo $(( $free_in_kb / 1024 ))
  fi
}

function get_total_memory_in_mega_bytes() {
  if [ $(uname -s) == "Linux" ]; then
    local total_in_kb=$(
      grep  MemTotal /proc/meminfo | \
        cut -d: -f2- | \
        sed 's/^[ ]*//g' | \
        cut -d' ' -f1
    )
    echo $(( $total_in_kb / 1024 ))
  fi
}

function add_apt_source() {
  if [ $(grep -r "$@" /etc/apt/sources.list* | wc -l) -lt 1 ]; then
    echo "# added by $(basename $0) @ $(date)" >> $escenic_sources
    echo "$@" >> $escenic_sources
  fi
}

function get_memory_usage_of_pid() {
  local file=/proc/$1/status
  if [ ! -e $file ]; then
    # TODO add support for non-Linux systems
    return
  fi

  grep VmSize $file | cut -d ":" -f2 | sed 's/^[ \t]*//g'
}

function get_memory_summary_of_pid() {
  local file=/proc/$1/status
  if [ ! -e $file ]; then
    # TODO add support for non-Linux systems
    return
  fi

  local size=$(
    grep VmSize $file | cut -d ":" -f2 | sed 's/^[ \t]*//g'
  )
  local peak=$(
    grep VmPeak $file | cut -d ":" -f2 | sed 's/^[ \t]*//g'
  )

  echo "${size} (peaked at: $peak)"
}


