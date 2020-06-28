#!/bin/bash

get_process_list()
{
    cd $RM_CONF_DIR
    ls *.xml | sed 's/\.xml$//'
}

process_operate()
{
    local action="$1"
    shift
    for proc in $*; do 
        if [ "$proc" != "gsdb" ] ; then
            procScript="$RM_SCRIPT_DIR/${proc}.sh"
        else
            proc="gaussDB"
            procScript="$RM_SCRIPT_DIR/rcommgsdb"
        fi
        
        if [ "$DUALMODE" == "0" ] && echo "$proc" | grep "floatip$" > /dev/null; then
            continue
        fi

        $procScript "$action" active 0 >/dev/null 2>&1 < /dev/null &
        pid=$!

        BACK_PID_LIST="$BACK_PID_LIST $proc:$pid"
    done
}

do_action()
{
    local action=$1
    [ -z "$action" ] && { echo "no action specificed!"; return 1; }

    BACK_PID_LIST=""
    NORAMAL_RES_LIST=""
    ABNORAMAL_RES_LIST=""
    local relaction=""

    # get fm procecss list from conf
    local process_list=$(get_process_list)
    process_operate "$action" "$process_list"

    local failResList=""
    for process in $BACK_PID_LIST; do 
        process_name=${process%%:*}
        pid=${process##*:}
        process_status="abnormal"

        LOG_INFO "wait $process_name:$pid"
        wait $pid
        if [ $? -eq 0 ] ; then
            process_status="normal"
        else
            failResList="$failResList $process_name"
        fi
        process_info="${process_name}\t${process_status}"
        echo -e $process_info
    done
    
    if [ -n "$failResList" ]; then
        LOG_ERROR "$action failed for resources:$failResList."
    else
        LOG_INFO "$action success for all resources"
    fi
}

# 检查浮动IP是否已经停止
isFloatIpStopped()
{
    # clean floatip if exist
    $RM_SCRIPT_DIR/exfloatip.sh status >>${LOG_FILE} 2>&1 && return 1
    LOG_INFO "$RM_SCRIPT_DIR/exfloatip.sh status return $?"
    
    # 一体机场景，停止内网IP
    if [ "$DEPLOY_MODE" == "0" ];then
        isInEscFloatIpStopped || return 1
    fi
    
    return 0
}

# 检查内网及逃生通道浮动IP是否已经停止
isInEscFloatIpStopped()
{
    $RM_SCRIPT_DIR/infloatip.sh status >>${LOG_FILE} 2>&1 && return 1
    LOG_INFO "$RM_SCRIPT_DIR/infloatip.sh status return $?"
    
    $RM_SCRIPT_DIR/escfloatip.sh status >>${LOG_FILE} 2>&1 && return 1
    LOG_INFO "$RM_SCRIPT_DIR/escfloatip.sh status return $?"

    return 0
}

stopFloatIpExcludeExIp()
{
    # 停止除exfloatip之外的其他浮动IP
    $RM_SCRIPT_DIR/infloatip.sh relstop >>${LOG_FILE} 2>&1
    LOG_INFO "$RM_SCRIPT_DIR/infloatip.sh relstop return $?"
    
    $RM_SCRIPT_DIR/escfloatip.sh relstop >>${LOG_FILE} 2>&1
    LOG_INFO "$RM_SCRIPT_DIR/escfloatip.sh relstop return $?"
}   
    
# 
EXTERN_RM_CONF=$HA_DIR/module/harm/plugin/conf/extern.conf
GM_PROCESS_CONF=$HA_DIR/module/harm/plugin/conf/process.conf
RES_SCRIPT_DIR=$HA_DIR/module/harm/plugin/script
