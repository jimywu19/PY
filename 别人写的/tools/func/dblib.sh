#!/bin/bash

. $HA_DIR/tools/func/globalvar.sh

HA_DATA_DIR=$HA_DIR/data
chmod 600 $HA_DATA_DIR -R
HA_FLAG_DIR="$HA_DATA_DIR"
HA_GLOBAL_DATA_DIR=$HA_DATA_DIR/global
[ -d "$HA_GLOBAL_DATA_DIR" ] || mkdir -p $HA_GLOBAL_DATA_DIR
HA_ACTIVE_DATA_DIR=$HA_DATA_DIR/active
[ -d "$HA_ACTIVE_DATA_DIR" ] || mkdir -p $HA_ACTIVE_DATA_DIR
HA_STANDBY_DATA_DIR=$HA_DATA_DIR/standby
[ -d "$HA_STANDBY_DATA_DIR" ] || mkdir -p $HA_STANDBY_DATA_DIR

# 资源失败次数及告警信息缓存目录
RM_FAILCOUNT_DIR=$HA_DATA_DIR/rm/failcount
RM_ALARM_DIR=$HA_DATA_DIR/rm/alarm
[ -d "$RM_FAILCOUNT_DIR" ] || mkdir -p $RM_FAILCOUNT_DIR
[ -d "$RM_ALARM_DIR" ] || mkdir -p $RM_ALARM_DIR

# HA状态记录文件
HA_STATE_FILE=$HA_GLOBAL_DATA_DIR/haState.conf

# 本机进行过文件同步的记录文件，在主备倒换时的强制文件同步后删除
HA_RSYNC_FILE=$HA_GLOBAL_DATA_DIR/rsync.conf

# hb IP冲突标记
HA_HB_IP_COLLISION_FLAG=$HA_GLOBAL_DATA_DIR/hbIpCollision.flag

# hb启动标记
HA_HB_START_FLAG=$HA_GLOBAL_DATA_DIR/hbStart.flag

# 修改管理网段的物理IP锁
MODIFY_IP_LOCK=$HA_GLOBAL_DATA_DIR/modifyIp.lock

# 修改管理网段的浮动IP锁
MODIFY_EXFLOAT_IP_LOCK=$HA_GLOBAL_DATA_DIR/modifyExFloatIp.lock

# 业务进程启动锁
PRYGMN_MONITOR_LOCK=$HA_GLOBAL_DATA_DIR/prygmn.lock

# HA进程启动锁
HA_START_LOCK=$HA_GLOBAL_DATA_DIR/hastart.lock

# hamon定时任务更新标记文件
HAMON_CRON_FLAG=$HA_GLOBAL_DATA_DIR/hamon_cron.flag

HA_FALLSTANDBY_FLAG_FILE=ha_fallstandby.flag
# ha主降备标记文件
HA_FALLSTANDBY_FLAG=$HA_GLOBAL_DATA_DIR/$HA_FALLSTANDBY_FLAG_FILE

# local offline标记文件
HB_OFFLINE_FLAG=$HA_GLOBAL_DATA_DIR/hbOffline.flag

PG_DATA_DIR=$GM_PATH/data/db
DB_FLAG_DIR=$HA_DATA_DIR/db/flag
mkdir -p $DB_FLAG_DIR
chown root: $DB_FLAG_DIR
chown root: $DB_FLAG_DIR/../

REBUILD_FLAG_FILE=${DB_FLAG_DIR}/rebuilding_flag.txt
PGOP_FLAG_FILE=${DB_FLAG_DIR}/pgsql_operation.txt
HA_STATUS=${DB_FLAG_DIR}/ha_status
PSQL_FALL_STANDBY_LOCK=${DB_FLAG_DIR}/psql_fall_standby.lock

OMSCRIPT=$HA_DIR/tools/omscript

# double primary flag file
_DOUBLE_PRIMARY_FLAG_=${DB_FLAG_DIR}/double_primary_flag
SWITCH_FATAL_FLAG=${DB_FLAG_DIR}/switch_fatal_flag.txt

