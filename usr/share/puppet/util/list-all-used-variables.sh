#! /usr/bin/env bash

# lists all referenced Puppet (Ruby) variables.

function red() {
 echo -e "\E[37;31m\033[1m${@}\033[0m"
}

find . -name *.erb | while read f; do
  if [ $(egrep \<%.*%\> $f | wc -l) -gt 0 ]; then
    echo $f "uses these variables:"
    s=$(grep -n \<%.*%\> $f | grep -v ^#)
    echo "$s" | egrep --color "<%.*%>"
  fi
done


