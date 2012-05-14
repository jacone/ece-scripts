#! /usr/bin/env bash

# by tkj@vizrt.com

print_h2_header "Operating system"

print_h3_header "Kernel"
print_pre_text $(uname -a)

print_h3_header "Distribution"
print_pre_text "$(lsb_release  -a 2>/dev/null)"

if [ $verbose -eq 1 ]; then
  print_h3_header "Installed packages"
  if [ $(which dpkg)x != "x" ]; then
    print_pre_text "$(dpkg -l 2>/dev/null)"
  elif [ $(which rpm)x != "x" ]; then
    print_pre_text "$(rpm -qa | sort 2>/dev/null)"
  fi
fi

print_h3_header "Timezone"
print_un_ordered_list_start
print_list_item "$(cat /etc/timezone) (from /etc/timezone)"
if [ -n "$TZ" ]; then
  print_list_item "$(echo $TZ) (from ${USER}'s environment variable)"
fi
print_un_ordered_list_end

# of the h2
print_section_end

