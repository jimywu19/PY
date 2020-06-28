#!/bin/bash

################################################
# init log
################################################
cd "$(dirname $0)"
CUR_PATH=$(pwd)
declare -r ScriptName=`basename $0`
# end init log

OCF_GMN_DIR=/usr/lib/ocf/resource.d/gmn

. $CUR_PATH/func/func.sh

mkdir -p $_HA_SH_LOG_DIR_
chown $DB_USER: $_HA_SH_LOG_DIR_
LOG_FILE=$_HA_SH_LOG_DIR_/haStopAll.log

. $HA_DIR/tools/func/gmnfunc.sh

usage()
{
    echo "stop HA process
    emptyParameter stop HA
    -f stop HA only
    -o stop HA only
    -r stop HA, remove HA monitor from crontab
    -a stop HA and all process which monitor by HA, remove HA monitor from crontab
    -h show help
example:
    haStartAll
    haStartAll -f
    haStartAll -o
    haStartAll -r
    haStartAll -a
"
}

# ֹͣ����IP
stopFloatIp()
{
    if [ "$DUALMODE" == "0" ]; then
        return 0
    fi
    
    if isFloatIpStopped ; then
        LOG_INFO "float ip is stopped, no need to stop it"
        return 0
    fi
    
    LOG_INFO "float ip is not stopped, stop it"
    
    $RM_SCRIPT_DIR/exfloatip.sh stop >>${LOG_FILE} 2>&1
    LOG_INFO "$RM_SCRIPT_DIR/exfloatip.sh stop return $?"
    
    # һ���������ֹͣ����������IP֮�����������IP
    if [ "$DEPLOY_MODE" == "0" ];then
        stopFloatIpExcludeExIp >>${LOG_FILE} 2>&1
    fi
    
    isFloatIpStopped || return 1
    
    return 0
}

# ����Ƿ���root�û�ִ�е�
checkUserRoot

# -o ͣHA�Ľ��̣�Ȼ��ɾ�����HA�Ķ�ʱ����
# -f ��ͣHA�Ľ���
# -a ֹͣHA�����صĽ���
# �հײ��� ֹͣHA������IP
# ����֮��Ĳ��������磺-r ֹͣHA������IP��Ȼ��ɾ�����HA�Ķ�ʱ����
STOP_OPTS="$1"

LOG_INFO "enter haStopAll STOP_OPTS:$STOP_OPTS"

case "$STOP_OPTS" in
    "" )
        :
        ;;
    -a|-r|-f|-o )
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

if [ -n "$STOP_OPTS" ] && [ "$STOP_OPTS" != "-f" ];then
    $HA_DIR/install/unreg_ha.sh >> $LOG_FILE 2>&1 || die "unreg ha failed"
    ECHOANDLOG_INFO "unreg ha successful"
fi

# TODO stop hamon

if [ "$STOP_OPTS" == "-a" ];then
    $HA_STOP_TOOL || die "stop ha failed"
    
    $HA_DIR/tools/gmnEx.sh stop >> $LOG_FILE 2>&1
    LOG_INFO "stop ha and all process successful"
elif [ "$STOP_OPTS" == "-o" ] || [ "$STOP_OPTS" == "-f" ];then
    $STOP_HA_MON_TOOL || die "stop ha monitor failed"
    $STOP_HA_PROC_TOOL || die "stop ha process failed"
    LOG_INFO "stop ha monitor and process successful"
else
    $STOP_HA_MON_TOOL || die "stop ha monitor failed"
    $STOP_HA_PROC_TOOL || die "stop ha process failed"
    LOG_INFO "stop ha monitor and process successful"

    # ֹͣ����IP
    stopFloatIp || die "stop floating ip failed"
    LOG_INFO "stopFloatIp successful"
fi

ECHOANDLOG_INFO "stop ha successful"
