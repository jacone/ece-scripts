# ece-install module for installing EAE

function install_analysis_server()
{
  run_hook install_analysis_server.preinst
  
  print_and_log "Installing an analysis server on $HOSTNAME ..."
  type=analysis
  
  install_ece_instance "analysis1"

  run cp ${escenic_root_dir}/analysis-engine-*/wars/*.war \
    ${tomcat_base}/webapps

  if [ -n "${fai_analysis_host}" ]; then
    appserver_host=${fai_analysis_host}
  fi
  if [ -n "${fai_analysis_port}" ]; then
    appserver_port=${fai_analysis_port}
  fi
  
    # deploy the EAE WARs
  run cp ${escenic_root_dir}/analysis-engine-*/wars/*.war \
    ${tomcat_base}/webapps

  set_correct_permissions
  
  local ece_command="ece -i ${instance_name} -t ${type} start"
  su - $ece_user -c "$ece_command" 1>>$log 2>>$log
  exit_on_error "su - $ece_user -c \"$ece_command\""

  local seconds=15
  print_and_log "Waiting ${seconds} seconds for EAE to come up ..."
  sleep $seconds
  
  # EAE cannot handle .cfg files with quotes values (!)
  dont_quote_conf_values=1
  
  print_and_log "Configuring EAE Reports ..."
  local file=${tomcat_base}/webapps/analysis-reports/WEB-INF/config/reports.cfg
  set_conf_file_value queryServiceUrl \
    http://${appserver_host}:${appserver_port}/analysis-qs/QueryService \
    ${file}

  print_and_log "Configuring EAE Logger ..."
  local file=${tomcat_base}/webapps/analysis-logger/WEB-INF/config/logger.cfg
  set_conf_file_value databaseQueueManager.reinsertcount \
    6 \
    ${file}
  set_conf_file_value pageview.maintenance.cron.expr '0 0 4 * * ? *' $file
  set_conf_file_value pageview.aggr.hour.cron.expr '0 10 * * * ?' $file
  set_conf_file_value imageResponse false $file
  set_conf_file_value pageview.maintenance.older.than.months 6 $file
  set_conf_file_value pageview.aggr.day.older.than.days 7 $file
  set_conf_file_value pageview.aggr.day.cron.expr '0 0 5 * * ? *' $file
  set_conf_file_value pageview.aggr.hour.older.than.hours 2 $file
  set_conf_file_value pageview.maintenance.older.than.days 0 $file

    # important to turn this off here, it's only for the EAE .cfg
    # files, see above.
  dont_quote_conf_values=0

    # touching web.xml to trigger a re-deploy of the EAE Reports
    # application.
  run touch ${tomcat_base}/webapps/analysis-reports/WEB-INF/web.xml
  run_hook install_analysis_server.postinst
}