ERR_HA_STATE=9
ERR_CONNECT=2

NOT_REBUILDING="0"
REBUILDING="1"

DB_STATUS_NORMAL="0"
DB_STATUS_ABNORMAL="1"

CHECK_PGFLAG_OK="0"
CHECK_PGFLAG_NOT_OK="1"

PSQL_NOT_RUNNING=3
HABUILD_NOT_RUNNING=2
ALL_NOT_RUNNING=1

PRIMARY_RUN_TYPE="primary"
STANDBY_RUN_TYPE="standby"

PRIMARY_STATUS="PRIMARY"
STANDBY_STATUS="STANDBY"

#db parameters
PT_PORT="5432"
DB_NAME="postgres"

PRIMARY_DB_RES="primarydb"
STANDBY_DB_RES="standbydb"

REMOTE_PORT="5790"

HA_ALARM_URL="haalarm"

# 告警相关变量定义
SEND_ALARM_TYPE="sendAlarm"
RESUME_ALARM_TYPE="resumeAlarm"
RESOURCE_ALARM_OVERDUE_TM=600
HB_INTER_ALARM_OVERDUE_TM=180
HA_ARBITRATE_ALARM_OVERDUE_TM=180
SYNC_FILE_ALARM_OVERDUE_TM=900

# Validate most critical parameters
function pgsql_validate_all() 
{
   return ${OCF_SUCCESS}
}

call_remote_by_ip()
{
    local subUrl="$1"
    local remoteIp="$2"
    local -i timeout="$3"
    
    if [ $timeout -le 2 ];then
        timeout=2
    elif [ $timeout -gt 600 ];then
        timeout=600
    fi
    
    local pemDir="$GM_PATH/tomcat/ommonitor/conf"

    # curl对于带空格的url或GET参数无法处理，需要将空格转化为url特殊编码，普通英文字符及符号:-_等不需要转化
    subUrl=$(echo "$subUrl" | sed 's/ /%20/g')
    
    # 获取文件标志
    #add for adapting ipv6
    if [ -z "$IP_TYPE" ] ||  [ "IPV4" == "$IP_TYPE" ]; then
        local url="https://${remoteIp}:${REMOTE_PORT}/ommonitor/${subUrl}"
        LOG_INFO "curl -s -f -m $timeout -k --cert $pemDir/all.pem \"${url}\""
    
        local result=$(curl -s -f -m $timeout -k --cert $pemDir/all.pem "${url}" 2>> $LOG_FILE)
        LOG_INFO "result=${result}"
        
        echo $result
    else
        local url="https://[${remoteIp}]:${REMOTE_PORT}/ommonitor/${subUrl}"
        LOG_INFO "curl -g -s -f -m $timeout -k --cert $pemDir/all.pem \"${url}\""
    
        local result=$(curl -g -s -f -m $timeout -k --cert $pemDir/all.pem "${url}" 2>> $LOG_FILE)
        LOG_INFO "result=${result}"
        
        echo $result
    fi
}

function sync_rsync_module()
{
    local module="$1"
    local path="$2"
        
    LOG_INFO "enter sync_rsync_module module:$module, path:$path"
    
    [ -n "$module" ] || return 1
    [ -n "$path" ] || return 1
    
    if [ "$DEPLOY_MODE" == "1" ];then
        rsync -vzrtopgl --progress --timeout=120 nobody@$REMOTE_GMN_EX_IP::${module} $path/ >> $LOG_FILE 2>&1 || return 1
        LOG_INFO "rsync -vzrtopgl --progress --timeout=120 nobody@$REMOTE_GMN_EX_IP::${module} $path/ success"
    else
        rsync -vzrtopgl --progress --timeout=120 nobody@$REMOTE_GMN_ESCAPE_IP::${module} $path/ >> $LOG_FILE 2>&1
        if [ $? -ne 0 ]; then
            LOG_INFO "result:$REMOTE_GMN_ESCAPE_IP is failed ,change ip to $REMOTE_GMN_IN_IP"
            rsync -vzrtopgl --progress --timeout=120 nobody@$REMOTE_GMN_IN_IP::${module} $path/ >> $LOG_FILE 2>&1 || return 1
        fi
        
        LOG_INFO "rsync -vzrtopgl --progress --timeout=120 nobody@$REMOTE_GMN_ESCAPE_IP or $REMOTE_GMN_IN_IP::${module} $path/ success"
    fi
    
    return 0
}

