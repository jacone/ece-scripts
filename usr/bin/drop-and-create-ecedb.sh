#! /usr/bin/env bash

#         version: $Revision: #9 $ $Date: 2011/01/27 $
# last updated by: $Author: torstein $
# 
# Script that will drop and re-create an ECE database, running
# all ECE and ECE plugins SQL scripts in the correct order.
#
# Currently, the script supports the following DBs:
#   * Oracle (when prompted by SQLPlus for io_owner, enter your $user,
#     for io_tablespace enter your $tablespace_data and for index
#     table space your $tablespace_index).
#   * MySQL
#
# Enjoy!
#
# -torstein@escenic.com

drop_db_first=0
user=ece5user
password=ece5password
db=ece5db
host=localhost
ece_home=/opt/escenic/engine
dbproduct=mysql
id="[`basename $0`]"

# oracle specific settings
create_oracle_user=0
tablespace_data=ece5_data
tablespace_index=ece5_index
oracle_data_dir=/home/oracle/app/oracle/oradata/orcl

function create_oracle_ece_user() {
    sqlplus /nolog << EOF
      connect /as sysdba;
      create user $user
        identified by $password
        default tablespace $tablespace_data
        quota unlimited on $tablespace_data;
      grant connect to $user;
      grant resource to $user;
      grant create any view to $user;
      grant execute on ctx_ddl to $user;
EOF
}

function run_db_scripts()
{
    for el in $db_fn_list; do
        file=$1/$el.sql
        echo $id "running $file ..."
        if [ -e $1/$el.sql ]; then
            if [ $dbproduct = "oracle" ]; then
                sqlplus $user/$password @$file
            else
                mysql -u $user -p$password -h $host $db < $file
            fi
        fi
    done
}

if [ $create_oracle_user -eq 1 ]; then
    create_oracle_ece_user
fi

if [ $drop_db_first -eq 1 ]; then
    echo $id "dropping and re-creating $db on $host ..."
    if [ $dbproduct = "mysql" ]; then
        mysql -h $host << EOF
          drop database $db;
EOF
    else
        sqlplus /nolog << EOF
          connect /as sysdba;
          drop tablespace $tablespace_data including contents;
          drop tablespace $tablespace_index including contents;
EOF
    fi
fi

# we first create the DB (or, if drop_db_first is 1, we've just
# dropped it above) before running the SQL scripts.
if [ $dbproduct = "mysql" ]; then
    mysql -h $host << EOF
        create database $db character set utf8 collate utf8_general_ci;
        grant all on $db.* to $user@'%' identified by '$password';
        grant all on $db.* to $user@'localhost' identified by '$password';
EOF
else
    sqlplus /nolog << EOF
        connect /as sysdba;
          
        create tablespace $tablespace_data 
        datafile '$oracle_data_dir/${tablespace_data}01.dbf'
        size 200M reuse
        autoextend on next 50M maxsize 2047M
        extent management local autoallocate;

        create tablespace $tablespace_index
        datafile '$oracle_data_dir/${tablespace_index}01.dbf'
        size 100M reuse
        autoextend on next 50M maxsize 2047M
        extent management local autoallocate;          
EOF
fi


db_fn_list="
tables
tables-stats
views
constants
constants-stats
constraints
indexes
history
"

run_db_scripts $ece_home/database/$dbproduct

for el in `find -L $ece_home/plugins -name $dbproduct`; do
    run_db_scripts $el
done

echo "${id} ${dbproduct}://${host}/${db} is now ready for ${user}/${password}"
