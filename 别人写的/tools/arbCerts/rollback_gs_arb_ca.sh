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
echo "`date` start to rollback arb cert">>$logfile

passord_props=$HA_DIR/module/thirdArb/conf/arb.properties
sed -i '/arb.keystorePwd/d' $passord_props
passwd_back=/opt/backup/gaussdb_arb.conf
grep "arb.keystorePwd" $passwd_back>>$passord_props
echo "`date` rollback arb cert end">>$logfile

cp -fp /opt/backup/tclient.keystore /opt/gaussdb/ha/module/thirdArb/conf/cert/

test=$(sh $conf_path/../script/thirdArbHealthCheck.sh|grep -i Successed|wc -l)

if [ $test -eq 1 ];then
  echo "`date` test rollback arb cert successfully">>$logfile
  sh $HA_DIR/module/hacom/script/stop_ha_process.sh
fi
echo successfully