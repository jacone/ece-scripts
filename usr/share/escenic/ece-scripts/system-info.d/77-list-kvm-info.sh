#! /usr/bin/env bash

if [ $(ps -u root | grep kvm | grep -v kvm-irqfd-clean | wc -l) -gt 0 ]; then
  i=1
  ps auxww | grep kvm | grep .img | sed "s/^root.*kvm/kvm/" | while read line; do
    print_h3_header "KVM image #${i} on $HOSTNAME"
    print_pre_text "$line"
    i=$(( $i + 1 ))
  done
fi


