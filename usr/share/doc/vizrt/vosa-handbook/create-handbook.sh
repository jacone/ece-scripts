#! /usr/bin/env bash

# by tkj@vizrt.com

handbook_org=vosa-handbook.org
target_dir=target

$(which blockdiag >/dev/null) || {
  cat <<EOF
You must have blockdiag installed. On Debian & Ubuntu the package is
called python-blockdiag
EOF
  exit 1
}

function generate_png_from_blockdiag() {
  cp -r graphics $target_dir
  
  for el in $target_dir/graphics/*.blockdiag; do
    echo "Generating PNG of $el ..."
    blockdiag $el
  done
}

function set_customer_specific_variables() {
  local conf_file=$(basename $0 .sh).conf
  if [ -r $conf_file  ]; then
    source $conf_file
  else
    return
  fi

  customer_filter_map="
    my-build-server~${trail_builder_host}
    my-build-user~${trail_builder_user}
    my-control-server~${trail_control_host}
    my-db~${trail_db_schema}
    my-editorial-server~${trail_editor_host}
    my-import-server~${trail_import_host}
    my-import-server~${trail_import_host}
    my-monitoring-server~${trail_monitoring_host}
    my-nfs-server~${trail_nfs_server_host}
    my-presentation-server~${trail_presentation_host}
    my-stats-server~${trail_analysis_host}
    my-webapp~${trail_website_name}
    my-website~${trail_website_name}
  "

  for el in $customer_filter_map; do
    local old_ifs=$IFS
    IFS='~'
    read from to <<< "$el"
    IFS=$old_ifs
    find $target_dir -name "*.org" | while read f; do
      sed -i "s~${from}~${to}~g" ${f}
    done
  done
}

function set_up_build_directory() {
  mkdir -p $target_dir
  cp *.org $target_dir
}

set_up_build_directory
generate_png_from_blockdiag
set_customer_specific_variables

# use emacs to generate HTML from the ORG files
echo "Generating new handbook HTML from ORG ..." 
emacs \
  --load vizrt-branding-org-mode.el \
  --batch --visit $target_dir/$handbook_org \
  --funcall org-export-as-html-batch 2> /dev/null || {
  cat <<EOF
Failed running the org export through Emacs.
EOF
}

echo "$target_dir/$(basename $handbook_org .org).html is now ready"



