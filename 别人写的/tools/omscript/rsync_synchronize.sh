#!/bin/bash
set +x
fpr1nt="$fpr1nt@$$"
__dig__=`md5sum $0|awk '{print $1}'` 

################################################
# init log
################################################
cd "$(dirname $0)"
CUR_PATH=$(pwd)
declare -r ScriptName=`basename $0`

# end init log
. $CUR_PATH/../func/func.sh || { echo "fail to load $CUR_PATH/func/func.sh"; exit 1; }
. $HA_DIR/tools/func/globalvar.sh || { echo "fail to load $HA_DIR/tools/func/globalvar.sh"; exit 1; }

mkdir -p $_HA_SH_LOG_DIR_
chown $DB_USER: $_HA_SH_LOG_DIR_

LOG_FILE=$_HA_SH_LOG_DIR_/rsync_synchronize.log
# end init log

. $HA_DIR/tools/func/dblib.sh

# 获取对端IP信息
getDoubleConfig "$_CONF_FILE_"

SYNC_IP=""

rsync_synchronize_key=${CUR_PATH}/rsync_synchronize_commond.sh

function execute()
{
    local force="$1"
    local path="$2"
    local syncPara="$3"
    
    local ret=0
    
    if [ "$syncPara" = "sync" ]; then
        # 同步的方式同步文件
        sh ${CUR_PATH}/rsync_synchronize_commond.sh "$SYNC_IP" "$path" "$force" >>${LOG_FILE} 2>&1
        ret=$?
    else
        # 异步的方式同步文件
        sh ${CUR_PATH}/rsync_synchronize_commond.sh "$SYNC_IP" "$path" "$force" >>${LOG_FILE} 2>&1 < /dev/null &
        ret=$?
    fi
    
    return $ret
}

# in standby host run rsyn data
function checkModle()
{
    if ! isCascadeStandbyRole;then
        LOG_INFO "current role is not standby cascade, don't need rsync date, exit..."
        exit 1
    fi
    
    local force="$1"
    if [ "$force" == "-f" ]; then
        LOG_INFO "in force sync mode"
        return 0
    fi
}

getRemoteDcIp()
{
    local dbInfo=""
    # 高斯DB用户
    local DB_PWD=$(grep "^$GSDB_ROLE:" $BASE_DIR/data/config/DBKey.cfg | sed "s/^$GSDB_ROLE://")
    
    local dbPwd=$(/usr/local/bin/pwswitch -d "$DB_PWD" -fp "$fpr1nt")
    dbInfo=$(su - dbadmin -c "gs_ctl query -P $dbPwd"); retVal=$? ;
    unset dbPwd
    unset DB_PWD
    
    SYNC_IP=""
    if [ $retVal -eq 0 ] && [ -n "$dbInfo" ]; then
        SYNC_IP=$(echo "$dbInfo" | sed -rn "/\s*Receiver info:/,/\s*CHANNEL\>/p" | grep CHANNEL -w | awk -F"<--" '{print $2}' | awk -F: '{print $1}')
        LOG_INFO "get SYNC_IP($SYNC_IP) from gs_ctl query"
        return 0
    fi
    
    SYNC_IP="$REMOTE_DC_NODE1_IP"
    if [ -n "$SYNC_IP" ] && check_ip_connect "$SYNC_IP" "3"; then
        LOG_INFO "get SYNC_IP($SYNC_IP) from remote dc node1 IP"
        return 0
    fi
    
    SYNC_IP="$REMOTE_DC_NODE2_IP"
    if [ -n "$SYNC_IP" ] && check_ip_connect "$SYNC_IP" "3"; then
        LOG_INFO "get SYNC_IP($SYNC_IP) from remote dc node2 IP"
        return 0
    fi

    LOG_ERROR "get SYNC_IP failed"
    exit 0
}

function main()
{   
    local force="$1"
    local path="$2"
    local syncPara="$3"
    
    LOG_INFO "Enter rsync: force:$force, path:$path, syncPara:$syncPara"
    checkModle "$force"
    
    getRemoteDcIp
    
    execute "$force" "$path" "$syncPara"
    local ret=$?
    LOG_INFO "Eixt rsync: force:$force, path:$path, syncPara:$syncPara, ret=$ret"
    
    return $ret
}

main $*
