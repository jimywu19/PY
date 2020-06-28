#!/bin/bash
set +x

################################################
# init log
################################################
cd "$(dirname $0)"
CUR_PATH=$(pwd)

declare -r ScriptName=`basename $0`
. /etc/profile 2>/dev/null
. $HA_DIR/tools/func/func.sh || { echo "fail to load $HA_DIR/tools/func/func.sh"; exit 1; }
. $HA_DIR/tools/func/globalvar.sh || { echo "fail to load $HA_DIR/tools/func/globalvar.sh"; exit 1; }

mkdir -p $_HA_SH_LOG_DIR_
chown $DB_USER: $_HA_SH_LOG_DIR_
LOG_FILE=$_HA_SH_LOG_DIR_/checkRemoteDb.log
# end init log

. $HA_DIR/tools/func/dblib.sh || die "fail to load $HA_DIR/tools/func/dblib.sh"
. $HA_DIR/tools/gsDB/dbfunc.sh

getDBStatusInfo()
{
    su - $DB_USER -c $HA_DIR/tools/gsDB/dbStatusInfo.sh 
}

proccess()
{
    if isRemoteDown ; then
        LOG_INFO "remote node is down, no need to handle"
        return 0
    fi
    
    local dbinfo=$(getDBStatusInfo)
    getDBState "$dbinfo"; retVal=$?
    
    if [ "$LOCAL_ROLE" != "$gs_r_primary" ]; then
        return 0
    fi

    local REMOTE_HOST=$REMOTE_nodeName
    if [ "$PEER_ROLE" == "$gs_r_standby" ]; then
        # �����ݿ�״̬����
        resumeResourceAlarm "$STANDBY_DB_RES:$REMOTE_HOST" 0
        resumeResourceAlarm "$PRIMARY_DB_RES:$REMOTE_HOST" 0
    else
        # �����ݿ�״̬�쳣
        sendResourceAlarm "$STANDBY_DB_RES:$REMOTE_HOST" 1
    fi
}
function main()
{
    # ��˫�����𣬲���Ҫ��鱸�����ݿ�
    if [ "$DUALMODE" != "1" ]; then
        return 0
    fi
    
    local lockFile=$HA_GLOBAL_DATA_DIR/checkRemoteDb.lock
    lockWrapCall "$lockFile" proccess "$@"
    return $?
}

main $*
