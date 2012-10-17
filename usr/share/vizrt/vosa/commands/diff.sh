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

function diff_vosa_file() {
  local vosa_file=$(get_vosa_file)
  diff $vosa_file $scm_dir/$vosa_input_file
}
