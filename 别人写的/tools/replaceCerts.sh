#!/bin/bash
set +x

#新建日志文件
CERT_LOG_DIR=/var/log/ha/shelllog
DB_USER=dbadmin
mkdir -p $CERT_LOG_DIR
chown $DB_USER: $CERT_LOG_DIR
LOG_FILE=$CERT_LOG_DIR/replaceCerts.log
touch $LOG_FILE
chmod 600 $LOG_FILE

. /opt/gaussdb/ha/tools/func/func.sh || { echo "fail to load /opt/gaussdb/ha/tools/func/func.sh"; exit 1; }

if [ $# -ne 4 ]; then
    echo "the number of input parameters wrong, must be equal to 4"
    exit 1
fi

cacert=$1
serverCert=$2
serverKey=$3
serverPwd=$4
clientCert=$2
clientKey=$3
clientPwd=$4

TMP_CERT_PATH='/tmp/gaussdb/certs'
mkdir -p $TMP_CERT_PATH
chmod 777 $TMP_CERT_PATH

alias cp='cp'
cp -rf $cacert $TMP_CERT_PATH/cacert.pem
cp -rf $serverCert $TMP_CERT_PATH/server.crt
cp -rf $serverKey $TMP_CERT_PATH/server.key
cp -rf $clientCert $TMP_CERT_PATH/client.crt
cp -rf $clientKey $TMP_CERT_PATH/client.key

sh haStopAll.sh -a

BASE_DIR=/opt/gaussdb
DATA_PATH=$BASE_DIR/data
BACKUP_CERTS_PATH=/opt/backup/cert_old

function copyCerts()
{
    unset HISTFILE
    CERT_CN='www.huawei.com'
    alias cp='cp'
    mkdir -p $BACKUP_CERTS_PATH
    cp -rf $DATA_PATH/certs/* $BACKUP_CERTS_PATH/
    rm -rf $DATA_PATH/certs/*
    cp -rf $TMP_CERT_PATH/* $DATA_PATH/certs/
    cp $DATA_PATH/certs/server* $DATA_PATH/db/
    cp $DATA_PATH/certs/cacert.pem $DATA_PATH/db/
    su - $DB_USER -c "gs_guc set -c repl_force_cert_check=\"'repl_All_peer_cn=$CERT_CN'\""
    chown dbadmin: $DATA_PATH/certs/ -R
    chmod 700 $DATA_PATH/certs
    chmod 600 $DATA_PATH/certs/*
}

function replaceServerCerts()
{
    unset HISTFILE
    rm -rf $DATA_PATH/db/server.key.rand
    rm -rf $DATA_PATH/db/server.key.cipher
    su - $DB_USER -c "gs_guc encrypt -M server -K $clientPwd"
    cp $DATA_PATH/db/server.key.cipher $DATA_PATH/certs/
    cp $DATA_PATH/db/server.key.rand $DATA_PATH/certs/
    chown dbadmin: $DATA_PATH/certs/ -R
    chmod 700 $DATA_PATH/certs
    chmod 600 $DATA_PATH/certs/*
}

function replaceClientCerts()
{
    unset HISTFILE
    rm -rf $DATA_PATH/db/client.key.rand
    rm -rf $DATA_PATH/db/client.key.cipher
    su - $DB_USER -c "gs_guc encrypt -M client -K $clientPwd"
    cp $DATA_PATH/db/client.key.rand $DATA_PATH/certs/
    cp $DATA_PATH/db/client.key.cipher $DATA_PATH/certs/
    rm -rf $DATA_PATH/db/client.key.rand
    rm -rf $DATA_PATH/db/client.key.cipher
    chown dbadmin: $DATA_PATH/certs/ -R
    chmod 700 $DATA_PATH/certs
    chmod 600 $DATA_PATH/certs/*
}

copyCerts

replaceServerCerts

replaceClientCerts

sh haStartAll.sh -a

. /etc/profile
GAUSSDB_INFO=`service gaussdb query`
db_state=`echo "$GAUSSDB_INFO" | grep DB_STATE | awk -F ':' '{print $2}'|tr -d ' '`
if [ "$db_state"x == "Normal"x ]; then
	rm -rf $TMP_CERT_PATH
	ECHOANDLOG_INFO "Replace the certificate successfully"
	exit 0
else
	ECHOANDLOG_ERROR "Failed to replce GaussDB certs!"
	exit 1
fi