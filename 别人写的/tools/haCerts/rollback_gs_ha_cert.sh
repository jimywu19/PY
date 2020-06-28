#!/bin/bash

#新建日志文件
CERT_LOG_DIR=/var/log/ha/shelllog
DB_USER=dbadmin
if [ ! -d $CERT_LOG_DIR ]; then
    mkdir -p $CERT_LOG_DIR
    chown $DB_USER: $CERT_LOG_DIR
fi
logfile=$CERT_LOG_DIR/replaceCerts.log
echo "`date` start to rollback ommha cert">>$logfile

back_pass=/opt/backup/haencode.passwd
back_cert=/opt/backup/cert/
cert_path=/opt/gaussdb/ha/local/cert/
decryptfile=/opt/gaussdb/ha/module/hacom/lib/server-key-decrypt.so

rm -f $cert_path/*
cp /opt/backup/cert/* $cert_path
chmod 500 $cert_path/*
encode_pass=`cat $back_pass`
/opt/gaussdb/ha/module/hacom/script/config_ha.sh -S ssl=true,twoway=true,rootca=$cert_path/root-ca.crt,serverca=$cert_path/server.crt,serverkey=$cert_path/server.pem,keypass=$encode_pass,keypassdecryptlib=$decryptfile
echo "`date` rollback ommha cert end">>$logfile

if [[ $? -ne 0 ]]; then
	echo "`date` rollback ommha cert failed">>$logfile
else
    echo "`date` rollback ommha cert successful">>$logfile
fi

echo successfully