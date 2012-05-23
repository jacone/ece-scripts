function clean_up() {
  if [ "$type" == "engine" ]; then
    print "Cleaning up generated files in $assemblytool_home ..." 
    run cd $assemblytool_home
    run ant clean
  fi

  if [ -d /var/cache/escenic ]; then
    print "Cleaning up ear, deb and rpm files in /var/cache/escenic ..." 
    run rm -rf /var/cache/escenic/*.{rpm,deb,ear}
  fi
}
