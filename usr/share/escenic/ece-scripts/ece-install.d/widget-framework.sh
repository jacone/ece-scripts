function install_widget_framework()
{
  print_and_log "Installing Widget Framework on $HOSTNAME ..."
  # TODO java.lang.NoClassDefFoundError:
  # Lcom/escenic/framework/captcha/ReCaptchaConfig;
  
  local wf_user=$(get_conf_value wf_user)
  local wf_password=$(get_conf_value wf_password)

  print_and_log "Creating a Maven settings file: $HOME/.m2/settings.xml ..."
  make_dir $HOME/.m2
  cat > $HOME/.m2/settings.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/settings/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                              http://maven.apache.org/xsd/settings-1.0.0.xsd">
  <servers>
    <server>
      <id>escenic-repo</id>
      <username>${wf_user}</username>
      <password>${wf_password}</password>
    </server>
  </servers>

  <profiles>
    <profile>
      <id>escenic-profile</id>
      <repositories>
        <repository>
          <id>escenic-repo</id>
          <name>Repository for EWF libraries</name>
          <url>http://repo.escenic.com/</url>
          <layout>default</layout>
        </repository>
      </repositories>
    </profile>
  </profiles>

  <activeProfiles>
    <activeProfile>escenic-profile</activeProfile>
  </activeProfiles>
</settings>
EOF

  print_and_log "Downloading Widget Framework from technet.escenic.com ..."
  for el in $wf_download_list; do
    cd $download_dir
    run wget $wget_opts \
      --http-user $technet_user \
      --http-password $technet_password \
      $el
    run cd $escenic_root_dir/
    run unzip -q -u $download_dir/$(basename $el)
  done

  install_packages_if_missing "maven2"
  assert_pre_requisite mvn

  export JAVA_HOME=$java_home
  wf_maven_dir=$(echo $escenic_root_dir/widget-framework-core-*/maven)
  run cd $wf_maven_dir

  print_and_log "Installing Widget Framework into your Maven repository ..."
  log "JAVA_HOME=$JAVA_HOME"

  run mvn $maven_opts install

    # installing the widget-framework-common as a ECE plugin
  wf_dist_dir=$(echo $wf_maven_dir/widget-framework-common/target/widget-framework-common-*-dist/widget-framework-common-*)
  cd $escenic_root_dir/assemblytool/plugins
  if [ ! -h $(basename $wf_dist_dir) ]; then
    ln -s $wf_dist_dir
  fi

  cp -r $wf_dist_dir/misc/siteconfig/* $common_nursery_dir/

  add_next_step "Widget Framework has been installed into your " \
    " Maven repo"
}
