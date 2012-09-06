#! /usr/bin/env bash

java_bin=$(which java)
file=/etc/escenic/ece.conf

if [ -r $file ]; then
  # don't like sourcing ece.conf, so getting it from grep instead.
  the_java_home=$(grep ^java_home $file | cut -d'=' -f2)
  if [ -n "$the_java_home" && -d "$the_java_home" ]; then
    java_bin=$the_java_home/bin/java
  fi
fi

if [ $(ls $java_bin 2>/dev/null | wc -l) -gt 0 ]; then
  print_h2_header "Java information"
  print_pre_text $(${java_bin} -version 2>&1)
  print_section_end
fi

