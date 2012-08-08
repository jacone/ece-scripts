function print_my_ip_to_the_world() {
  local file=$HOME/.vizrt/system-info/myip.cache
  mkdir -p $(dirname $file)

  # we only query ifconfig.me every ten minutes
  local max_age=600
  local restore=0
  local update=0

  if [[ -a $file ]] ; then
    # determine if file is legal and has a useful value
    local age=$(get_file_age_in_seconds $file) 
    if [[ $age -gt $max_age ]] ; then
      local update=1
    fi
    local old_value=$(cat $file)
  else
    local update=1
  fi


  if [[ $update -eq 1 ]]; then
    new_value="$( curl --silent \
        --connect-timeout 30 \
        ifconfig.me 2>/dev/null )"
  fi


  local value=$old_value
  if [[ $update -eq 1 ]] ; then
    local value=$new_value
    if [ ! -z "$old_value" ] ; then
      # Restore old value if it failed (keep it for 10 minutes)
      local restore=0
      if [ -z "$new_value" ] ; then
        local restore=1
      elif [[ ! ( $new_value =~ ^[0-9] ) ]] ; then
        local restore=1
      fi
      if [[ $restore -eq 1 ]] ; then
        local tmpfile=$(mktemp ${file}.XXXXXXX)
        echo $old_value > $tmpfile
        value=$old_value
        mv $tmpfile $file
      fi
    fi
    # touch the file to indicate that it's now up-to-date.
    touch $file
  fi

  echo $value
}

print_h2_header "Overview of IPs on $HOSTNAME"

print_h3_header "Interfaces and their IPs"
print_pre_text "$(/sbin/ifconfig | grep -v inet6 | egrep -v "127.0" | grep inet -B 1 | sed 's/--//g')"

print_h3_header "${HOSTNAME}'s IP when accessing the world"
print_pre_text "$(print_my_ip_to_the_world)"

print_section_end
