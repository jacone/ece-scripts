#! /usr/bin/env bash

if [ $(which vosa 2>/dev/null | wc -l) -gt 0 ]; then
  print_h2_header "VOSA status"
  print_un_ordered_list_start
  vosa status | cut -d ' ' -f 1-5 | while read line; do
    print_list_item "$line"
  done
  print_un_ordered_list_end
fi

if [ $(ps -u root | grep kvm | grep -v kvm-irqfd-clean | wc -l) -gt 0 ]; then
  i=1
  print_h2_header "KVM guests running on $HOSTNAME"
  ps auxww | grep kvm | grep .img | sed "s/^root.*kvm/kvm/" | while read line; do
    print_h3_header "KVM image #${i} on $HOSTNAME"
    print_pre_text "$line"
    i=$(( $i + 1 ))
  done
fi


