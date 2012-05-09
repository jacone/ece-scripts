assemble_attempts=0

function assemble()
{
  if [ "$assemble_attempts" -gt 1 ]; then
    print "I've tried to assemble twice now and FAILED :-("
    print "You probably have multiple versions of one or more plugins"
    print "Check your plugins directory, sort it out and try again."
    exit 1
  fi
  assemble_attempts=$(( $assemble_attempts + 1 ))
  
  if [[ "$type" != "engine" && "$type" != "search" ]]; then
    print "You cannot assemble instances of type $type"
    exit 1
  fi

  message="Assembling your EAR file"
  print $message "..."
  log $message "..." >> $log

  cd $assemblytool_home && \
    ant -q ear -DskipRedundancyCheck=true \
    1>>$log \
    2>>$log
  exit_on_error "$message"

  # test to see if the new versions of ECE & plugins are upgrades of
  # the previous ones
  duplicates_found=0
  known_unharmful_duplicates="activation- $'\n' ehcache-$'\n' stax-api-$'\n'"
  
  cd $assemblytool_home/dist/.work/ear/lib
  for el in *.jar; do
    jar=$(basename $(echo $el | sed  -e  's/[0-9]//g') .jar | sed 's/\.//g')
    if [ $(echo $known_unharmful_duplicates | grep $jar | wc -l) -gt 0 ]; then
      continue
    fi

    # we check for duplicate JARs like plugin-1.2.3.jar and
    # plugin-1.2.4.jar. We remove plugin-1.2.3-tests.jar out the
    # equations (if it happens to be there).
    if [ $(\ls *.jar | \
      sed -e 's/\.jar//' -e 's/-tests$//g' | \
      grep "^${jar}[0-9]" | \
      sort | \
      uniq | \
      wc -l) -gt 1 ]; then
      duplicates_found=1
      debug "More than one version of $(echo $jar | sed 's/-$//g')"
    fi
  done

  if [ "$duplicates_found" -eq 1 ]; then
    print "Multiple versions of ECE and/or 3rd party libraries found."
    print "Remember, you need to run '$(basename $0) clean assemble' when "
    print "upgrading either ECE or one of the plugins."
    print "I will now clean it up for you and re-run the assembly."
    clean_up
    assemble
  fi
  
  mkdir -p $ear_cache_dir/
  exit_on_error "creating $ear_cache_dir"

  cp $assemblytool_home/dist/engine.ear $cache_dir
  exit_on_error "copying ear to $ear_cache_dir"

  debug $assemblytool_home/dist/engine.ear "is now ready"
}

