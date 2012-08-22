function clean_up() {
  if [[ "$type" == "engine" && -e "$assemblytool_home/build.xml" ]]; then
    print "Cleaning up generated files in $assemblytool_home ..." 
    run cd $assemblytool_home
    run ant clean
  fi

  if [ -d "${cache_dir}" ]; then
    print "Cleaning up ear, deb and rpm files in ${cache_dir} ..." 
    run rm -rf ${cache_dir}/*.{rpm,deb,ear}
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