function call_ommonitor_local()
{
	LOG_INFO "---------------start call_ommonitor_local,arg=${1}----------------"
    
    local subUrl="$1"
    
    #add for adapting IPV6
    if [ -z "$IP_TYPE" ] ||  [ "IPV4" == "$IP_TYPE" ]; then
        local localIp="127.0.0.1"
    else
        local localIp="::1"
    fi
    
    
    if [ "-${result}" = "-" ]; then
        LOG_INFO "Error: call_ommonitor_local timeout or failed"
        return
    fi
    
    echo ${result}
	return ${result}
}


ACTIVE_STATE="active"
STANDBY_STATE="standby"
UNKNOW_STATE="unknow"
STANDBY_STATE_CODE=10
ACTIVE_STATE_CODE=11
UNKNOW_STATE_CODE=12

queryRemoteState()
{
    local suburl="${REMOTE_OPER_URL}?method=get_ha_status"
    local getTimeout=2
    
    local remoteStatusCode=$(get_remote_status "$suburl" "$getTimeout")
    
    case $remoteStatusCode in
        $ACTIVE_STATE_CODE)
            REMOTE_STATE="$ACTIVE_STATE"
            ;;
        $STANDBY_STATE_CODE)   
            REMOTE_STATE="$STANDBY_STATE"
            ;;
        *)
            REMOTE_STATE="$UNKNOW_STATE"
            ;;
    esac
}

queryRemoteForbidSwitch()
{
    QUERY_METOD="-q"
    local suburl="haswitch?method=$QUERY_METOD&appname=$appname"
    local getTimeout=2
    
    local ret=$(get_remote_status "$suburl" "$getTimeout")
    if [ -z "$ret" ];then
        ret=$ERR_CONNECT
    fi
    
    if [ $ret -eq 0 ];then
        echo "forbid ha switch is open."
    elif [ $ret -eq $ERR_CONNECT ]; then
        echo "query forbid ha switch failed, connect timeout."
    elif [ $ret -eq $ERR_HA_STATE ]; then
        echo "query forbid ha switch failed, ha state error."
    else
        echo "forbid ha switch is closed."
    fi
    
    return $ret
}

# 获取HA状态
getHaState()
{
    LOCAL_HOST=$LOCAL_nodeName
    REMOTE_HOST=$REMOTE_nodeName

    # TODO R5针对OMM HA，如果本机HA未运行，此处查询为 NULL
    HA_STATES=$($HA_STATUS_TOOL 2> /dev/null)
    local getHaStatesRet=$?
    if [ $getHaStatesRet -ne 0 ] && [ "-${DUALMODE}" != "-0" ];then
        HA_STATES=$($HA_CLIENT_TOOL --ip="$REMOTE_GMN_EX_IP" --port=61806 --gethastatus 2> /dev/null)
        getHaStatesRet=$?
    fi
    
    if [ $getHaStatesRet -ne 0 ]; then
        LOCAL_STATE="$UNKNOW_STATE"
    else
        LOCAL_STATE=$(echo "$HA_STATES" | awk '{if ($1 == "'$LOCAL_HOST'") print $6}' | sed -r "s/^(NULL|--)$/$UNKNOW_STATE/")
    fi
        
    # if it is single, not to check remote.
    if [ "-${DUALMODE}" = "-0" ]; then
        return 0
    fi
    
    if ! check_hb_ips_connect "1"; then
        LOG_INFO "can not connet remote, REMOTE_STATE=$UNKNOW_STATE"
        REMOTE_STATE="$UNKNOW_STATE"
    else
        # 获取备机状态
        if [ $getHaStatesRet -ne 0 ]; then
            REMOTE_STATE="$UNKNOW_STATE"
        else
            REMOTE_STATE=$(echo "$HA_STATES" | awk '{if ($1 == "'$REMOTE_HOST'") print $6}' | sed -r "s/^(NULL|--)$/$UNKNOW_STATE/")
        fi
    fi
}

