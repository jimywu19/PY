#!/bin/bash

OMM_AGENT_BACKUP_POLICY=$1
UPLOAD_SERVER_CONFIG_PATH="/opt/gaussdb/ha/tools/backupAndRestore/Upload_Server.cfg"
BACKUP_CONFIG_PATH="/opt/gaussdb/ha/tools/backupAndRestore/backup.conf"
PARSE_SERVER_SCRIPT_PATH="/opt/gaussdb/ha/tools/backupAndRestore/parseServerInfoJson.py"

if [[ -e ${UPLOAD_SERVER_CONFIG_PATH} ]] && [[ -e ${BACKUP_CONFIG_PATH} ]];then
    backup_ftp_mode="1"
    backup_encrypt_passwd=""
    backup_passwd=`python ${PARSE_SERVER_SCRIPT_PATH} "$OMM_AGENT_BACKUP_POLICY" "passWord"`
    if [[ ${backup_passwd} ]];then
        backup_encrypt_passwd=`source /etc/profile && pwswitch -e ${backup_passwd}`
    fi

    backup_ip=`python ${PARSE_SERVER_SCRIPT_PATH} "$OMM_AGENT_BACKUP_POLICY" "ip"`
    backup_port=`python ${PARSE_SERVER_SCRIPT_PATH} "$OMM_AGENT_BACKUP_POLICY" "port"`
    backup_user=`python ${PARSE_SERVER_SCRIPT_PATH} "$OMM_AGENT_BACKUP_POLICY" "userName"`
    backup_filepath=`python ${PARSE_SERVER_SCRIPT_PATH} "$OMM_AGENT_BACKUP_POLICY" "shareDir"`

    sed -ri "s|(FTP_SERVER_IP:)(.*)|\1${backup_ip}|" "$UPLOAD_SERVER_CONFIG_PATH"
    sed -ri "s|(FTP_SERVER_PORT:)(.*)|\1${backup_port}|" "$UPLOAD_SERVER_CONFIG_PATH"
    sed -ri "s|(FTP_SERVER_USER:)(.*)|\1${backup_user}|" "$UPLOAD_SERVER_CONFIG_PATH"
    sed -ri "s|(FTP_SERVER_PASSWD:)(.*)|\1${backup_encrypt_passwd}|" "$UPLOAD_SERVER_CONFIG_PATH"
    sed -ri "s|(FTP_SERVER_FILEPATH:)(.*)|\1${backup_filepath}|" "$UPLOAD_SERVER_CONFIG_PATH"
    sed -ri "s|(UPLOAD_FTP_MODE=)(.*)|\1${backup_ftp_mode}|" "$BACKUP_CONFIG_PATH"
else
    echo "config file path does not exist"
fi