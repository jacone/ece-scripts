#! /usr/bin/env bash

if [ $(which java 2>/dev/null | wc -l) -gt 0 ]; then
  print_h2_header "Java information"
  print_pre_text $(java -version 2>&1)
  print_section_end
fi

