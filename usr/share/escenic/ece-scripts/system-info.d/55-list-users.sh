#! /usr/bin/env bash

print_h2_header "Logged in users"
print_pre_text "$(who -H)"

print_h2_header "Last Boot"
print_pre_text "$(who -b)"