queryHaState()
{
    getHaState
    
    HA_STATE="LOCAL_HOST=${LOCAL_HOST}\nLOCAL_STATE=${LOCAL_STATE}\nLOCAL_IP=${LOCAL_GMN_EX_IP}"
    
    # if it is doube, check remote.
    if [ "-${DUALMODE}" = "-1" ]; then
        HA_STATE="$HA_STATE\n\nREMOTE_HOST=${REMOTE_HOST}\nREMOTE_STATE=${REMOTE_STATE}\nREMOTE_IP=${REMOTE_GMN_EX_IP}"
    fi
    
    LOG_INFO "leave queryHaState:$HA_STATE"
    echo -e "$HA_STATE"
}

check_hb_ips_connect()
{
    local -i retryPingCount=$1
    if [ $retryPingCount -le 0 ]; then
        retryPingCount=3
    fi
    
    if [ "$DEPLOY_MODE" == "1" ];then
        # 非一体机部署
        LOG_INFO "check gmn ex ip connectivity, ip=${REMOTE_GMN_EX_IP}"
        if ! check_ip_connect "$REMOTE_GMN_EX_IP" "$retryPingCount"; then
            LOG_ERROR "can not access to gmn ex ip"
            return 1
        fi
    else
        # 一体机部署
        LOG_INFO "check escape or gmn in ip connectivity, escIp=${REMOTE_GMN_ESCAPE_IP}, inIp=${REMOTE_GMN_IN_IP}"
        if ! check_ip_connect "$REMOTE_GMN_ESCAPE_IP" "$retryPingCount"; then
            if ! check_ip_connect "$REMOTE_GMN_IN_IP" "$retryPingCount"; then
                LOG_ERROR "can not access to escape or gmn in ip"
                return 1
            fi
        fi
    fi
    
    LOG_INFO "check_hb_ips success"
    return 0
}

delay4StartHa()
{
    # 如果本节点此前是standby，且对端节点为unknown，则睡眠一段时间再启动HA，等待对方升主
    local lastState=$(tail -1 $HA_STATE_FILE)
    local state=$(echo "$lastState" | awk -F'=|,' '{print $2}')
    if [ "$state" == "standby" ];then
        LOG_INFO "last state of node is standby"
        eval "$(QueryHaState)"
        if [ "$LOCAL_STATE" = "$UNKNOW_STATE" ]; then
            if [ "$REMOTE_STATE" = "$UNKNOW_STATE" ]; then
                # 如果对端节点尚未起来，则等待120秒，等待对端节点启动，避免主备同时下电，备机先起来抢占主的情况
                # 同时避免，备机掉电的情况下，主机无法单主运行，使得主机有时间清除pseudogmn资源故障，优先升主
                LOG_WARN "REMOTE_STATE is UNKNOW_STATE:$UNKNOW_STATE and LOCAL_STATE is UNKNOW_STATE:$LOCAL_STATE, so sleep 120 second"
                sleep 120
            else
                # 如果对端节点（主机）已经起来，则sleep较短的时间，让对端节点优先升主
                LOG_WARN "REMOTE_STATE is UP:$REMOTE_STATE and LOCAL_STATE is UNKNOW_STATE:$LOCAL_STATE, so sleep 30 second"
                sleep 30
            fi
        fi
    fi
}

