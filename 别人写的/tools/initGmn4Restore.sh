#!/bin/bash

cd "$(dirname $0)"
CUR_PATH=$(pwd)
. $CUR_PATH/func/func.sh

LOG_FILE=$_HA_SH_LOG_DIR_/initGmn4Restore.log

die()
{
    LOG_ERROR "$*"
    echo $*
    exit 1
}

swapGmnConf()
{
    local tmpConf="$BACKUP_CONF_FILE".tmp
    cp -af $BACKUP_CONF_FILE $tmpConf || return 1
    sed -i "s/LOCAL/_TMP_LABELS_/" $tmpConf || return 1
    sed -i "s/REMOTE/LOCAL/" $tmpConf || return 1
    sed -i "s/_TMP_LABELS_/REMOTE/" $tmpConf || return 1
    
    LOG_INFO "swapGmnConf LOCAL_GMN_EX_IP:$LOCAL_GMN_EX_IP, REMOTE_GMN_EX_IP:$REMOTE_GMN_EX_IP, LOCAL_nodeName:$LOCAL_nodeName, REMOTE_nodeName:$REMOTE_nodeName"

    local FIRST_NODE=$(echo -e "$LOCAL_nodeName\n$REMOTE_nodeName" | sort -f | head -1)
    
    if [ "$FIRST_NODE" == "$LOCAL_nodeName" ];then
        LOG_INFO "local node is first node"
        
        BACKUP_CONF_FILE_NODE1="$BACKUP_CONF_FILE"
        BACKUP_CONF_FILE_NODE2="$tmpConf"
    else
        LOG_INFO "local node is seconde node"
        
        BACKUP_CONF_FILE_NODE1="$tmpConf"
        BACKUP_CONF_FILE_NODE2="$BACKUP_CONF_FILE"
    fi
}

getNodeNum()
{
    if [ "$NODE_NUM" == "1" -o "$NODE_NUM" == "2" ]; then
        LOG_INFO "NODE_NUM:$NODE_NUM is valid, no need to getNodeNum"
        return
    fi
    
    if ! [ -f "$RUN_TIME_CONF_FILE" ]; then
        LOG_INFO "$RUN_TIME_CONF_FILE is not exsit, cannot need to getNodeNum"
        return
    fi
    
    getOldDoubleConfig "$RUN_TIME_CONF_FILE"
    FIRST_NODE=$(echo -e "$OLD_LOCAL_nodeName\n$OLD_REMOTE_nodeName" | sort -f | head -1)
    LOG_INFO "getNodeNum FIRST_NODE:$FIRST_NODE, OLD_LOCAL_nodeName:$OLD_LOCAL_nodeName, OLD_REMOTE_nodeName:$OLD_REMOTE_nodeName"
    
    if [ "$FIRST_NODE" == "$OLD_LOCAL_nodeName" ];then
        LOG_INFO "local node is first node"
        NODE_NUM="1"
    else
        LOG_INFO "local node is seconde node"
        NODE_NUM="2"
    fi
}

SRC_DIR="$HA_DIR/conf/"

GMN_MODE_SINGLE="s"
GMN_MODE_DOUBLE="d"
GMN_MODE=""
HA_TOOLS_DIR=$HA_DIR/tools
HA_CONF_DIR=$HA_DIR/conf
    
# 一体机场景，HA配置文件模板
FC_CFG_DIR=$HA_CONF_DIR/allInOne
FC_SINGLE_CFG=$FC_CFG_DIR/MODE1/gmn.cfg
FC_DOUBLE_LOCAL_CFG=$FC_CFG_DIR/MODE2/node1/gmn.cfg
FC_DOUBLE_REMOTE_CFG=$FC_CFG_DIR/MODE2/node2/gmn.cfg

# 非一体机场景，HA配置文件模板，需要用户在执行本脚本的时候先修改该配置文件模板
NONE_FC_CFG_DIR=$HA_CONF_DIR/noneAllInOne
NONE_FC_CFG=$NONE_FC_CFG_DIR/gmn.cfg

RUN_TIME_CONF_FILE=$SRC_DIR/runtime/gmn.cfg
BACKUP_CONF_FILE=$SRC_DIR/runtime/gmn.cfg.restore
BACKUP_CONF_FILE_NODE1=$SRC_DIR/runtime/gmn.cfg.restore
BACKUP_CONF_FILE_NODE2=$SRC_DIR/runtime/gmn.cfg.restore.swap

# 检查是否是root用户执行的
checkUserRoot

############################## main ######################################
#
##########################################################################
LOG_INFO "enter initGmn4Restore $*"

NODE_NUM=""
getDoubleConfig "$BACKUP_CONF_FILE"

FC_INIT_PARA=""
if echo "$haMode" | grep -wiE "^false|1$" >/dev/null; then
    LOG_INFO "initGmn4Restore single mode"
    
    GMN_MODE="$GMN_MODE_SINGLE"
    FC_INIT_PARA="-m s"
else
    LOG_INFO "initGmn4Restore double mode"
    
    GMN_MODE="$GMN_MODE_DOUBLE"
    swapGmnConf || die "swapGmnConf failed"
    
    # 获取节点编号
    getNodeNum
    
    if [ "$NODE_NUM" == "1" ];then
        FC_INIT_PARA="-m d -n 1"
        BACKUP_CONF_FILE="$BACKUP_CONF_FILE_NODE1"
    elif [ "$NODE_NUM" == "2" ];then
        FC_INIT_PARA="-m d -n 2"
        BACKUP_CONF_FILE="$BACKUP_CONF_FILE_NODE2"
    else
        die "node is ha mode, must give parameter for node num"
    fi
fi

# make directory
mkdir -p $SRC_DIR || die "mkdir failed"

if ! [ -n "$LOCAL_GMN_ESCAPE_IP" ];then
    LOG_INFO "start $HA_TOOLS_DIR/gmninit.sh "1" "restore" "$BACKUP_CONF_FILE""
    # 非一体机
    # 使用恢复的方式初始化gmn
    $HA_TOOLS_DIR/gmninit.sh "1" "restore" "$BACKUP_CONF_FILE" || die "gmninit.sh 1 restore $BACKUP_CONF_FILE failed "
    
    cp -af "$BACKUP_CONF_FILE" $SRC_DIR/runtime/gmn.cfg || die "cp -af $BACKUP_CONF_FILE $SRC_DIR/runtime/gmn.cfg failed"
    cp -af "$BACKUP_CONF_FILE" $SRC_DIR/noneAllInOne/gmn.cfg || die "cp -af $BACKUP_CONF_FILE $SRC_DIR/noneAllInOne/gmn.cfg failed"
else
    LOG_INFO "start $HA_TOOLS_DIR/gmninit.sh "0" "restore" "$BACKUP_CONF_FILE" $FC_INIT_PARA"
    
    # 一体机场景
    # 使用恢复的方式初始化gmn
    $HA_TOOLS_DIR/gmninit.sh "0" "restore" "$BACKUP_CONF_FILE" $FC_INIT_PARA || die "gmninit.sh 0 restore $BACKUP_CONF_FILE $FC_INIT_PARA failed "
    
    cp -af "$BACKUP_CONF_FILE" $SRC_DIR/runtime/gmn.cfg || die "cp -af $BACKUP_CONF_FILE $SRC_DIR/runtime/gmn.cfg failed"
fi

ECHOANDLOG_INFO "init for restore successful"

exit 0
