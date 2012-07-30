function run_assembly_tool() {
  run cd $assemblytool_home 
  run ant -q ear -DskipRedundancyCheck=true
}

# the JARs are known to share code between them (!)
jar_white_list="xmlParserAPIs|commons-beanutils|jaxen|xom|xml-apis|relaxngDatatype"

function warn_about_duplicate_jars() {
  local a_class_list=""
  for el in $assemblytool_home/dist/.work/ear/lib/*.jar; do
    local a_class=$(unzip -t $el | \
      grep class | \
      grep -v "No errors" | \
      cut -d':' -f2 | \
      sed 's/^[ ]//g' | \
      cut -d' ' -f1 | \
      sort -r | \
      head -1)
    a_class_list="${a_class}\n${a_class_list}"
  done

  for el in $(echo -e "$a_class_list" | sort | uniq); do
    local a_class_count=$(
      grep $el $assemblytool_home/dist/.work/ear/lib/*.jar | \
        egrep -v "$jar_white_list" | \
        wc -l
    )
    
    if [ $a_class_count -gt 1 ]; then
      print_and_log $(yellow WARNING) "These JARs contain (at least some) of the same files:"
      grep $el $assemblytool_home/dist/.work/ear/lib/*.jar | \
        egrep -v "$jar_white_list" | \
        cut -d' ' -f3 | while read f; do
        local file=$(basename $f)
        for ele in $(find -L \
          $assemblytool_home/plugins \
          $ece_home/lib \
          -name $file | \
          egrep -v "WEB-INF|test"); do
          print_and_log "-" $ele
        done
      done
    fi
  done
}

function assemble() {
  if [[ "$type" != "engine" && "$type" != "search" ]]; then
    print "You cannot assemble instances of type $type"
    exit 1
  fi

  print_and_log "Assembling your EAR file..."
  run_assembly_tool

  warn_about_duplicate_jars
  
  mkdir -p $ear_cache_dir/
  exit_on_error "creating $ear_cache_dir"

  run cp $assemblytool_home/dist/engine.ear $cache_dir
  exit_on_error "copying ear to $ear_cache_dir"

  debug $assemblytool_home/dist/engine.ear "is now ready"
}

