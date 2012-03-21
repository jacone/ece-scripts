#! /usr/bin/env bash

# by tkj@vizrt.com

print_h2_header "Operating system"

print_pre_text "$(lsb_release  -a 2>/dev/null)"
