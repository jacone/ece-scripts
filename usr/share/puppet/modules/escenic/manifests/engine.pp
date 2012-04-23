$default_engine_type = "pres"
$default_pres_search_host = "search-pres"
$default_edit_search_host = "edit-pres"

define escenic::engine(
  $type = $default_engine_type,
  $search_host = "")
{
  if ($search_host == "") {
    if ($type == "editor") {
      $real_search_host = $default_edit_search_host
     }
     else {
       if ($type == "presentation") {
         $real_search_host = $default_pres_search_host
       }
       else {
         fail("You specified an invalid type=$type")
       }
     }  
  }   
  else {
    $real_search_host = $search_host
  }
   
  $common_content="                                                                                                     fai_enabled=1                                                                                                         fai_${type}_install=1                                                                                                 fai_${type}_search_host=${real_search_host}                                                                           fai_${type}_db_host=$db_host                                                                                            "
  $editor_content="                                                                                                     # editor specific                                                                                                                "
   
  file { "/root/ece-install-$name.conf":
    content =>  $type ? {
      editor => "$common_content $editor_content",
      default => "# you specific a non existant profile: $type"
    }
  }  
}
