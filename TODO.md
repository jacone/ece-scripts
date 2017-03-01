
# Version 3.x aka "akbash"

## /usr/sbin/ece-install

- Support for installing ECE & plugins using the escenic APT
  repositories.
- YAML based configuration file format
- Easier to extend `ece-install`. Preferably in any language. Put a
  file in a directory and `ece-install` will execute that file at a
  predictable point in time.
- ✔ Remove the interactive mode. It's rarely used and complicates the
  source code and configuration options unnecessarily.

## /usr/bin/ece

- Easier to extend, e.g. put `create-publication.sh` in a directory,
  e.g.`ece.d`, and get `ece create-publication`. The
  `create-publication` sub command is then included in TAB completion,
  help screens and `man` pages.
  
