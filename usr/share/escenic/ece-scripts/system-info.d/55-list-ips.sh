
print_h2_header "Overview of IPs on $HOSTNAME"

print_h3_header "Interfaces and their IPs"
print_pre_text "$(/sbin/ifconfig | grep -v inet6 | egrep -v "127.0" | grep inet -B 1 | sed 's/--//g')"

print_h3_header "${HOSTNAME}'s IP when accessing the world"
print_pre_text "$(curl --silent --connect-timeout 5 ifconfig.me 2>/dev/null)"

print_section_end
