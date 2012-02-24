#! /usr/bin/env bash

# by tkj@vizrt.com

if [ ! -e bash_unit ]; then
  wget --quiet https://raw.github.com/skybert/my-little-friends/master/bash/bash_unit
fi
if [ ! -e alexandria ]; then
  wget --quiet https://raw.github.com/skybert/my-little-friends/master/bash/alexandria
fi

source bash_unit

function common_test_is_loaded() {
  echo 1
}

