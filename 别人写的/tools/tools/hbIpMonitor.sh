#!/bin/bash

################################################
# init log
################################################
cd "$(dirname $0)"
CUR_PATH=$(pwd)
declare -r ScriptName=`basename $0`

. $CUR_PATH/func/func.sh || { echo "fail to load $CUR_PATH/func/func.sh"; exit 1; }
mkdir -p $_HA_SH_LOG_DIR_
chown $DB_USER: $_HA_SH_LOG_DIR_
LOG_FILE=$_HA_SH_LOG_DIR_/hbIpMonitor.log

. $CUR_PATH/func/dblib.sh
. /etc/profile 2>/dev/null

GMN_BIN_DIR=/opt/goku/services/common/bin/
HA_OM_PATH=$HA_DIR/tools/omscript

#################################################

main()
{
    chown $GMN_USER: $_HA_LOG_DIR_/core/ -R
    chown $GMN_USER: $_HA_LOG_DIR_/runlog/ -R
    chown $GMN_USER: $_HA_LOG_DIR_/scriptlog/ -R
    
    if [ "$DUALMODE" == "0" ]; then
        LOG_INFO "in single mode, no need to run"
        return 0
    fi
    
    # 获取ha配置
    getDoubleConfig "$_CONF_FILE_"
    
    IP_COLLISION_LIST=""
    
    if ! checkHeartbeatIpCollision >> $LOG_FILE 2>&1;then
        # 心跳IP不冲突
        LOG_INFO "checkHeartbeatIpCollision not return 0, there is not hb ip collision"
        return 0
    fi
    
    # 心跳IP冲突，停止所有服务，创建IP冲突标记
    IP_COLLISION_LIST=$(echo "$IP_COLLISION_LIST" | sed 's/^ //')
    echo -e "collision ip:$IP_COLLISION_LIST\ncollision time:$(date)" > $HA_HB_IP_COLLISION_FLAG
    LOG_WARN "checkHeartbeatIpCollision return 0, there is hb ip collision, need to stop service"
    
    $GMN_BIN_DIR/stopALL.sh >> $LOG_FILE 2>&1
    LOG_INFO "$GMN_BIN_DIR/stopALL.sh end"
}

main
