#!/bin/sh
find $1 -type d -name '*.erb' | sed 's/.*templates\(.*\)/\1/'