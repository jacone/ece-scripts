#! /usr/bin/env bash

# by tkj@vizrt.com

handbook_org=vosa-handbook.org
target_dir=/tmp/$(basename $0 .sh)-$(date --iso)

$(which blockdiag >/dev/null) || {
  cat <<EOF
You must have blockdiag installed. On Debian & Ubuntu the package is
called python-blockdiag
EOF
  exit 1
}

function run() {
  "$@"
  if [ $? -ne 0 ]; then
    echo "Command [ $@ ] FAILED :-("
    exit 1
  fi
}

function generate_svg_from_blockdiag() {
  run cp -r graphics $target_dir
  
  for el in $target_dir/graphics/*.blockdiag; do
    echo "Generating SVG of $el ..."
    run blockdiag -T SVG $el
  done
}

function set_customer_specific_variables() {
  local conf_file=$(basename $0 .sh).conf
  if [ -r $conf_file  ]; then
    source $conf_file
    host_name_list_outside_network="
      $host_name_list_outside_network
      ${trail_host_name_list_outside_network}
    "
  else
    echo "No ${conf_file} found, I'm making something up ..."
    trail_presentation_host=pres1
    trail_presentation_host_list=$trail_presentation_host
    trail_db_master_host=db1
    trail_nfs_master_host=nfs1
  fi

  local virtual_host_key_prefix="trail_virtual_host_"
  local first_virtual_host=$(
    set | grep ^${virtual_host_key_prefix} | head -1
  )

  if [ -n $first_virtual_host ]; then
    first_publication=$(
      echo  $first_virtual_host | \
        sed "s#${virtual_host_key_prefix}##" | \
        cut -d'=' -f1
    )
    first_website=$(
      echo  $first_virtual_host | \
        cut -d'=' -f2 | \
        cut -d':' -f1
    )
  fi

  customer_filter_map="
    my-backup-dir~${trail_escenic_backups_dir}
    my-network~$(get_network_name)
    my-build-server~${trail_builder_host-builder}
    my-build-user~${trail_builder_user-buildy}
    my-control-server~${trail_control_host-control}
    my-db-server~${trail_db_master_host-db1}
    my-db~${trail_db_schema-mydb}
    my-editorial-server~${trail_editor_host-edit1}
    my-import-server~${trail_import_host-edit2}
    my-monitoring-server~${trail_monitoring_host-mon}
    my-nfs-server~${trail_nfs_master_host-nfs1}
    my-presentation-server~${trail_presentation_host-pres1}
    my-stats-server~${trail_analysis_host-analysis}
    my-publication~${first_publication}
    my-webapp~${first_publication}
    my-website~${first_website}
  "
  for el in $customer_filter_map; do
    local old_ifs=$IFS
    IFS='~'
    read from to <<< "$el"
    IFS=$old_ifs
    find $target_dir -name "*.org" | while read f; do
      run sed -i "s~${from}~${to}~g" ${f}
    done
  done
}

function set_up_build_directory() {
  run mkdir -p $target_dir/graphics
  run cp *.org $target_dir
}

function get_blockdiag_defs() {
  if [ -n "$trail_db_master_host" ]; then
    echo " " $trail_db_master_host '[shape = "flowchart.database" ];'
  fi
  if [ -n "$trail_db_slave_host" ]; then
    echo " " $trail_db_slave_host '[shape = "flowchart.database" ];'
  fi
  if [ -n "$trail_presentation_host_list" ]; then
    for el in $trail_presentation_host_list; do
      echo " " $el '[color = "orange" ];'
    done
  fi
  if [ -n "$trail_editor_host" ]; then
    echo " " $trail_editor_host '[color = "orange" ];'
  fi
  if [ -n "$trail_import_host" ]; then
    echo " " $trail_import_host '[color = "orange" ];'
  fi
  if [ -n "$trail_analysis_host" ]; then
    echo " " $trail_analysis_host '[color = "yellow" ];'
  fi
  if [ -n "$trail_db_vip_host" ]; then
    echo " " $trail_db_vip_host '[shape = roundedbox];'
  fi
  if [ -n "$trail_nfs_vip_host" ]; then
    echo " " $trail_nfs_vip_host '[shape = roundedbox];'
  fi
  if [ -n "$trail_lb_host" ]; then
    echo " " $trail_lb_host '[shape = roundedbox];'
  fi
}

function get_blockdiag_groups() {
  # serving presentation
  echo "  group {"
  echo "    internet;"
  if [ -n "$trail_lb_host" ]; then
    echo "    $trail_lb_host;"
  fi
  if [ -n "$trail_presentation_host_list" ]; then
    for el in $trail_presentation_host_list; do
      echo "    $el;"
    done
  fi
  if [ -n "$trail_analysis_host" ]; then
    echo "    $trail_analysis_host;"
  fi
  echo '    color = "white";'
  echo "  }"
}

function get_blockdiag_call_flow() {

  # from the internet and to the ECEs
  local lb_call_flow="internet ->"
  if [ -n "$trail_lb_host" ]; then
    lb_call_flow="$lb_call_flow $trail_lb_host ->"
  fi
  for el in $trail_presentation_host_list; do
    lb_call_flow="$lb_call_flow ${el},"
  done
  echo " " ${lb_call_flow} | sed 's/,$/;/g'
  
  if [ -n "$trail_editor_host" ]; then
    echo "  journalist -> $trail_editor_host" \
      '[ label = "writes" ];'
  fi
  if [ -n "$trail_import_host" ]; then
    echo "  xml-feeds -> $trail_import_host" \
      '[ label = "imports" ];'
  fi
  
  # ECEs
  for el in \
    $trail_presentation_host_list \
    $trail_editor_host \
    $trail_import_host; do
    local one_flow="$el ->"

    if [ -n "$trail_db_vip_host" ]; then
      one_flow="${one_flow} $trail_db_vip_host,"
    elif [ -n "$trail_db_master_host" ]; then
      one_flow="${one_flow} $trail_db_master_host,"
    fi
    if [ -n "$trail_nfs_vip_host" ]; then
      one_flow="${one_flow} $trail_nfs_vip_host,"
    elif [ -n "$trail_nfs_master_host" ]; then
      one_flow="${one_flow} $trail_nfs_master_host,"
    fi
    echo " " ${one_flow} | sed 's/,$/;/g'
  done

  for el in $trail_presentation_host_list; do
    if [ -n "$trail_analysis_host" ]; then
      echo "  $el -> $trail_analysis_host;"
    fi
  done
  
  # DB
  if [ -n "$trail_db_vip_host" -a \
    -n "$trail_db_master_host" -a \
    -n "$trail_db_slave_host" ]; then
    echo " " $trail_db_vip_host "->" \
      $trail_db_master_host"," \
      $trail_db_slave_host";"
  fi
  if [ -n "$trail_db_master_host" -a \
    -n "$trail_db_slave_host" ]; then
    echo " " $trail_db_master_host "<->" $trail_db_slave_host \
      '[ label = "syncs" ];'
  fi

  # NFS
  if [ -n "$trail_nfs_vip_host" -a \
    -n "$trail_nfs_master_host" -a \
    -n "$trail_nfs_slave_host" ]; then
    echo " " $trail_nfs_vip_host "->" \
      $trail_nfs_master_host"," \
      $trail_nfs_slave_host";"
  fi
  if [ -n "$trail_nfs_master_host" -a \
    -n "$trail_nfs_slave_host" ]; then
    echo " " $trail_nfs_master_host "<->" $trail_nfs_slave_host \
      '[ label = "syncs" ];'
  fi
}

function generate_architecture_diagram() {
  local file=$target_dir/graphics/architecture.blockdiag
  cat > $file <<EOF
# generated by $(basename $0) @ $(date)
blockdiag {
 orientation = portrait;
 journalist [ shape = "actor" ];

  internet [ shape = "cloud" ];
$(get_blockdiag_defs)

$(get_blockdiag_groups)

$(get_blockdiag_call_flow)
}
EOF
}

function generate_html_from_org() {
# use emacs to generate HTML from the ORG files
  echo "Generating new handbook HTML from ORG ..." 
  run emacs \
    --load vizrt-branding-org-mode.el \
    --batch --visit $target_dir/$handbook_org \
    --funcall org-export-as-html-batch 2> /dev/null
  echo "$target_dir/$(basename $handbook_org .org).html is now ready"
}

function get_network_name() {
  if [ -n "$trail_network_name" ]; then
    echo ".${trail_network_name}"
  else
    echo ""
  fi
}

host_name_list_outside_network="
  amazonaws.com
"

## $1 :; the host (not FQDN)
function get_fqdn() {
  for el in $host_name_list_outside_network; do
    echo "el=$el" >> /tmp/t
    if [ $(echo $1 | grep $el | wc -l) -gt 0 ]; then
      echo "$1"
      return
    fi
  done
  
  echo "${1}$(get_network_name)"
}

## $1 :; the host (not FQDN)
function get_link() {
  echo "http://$(get_fqdn $1)"
}

function get_generated_overview() {
  cat <<EOF
|-------------------------------------------|
| Machine     | Service quick links         |
|-------------------------------------------|
EOF
  if [ -n "${trail_monitoring_host}" ]; then
    cat <<EOF 
| $(get_fqdn $trail_monitoring_host) | \
  [[$(get_link ${trail_monitoring_host}):${trail_monitoring_port-80}/munin/][munin]] \
  [[$(get_link ${trail_monitoring_host}):${trail_monitoring_port-80}/icinga/][icinga]] \
|
EOF
  fi
  
  if [ -n "${trail_control_host}" ]; then
    cat <<EOF 
| $(get_fqdn $trail_control_host) | \
  [[http://$(get_link $trail_control_host):5679][hugin]] \
|
EOF
  fi

  if [ -n "${trail_editor_host}" ]; then
  cat <<EOF 
| $(get_fqdn ${trail_editor_host}) | \
  [[$(get_link ${trail_editor_host}):5678/][system-info]] \
  [[$(get_link ${trail_editor_host}):${trail_editor_port-8080}/escenic-admin/][escenic-admin]] \
  [[$(get_link ${trail_editor_host}):${trail_editor_port-8080}/solr/admin/][solr]] \
  [[$(get_link ${trail_editor_host}):${trail_editor_port-8080}/studio/][studio]] \
  [[$(get_link ${trail_editor_host}):${trail_editor_port-8080}/escenic/][escenic]] \
  [[$(get_link ${trail_editor_host}):${trail_editor_port-8080}/webservice/][webservice]] \
|
EOF
  fi
  
  if [ -n "${trail_import_host}" ]; then
  cat <<EOF 
| $(get_fqdn ${trail_import_host}) | \
  [[$(get_link ${trail_import_host}):5678/][system-info]] \
  [[$(get_link ${trail_import_host}):${trail_import_port}/escenic-admin/][escenic-admin]] \
  [[$(get_link ${trail_import_host}):${trail_import_port}/solr/admin/][solr]] \
  [[$(get_link ${trail_import_host}):${trail_import_port}/studio/][studio]] \
  [[$(get_link ${trail_import_host}):${trail_import_port}/escenic/][escenic]] \
  [[$(get_link ${trail_import_host}):${trail_import_port}/webservice/][webservice]] \
|
EOF
  fi
  
  for el in nop $trail_presentation_host_list; do
    if [[ $el == "nop" ]]; then
      continue
    fi
    cat <<EOF 
| $(get_fqdn ${el}) | \
  [[$(get_link ${el}):5678/][system-info]] \
  [[$(get_link ${el}):8080/escenic-admin/][escenic-admin]] \
  [[$(get_link ${el}):8081/solr/admin/][solr]] \
|
EOF
  done
  
  if [ -n "${trail_analysis_host}" ]; then
    cat <<EOF 
| $(get_fqdn ${trail_analysis_host}) | \
  [[$(get_link ${trail_analysis_host}):5678/][system-info]] \
  [[$(get_link ${trail_analysis_host}):${trail_analysis_port-8080}/analysis-reports/][analysis-reports]] \
  [[$(get_link ${trail_analysis_host}):${trail_analysis_port-8080}/analysis-logger/admin][analysis-logger]] \
  [[$(get_link ${trail_analysis_host}):${trail_analysis_port-8080}/analysis-qs/admin][analysis-qs]] \
|
EOF
  fi
  
  for el in nop $trail_nfs_master_host \
    $trail_nfs_slave_host \
    $trail_db_master_host \
    $trail_db_slave_host; do
    if [[ $el == "nop" ]]; then
      continue
    fi
    cat <<EOF 
| $(get_fqdn ${el}) | \
  [[$(get_link ${el}):5678/][system-info]] \
|
EOF
  done
  cat <<EOF
|-------------------------------------------|
EOF
}

## included from overview.org
function generate_overview_org() {
  local file=$target_dir/generated-overview.org
  cat > $file <<EOF
$(get_generated_overview)
EOF
}

set_up_build_directory
set_customer_specific_variables
generate_architecture_diagram
generate_svg_from_blockdiag
generate_overview_org
generate_html_from_org

