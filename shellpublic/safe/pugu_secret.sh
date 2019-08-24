#!/bin/sh
# secret shell script for pugu
# author:dengyu

SHELLPUBLIC=/home/pugu/shellpublic

case ${action} in
    updateme)
        new_script=${SHELLPUBLIC}/safe/
        sh -e ${new_script} >/dev/null
        if [ $? -ne 0 ];then
            echo "sth wrong in ${new_script}"
            exit 1
        fi
        ;;
    publish)
        ;;
    temporary_login)
        # TODO: 临时登录, 发推送给老板确认
        ;;
    
esac
