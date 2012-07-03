
print_h2_header "List of ${HOSTNAME}'s outgoing connections"

local_ip_list=$(/sbin/ifconfig | \
  grep inet | \
  grep -v inet6 | \
  grep -v 127.0 | \
  cut -d':' -f2 | \
  cut -d' ' -f1)

egrep="arne"

for el in $local_ip_list; do
  egrep="127.0.⎈|$el"
done

print_un_ordered_list_start

netstat --numeric --program --tcp 2>/dev/null | \
  grep ESTABLISHED | \
  awk '{print $5,$7}' | \
  sed 's/-$//g' | \
  egrep -v "$egrep" | \
  column -t | \
  sort | while read f; do
  # here we could also create graphics $f contains both destination
  # IP, port and originating PID and program
  print_list_item "$f"
done
print_un_ordered_list_end

print_section_end
