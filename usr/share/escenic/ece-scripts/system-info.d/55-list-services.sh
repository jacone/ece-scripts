function print_listening_services() {
  echo -e "Port\tProgram";
  netstat -ntlp 2>/dev/null | \
    grep ^tcp | \
    sed -e 's/127.0.0.1://g' -e 's/0.0.0.0://g' -e  's/::://g' | \
    awk '{print $4, $7}' | \
    sort -n | \
    uniq | \
    column -t | \
    sed 's#[0-9]*/##'
}

print_h2_header "Overview of all server services on $HOSTNAME"
print_pre_text "$(print_listening_services)"

if [ $(whoami) != "root" ]; then
  print_p_text "Run $(basename $0) as  root to get more details in this listing"
fi

print_section_end