# 升主前或者重启heartbeat之前将资源的失败次数清理掉，避免出现，资源失败不到3次就发告警的情况
clearRmFailCountOnFile()
{
    [ -d "$RM_FAILCOUNT_DIR" ] || return 0
    
    rm -rf $RM_FAILCOUNT_DIR/*
}

# 强制发送资源异常告警
forceSendResourceAlarm()
{
    local res="$1"
    
    [ -n "$res" ] || return 1
    
    local resFile="$RM_FAILCOUNT_DIR/$res"
    
    echo 3 > $resFile
    
    sendResourceAlarm "$res" "1"
}

# 根据资源状态确定是否发送告警并发送
sendResourceAlarm()
{
    local res="$1"
    local status="$2"
    
    [ -n "$res" ] || return 1
    
    local resFile="$RM_FAILCOUNT_DIR/$res"
    local resAlarmFile="$RM_ALARM_DIR/$res"
    
    local ret=0
    if [ "$status" != "0" ];then
        if [ -e "$resFile" ];then
            local -i count=$(cat $resFile)
            ((++count))
            if [ $count -ge 3 ]; then
                echo 3 > $resFile
                if isNeedSendAlarm "$resAlarmFile" "$SEND_ALARM_TYPE" "$RESOURCE_ALARM_OVERDUE_TM"; then
                    sendAlarm "$PROCESS_ALARM_ID" "$res"
                    ret=$?
                    LOG_INFO "send alarm $res return $ret"

                    # 发送告警成功
                    if [ "$ret" == "0" ]; then
                        local curTime=$(date +"%s")
                        echo -e "$SEND_ALARM_TYPE,$curTime" > "$resAlarmFile"
                    fi
                fi
            elif [ $count -lt 3 ];then
                echo $count > $resFile
            else
                LOG_ERROR "$res still fail"
            fi
        else
            local -i count=1
            echo $count > $resFile
        fi
    fi
}

# 根据资源状态确定是否需要恢复告警并恢复
resumeResourceAlarm()
{
    local res="$1"
    local status="$2"
    
    [ -n "$res" ] || return 1
    
    local resFile="$RM_FAILCOUNT_DIR/$res"        
    local resAlarmFile="$RM_ALARM_DIR/$res"
    
    local ret=0
    if [ "$status" == "0" ];then
        if [ -e "$resAlarmFile" ];then
            sendAlarm "$PROCESS_ALARM_ID" "$res" "yes"
            ret=$?
            LOG_INFO "send resume alarm $res return $ret"
            
            # 发送告警成功
            if [ "$ret" == "0" ]; then
                rm -f "$resAlarmFile"
            fi
        fi
        echo 0 > "$resFile"
    fi
}

# 根据flag文件来判断是否需要发送告警
isNeedSendAlarm()
{
    local flagFile="$1"
    if ! [ -f "$flagFile" ];then
        return 0
    fi

    local alarmType="$2"
    if [ -z "$alarmType" ]; then
        LOG_WARN "alarmType:$alarmType is empty"
        return 0
    fi
    
    local maxRetryTime="$3"
    if [ -z "$maxRetryTime" ]; then
        maxRetryTime=1800
    fi
    
    local tailInfo=$(tail -1 "$flagFile" | grep "^$alarmType")
    if [ -n "$tailInfo" ]; then
        local lastTime=$(echo "$tailInfo" | awk -F, '{print $2}')
        local curTime=$(date +%s)
        local diff=0
        ((diff = curTime - lastTime))
        if [ $diff -lt 0 ]; then
            # 如果时间差为负数，有可能修改过时间，刷新一下最近一次发送告警的时间
            sed -i "s/$lastTime/$curTime/" "$flagFile"
            LOG_INFO "no need to $alarmType, because in $flagFile:$tailInfo, set $lastTime to $curTime"
            return 1
        elif [ $diff -lt $maxRetryTime ]; then
            LOG_INFO "no need to $alarmType, because in $flagFile:$tailInfo, curTime:$curTime"
            return 1
        else
            # 如果时间差超过指定的时间，即便之前发送过告警，此处也重复发送告警
            LOG_INFO "need to $alarmType, because in $flagFile:$tailInfo, $curTime - $lastTime great then $maxRetryTime"
            return 0
        fi
    fi
    
    return 0
}

COUNT_FILE=$HA_ACTIVE_DATA_DIR/check_count.flag
countOverFlow()
{
    local checkCountFile="$1"

    local result=$(get_remote_status "haswitch")
    if [ -z "$result" ]; then
        if ! [ -f "$checkCountFile" ]; then
            echo 1 > "$checkCountFile"
            LOG_INFO "checkCountFile is not exist, so create it. count 1"
        else
            local failCount=$(cat "$checkCountFile")
            LOG_ERROR "remote hamon not running, so is abnormal"
            if [ $failCount -eq 3 ]; then
                ret=1
                LOG_INFO "count equal 3. "
            else
                ((++failCount))
                echo "$failCount" > "$checkCountFile"
                LOG_INFO "count is $failCount"
            fi
        fi
    else
        echo 0 > "$checkCountFile"
        LOG_INFO "count back to 0"
    fi
}

isRemoteDown()
{
    local HA_STATES=$($HA_STATUS_TOOL 2> /dev/null)
    local getHaStatesRet=$?
    if [ $getHaStatesRet -ne 0 ]; then
        return 0
    fi
    
    # 获取对端IP、主机名信息
    getDoubleConfig "$_CONF_FILE_"
    local REMOTE_HOST=$REMOTE_nodeName
    
    local REMOTE_STATE=$(echo "$HA_STATES" | awk '{if ($1 == "'$REMOTE_HOST'") print $6}' | sed -r "s/^(NULL|--)$/$UNKNOW_STATE/")
    if [ "$REMOTE_STATE" == "$UNKNOW_STATE" ]; then
        return 0
    fi
    
    return 1
}

proccessHbInterval()
{
    for ((i=0; i < 3; i++)); do
        sleep 5
        if ! isRemoteDown ; then
            LOG_INFO "remote node is ok, no need to send alarm"
            return 0
        fi
    done
    
    sendAlarm "$@"
}

function handleHbInterval()
{
    local lockFile=$HA_GLOBAL_DATA_DIR/handleHbInterval.lock
    lockWrapCall "$lockFile" proccessHbInterval "$@"
    return $?
}

fallStandby()
{
    LOG_INFO "enter fallStandby"
    local ha_module_root="$HA_DIR/module"
    local config_ha_script="$ha_module_root/hacom/script/config_ha.sh"
    local stop_haproc_script="$ha_module_root/hacom/script/stop_ha_process.sh"
    local -i localRole=$5
   
    if [ $localRole -ne 1 ] && [ $localRole -ne 3 ]; then
        LOG_INFO "Ingore deactiving."
        return 0
    fi
    
    ${config_ha_script} -j standby
    if [ $? -ne 0 ];then
        LOG_ERROR "Config ha to standby failed."
        return 9
    fi


    ${stop_haproc_script}
    if [ $? -ne 0 ];then
        LOG_ERROR "Stop ha failed."
        return 9
    fi  
 
    LOG_INFO "Active degrade to standby successfully."
    return 0  
}

# 告警相关全局变量定义
PROCESS_ALARM_ID="9801"
SWITCHOVER_ALARM_ID="9901"
HB_INTERUPT_ALARM_ID="9902"
FILE_SYNC_ALARM_ID="9903"
HA_RESOURCE_ALARM_ID="9904"
HA_ARBITRATE_ALARM_ID="9905"

RESUME_ALARM="yes"
    
FILE_SYNC_ALARM_RESID="File synchronization"
HB_INTER_ALARM_RESID="Heartbeat interruption"
HA_ARBITRATE_ALARM_RESID="HA arbitrate"

HA_ALM_HB_LOST=0    # 主备节点间心跳中断 */
HA_ALM_SYNC_FAIL=1  # 主备节点同步数据异常 */
HA_ALM_HA_SWAP=2    #    /* 主备节点倒换 */
HA_ALM_REBOOT=3     #    /* 单机复位 */
HA_ALM_LK_LOST=4    #     /* 链路中断 */
HA_ALM_NETWORKDOWN=5 #    /* 网络中断 */
handNotifyEvent()
{
    ParaNum=9
    LOG_INFO "enter handNotifyEvent $*"
    #函数调用的参数判断
    if [ $# -ne ${ParaNum} ]; then
        LOG_ERROR "haalarmlog: Param num($#) is invalid(${ParaNum})."
        return 1
    fi
    
    # 告警类型
    G_alarmID="$1"
    # 告警类型定义 -- 0:故障告警; 1:恢复告警; 2:事件告警
    G_alarmCategory="$2"
    
    ##<9>
    G_additionalInfo=$5
    if [ -z "${G_additionalInfo}" ]; then
        G_additionalInfo="LocalHost($6);LocalHA($7);PeerHost($8);PeerHA($9)."
    fi

    if [ "$G_alarmID" == "$HA_ALM_HA_SWAP" ]; then
        saveSwitchRecord
    fi
    
    # 
    G_additionalInfo="($7),($9)"
    
    local alarmResource=""
    
    case $G_alarmID in
        $HA_ALM_NETWORKDOWN)
            fallStandby "$@"
            return 0
            ;;
        $HA_ALM_HB_LOST)
            G_alarmID="$HB_INTERUPT_ALARM_ID"
            alarmResource="$HB_INTER_ALARM_RESID"
            if [ "$G_alarmCategory" != "1" ]; then
                handleHbInterval "$G_alarmID" "$alarmResource"
                return 0
            fi
            ;;
        $HA_ALM_SYNC_FAIL)
            G_alarmID="$FILE_SYNC_ALARM_ID"
            alarmResource="$FILE_SYNC_ALARM_RESID"
            ;;
        $HA_ALM_HA_SWAP)   
            G_alarmID="$SWITCHOVER_ALARM_ID"
            getDoubleConfig "$_CONF_FILE_"
            # 双机倒换需要发告警，先发一次告警，然后马上发一次恢复告警，告警为一条已经恢复的记录
            alarmResource="${REMOTE_nodeName}-${LOCAL_nodeName}-${REMOTE_GMN_EX_IP}-${LOCAL_GMN_EX_IP}"
            sendAlarm "$G_alarmID" "$alarmResource"
            LOG_INFO "sendAlarm "$G_alarmID" "$alarmResource" return $?"
            sendAlarm "$G_alarmID" "$alarmResource" "$RESUME_ALARM"
            LOG_INFO "sendAlarm "$G_alarmID" "$alarmResource" "$RESUME_ALARM" return $?"
            return 0
            ;;
        *)
            return
            ;;
    esac
    
    local isResume=
    if [ "$G_alarmCategory" == "1" ]; then
        isResume="$RESUME_ALARM"
    fi

    sendAlarm "$G_alarmID" "$alarmResource" "$isResume"
    LOG_INFO "sendAlarm "$G_alarmID" "$alarmResource" "$isResume" return $?"
}

