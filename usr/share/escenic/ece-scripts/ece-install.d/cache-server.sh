# ece-install module for installing the cache server

varnish_redhat_rpm_url=http://repo.varnish-cache.org/redhat/varnish-3.0/el5/noarch/varnish-release-3.0-1.noarch.rpm

function install_cache_server()
{
  print_and_log "Installing a caching server on $HOSTNAME ..."

  if [[ $on_debian_or_derivative -eq 1 &&
        $(apt-key list | grep varnish-software.com | wc -l) -eq 0 ]]; then
    curl ${curl_opts} \
      http://repo.varnish-cache.org/debian/GPG-key.txt \
      2>> $log | \
      apt-key add - \
      1>>$log 2>>$log
    run apt-get update
    
    code_name=$(lsb_release -s -c)
    supported_code_name=0
    
    # list taken from http://repo.varnish-cache.org/debian/dists/
    supported_list="lenny squeeze hardy lucid"
    for el in $supported_list; do
      if [ $code_name = $el ]; then
        supported_code_name=1
      fi
    done
    
    if [ $supported_code_name -eq 1 -a $on_debian -eq 1 ]; then
      add_apt_source "deb http://repo.varnish-cache.org/debian/ $(lsb_release -s -c) varnish-3.0"
    elif [ $supported_code_name -eq 1 -a $on_ubuntu -eq 1 ]; then
      add_apt_source "deb http://repo.varnish-cache.org/ubuntu/ $(lsb_release -s -c) varnish-3.0"
    fi
    
  elif [[ $on_redhat_or_derivative -eq 1 &&
        $(rpm -qa | grep varnish-release | wc -l) -lt 1 ]]; then
    print "Installing the Varnish repository RPM"
    run rpm --nosignature -i $varnish_redhat_rpm_url
  fi

  install_packages_if_missing varnish
  assert_pre_requisite varnishd

  if [ $fai_enabled -eq 0 ]; then
    print "You must now list your backend servers."
    print "These must be host names (not IPs) and must all be resolvable"
    print "by your cache host ($HOSTNAME), preferably from /etc/hosts"
    print "Seperate the entries with a space. e.g.: app1:8080 app2:8080."
    print "Press ENTER to accept the default: ${HOSTNAME}:${appserver_port}"
    echo -n "Your choice [${HOSTNAME}:${appserver_port}]> "
    read backend_servers
  else
    backend_servers=${fai_cache_backends}
  fi

  if [ -z "$backend_servers" ]; then
    backend_servers="localhost:${appserver_port}"
  fi

  set_up_varnish $backend_servers

  add_next_step "Cache server is up and running at http://${HOSTNAME}:80/"
}

function set_up_varnish()
{
  print_and_log "Setting up Varnish to match your environment ..."
  run /etc/init.d/varnish stop

    # we need to swap standard err and standard out here as varnishd
    # -V for some reason writes to standard error.
  using_varnish_3=$(varnishd -V 3>&1 1>&2 2>&3 | grep varnish-3 | wc -l)
  
  local file=/etc/default/varnish
  if [ $on_redhat_or_derivative -eq 1 ]; then
    file=/etc/sysconfig/varnish
  fi
  
  sed -i -e 's/6081/80/g' -e 's/^START=no$/START=yes/' $file
  exit_on_error "sed on $file"

  cat > /etc/varnish/default.vcl <<EOF
/* Varnish configuration for Escenic Content Engine              -*- java -*- */

/* IPs that are allowed to access the administrative pages/webapps. */
acl staff {
  "localhost";
EOF
  for l in $(get_privileged_hosts); do
    cat >> /etc/varnish/default.vcl <<EOF
  # Privileged host (either doing the ece-install or listed as such)
  "${l}";
EOF
  done
  
  cat >> /etc/varnish/default.vcl <<EOF
}

/* The IP of the Adactus/Mobilize server */
acl adactus {
  "203.33.232.216";
}

/* Our web server for serving static content */
backend static {
  .host = "localhost";
  .port = "81";
}

EOF
  local i=0
  for el in $backend_servers; do
    appserver_id=$(echo $el | cut -d':' -f1 | sed 's/-/_/g')
    appserver_host=$(echo $el | cut -d':' -f1)
    appserver_port=$(echo $el | cut -d':' -f2)

    cat >> /etc/varnish/default.vcl <<EOF
backend ${appserver_id}${i} {
  .host = "$appserver_host";
  .port = "$appserver_port";
}

EOF
    i=$(( $i+1 ))
  done

  cat >> /etc/varnish/default.vcl <<EOF
/* The client director gives us session stickiness based on client
 * IP. */
director webdirector client {
EOF

  i=0
  for el in $backend_servers; do
	  appserver_id=$(echo $el | cut -d':' -f1 | sed 's/-/_/g')        
    cat >> /etc/varnish/default.vcl <<EOF
  {
     .backend = ${appserver_id}${i};
     .weight = 1;
  }
EOF
    i=$(( $i+1 ))
  done

  cat >> /etc/varnish/default.vcl <<EOF
}

sub vcl_recv {
  if (!client.ip ~ staff &&
      (req.url ~ "^/escenic" ||
       req.url ~ "^/studio" ||
       req.url ~ "^/munin" ||
       req.url ~ "^/webservice" ||
       req.url ~ "^/escenic-admin")) {
     error 405 "Not allowed.";
  }

  /* Only Adactus/Mobilize is allowed to access the /binary context
   * which contains all the full quality video files. */
  if (!client.ip ~ adactus && req.url ~ "^/binary") {
    error 405 "Not allowed.";
  }

  if (req.url ~ "^/munin") {
    set req.url = regsub(req.url, "^/munin", "/");
    set req.backend = static;
  }
  else {
    set req.backend = webdirector;
  }

  if (req.url ~ "\.(png|gif|jpg|css|js)$" || req.url == "/favicon.ico") { 
    remove req.http.Cookie;
  }
}

 /* Called when content is fetched from the backend. */
sub vcl_fetch {
  /* Remove cookies from these resource types and cache them for a
   * long time */
  if (req.url ~ "\.(png|gif|jpg|css|js)$" || req.url == "/favicon.ico") { 
    set beresp.ttl = 5h;
    remove beresp.http.Set-Cookie;
  }
}

sub vcl_deliver {
  /* Adds debug header to the result so that we can easily see if a
   * URL has been fetched from cache or not.
   */
  if (obj.hits > 0) {
EOF
  if [ $using_varnish_3 -gt 0 ]; then
    cat >> /etc/varnish/default.vcl <<EOF
    set resp.http.X-Cache = "HIT #" + obj.hits;
EOF
  else
    cat >> /etc/varnish/default.vcl <<EOF
    set resp.http.X-Cache = "HIT #" obj.hits;
EOF
  fi
  
  cat >> /etc/varnish/default.vcl <<EOF
  }
  else {
    set resp.http.X-Cache = "MISS";
  }

  set resp.http.X-Cache-Backend = req.backend;
}
EOF
  run /etc/init.d/varnish start
}
