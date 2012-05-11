#! /usr/bin/env bash

print_h2_header "Logged in users"
print_un_ordered_list_start
who -H | while read line; do
  print_list_item "$line"
done
print_un_ordered_list_end

print_h2_header "Last Boot"
who -b | while read line; do
  print_pre_text "$line"
done


