#! /usr/bin/env bash

# by tkj@vizrt.com

if [ -x /usr/sbin/mysqld ]; then
  print_h2_header "DB information"
  print_pre_text "$(/usr/sbin/mysqld -V)"
else
  print_pre_text "$(mysql -V 2>/dev/null)"
  print_pre_text "$(mysql5 -V 2>/dev/null)"
fi
