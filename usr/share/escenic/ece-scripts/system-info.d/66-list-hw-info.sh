
print_h2_header "Disks used on $HOSTNAME"
print_pre_text "$(df -hT)"
print_section_end

print_h2_header "Memory on $HOSTNAME"
print_pre_text "$( cat <<EOF
Total memory: `grep MemTotal /proc/meminfo | cut -d':' -f2`
Free memory: `grep MemFree /proc/meminfo | cut -d':' -f2`
EOF
)"
print_section_end

print_h2_header "CPU(s) on $HOSTNAME"
print_un_ordered_list_start
print_list_item "Number of CPUs:" $(grep "model name" /proc/cpuinfo | wc -l)
print_list_item "Model: \
  $(grep model\ name /proc/cpuinfo | \
    cut -d: -f2- | \
    sed 's/^[ ]//g' | \
    sort | \
    uniq)"
print_un_ordered_list_end
print_section_end
