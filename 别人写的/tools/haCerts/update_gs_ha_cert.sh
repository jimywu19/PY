#!/bin/bash
source /etc/profile

#新建日志文件
CERT_LOG_DIR=/var/log/ha/shelllog
DB_USER=dbadmin
if [ ! -d $CERT_LOG_DIR ]; then
    mkdir -p $CERT_LOG_DIR
    chown $DB_USER: $CERT_LOG_DIR
fi
logfile=$CERT_LOG_DIR/replaceCerts.log
echo "`date` start to update ommha cert">>$logfile

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

cafile=$cafile
cert=$cert
private_key=$key
key_passwd=$passwd

cert_path=/opt/gaussdb/ha/local/cert/
HA_KEY_TOOL=/opt/gaussdb/ha/module/hacom/tools/key-tool
decryptfile=/opt/gaussdb/ha/module/hacom/lib/server-key-decrypt.so

#备份旧证书
cp -rf $cert_path/ /opt/backup/
rm -rf /opt/gaussdb/ha/local/cert/*
cat /opt/gaussdb/ha/local/hacom/conf/hacom_local.xml|grep "ssl"|awk -F "ServerKeyPass value=" '{print $2}'|awk -F ">" '{print $1}'|tr -d '"'>/opt/backup/haencode.passwd
echo "`date` backup update ommha cert end">>$logfile

#拷贝新证书
cp -p $cafile $cert_path/root-ca.crt
cp -p $cert $cert_path/server.crt
cp -p $key $cert_path/server.pem

chmod 500 $cert_path/*
encode_pass=$($HA_KEY_TOOL -e "$passwd" | grep "Encrypted password" | awk -F: '{print $2}'| sed 's/^[ \t]*//g')
/opt/gaussdb/ha/module/hacom/script/config_ha.sh -S ssl=true,twoway=true,rootca=$cert_path/root-ca.crt,serverca=$cert_path/server.crt,serverkey=$cert_path/server.pem,keypass=$encode_pass,keypassdecryptlib=$decryptfile
echo "`date` update ommha cert end">>$logfile

if [[ $? -ne 0 ]]; then
	echo "`date` update ommha cert failed">>$logfile
else
    echo "`date` update ommha cert successful">>$logfile
fi

echo successfully