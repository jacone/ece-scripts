
print_h2_header "Overview of all server services on $HOSTNAME"
print_pre_text "$(netstat -ntlp 2>/dev/null | sed -r 's,[0-9]+/([-\.a-z0-9]*).*,\1,' )"

if [ $(whoami) != "root" ]; then
  print_p_text "Run $(basename $0) as  root to get more details in this listing"
fi

print_section_end
