default_java_version=1.6
sun_java_bin_url=http://download.oracle.com/otn-pub/java/jdk/6u39-b04/jdk-6u39-linux-i586.bin
if [[ $(uname -m) == "x86_64" ]]; then
  sun_java_bin_url=http://download.oracle.com/otn-pub/java/jdk/6u39-b04/jdk-6u39-linux-x64.bin
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
  
  print_and_log "Downloading Sun Java from download.oracle.com ..."
  run cd $download_dir
  local file_name=$(basename $sun_java_bin_url)
  run wget --no-cookies --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com" -O $file_name $wget_opts $sun_java_bin_url

  # calculating start and stop offset from where to extract the zip
  # from the java data blob. calculation taken from
  # git://github.com/rraptorr/sun-java6.git
  local tmp_jdk=jdk-tmp.zip
  local binsize=$(wc -c $file_name | awk '{print $1}');
  local zipstart=$(unzip -ql $file_name 2>&1 >/dev/null | \
      sed -n -e 's/.* \([0-9][0-9]*\) extra bytes.*/\1/p');
  tail -c $(expr $binsize - $zipstart) $file_name > $tmp_jdk
  
  run cd /opt
  run unzip -q -o $download_dir/$tmp_jdk
  local latest_jdk=$(find . -maxdepth 1 -type d -name "jdk*" | sort -r | head -1)
  run rm -f /opt/jdk
  run ln -s $latest_jdk jdk

  # generate jar files from the .pack files
  for el in $(find /opt/jdk/ -name "*.pack"); do
    file_name=$(basename $el .pack)
    local dir=$(dirname $el)
    run /opt/jdk/bin/unpack200 $el $dir/$file_name.jar
  done

  # update RedHat's alternatives system to use Sun Java as its
  # default.
  for el in java javac jar; do
    if [ ! -e /usr/bin/$el ]; then
      ln -s /usr/bin/$el /etc/alternatives/$el
    fi
    # doesn't seem to like running inside the run wrapper
    alternatives --set $el /opt/jdk/bin/$el 1>>$log 2>>$log
  done

  # setting java_home to the newly installed location
  java_home=/opt/jdk
  
  local version=$(java -version 2>&1 | grep version | cut -d'"' -f2)
  print_and_log "Sun Java $version is now installed in /opt/jdk"

  add_next_step "By using Sun Java, you must accept this license: " \
    "http://www.oracle.com/technetwork/java/javase/terms/license/"
}



