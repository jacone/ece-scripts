#!/bin/sh
/usr/bin/find $1 -type f | sed 's/.*templates\(.*\)\.erb/\1/'

