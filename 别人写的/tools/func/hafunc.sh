#!/bin/bash

. $HA_DIR/tools/func/func.sh
. $HA_DIR/tools/func/dblib.sh 

mkdir -p $HA_FLAG_DIR
HARESOURCE_TIME_STAMP=${HA_FLAG_DIR}/ha_resource_time_stamp

LOG_FILE="$_HA_SH_LOG_DIR_/hafun.log"
NO_DEED_ALARM_RESOURCE="prygmn stygmn"

ha_do_action()
{
    local opuser="$1"
    local monitorScript="$2"
    local operation="$3"
    local role="$4"
    
    if [ "$opuser" == root ];then
        # 如果是Restart，先status看一下是否真正异常，如果异常，则重启
        if [ "$operation" == "restart" ] && ${monitorScript} status > /dev/null && [ -n "$role" ]; then
            return 0
        fi
        ${monitorScript} ${operation} > /dev/null 2>&1 < /dev/null || { echo "${operation} failed" ;  return 1; }
    else
        # 如果是Restart，先status看一下是否真正异常，如果异常，则重启
        if [ "$operation" == "restart" ] && su - "$GMN_USER" -c "${monitorScript} status" > /dev/null && [ -n "$role" ]; then
            return 0
        fi
        su - "$GMN_USER" -c "${monitorScript} ${operation}" > /dev/null 2>&1 < /dev/null || { echo "${operation} failed" ;  return 1; }
    fi
    
    echo "${operation} success"
    
    return 0
}

# TODO to delete
handleStartRusult()
{
    local opuser=$1
    local resourceName=$2
    local monitorScript=$3
    local operation=$4
    
    local ret=0
    
    # 启动时，连续3次启动失败，才返回失败
    for ((i = 0; i < 2; ++i)); do
        ha_do_action "$opuser" "${monitorScript}" "${operation}" && return 0
        ret=$?
    done
    
    LOG_ERROR "resourceName:$resourceName start failed on 3 times, need to send alarm and switchover"
    
    # 发送资源异常告警
    forceSendResourceAlarm "$resourceName"
    
    return $ret
}

usage()
{
    echo "monitor process
    start
    stop
    repair
    restart
    status
    notify
    -h show help
"
}

haCall()
{
    local resourceName=$1
    local operation=$2
    local role="$3"
    
    PROC_CONF=$HA_DIR/module/harm/plugin/conf/process.conf
    PORC_LINES=$(grep "^$resourceName\>" $PROC_CONF)
    
    local monitorScript=$(echo "$PORC_LINES" | awk -F"," '{print $2}')
    eval "monitorScript=$monitorScript"
    local opuser=$(echo "$PORC_LINES" | awk -F"," '{print $3}')
    if [ -z "$opuser" ]; then
        opuser=""$GMN_USER""
    fi
    
    # 只有hearbeat monitor调用的时候，才记录heartbeat调用的时间
    if [ "$operation" == "status" ];then
        # 记录资源被heartbeat调用时的时间
        date +%s >${HARESOURCE_TIME_STAMP}
    fi

    if [ "$operation" == "notify" ];then
        # 记录资源告警或恢复告警
        resourceNotify "$@"
        return $?
    fi
    
    RM_CURENT_FAIL_DIR=$GM_PATH/data/ha/rm/current/$resourceName

    errcode=1
    if [ -z "${monitorScript}" ]; then
        LOG_ERROR "The monitorScript parameter is empty, $*"
        return 2 
    fi

    if [ -z "${resourceName}" ]; then
        LOG_ERROR "The resourceName parameter is empty, $*"
        return 2
    fi
    
    if [ ! -f "${monitorScript}" ]; then
        LOG_ERROR "${monitorScript} is not exists"
        echo "This command is unavailable in the current deployment scenario."
        return 2
    fi
    
    case "$operation" in
        start|stop|restart|status|notify )
            :
            ;;
        -h )
            usage
            exit 0
            ;;
        *) 
            ECHOANDLOG_ERROR "Paramter error, $operation"
            usage
            return 2
            ;;
    esac
    
    ret=0
    ha_do_action "$opuser" "${monitorScript}" "${operation}" "$role" || ret=$errcode

    return $ret
}
