#!/bin/sh
find $1 -type f -name '*.erb' | sed 's/.*templates\(.*\)\.erb/\1/'

