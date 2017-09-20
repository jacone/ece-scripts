#!/usr/bin/awk -f

BEGIN {
  linecount++;
}

# main
match($0, /^##(.*)$/, a) {
  # Store the line for safe keeping.
  lines[linecount++] = a[1]
  next;
}


match($0, /^function +([a-zA-Z0-9_]*)[^a-zA-Z0-9_]/, a) {
  if (("fn="a[1]) == ARGV[ARGC-1]) {
    for (i = 0; i < linecount; i++) {
      if (i == 0) {
        print lines[i]
      }
      else {
        print "      " lines[i]
      }
    }
  }
  next;
}

{
  # ignore all non-matching lines...
  for (i in lines)
     delete lines[i]
  linecount=0
  next;
}


