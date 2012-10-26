## Common library for downloading XML feeds via FTP and HTTP.

function download_latest_files() {
  if [[ $uri == "ftp://"* ]]; then
    local user_and_password="
      $wget_opts
      --ftp-user $user
      --ftp-password $password
    "
  elif [[ $uri == "http://"* ]]; then
    local user_and_password="
      $wget_opts
      --http-user $user
      --http-password $password
    "
  fi

  # long sed from
  # http://stackoverflow.com/questions/1881237/easiest-way-to-extract-the-urls-from-an-html-page-using-sed-or-awk-only
  local list_of_files=$(
    wget $user_and_password --quiet --output-document - $uri | \
      grep ^'<a href' | \
      sed -e 's/<a /\n<a /g' \
      -e 's/<a .*href=['"'"'"]//' \
      -e 's/["'"'"'].*$//' \
      -e '/^$/ d'
  )

  download_files_if_desired $list_of_files
}

## Will only download files which are newer than max_file_age and
## which haven't been downloaded before.
## 
## $@ :: list of URIs
function download_files_if_desired() {
  for el in $list_of_files; do
    if [ $(is_already_downloaded $uri/$el) -eq 1 ]; then
      print $el has already been downloaded, skipping to the next
      continue
    fi
    print downloading $uri/$el "..."
    download_uri_target_to_dir \
      $uri/$el \
      $raw_spool_base_dir/$publication_name/$job_name/
    echo $uri/$el >> $(get_state_file)
  done
}

function is_already_downloaded() {
  if [ ! -e $(get_state_file) ]; then
    echo 0
    return
  fi

  if [ $(grep "$1" $(get_state_file) | wc -l) -gt 0 ]; then
    echo 1
    return
  fi

  echo 0
}

function get_state_file() {
  echo $raw_state_base_dir/$publication_name/$job_name/download.state
}


