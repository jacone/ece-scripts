function run_ece_top() {
  set_type_port
  watch curl -s http://localhost:${port}/escenic-admin/top
}
