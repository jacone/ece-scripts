#!/bin/sh
find $1 -type d | sed 's/.*templates\(.*\)/\1/'