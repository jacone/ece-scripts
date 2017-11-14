#! /usr/bin/env bash

# Logged in users counts as "temporary" information.
if [ $temporaries -eq 1 ] ; then
  print_h2_header "Logged in users"
  print_pre_text "$(who -H)"
fi


