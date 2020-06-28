#!/bin/bash
source /etc/profile

#新建日志文件
CERT_LOG_DIR=/var/log/ha/shelllog
DB_USER=dbadmin
if [ ! -d $CERT_LOG_DIR ]; then
    mkdir -p $CERT_LOG_DIR
    chown $DB_USER: $CERT_LOG_DIR
fi
CERT_LOG_FILE=$CERT_LOG_DIR/replaceCerts.log
echo "`date` start to update gscert">>$CERT_LOG_FILE

#接收ommagent参数
ARGS=`getopt -a -o h -l cafile:,cert:,key: -- "$@"`
[ $? -ne 0 ] && usage
eval set -- "${ARGS}"
while true
do
        case "$1" in
        --cafile)
                cafile="$2"
                shift
                ;;
        --cert)
                cert="$2"
                shift
                ;;
        --key)
                key="$2"
                shift
                ;;
        --)
                shift
                break
                ;;
        esac
shift
done
read passwd

cacert=$cafile
serverCert=$cert
serverKey=$key
serverPwd=$passwd
clientCert=$cert
clientKey=$key
clientPwd=$passwd

TMP_CERT_PATH='/tmp/certs'
mkdir -p $TMP_CERT_PATH
chmod 777 $TMP_CERT_PATH

alias cp='cp'
cp -rf $cacert $TMP_CERT_PATH/cacert.pem
cp -rf $serverCert $TMP_CERT_PATH/server.crt
cp -rf $serverKey $TMP_CERT_PATH/server.key
cp -rf $clientCert $TMP_CERT_PATH/client.crt
cp -rf $clientKey $TMP_CERT_PATH/client.key



DB_USER=dbadmin
mkdir -p $CERT_LOG_DIR
chown $DB_USER: $CERT_LOG_DIR


echo "`date` ha stop end ">>$CERT_LOG_FILE
DATA_PATH=/opt/gaussdb/data
BACKUP_CERTS_PATH=/opt/backup/cert_old
CN=`openssl x509 -in $serverCert -subject -noout|awk -F "=" '{print $NF}'`

function copyCerts()
{
    unset HISTFILE
    CERT_CN="$CN"
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
    su - $DB_USER -c "gs_guc encrypt -M server -K $serverPwd"
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
echo "`date` copy cert end">>$CERT_LOG_FILE
replaceServerCerts
echo "`date` replace server cert end">>$CERT_LOG_FILE
replaceClientCerts
echo "`date` replace client cert end">>$CERT_LOG_FILE
su - $DB_USER -c "gs_ctl restart">/dev/null 2>&1 &
echo "`date` ha start end">>$CERT_LOG_FILE
sleep 20

db_local_ret=`service gaussdb query | grep DB_STATE | awk -F ':' '{print $2}' | tr -d ' '`
if [ -z $db_local_ret  ]; then
    echo "`date` GaussDB is abnormal!">>$CERT_LOG_FILE
    exit 1
else
    rm -rf $TMP_CERT_PATH
    echo "`date` Update the certificate successfully">>$CERT_LOG_FILE
fi