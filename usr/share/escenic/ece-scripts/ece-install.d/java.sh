default_java_version=1.6
sun_java_bin_url=http://download.oracle.com/otn-pub/java/jdk/6u39-b04/jdk-6u39-linux-i586.bin
if [[ $(uname -m) == "x86_64" ]]; then
  sun_java_bin_url=http://download.oracle.com/otn-pub/java/jdk/8u121-b13/e9e7ea248e2c4826b92b3f075a80e441/jdk-8u121-linux-x64.rpm
fi
  
# Install oracle java from webupd8
# http://www.webupd8.org/2012/01/install-oracle-java-jdk-7-in-ubuntu-via.html
function install_oracle_java(){
  # First get the java version
  server_java_version=${fai_server_java_version-${default_java_version}}
  debian_package_name=""

  if [ $server_java_version = "1.6" ]; then
    debian_package_name="oracle-java6-installer"
    java_home="/usr/lib/jvm/java-6-oracle"
  elif [ $server_java_version = "1.7" ]; then
    debian_package_name="oracle-java7-installer"
    java_home="/usr/lib/jvm/java-7-oracle"
  #elif [ $server_java_version = "1.8" ]; then
  #  debian_package_name="oracle-java8-installer"
  #  java_home="/usr/lib/jvm/java-8-oracle"
  else
    # Error: Invalid java version
    print_and_log "Unsupported Java version. Cannot proceed. Exiting ...."
    return 0
  fi

  install_packages_if_missing python-software-properties software-properties-common
  run add-apt-repository -y ppa:webupd8team/java
  run apt-get update
  echo "$debian_package_name shared/accepted-oracle-license-v1-1 boolean true" | debconf-set-selections
  install_packages_if_missing $debian_package_name
}

function install_sun_java_on_redhat() {
  if [[ $(${java_home}/bin/java -version 2>&1 | \
    grep HotSpot | wc -l) -gt 0 ]]; then
    print_and_log "Sun Java is already installed on $HOSTNAME"
    return
  fi
  
  print_and_log "Downloading Oracle Java from download.oracle.com ..."
  local file_name=${download_dir}/${sun_java_bin_url##*/}
  run wget \
      --no-cookies \
      --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com ; oraclelicense=accept-securebackup-cookie" \
      -O $file_name \
      $wget_opts \
      $sun_java_bin_url

  run rpm -Uvh "${file_name}"

  local version=$(java -version 2>&1 | grep version | cut -d'"' -f2)
  print_and_log "Oracle Java $version is now installed"

  add_next_step "By using Oracle Java, you must accept this license: " \
    "http://www.oracle.com/technetwork/java/javase/terms/license/"
}



