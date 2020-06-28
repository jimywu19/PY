#!/bin/bash

################################################
# init log
################################################
cd "$(dirname $0)"
CUR_PATH=$(pwd)
declare -r ScriptName=`basename $0`
# end init log

. $CUR_PATH/func/func.sh
mkdir -p $_HA_SH_LOG_DIR_
chown $DB_USER: $_HA_SH_LOG_DIR_
LOG_FILE=$_HA_SH_LOG_DIR_/haStartAll.log

. $HA_DIR/tools/func/dblib.sh

usage()
{
    echo "start HA process
Paramter 1:
    emptyParameter start HA
    -m start HA and register HA monitor to crontab interactive
    -r start HA and register HA monitor to crontab
    -a start HA and register HA monitor to crontab
    -h show help
Paramter 2:
    onboot delay to start
example:
    haStartAll
    haStartAll -m
    haStartAll -r
    haStartAll -a
    haStartAll -r onboot
"
}

startHa()
{
    if ! $HA_DIR/module/hacom/script/status_ha.sh >> $LOG_FILE 2>&1; then
        if $HA_DIR/module/hacom/script/start_ha.sh >> $LOG_FILE 2>&1 ; then
            LOG_INFO "start hb success"
        else
            LOG_ERROR "start hb faild"
        fi
    fi
}

startHaMon()
{
    if $GM_PATH/bin/ommonitor_monitor.sh start >> $LOG_FILE 2>&1; then
        LOG_INFO "start ommonitor success"
    else
        LOG_ERROR "ommonitor start faild"
        RET=1
    fi
}

# 检查是否是root用户执行的
checkUserRoot

METHOD="$1"
STAGE="$2"

case "$METHOD" in
    "" )
        :
        ;;
    -a )
        :
        ;;
    -r )
        :
        ;;
    -m )
        :
        ;;
    -h )
        usage
        exit 0
        ;;
    *) 
        ECHOANDLOG_ERROR "Paramter error, $@"
        usage
        exit 1
        ;;
esac
    
# 双机环境，检测是否心跳IP冲突，存在IP冲突，不允许启动HA
if [ "$DUALMODE" == "1" ] && [ -f "$HA_HB_IP_COLLISION_FLAG" ]; then
    COLLISION_IP=$(grep "^collision ip:" "$HA_HB_IP_COLLISION_FLAG" | awk -F":" '{print $2}')
    if [ "$METHOD" != "-m" ]; then
        ECHOANDLOG_ERROR "HA cannot be enabled because the heartbeat IP address {$COLLISION_IP} of the system conflicts with another IP address."
        exit 10
    else
        . $CUR_PATH/get_config/config_parameter_get.sh
        if ! promptConfirmIpCollision ; then
            LOG_WARN "user choise not to start HA"
            exit 10    
        else
            LOG_INFO "user choise to start HA, rm -f $HA_HB_IP_COLLISION_FLAG"
            rm -f "$HA_HB_IP_COLLISION_FLAG"
        fi
    fi
fi

RET=0

if [ "$DUALMODE" = "1" -a "$STAGE" = "onboot" ]; then
    # 如果本节点此前是standby，且对端节点为unknown，则睡眠一段时间再启动HA，等待对方升主
    delay4StartHa
fi

# TODO 启动HA Mon

# 删除进程
rm -f /var/run/goku/*

if [ -n "$METHOD" ];then
    $HA_DIR/install/reg_ha.sh >> $LOG_FILE 2>&1 || die "reg ha failed"
    ECHOANDLOG_INFO "reg ha successful"
else
    if [ "$RET" == "1" ];then
        die "start ha failed"
    fi
fi

# 启动HB
startHa

ECHOANDLOG_INFO "start ha successful"
HACert_DIR=/opt/gaussdb/ha/tools/haCerts/
       registerCert -name "common-gaussdb-ha" -user "root" -group "root" \
       -cert "$HACert_DIR/query_gs_ha_cert.sh" \
       -cafile "$HACert_DIR/query_gs_ha_ca.sh" \
       -key "$HACert_DIR/query_gs_ha_key.sh" \
       -cert_path "/home/gaussdb/certs/" \
       -step_2 "$HACert_DIR/update_gs_ha_cert.sh" \
       -step_2_rollback "$HACert_DIR/rollback_gs_ha_cert.sh" >/dev/null 2>&1

       if [ $? -ne 0 ];then
         echo "`date` register hacert to omm agent failure">>$LOG_FILE
       else
         echo "`date` register hacert to omm agent successfully">>$LOG_FILE
       fi
GSCert_DIR=/opt/gaussdb/ha/tools/gsCerts/
       registerCert -name "common-gaussdb-self" -user "root" -group "root" \
       -cert "$GSCert_DIR/query_gs_cert.sh" \
       -cafile "$GSCert_DIR/query_gs_ca.sh" \
       -key "$GSCert_DIR/query_gs_key.sh" \
       -cert_path "/home/gaussdb/certs/" \
       -step_2 "$GSCert_DIR/update_gaussdb_cert.sh" \
       -step_2_rollback "$GSCert_DIR/rollback_gaussdb_cert.sh" >/dev/null 2>&1

       if [ $? -ne 0 ];then
         echo "`date` register gscert to omm agent failure">>$LOG_FILE
       else
         echo "`date` register gscert to omm agent successfully">>$LOG_FILE
       fi
/opt/gaussdb/ha/tools/backupAndRestore/unifiedBackup.sh REG > /dev/null 2>&1

if [ $? -ne 0 ];then
    echo "`date` register gaussdb backup to omm agent failure">>$LOG_FILE
else
    echo "`date` register gaussdb backup to omm agent successfully">>$LOG_FILE
fi
