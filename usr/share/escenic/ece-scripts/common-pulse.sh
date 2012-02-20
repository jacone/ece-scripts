#! /usr/bin/env bash

# by tkj@vizrt.com

# depends on common-bashing
common_bashing_is_loaded > /dev/null 2>&1 || source common-bashing.sh

pulse_bits="-\|/"

function pulse() {
  echo -ne "\b${pulse_bits: i++ % ${#pulse_bits}: 1}"
}

function show_pulse() {
  printne "${@: 2: $(( $# - 1 ))} ...."
  local pulse_pid=$1
  while true; do
    kill -0 $pulse_pid 2>/dev/null
    if [ $? -eq 0 ]; then
      pulse
      sleep 0.25
    else
      wait $pulse_pid
      local exit_code=$?
      if [ $exit_code -eq 0 ]; then
        echo -e '\b\E[37;32m'" \033[1mok\033[0m"
        tput sgr0
      else
        echo -e '\b\E[37;31m'" \033[1mfailed\033[0m"
        tput sgr0
      fi
      
      break
    fi
  done
}

