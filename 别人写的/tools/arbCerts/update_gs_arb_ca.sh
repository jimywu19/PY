#!/bin/bash
#(root 执行)
source /etc/profile

#新建日志文件
CERT_LOG_DIR=/var/log/ha/shelllog
DB_USER=dbadmin
if [ ! -d $CERT_LOG_DIR ]; then
    mkdir -p $CERT_LOG_DIR
    chown $DB_USER: $CERT_LOG_DIR
fi
logfile=$CERT_LOG_DIR/replaceCerts.log
echo "`date` start to change arb cert">>$logfile

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

#ca证书路径
cert_path=$cafile
#keystore密码
keystore_passwd=$passwd
#生成的keystore路径
keystore=tclient.keystore

#1.生成新的keystore
cp -p $HA_DIR/conf/arb/certs/ca.crt temp_ca.crt
cat $cert_path>>temp_ca.crt
awk '{if( $0 ~ /-*BEGIN CERTIFICATE-*/){i=i+1;output="sub_ca"i".crt";print $0>>output}else{print $0>>output}}' temp_ca.crt
i=1
for ca in `ls|grep sub_ca`
do
  j=$((i++))
  echo yes|keytool -keystore $keystore -storepass $keystore_passwd -alias ca$j -import -trustcacerts -file $ca >/dev/null 2>&1
done

if [ -f $keystore ];then
   echo "`date` generate new keystore success">>$logfile
else
   echo "`date` generate new keystore fail">>$logfile
   exit -1;
fi
#2备份原始keystore

conf_path=$HA_DIR/module/thirdArb/conf
mv $conf_path/cert/tclient.keystore /opt/backup/
conf_props=$conf_path/arb.properties
grep -E "arb.keystorePwd" $conf_props>/opt/backup/gaussdb_arb.conf
echo "`date` backup original keystore end">>$logfile

#change keystore
cp $keystore $HA_DIR/module/thirdArb/conf/cert/
encode_pass=`sh $conf_path/../script/encrypt.sh -e $keystore_passwd|awk -F ":" '{print$2}'|tr -d ' '`
sed -i "s@arb.keystorePwd=.*@arb.keystorePwd=${encode_pass}@g" $conf_props
sleep 60
echo "`date` change keystore end">>$logfile

#test
test=$(sh $conf_path/../script/thirdArbHealthCheck.sh|grep -i Successed|wc -l)

if [ $test -eq 1 ];then
  echo "`date` test update arb cert successfully">>$logfile
  sh $HA_DIR/module/hacom/script/stop_ha_process.sh
fi
rm $keystore sub_ca* temp_ca.crt
echo successfully