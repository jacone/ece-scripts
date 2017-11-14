# removes log files older than <numbber> days
old_log_file_max_age_in_days=5

function get_log_file_dir_list() {
  local dir_list="${log_dir}"

  local dir=${tomcat_base}/logs
  if [ -d $dir ]; then
    dir_list="${dir_list} ${dir}"
  fi

  echo $dir_list
}

function remove_old_logs_if_exist() {
  debug "Looking for old log files in $1 ..."

  local old_log_files="$(
    find -L $1 -mtime +${old_log_file_max_age_in_days} -type f
  )"

  if [ -z "${old_log_files}" ]; then
    return
  fi

  print_and_log "Deleting" \
    $(echo "$old_log_files" | wc -l) \
    "log files in $1" \
    "older than ${old_log_file_max_age_in_days} days"
  run rm $old_log_files
}

function remove_old_log_files() {
  local dir_list=$(get_log_file_dir_list)

  for el in $dir_list; do
    remove_old_logs_if_exist $el
  done
}
