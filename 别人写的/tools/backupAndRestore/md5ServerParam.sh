#!/bin/bash

source /etc/profile
fpr1nt="$fpr1nt@$$"
UPLOAD_SERVER_PATH="/opt/gaussdb/ha/tools/backupAndRestore/Upload_Server.cfg"

ip=$(grep "FTP_SERVER_IP:" "$UPLOAD_SERVER_PATH" | sed "s/^FTP_SERVER_IP://")
port=$(grep "FTP_SERVER_PORT:" "$UPLOAD_SERVER_PATH" | sed "s/^FTP_SERVER_PORT://")
username=$(grep "FTP_SERVER_USER:" "$UPLOAD_SERVER_PATH" | sed "s/^FTP_SERVER_USER://")
sharedir=$(grep "FTP_SERVER_FILEPATH:" "$UPLOAD_SERVER_PATH" | sed "s/^FTP_SERVER_FILEPATH://")

password=$(grep "FTP_SERVER_PASSWD:" "$UPLOAD_SERVER_PATH" | sed "s/^FTP_SERVER_PASSWD://")

decrypt_passwd=""
if [[ ${password} ]];then
    decrypt_passwd=$(pwswitch -d "$password" -fp "$fpr1nt")
fi

md5ServerParam=`echo -n "ip=${ip},port=${port},protocol=SFTP,username=${username},password=${decrypt_passwd},sharedir=${sharedir}" | md5sum | cut -d ' ' -f1`

echo ${md5ServerParam}