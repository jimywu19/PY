#!/bin/bash

################################################
# init log
################################################
cd "$(dirname $0)"
CUR_PATH=$(pwd)

declare -r ScriptName=`basename $0`
. /etc/profile 2>/dev/null
. $HA_DIR/tools/func/func.sh || { echo "fail to load $HA_DIR/tools/func/func.sh"; exit 1; }

mkdir -p $_HA_SH_LOG_DIR_
LOG_FILE=$_HA_SH_LOG_DIR_/clearFailed.log
# end init log

. $HA_DIR/tools/func/dblib.sh || die "fail to load $HA_DIR/tools/func/dblib.sh"

OMSCRIPT=$CUR_PATH
HA_ACTIVE_RM_FLAG_DIR=$HA_FLAG_DIR/active/rm
mkdir -p $HA_ACTIVE_RM_FLAG_DIR
HA_ACTIVE_RM_FLAG=$HA_ACTIVE_RM_FLAG_DIR/negative.flag

#ha_resource_time_stamp file 
HARESOURCE_TIME_STAMP=${HA_FLAG_DIR}/ha_resource_time_stamp

#resource wait max time
RESOURCE_TIME_OUT=300

# funtion:if the time stamp is greater than 10 minuter，stop heartbeat
function check_ha_resource_time_stamp()
{
    if [ ! -f ${HARESOURCE_TIME_STAMP} ]; then
        LOG_WARN "file:${HARESOURCE_TIME_STAMP} not exsit, touch it"
        date +%s >${HARESOURCE_TIME_STAMP}
        return
    fi
    
    local old_seconds=$(cat "${HARESOURCE_TIME_STAMP}" | tr -d ' ')
    local new_seconds=$(date +%s)
    local time=$(expr ${new_seconds} - ${old_seconds})
    LOG_INFO "new_seconds=${new_seconds} , old_seconds=${old_seconds}, diff=${time}"

    if [ ${time} -ge ${RESOURCE_TIME_OUT} ]; then
        LOG_WARN "ha resource exception, need restart ha"
        $HA_STOP_PROC_TOOL 1>>${LOG_FILE} 2>&1
        date +%s >${HARESOURCE_TIME_STAMP}
    fi
}

clearResourceFault()
{
    local res=
    for res in $SINGLE_RES_LIST ; do
        $HA_CLIENT --clearrmfault --name=$res >> $LOG_FILE 2>&1
        LOG_INFO "HA_CLIENT --clearrmfault --name=$res"
    done
}

# 清除备机主资源组资源负分
clearResourceFaultOnStandby()
{
    local remoteHost=$(echo "$REMOTE_nodeName" | tr [:upper:] [:lower:])
    local curTime=$(date +"%s")

    local oldTime=0
    ((oldTime=curTime-SWITCH_INTERVAL_TIME))
    
    local switchInfo=$(cat "$HA_STATE_FILE"  | awk '{if ($1 > old && $1 < cur) print $1}' "cur=$curTime" "old=$oldTime")
    local maxActiveNum=0
    ((maxActiveNum=(MAX_SWITCH_NUM + 1)/2))
    
    local activeNum=$(echo "$switchInfo" | wc -l)
    if [ $activeNum -ge $maxActiveNum ];then
        LOG_INFO "activeNum=$activeNum, MAX_SWITCH_NUM=$MAX_SWITCH_NUM, there is a lot of switchover, so no need to clear failed on ${remoteHost}"
    else
        # 清除原主机的主资源组的故障
        LOG_WARN "activeNum=$activeNum, MAX_SWITCH_NUM=$MAX_SWITCH_NUM, there is not a lot of switchover, so need to clear failed on ${remoteHost}"
        
        clearResourceFault ""
    fi
    
    # 删除一星期之前的倒换记录
    local overdue=0
    ((overdue = curTime - 7*60*60*24))
    local -i lastOverdue=$(cat "$HA_STATE_FILE" | awk '{if ($1 < overdue) print NR}' "overdue=$overdue" | tail -1)
    local -i total=$(cat "$HA_STATE_FILE" | wc -l)
    if [ $lastOverdue -ge $total ]; then
        ((lastOverdue = total - 1))
    fi
    
    if [ $lastOverdue -gt 0 ]; then
        LOG_INFO "sed -i "1,${lastOverdue}d" "$HA_STATE_FILE""
        sed -i "1,${lastOverdue}d" "$HA_STATE_FILE"
    fi
    
    return 0
}

#
# 功能:检查备资源是否存在负分
function is_need_clear()
{
    LOG_INFO "enter is_need_clear, DUALMODE=$DUALMODE"

    if [ "$DUALMODE" != "0" ]; then
        local remoteHost=$(echo "$REMOTE_nodeName" | tr [:upper:] [:lower:])
        
        # 如果主资源组在对端运行，则需要考虑清除主资源组在本节点上的故障
        getHaState
        if [ "$LOCAL_STATE" != "$STANDBY_STATE" ];then
            LOG_INFO "LOCAL_STATE:$LOCAL_STATE is not $STANDBY_STATE, no need to clear primary grp"
            return 0
        fi

        # 清除备机资源故障
        clearResourceFaultOnStandby
    fi
}

procClearFailed()
{
    LOG_INFO "------- start clearFailed.sh -------"
    date +%s > $HAMON_CRON_FLAG

    # 获取对端IP信息
    getDoubleConfig "$_CONF_FILE_"
    MYNODENAME="$LOCAL_nodeName"

    SINGLE_RES_LIST=$($HA_STATUS_TOOL 2>/dev/null | awk '{if ($1 == host && $5 == "Single_active") print $2}' "host=$MYNODENAME")
    if [ -z "$SINGLE_RES_LIST" ]; then
        LOG_INFO "singleResList:$SINGLE_RES_LIST is empty, no need to clear failed"
        return 0
    fi
    
    # 检测是否需要清理
    is_need_clear 

    # 检测本次操作与上次操作时间间隔,如果时间不一致，10分钟重启HA
    
    LOG_INFO "------ clearFailed.sh end -------"
}
function main()
{
    local clearFailedLock=$HA_GLOBAL_DATA_DIR/clearFailed.lock
    lockWrapCall "$clearFailedLock" procClearFailed "$@"
    return $?
}

main $*
