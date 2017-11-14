function get_vosa_file() {
  local file=${vosa_dir}/${instance}/$vosa_input_file
  if [ -e ${file} ]; then
    echo $file
  else
    file=${vosa_dir}/common/$vosa_input_file
    if [ -e ${file} ]; then
      echo $file
    fi
  fi
}

function cat_vosa_file() {
  local file=$(get_vosa_file)
  if [ -e ${file} ]; then
    echo "Contents of $file"
    echo "===="
    cat $file
    echo "===="
  else
    echo "Couldn't find $vosa_input_file in any of the vosa file layers"
    exit 1
  fi
}
