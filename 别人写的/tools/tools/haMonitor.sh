#!/bin/bash

################################################
# init log
################################################
cd "$(dirname $0)"
CUR_PATH=$(pwd)
declare -r ScriptName=`basename $0`

. /etc/profile 2>/dev/null
. $CUR_PATH/func/func.sh || { echo "fail to load $CUR_PATH/func/func.sh"; exit 1; }

mkdir -p $_HA_SH_LOG_DIR_
chown $DB_USER: $_HA_SH_LOG_DIR_
LOG_FILE=$_HA_SH_LOG_DIR_/ha_monitor.log

GMN_BIN_DIR=$GM_PATH/bin

OMMONITOR_ACCESS_FLAG=$_HA_SH_LOG_DIR_/ommonitor_access.flag
OMMONITOR_MON_FLAG=$_HA_SH_LOG_DIR_/ommonitor_mon.flag

. $CUR_PATH/func/dblib.sh

#################################################

die()
{
    ECHOANDLOG_ERROR "$*"
    exit 1
}

HAMON_CRON_TIME_OUT=300
HAMON_CRON_FAIL_TIMES=10

# 如果HA Mon的定时任务连续10次在5分钟内都没有被调用到，需要重启HA Mon
function check_ha_mon_time_stamp()
{
    BASEDIR="$GM_PATH"
    INSTANCE_LABEL="tomcat.instance.name=ommonitor"
    local haInfo=$(ps -ww -eo pid,etime,cmd | grep "${BASEDIR}/tomcat" | grep "org.apache.catalina.startup.Bootstrap" | grep "$INSTANCE_LABEL\>" | grep -v grep)
    local hbPid=$(echo "$haInfo" | awk '{print $1}')

    if [ -z "$hbPid" ];then
        LOG_WARN "hamon is not running, no need to restart"
        rm -f $OMMONITOR_MON_FLAG
        return 0
    fi
    
    local hbEtime=$(echo "$haInfo" | awk '{print $2}')
    local timeSeg=$(echo "$hbEtime" | awk -F: '{print NF}')
    local -i mins=$(echo "$hbEtime" | awk -F: '{print $1}' | sed 's/^0*//g')
    
    # ha mon启动6分钟后，再检测是否需要判断ha mon的定时任务是否生效
    AFTER_START_TIME=6
    if [ $timeSeg -le 2 -a $mins -lt $AFTER_START_TIME ];then
        LOG_INFO "hbEtime:$hbEtime is less then $AFTER_START_TIME, so no need to continue check ha mon monitor failed"
        rm -f $OMMONITOR_MON_FLAG
        return 0
    fi

    if [ ! -f ${HAMON_CRON_FLAG} ]; then
        date +%s >${HAMON_CRON_FLAG}
        rm -f $OMMONITOR_MON_FLAG
        return 0
    fi
    
    local old_seconds=$(cat "${HAMON_CRON_FLAG}" | tr -d ' ')
    local new_seconds=$(date +%s)
    local time=$(expr ${new_seconds} - ${old_seconds})
    LOG_INFO "new_seconds=${new_seconds} , old_seconds=${old_seconds}, diff=${time}"
    
    if [ ${time} -ge ${HAMON_CRON_TIME_OUT} ]; then
        if ! [ -e $OMMONITOR_MON_FLAG ]; then
            LOG_WARN "ha mon monitor exception at time:1, max retry:$HAMON_CRON_FAIL_TIMES, no need restart ha mon"
            echo 1 > $OMMONITOR_MON_FLAG
        else
            local -i retry=$(cat $OMMONITOR_MON_FLAG)
            if [ $retry -gt $HAMON_CRON_FAIL_TIMES ]; then
                rm -f $OMMONITOR_MON_FLAG
                LOG_ERROR "ha mon monitor exception at time:$retry, max retry:$HAMON_CRON_FAIL_TIMES, need restart ha mon"
                su - root -c "$GMN_BIN_DIR/ommonitor_monitor.sh restart"
                return 0
            else
                LOG_WARN "ha mon monitor exception at time:$retry, max retry:$HAMON_CRON_FAIL_TIMES, no need restart ha mon"
                ((retry++))
                echo $retry > $OMMONITOR_MON_FLAG
            fi
        fi
    else
        LOG_INFO "ha mon monitor turn normal, rm -f $OMMONITOR_MON_FLAG"
        rm -f $OMMONITOR_MON_FLAG
        
        # 如果时间差为负数，则更新一下hamon的定时任务生效时间
        if [ $time -lt 0 ]; then
            LOG_INFO "time:$time -lt 0, date +%s > ${HAMON_CRON_FLAG}"
            date +%s > ${HAMON_CRON_FLAG}
        fi
    fi

    return 0
}

main()
{
    if ps -ww -eo pid,cmd | grep -w "haStartAll.sh" | awk '{print $2, $3}' | grep "^/bin/bash $HA_DIR/tools/haStartAll.sh$" > /dev/null; then
        LOG_INFO "$HA_DIR/tools/haStartAll.sh is running, exit now"
        return 0
    fi
    
    $STATUS_HA_MON_TOOL > /dev/null
    local ret=$?
    if [ $ret -ne 0 ] ; then
        LOG_ERROR "$STATUS_HA_MON_TOOL return $ret, start now"
        $START_HA_MON_TOOL
        ret=$?
        LOG_INFO "$START_HA_MON_TOOL return $ret"
    fi
    
    # TODO STATUS_HA_MON_TOOL 僵死处理，如果连续mon检测正常，但是HA不正常未启动，则重启mon
    
    # TODO 清除单主资源故障，暂时将定时任务放在这里
    $OMSCRIPT/clearFailed.sh > /dev/null 2>&1 < /dev/null &
    
    # TODO 备机数据库告警，暂时将定时任务放在这里
    $OMSCRIPT/checkRemoteDb.sh > /dev/null 2>&1 < /dev/null &
    
    # 如果是容灾场景，且当前是主站点，启动rsyncd进程，以便备站点同步文件
    if isCascadePrimaryRole ; then
        $OMSCRIPT/rsync_monitor.sh > /dev/null 2>&1 < /dev/null &
    fi
    
    # 安全
    chmod 600 $HA_DIR/local/harm/conf/run_phase.txt
    chmod 600 $HA_DIR/local/haarb/conf/haarb_local.xml
    
    if grep "^@" /etc/security/chroot.conf > /dev/null ; then
        if ! service user-jail status > /dev/null 2>&1 ; then
            service user-jail start > /dev/null
        fi
    fi
    
    rm -f "$OMMONITOR_ACCESS_FLAG"
}

main
