#! /usr/bin/env bash

# by tkj@vizrt.com

print_h2_header "Operating system"

print_h3_header "Kernel"
print_pre_text $(uname -a)
print_section_end

print_h3_header "Distribution"
print_pre_text "$(lsb_release  -a 2>/dev/null)"
print_section_end

# of the h2
print_section_end