getAlarmJsonData()
{
    local alarmId="$1"
    local resourceId="$2"
    local isResume="$3"
    
    local key="ALARM_TEMPLATE_$alarmId"
    
    sed -n "/^$key={/,/^}/p" $HA_DIR/tools/func/alarm.cfg | sed "s/^$key=//"
}

replaceKeyValues()
{
    local key="$1"
    local value="$2"
    local json="$3"
    
    echo "$json" | sed -r 's/("'"$key"'":\s*")[^"]*/\1'"$value"'/'
}

replacePlaceholder()
{
    local placeholder="$1"
    local value="$2"
    local json="$3"
    echo "$json" | sed "s/$placeholder/$value/"
}

sendAlarmByCurl()
{
    local alarmId="$1"
    local resourceId="$2"
    local isResume="$3"
    
    local json=$(getAlarmJsonData "$@")
    
    json=$(replaceKeyValues "alarmID" "$alarmId" "$json")
    
    case "$alarmId" in
        $PROCESS_ALARM_ID )
            local resource=$(echo "$resourceId" | awk -F: '{print $1}')
            local host=$(echo "$resourceId" | awk -F: '{print $2}')
            json=$(replacePlaceholder "%s" "$resource" "$json")
            json=$(replacePlaceholder "%s" "$host" "$json")
            ;;
        $SWITCHOVER_ALARM_ID )
            local srcHost=$(echo "$resourceId" | awk -F- '{print $1}')
            local destHost=$(echo "$resourceId" | awk -F- '{print $2}')
            local srcIp=$(echo "$resourceId" | awk -F- '{print $3}')
            local destIp=$(echo "$resourceId" | awk -F- '{print $4}')
            
            json=$(replacePlaceholder "%s" "$srcHost" "$json")
            json=$(replacePlaceholder "%s" "$destHost" "$json")
            json=$(replacePlaceholder "%s" "$srcIp" "$json")
            json=$(replacePlaceholder "%s" "$destIp" "$json")
            
            resourceId="${srcHost}-${destHost}"
            ;;
        $HA_ARBITRATE_ALARM_ID )
            local host=$(echo "$resourceId" | awk -F: '{print $2}')
            
            resourceId="$host"
            ;;
    esac
    
    json=$(replaceKeyValues "resourceID" "$resourceId" "$json")
    json=$(replaceKeyValues "resourceIDName" "$resourceId" "$json")
    
    local time=$(date -u +'%Y-%m-%d %H:%M:%S.%N')
    time=$(echo "$time" | sed 's/[0-9]\{6,6\}$//')
    json=$(replaceKeyValues "occurTime" "$time" "$json")
    
    if [ "$isResume" = "$RESUME_ALARM" ]; then
        json=$(replaceKeyValues "category" "2" "$json")
        json=$(replaceKeyValues "clearTime" "$time" "$json")
    fi
    
    #add for adapting ipv6
    if [ -z "$IP_TYPE" ] || [ "IPV4" == "$IP_TYPE" ]; then
        local result=$(curl -s -f -m 6 -H "Content-Type: application/json" -d ''"$json"'' -k https://127.0.0.1:8042/goku/rest/v1.5/fm/sendAlarm -w %{http_code})
        if echo result="$result" | grep '"errorCode":0,' > /dev/null ; then
            return 0
        else
            return 1
        fi
    else
        local result=$(curl -g -s -f -m 6 -H "Content-Type: application/json" -d ''"$json"'' -k https://[::1]:8042/goku/rest/v1.5/fm/sendAlarm -w %{http_code})
        if echo result="$result" | grep '"errorCode":0,' > /dev/null ; then
            return 0
        else
            return 1
        fi
    fi
}

sendAlarm()
{
    local alarmId="$1"
    local resourceId="$2"
    local isResume="$3"
    
    [ -n "$alarmId" -a -n "$resourceId" ] || return 1
    
    if [ "$alarmId" == "$HA_ARBITRATE_ALARM_ID" ];then
        resourceId="$resourceId:$(uname -n)"
    fi
    
    local lcAll="$LC_ALL"
    unset LC_ALL

    sendAlarmByCurl "$alarmId" "$resourceId" "$isResume"
    local ret=$?
    
    [ -z "$lcAll" ] || export LC_ALL="$lcAll"
    
    return $ret
}

resourceNotify()
{
    local resourceName="$1"
    local haRole="$3"
    local type="$5"
    local nodeName="$6"

    local isResume=""
    if [ "$type" = "0" ]; then
        isResume="$RESUME_ALARM"
    fi
    
    local ret=0
    # 处理非数据库资源，直接发送告警或者恢复告警
    if [ "$resourceName" != "rcommgsdb" ]; then
        if [ "$haRole" = "active" ]; then
            sendAlarm "$PROCESS_ALARM_ID" "$resourceName:$nodeName" "$isResume" || ret=$?
        fi
        
        return $ret
    fi
    
    # 处理数据库资源
    # 如果是备机直接返回成功，因为备机无法发送告警
    if [ "$haRole" != "active" ]; then
        return 0
    fi
    
    sendAlarm "$PROCESS_ALARM_ID" "$PRIMARY_DB_RES:$nodeName" "$isResume" || ret=$?
    
    # 如果是恢复告警，则需要恢复备数据库资源在本节点产生的告警
    if [ "$isResume" = "$RESUME_ALARM" ]; then
        sendAlarm "$PROCESS_ALARM_ID" "$STANDBY_DB_RES:$nodeName" "$isResume" || ret=$?
    fi
    
    return $ret
}

saveSwitchRecord()
{
    date +"%s" >> $HA_STATE_FILE
}
