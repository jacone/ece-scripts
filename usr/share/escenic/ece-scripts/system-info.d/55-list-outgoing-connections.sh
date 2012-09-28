function get_random_color() {
  color_array=($(echo "orange green red cyan red pink grey yellow"))
  number_of_colors=${#color_array[*]}
  color=${color_array[$((RANDOM % number_of_colors))]}
  echo "${color}"
}

function create_blockdiag_src() {
  echo "blockdiag {"
  
  echo "$@" | while read f; do
    read count program target <<< "$f"
    echo \"${program}\" "[color=\"$(get_random_color)\"];"
    only_program=$(echo $program | cut -d'/' -f2)
    echo '  '\"${program}\" "->" \"${target}\" "[label=\"$count conn\"];"
  done

  echo "}"
}

function generate_blockdiag() {
  local dir=/var/www/system-info
  if [ ! -w $dir ]; then
    return
  fi

  local tmp=$dir/${HOSTNAME}.blockdiag
  echo "$@" > $tmp
  local png_file=$dir/${HOSTNAME}.png
  blockdiag -o $png_file $tmp

  print_h2_header "Current archicture overview"
  print_pre_text "${HOSTNAME}'s diagram: http://${HOSTNAME}:5678/${HOSTNAME}.png"
}

function get_outbound_connections() {
  local local_ip_list=$(/sbin/ifconfig | \
    grep inet | \
    grep -v inet6 | \
    grep -v 127.0 | \
    cut -d':' -f2 | \
    cut -d' ' -f1)

  local egrep="127.0."

  for el in $local_ip_list; do
    egrep="${egrep}|$el"
  done

  netstat --numeric --program --tcp 2>/dev/null | \
    grep ESTABLISHED | \
    awk '{print $7,$5}' | \
    sed 's/-$//g' | \
    egrep -v "$egrep" | \
    column -t | \
    uniq -c | \
    sort -r | \
    sed 's/^[ ]*//g'
}

function create_diagram_if_possible() {
  if [ -r /etc/default/system-info ]; then
    source /etc/default/system-info
    if [ ${do_not_generate_diagram-0} -eq 1 ]; then
      return
    fi
  fi

  which blockdiag 2>/dev/null
  if [ $? -eq 0 ]; then
    blockdiag_src=$(create_blockdiag_src "$outbound_connections")
    generate_blockdiag "$blockdiag_src"
  fi
}

outbound_connections="$(get_outbound_connections)"

function list_outgoing_connections() {
  if [ ${temporaries-1} -eq 0 ]; then
    return
  fi
  
  print_h2_header "List of ${HOSTNAME}'s outgoing connections"
  print_un_ordered_list_start
  echo "$outbound_connections"  | while read f; do
    read count program target <<< "$f"
    print_list_item "$program $count conns -> $target"
  done
  print_un_ordered_list_end

}

list_outgoing_connections
create_diagram_if_possible
