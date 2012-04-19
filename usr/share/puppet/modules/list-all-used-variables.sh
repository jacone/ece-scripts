#! /usr/bin/env bash

# lists all referenced Puppet (Ruby) variables.

find . -name *.erb | xargs egrep \<%.*%\> | while read f; do
  if [ $(echo $f | cut -d: -f2 | grep -v ^# | wc -l) -gt 0 ]; then
    echo $(echo $f | cut -d: -f1) ":"
    echo $f | cut -d: -f2-
  fi
done


