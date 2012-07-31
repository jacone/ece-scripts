
print_h2_header "Overview of all server services on $HOSTNAME"
print_pre_text "$(netstat -ntlp 2>/dev/null | awk '{print $4, $7}' | cut -d':' -f2 | grep ^[0-9] | sort -n | uniq | column -t)"

if [ $(whoami) != "root" ]; then
  print_p_text "Run $(basename $0) as  root to get more details in this listing"
fi

print_section_end
