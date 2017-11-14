#!/bin/bash -e

echo "--- START : post install hook - copy files ---"

src_dir=files

# copy everything under files into the images
if [[ -d $1/$src_dir && \
  $(find $1/$src_dir -maxdepth 1 | wc -l) -gt 1 ]]; then
    scp -F $2/ssh.conf -rv $1/$src_dir/* root@guest:/tmp/.
fi

echo "--- END : post install hook - copy files ---"
