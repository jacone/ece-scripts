#! /usr/bin/env bash

# by tkj@vizrt.com

## $1 is instance
function create_ece_overview() {
  if [ $(whoami) == "root" ]; then
    local command="ece -q -i $1 info"
    local data="$(su - $ece_user -c " $command ")"$'\n'

    comman="ece -q -i $1 versions"
    data="$data $(su - $ece_user -c" $command " | cut -d'*' -f2-)"
  else
    local data="$(ece -q -i $1 info)"$'\n'
    data="$data $(ece -q -i $1 versions | cut -d'*' -f2-)"
  fi
  
  
  echo "$data" | while read line; do
    if [[ $line == "|->"* ]]; then
      print_list_item $(wrap_in_anchor_if_applicable ${line:3})
    elif [ $(echo $line | cut -d':' -f2- | wc -c) -gt 1 ]; then
      print_list_item $(wrap_in_anchor_if_applicable $line)
    else
      print_un_ordered_list_end
      print_h4_header $(echo $line | cut -d: -f1)
      print_un_ordered_list_start
    fi
  done
  
  print_un_ordered_list_end
}

function get_overview_of_all_instances() {
  local instance_list=$(get_instance_list)

  if [ -z "$instance_list" ]; then
    return
  fi

  print_h2_header "Overview of all the ECE instances on $HOSTNAME"
  for el in $(get_instance_list); do
    print_h3_header "Overview of instance $el"
    print_un_ordered_list_start
    create_ece_overview $el
  done
}

get_overview_of_all_instances

