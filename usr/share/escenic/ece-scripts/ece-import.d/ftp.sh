## Common library for downloading XML feeds via FTP.
##
## Example usage, e.g. /etc/cron.hourly/my-import
##   ===================================================================
##   # You must change these  
##   download_dir=/var/spool/escenic/import/mypub/afeed
##   ftp_password="foo"
##   ftp_url=ftp://myfeed.com/afeed
##   ftp_user="myuser"
##
##   # You can leave these at the defaults values in most cases 
##   ftp_download_history=/var/lib/escenic/ftp-history-cron.$(basename $0 .sh)
##   lock_file=/var/lock/escenic/$(basename $0 .sh).lock
##   log=/var/log/escenic/cron.$(basename $0 .sh).log
##   max_file_age_in_hours=10
##   now=$(date +%s)
##
##   # Finally, you need these two lines to do the actual import.
##   download_latest_ftp_files
##   fix_ownership_of_download_files
##   ===================================================================

function create_parent_dir_if_it_does_not_exists() {
  local dir=$(dirname $1)
  if [ ! -d $dir ]; then
    mkdir -p $dir
  fi
}

function fix_ownership_of_download_files() {
  if [ -d $download_dir ]; then
    run chown -R escenic:escenic $download_dir/
  fi

  for el in archive error; do
    local dir=$(dirname $download_dir)/$el
    
    if [ -e $dir ]; then
      chown -R escenic:escenic $dir/
    fi
  done
}

function update_ftp_download_history() {
  if [ -z $ftp_download_history ]; then
    print_and_log "You must set ftp_download_history in your configuration"
    return
  fi

  create_parent_dir_if_it_does_not_exists $ftp_download_history
  echo $(date) $1 >> $ftp_download_history
}

function download_latest_ftp_files() {
  wget -q --ftp-user "$ftp_user" --ftp-password "$ftp_password" $ftp_url -O - | \
    grep .xml | \
    sed -e 's/^[ ]*//g' -e 's/<a\ href=\"\(.*.xml\)\">.*/\1/g' | while read f; do
    # remove everything before ftp:, that's the file URL
    local file=$(echo "$f" | sed 's/.*\(ftp:.*\)/\1/g')
    local date_string=$(
      echo "$f" | \
        cut -d' ' -f1-4 | \
        sed \
        -e 's/ Jan /-01-/g' \
        -e 's/ Feb /-02-/g' \
        -e 's/ Mar /-03-/g' \
        -e 's/ Apr /-04-/g' \
        -e 's/ May /-05-/g' \
        -e 's/ Jun /-06-/g' \
        -e 's/ Jul /-07-/g' \
        -e 's/ Aug /-08-/g' \
        -e 's/ Sep /-09-/g' \
        -e 's/ Oct /-10-/g' \
        -e 's/ Nov /-11-/g' \
        -e 's/ Dec /-12-/g'
    );
    local file_date=$(date --date="$date_string" +%s)
    local age=$(( ${now} - ${file_date} ))
    local age_in_hours=$(( age / ( 60 * 60 ) ))
    
    if [ $age_in_hours -le $max_file_age_in_hours ]; then
      if [ $(grep $file $ftp_download_history | wc -l) -gt 0 ]; then
        print_and_log "Already downloaded $file, skipping it"
        continue
      fi
      
      print_and_log "Downloading ${file} which is $age_in_hours hours old" \
        "($date_string)"
      
      download_uri_target_to_dir $file $download_dir
      update_ftp_download_history $file
    fi
  done
}

