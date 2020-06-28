#!/bin/bash
set +x
. /etc/profile 2>/dev/null

log_path="$1"
UPLOAD_SERVER_CONFIG_PATH="/opt/gaussdb/ha/tools/backupAndRestore/Upload_Server.cfg"

main(){
    if [[ -f "${log_path}" ]]; then
        result=$(tail -n 3 ${log_path})

        str_failed="failed"
        str_success="success"
        str_local_backup_success="Backup successfully"
        failed_result=`echo ${result} | grep ${str_failed}`
        success_result=`echo ${result} | grep ${str_success}`
        local_backup_result=`echo ${result} | grep "${str_local_backup_success}"`

        server_ip=`grep "FTP_SERVER_IP" ${UPLOAD_SERVER_CONFIG_PATH}`
        server_port=`grep "FTP_SERVER_PORT" ${UPLOAD_SERVER_CONFIG_PATH}`
        server_user=`grep "FTP_SERVER_USER" ${UPLOAD_SERVER_CONFIG_PATH}`
        server_password=`grep "FTP_SERVER_PASSWD" ${UPLOAD_SERVER_CONFIG_PATH}`
        server_path=`grep "FTP_SERVER_FILEPATH" ${UPLOAD_SERVER_CONFIG_PATH}`

        server_ip_value=`echo ${server_ip#FTP_SERVER_IP:}`
        server_port_value=`echo ${server_ip#FTP_SERVER_PORT:}`
        server_user_value=`echo ${server_ip#FTP_SERVER_USER:}`
        server_password_value=`echo ${server_ip#FTP_SERVER_PASSWD:}`
        server_path_value=`echo ${server_ip#FTP_SERVER_FILEPATH:}`

        # 如果远端服务器IP为空或者127.0.0.1，则本地备份成功则表示成功，否则需要成功上传远端备份服务器才算成功。
        if [[ -z "$server_ip_value" ]] || [[ x"$server_ip_value" = x"127.0.0.1" ]];then
            if [[ -n ${str_local_backup_success} ]];then
                echo "{'state':'SUCCESS','taskId':'','errorMsg':''}" && exit 0
            else
                echo "{'state':'FAILED','taskId':'','errorMsg':'backup failed'}" && exit 0
            fi
        else
            if [[ -n ${success_result} && -z ${failed_result} ]];then
                echo "{'state':'SUCCESS','taskId':'','errorMsg':''}" && exit 0
            else
                echo "{'state':'FAILED','taskId':'','errorMsg':'backup failed'}" && exit 0
            fi
        fi
    else
        echo "{'state':'FAILED','taskId':'','errorMsg':'backup failed'}" && exit 0
    fi
}
main
