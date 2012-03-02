# parameters:
# $1 - what kind of webserver. Available options are:
#      * 0 - cache server
#      * 1 - monitoring server
#      * 2 - both cache & monitoring server
function install_web_server()
{
  print_and_log "Installing a web server on $HOSTNAME ..."

  if [ $on_debian_or_derivative -eq 1 ]; then
    packages="nginx"
    install_packages_if_missing $packages
  else
    debug "Web server installation not supported on your system."
    return
  fi
  
  file=/etc/nginx/sites-available/default
    # in some very unusual cases, this file will not exist (can occur
    # when re-running ece-install several times).
  if [ -e $file ]; then
    run mv $file $file.orig
  fi

  if [ $1 -eq 0 ]; then
    port=81
    cat > $file <<EOF
server {
  listen ${port} default;
  access_log  /var/log/nginx/localhost.access.log;

  # Typical endpoint for Adactus/Mobilize to get the videos to
  # transcode.
  location /binary {
    root $escenic_data_dir;
    index index.html;
  }
}
EOF
  elif [ $1 -eq 1 ]; then
    port=80
    cat > $file <<EOF
server {
  listen ${port} default;
  access_log  /var/log/nginx/localhost.access.log;

  location / {
    root /var/cache/munin/www;
    index index.html;
  }
}
EOF
  elif [ $1 -eq 3 ]; then
    port=81
    cat > $file <<EOF
server {
  listen ${port} default;
  access_log  /var/log/nginx/localhost.access.log;

  location / {
    root /var/cache/munin/www;
    index index.html;
  }

  # Typical endpoint for Adactus/Mobilize to get the videos to
  # transcode.
  location /binary {
    root $escenic_data_dir;
    index index.html;
  }
}
EOF
  fi
  
  run /etc/init.d/nginx restart

  if [ $1 -eq 0 ]; then
    add_next_step "http://${HOSTNAME}:${port}/binary gives the Adactus endpoint"
  elif [ $1 -eq 1 ]; then
    add_next_step "http://${HOSTNAME}:${port}/ gives the Munin interface"
  elif [ $1 -eq 2 ]; then
    add_next_step "http://${HOSTNAME}:${port}/       gives the Munin interface"
    add_next_step "http://${HOSTNAME}:${port}/binary gives the Adactus endpoint"
  fi
}
