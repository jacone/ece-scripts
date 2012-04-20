#! /usr/bin/env bash

# lists all referenced Puppet (Ruby) variables.

function red() {
  echo -e "\E[37;31m\033[1m${@}\033[0m"
}

function list_all_ruby_expressions() {
  find . -name "*.erb" | while read f; do
    if [ $(egrep \<%.*%\> $f | wc -l) -gt 0 ]; then
      echo $f "uses these Ruby expressions:"
      s=$(grep -n \<%.*%\> $f | grep -v ^#)
      echo "$s" | egrep --color "<%.*%>"
    fi
  done
}

function list_all_ruby_variable_expressions() {
  find . -name "*.erb" | while read f; do
    if [ $(egrep \<%=.*%\> $f | wc -l) -gt 0 ]; then
      if [ -z "$1" ]; then
        echo $f "uses these variables:"
      fi
      
      s=$(grep -n \<%=.*%\> $f | grep -v ^#)

      echo "$s" | \
        sed 's#\(.*\)<%=\(.*\)%>\(.*\)#\2#' | \
        sed 's#^[ ]##g'
    fi
  done
}

function list_all_ruby_variables_machine_readable() {
  list_all_ruby_variable_expressions no-paths | \
    sort | \
    uniq
}

while getopts "acmh" opt; do
  case $opt in
    a)
      list_all_ruby_expressions
      exit 0
      ;;
    c)
      list_all_ruby_variable_expressions
      exit 0
      ;;
    m)
      list_all_ruby_variables_machine_readable
      exit 0
      ;;
    h)
cat <<EOF
Usage: $(basename $0) [OPTION]

OPTIONS:
   -a    List all Ruby expressions listed per file. This options is also
         the default behaviour if no option is specified.
   -c    List only Ruby variables listed per file
   -m    List all Ruby variables used in all files, machine readable.
   -h    This help screen.

EOF
      exit 0
      ;;
  esac
done

list_all_ruby_expressions

