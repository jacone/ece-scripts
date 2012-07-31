function print_my_ip_to_the_world() {
  local file=$HOME/.vizrt/system-info/myip.cache
  mkdir -p $(dirname $file)

  # we only query ifconfig.me every ten minutes
  local max_age=600

  if [[ ! -e $file || $(get_file_age_in_seconds $file) -gt $max_age ]]; then
    curl --silent \
      --connect-timeout 30 \
      ifconfig.me \
      2>/dev/null \
      > $file
  fi

  cat $file
}

print_h2_header "Overview of IPs on $HOSTNAME"

print_h3_header "Interfaces and their IPs"
print_pre_text "$(/sbin/ifconfig | grep -v inet6 | egrep -v "127.0" | grep inet -B 1 | sed 's/--//g')"

print_h3_header "${HOSTNAME}'s IP when accessing the world"
print_pre_text "$(print_my_ip_to_the_world)"

print_section_end
