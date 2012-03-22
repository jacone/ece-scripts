#! /usr/bin/env bash

# by tkj@vizrt.com

if [ "$(which mysqld)x" != "x" ]; then
  print_h2_header "DB information"
  print_pre_text "$(mysqld -V)"
  print_section_end
fi
