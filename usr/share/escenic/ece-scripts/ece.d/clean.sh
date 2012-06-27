function clean_up() {
  if [[ "$type" == "engine" && -d $assemblytool_home ]]; then
    print "Cleaning up generated files in $assemblytool_home ..." 
    run cd $assemblytool_home
    run ant clean
  fi

  if [ -d /var/cache/escenic ]; then
    print "Cleaning up ear, deb and rpm files in /var/cache/escenic ..." 
    run rm -rf /var/cache/escenic/*.{rpm,deb,ear}
  fi

  if [[ $appserver == "tomcat" ]]; then
    local dir_list="
    $tomcat_base/work
    $tomcat_base/temp
    "
    for el in $dir_list; do
      if [ -d $el ]; then
        print "Cleaning up ${instance}'s $(basename $el) directory in $el ..."
        run rm -rf $el/*
      fi
    done
  fi
}
