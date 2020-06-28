#!/bin/bash
source /etc/profile
#接收ommagent参数

#新建日志文件
CERT_LOG_DIR=/var/log/ha/shelllog
DB_USER=dbadmin
if [ ! -d $CERT_LOG_DIR ]; then
    mkdir -p $CERT_LOG_DIR
    chown $DB_USER: $CERT_LOG_DIR
fi
CERT_LOG_FILE=$CERT_LOG_DIR/replaceCerts.log
echo "`date` start to rollback gscert">>$CERT_LOG_FILE

echo "`date` ha stop end">>$CERT_LOG_FILE
DATA_PATH=/opt/gaussdb/data
BACKUP_CERTS_PATH=/opt/backup/cert_old
CN=`openssl x509 -in $BACKUP_CERTS_PATH/server.crt -subject -noout|awk -F "=" '{print $NF}'`

function rollbackCerts()
{
    unset HISTFILE
    CERT_CN="$CN"
    alias cp='cp'
    rm -rf $DATA_PATH/certs/*
    cp -rf $BACKUP_CERTS_PATH/* $DATA_PATH/certs/
	chown dbadmin: $DATA_PATH/certs/ -R
    chmod 700 $DATA_PATH/certs
    chmod 600 $DATA_PATH/certs/*
	rm -rf $DATA_PATH/db/server*
    rm -f $DATA_PATH/db/cacert.pem
    cp -p $DATA_PATH/certs/server* $DATA_PATH/db/
    cp -p $DATA_PATH/certs/cacert.pem $DATA_PATH/db/
    su - $DB_USER -c "gs_guc set -c repl_force_cert_check=\"'repl_All_peer_cn=$CERT_CN'\""
}

rollbackCerts
echo "`date` rollback gscert end">>$CERT_LOG_FILE
su - dbadmin -c "gs_ctl restart"
echo "`date` ha start end">>$CERT_LOG_FILE
ha_ret=`service had query|grep -i gaussdb|grep -i normal|wc -l`

if [ $ha_ret -eq 2 ]; then
    db_local_ret=`service gaussdb query | grep DB_STATE | awk -F ':' '{print $2}' | tr -d ' '`
    db_peer_ret=`service gaussdb query| grep PEER_STATE | awk -F ':' '{print $2}' | tr -d ' '`
    if [ $db_local_ret == "Normal"  -a  $db_peer_ret == "Normal" ]; then
        rm -rf $TMP_CERT_PATH
		echo "`date` Rollback the certificate successfully">>$CERT_LOG_FILE
    fi
else
		echo "`date` Failed to rollback GaussDB certs!">>$CERT_LOG_FILE
fi
echo successfully