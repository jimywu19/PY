#!/bin/bash
set +x

. /etc/profile 2>/dev/null

. $HA_DIR/tools/func/globalvar.sh || { echo "fail to load $HA_DIR/tools/func/globalvar.sh"; exit 1; }
. $HA_DIR/tools/func/func.sh || { echo "fail to load $HA_DIR/tools/func/func.sh"; exit 1; }
. $HA_DIR/tools/func/dblib.sh || { echo "fail to load $HA_DIR/tools/func/dblib.sh"; exit 1; }
. $HA_DIR/tools/gsDB/dbfunc.sh || { echo "fail to load $HA_DIR/tools/gsDB/dbfunc.sh"; exit 1; }

GMN_BIN_DIR=$GM_PATH/bin

ALARM_USER="zabbix"
ALARM_DATA_DIR=/home/$ALARM_USER/dbAlarmData
alarmFile="db_zabbix_alarm"
currentRoleFile="current_db_role_zabbix"

#################################################

sendResourceAlarm()
{
    local res="$1"
    local status="$2"

    [ -n "$res" ] || return 1

    if [ ! -d $ALARM_DATA_DIR ]; then
        mkdir $ALARM_DATA_DIR
        chown $ALARM_USER: $ALARM_DATA_DIR
    fi

    local resFile="$ALARM_DATA_DIR/$res"

    echo $status > $resFile

    chown $ALARM_USER: $resFile >>/dev/null 2>&1
}

dbinfo=$(su - dbadmin -c "$HA_DIR/tools/gsDB/dbStatusInfo.sh")
queryRet=$?

#获取当前数据库节点状态失败
if [ $queryRet -ne 0 ]; then
    sendResourceAlarm "$alarmFile" "c1(current abnormal)"
    exit 0
fi
getDBState "$dbinfo"; retVal=$?

#获取当前数据库节点状态失败
if [ $retVal -ne 0 ]; then
    sendResourceAlarm "$alarmFile" "c1(current abnormal)" 
    exit 0
fi

if [ "$LOCAL_ROLE" != "$gs_r_primary" ]; then
    if [ "$DB_STATE" == "Normal" ]; then
        sendResourceAlarm "$alarmFile" "s0(standby normal)"
        sendResourceAlarm "$currentRoleFile" "1"
    else
        sendResourceAlarm "$alarmFile" "s1(standby abnormal)"
    fi
    exit 0
fi

#主数据库状态异常
if [ "$DB_STATE" != "Normal" ]; then
    sendResourceAlarm "$alarmFile" "p1(primary abnormal)"    
    exit 1
fi

if [ "$PEER_ROLE" == "$gs_r_standby" ]; then
    SYNC_PERCENT=$(echo "$dbinfo" | grep -w 'SYNC_PERCENT' | awk -F: '{print $2}')
    SYNC_PERCENT=$(echo $SYNC_PERCENT)
    PEER_STATE=$(echo "$dbinfo" | grep -w 'PEER_STATE' | awk -F: '{print $2}')
    PEER_STATE=$(echo $PEER_STATE)
    if [ "$PEER_STATE" == "Normal" ] && [ -n "$SYNC_PERCENT" ]; then
        #主备数据库状态正常
        sendResourceAlarm "$alarmFile" "p0s0(primary and standby normal)"
        sendResourceAlarm "$currentRoleFile" "0"
        exit 0
    fi
fi
#主数据库正常，备数据库状态异常
sendResourceAlarm "$alarmFile" "p0s1(primary normal,but standby abnormal)"
sendResourceAlarm "$currentRoleFile" "0"
exit 1
