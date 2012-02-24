function get_deploy_white_list()
{
    local white_list="escenic-admin"
    
    if [ $install_profile_number -eq $PROFILE_PRESENTATION_SERVER \
        -a -n "${publication_name}" ]; then
        white_list="${white_list} ${publication_name} "
    elif [ $install_profile_number -eq $PROFILE_SEARCH_SERVER ]; then 
        white_list="${white_list} solr indexer-webapp"
    elif [ $install_profile_number -eq $PROFILE_PRESENTATION_SERVER ]; then
        white_list="${white_list} "$(get_publication_short_name_list)
    elif [ $install_profile_number -eq $PROFILE_EDITORIAL_SERVER ]; then
        white_list="${white_list} escenic studio indexer-webservice"
        white_list="${white_list} "$(get_publication_short_name_list)
    fi

    echo ${white_list}
}

function get_publication_short_name_list()
{
    local short_name_list=""
    
    local publication_def_dir=${escenic_root_dir}/assemblytool/publications
    if [ $(ls ${publication_def_dir} | grep .properties$ | wc -l) -eq 0 ]; then
        echo ${short_name_list}
        return
    fi

    for el in $(find ${publication_def_dir} -maxdepth 1 -name "*.properties"); do
        local short_name=$(basename $el .properties)
        short_name_list="${short_name_list} ${short_name}"
    done

    echo ${short_name_list}
}



