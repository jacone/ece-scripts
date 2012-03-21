
print_h2_header "Overview of all server services on $HOSTNAME"
print_pre_text "$(netstat -nlp 2>/dev/null | egrep -v "tcp6|ACC" | grep LISTEN)"

if [ $(whoami) != "root" ]; then
  print_p_text "Run $(basename $0) as  root to get more details in this listing"
fi

print_section_end
