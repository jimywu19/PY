#!/bin/bash
################################################
# init log
################################################
cd "$(dirname $0)"
CUR_PATH=$(pwd)
declare -r ScriptName=`basename $0`

. $CUR_PATH/../func/func.sh

mkdir -p $_HA_SH_LOG_DIR_
chown $DB_USER: $_HA_SH_LOG_DIR_
LOG_FILE=$_HA_SH_LOG_DIR_/mgr_ip_monitor.log
# end init log

. $HA_DIR/tools/func/globalvar.sh
. $HA_DIR/tools/func/dblib.sh

# IP工具脚本
IPTOOLS_DIR=$HA_DIR/tools/iptools
ESCAPE_IP_TOOL=$IPTOOLS_DIR/escapeIpMonitor.sh
GMN_IN_IP_TOOL=$IPTOOLS_DIR/localGmnInIpMonitor.sh
GMN_EX_IP_TOOL=$IPTOOLS_DIR/localGmnExIpMonitor.sh
GMN_OM_IP_TOOL=$IPTOOLS_DIR/omIpMonitor.sh

startGmnExIp()
{
    local ret=0
    if $GMN_EX_IP_TOOL status > /dev/null; then
        LOG_INFO "gmn ex ip status return 0"
    else
        $GMN_EX_IP_TOOL start > /dev/null
        ret=$?
        [ $ret -eq 0 ] || ((err |= 0x01))
        LOG_INFO "$GMN_EX_IP_TOOL start return $ret, and err:$err"
    fi
    
    # 获取对端IP信息
    getDoubleConfig "$_CONF_FILE_"
    # ICT场景，监控OM IP
    if [ -n "$LOCAL_GMN_OM_IP" ] && [ -f /opt/goku/uninstall/module_path_ict.xml ] ; then
        if $GMN_OM_IP_TOOL status > /dev/null; then
            LOG_INFO "gmn om ip status return 0"
        else
            $GMN_OM_IP_TOOL start > /dev/null
            ret=$?
            [ $ret -eq 0 ] || ((err |= 0x10))
            LOG_INFO "$GMN_OM_IP_TOOL start return $ret, and err:$err"
        fi
    fi
    return $ret
}

date +%s > $HAMON_CRON_FLAG

err=0
if [ "$DEPLOY_MODE" == "1" ];then
    startGmnExIp
    ret=$?
    exit 0
else
    lockWrapCall "$MODIFY_IP_LOCK" startGmnExIp
    ret=$?
    [ $ret -eq 0 ] || ((err |= 0x01))
    LOG_INFO "startGmnExIp return $ret, and err:$err"
    
    if $GMN_IN_IP_TOOL status > /dev/null; then
        LOG_INFO "gmn in ip status return 0"
    else
        $GMN_IN_IP_TOOL start > /dev/null
        ret=$?
        [ $ret -eq 0 ] || ((err |= 0x01))
        LOG_INFO "$GMN_IN_IP_TOOL start return $ret, and err:$err"
    fi
    
    if $ESCAPE_IP_TOOL status > /dev/null; then
        LOG_INFO "gmn esc ip status return 0"
    else
        $ESCAPE_IP_TOOL start > /dev/null
        ret=$?
        [ $ret -eq 0 ] || ((err |= 0x01))
        LOG_INFO "$ESCAPE_IP_TOOL start return $ret, and err:$err"
    fi
    
    exit $err
fi

