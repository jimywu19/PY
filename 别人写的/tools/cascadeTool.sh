#!/bin/bash

cd "$(dirname $0)"
CUR_PATH=$(pwd)
. $CUR_PATH/func/func.sh
. $HA_DIR/tools/gsDB/dbfunc.sh

LOG_FILE=$_HA_SH_LOG_DIR_/cascadeTool.log

die()
{
    LOG_ERROR "$*"
    echo $*
    exit 1
}

usage()
{
    echo "cascade configure tools
example:
    cascadeTool add -i remoteDcNode1IP:remoteDcNode2IP -r [primary|standby]
    cascadeTool del
    cascadeTool query
    cascadeTool mod -r [primary|standby]
    cascadeTool mod -i remoteDcNode1IP:remoteDcNode2IP
    cascadeTool mod -i remoteDcNode1IP:remoteDcNode2IP -r [primary|standby]
"
}

savePara2GmnConf()
{
    local key=$1
    local cfgFile=$2
    local value=""
    
    if ! [ -f "$cfgFile" ]; then
        LOG_ERROR "$cfgFile is not exsit"
        return 1
    fi
    
    eval "value=\$$key"
    
    if ! echo "$key" | grep -E "^LOCAL_|REMOTE_" > /dev/null; then
        if grep "^$key=" $cfgFile > /dev/null; then
            sed -i "s/^$key=.*$/$key=$value/" $cfgFile
        else
            local type="GLOBAL"
            sed -i "/^\[$type\]/,/\[/ s/^\[$type\]$/&\n$key=$value/" "$cfgFile"
        fi
        
    else
        local relKey="${key#*_}"
        local type="${key%%_*}"

        if grep "^$relKey=" $cfgFile > /dev/null; then
            sed -i "/^\[$type\]/,/\[/ s/^$relKey=.*$/$relKey=$value/" "$cfgFile"
        else
            sed -i "/^\[$type\]/,/\[/ s/^\[$type\]$/&\n$relKey=$value/" "$cfgFile"
        fi
    fi
}

configDbConfig()
{
    local remoteDcIp1=$1
    local remoteDcIp2=$2

    local localIp="$LOCAL_GMN_EX_IP"
    
    local ips4Db=""

    local port="15210"
    
    local -i index=1
    if [ -n "$remoteDcIp1" ]; then
        checkIp "$remoteDcIp1" >> $LOG_FILE 2>&1 || die "The IP($remoteDcIp1) is invalid"
        ((++index))
        ips4Db="localhost=$localIp localport=$port remotehost=$remoteDcIp1 remoteport=$port"
        su - $DB_SYS_USER -c "gs_guc reload -c replconninfo$index=\"'$ips4Db'\" " >> $LOG_FILE 2>&1
        LOG_INFO "gs_guc reload -c replconninfo$index=\"'$ips4Db'\" return $?"
    fi

    if [ -n "$remoteDcIp2" ]; then
        checkIp "$remoteDcIp2" >> $LOG_FILE 2>&1 || die "The IP($remoteDcIp2) is invalid"
        ((++index))
        ips4Db="localhost=$localIp localport=$port remotehost=$remoteDcIp2 remoteport=$port"
        su - $DB_SYS_USER -c "gs_guc reload -c replconninfo$index=\"'$ips4Db'\" " >> $LOG_FILE 2>&1
        LOG_INFO "gs_guc reload -c replconninfo$index=\"'$ips4Db'\" return $?"
    fi
    
    ((++index))
    for ((; index <= 3; ++index)); do
        su - $DB_SYS_USER -c "gs_guc reload -c replconninfo$index=\"''\" " >> $LOG_FILE 2>&1
        LOG_INFO "gs_guc reload -c replconninfo$index=\"''\" return $?"
    done
    
    return 0
}

saveRemoteDcIps()
{
    savePara2GmnConf REMOTE_DC_NODE1_IP "$_CONF_FILE_"

    savePara2GmnConf REMOTE_DC_NODE2_IP "$_CONF_FILE_"

    cp -af "$_CONF_FILE_" $HA_DIR/conf/noneAllInOne/gmn.cfg
    
    # 配置数据库级联
    configDbConfig "$REMOTE_DC_NODE1_IP" "$REMOTE_DC_NODE2_IP"
    
    configDbConfig "$REMOTE_DC_NODE1_IP" "$REMOTE_DC_NODE2_IP"
}

configCascade()
{
    local role="$role"
    local remoteDcIps="$2"
    
    [ -f "$RUN_TIME_CONF_FILE" ] || die "Must configure HA first"

    isCascadeMode && die "In cascade mode already."   
 
    echo "$role" > $CASCADE_CONF
    
    REMOTE_DC_NODE1_IP=$(echo "$remoteDcIps" | awk -F: '{print $1}')
    REMOTE_DC_NODE2_IP=$(echo "$remoteDcIps" | awk -F: '{print $2}')

    if [ -z "$REMOTE_DC_NODE1_IP" ] && [ -z "$REMOTE_DC_NODE2_IP" ]; then
        die "must configure remote IP"
    fi

    if [ "$role" == "$STANDBY_CASCADE_STATE" ]; then
        setRole2Standby
    elif [ "$role" == "$PRIMARY_CASCADE_STATE" ]; then
        setRole2Active
    else
        die "Cascade role($role) is invalid"
    fi
    
    saveRemoteDcIps
 
    LOG_INFO "stop ha process" 
    $STOP_HA_PROC_TOOL
}

setRole2Standby()
{
    if grep -wq rcommgsdb_cascade $HA_RM_CONF/gsdb.xml ; then
        LOG_INFO "There is rcommgsdb_cascade in gsdb.xml, it may be standby"
        return 0
    fi
    
    rm -rf $HA_RM_CASCADE_CONF
    cp -af $HA_RM_CONF $HA_RM_CASCADE_CONF
    cd $HA_RM_CONF
    ls *.xml | grep -Ev "^gsdb.xml$|^exfloatip.xml$" | xargs -i rm -f {}
    sed -i "s/\<rcommgsdb\>/rcommgsdb_cascade/" gsdb.xml
    cd - >/dev/null
}

setRole2Active()
{
    LOG_INFO "set role to active"

    if ! [ -e "$HA_RM_CASCADE_CONF" ] ; then
        LOG_INFO "HA rm cascade configure file is not exist"
    else
        rm -rf $HA_RM_CONF
        cp -af $HA_RM_CASCADE_CONF $HA_RM_CONF
    fi
}

getParametes()
{
    while getopts r:i: option
    do
        case "$option"
        in
            r)  role=$OPTARG
                if [ "$role" != "$PRIMARY_CASCADE_STATE" ] && [ "$role" != "$STANDBY_CASCADE_STATE" ]; then
                    die "The role($role) is invalid"
                fi
                ;;
            i)  remoteDcIps=$OPTARG
                if [ -z "$remoteDcIps" ]; then
                    die "The IP of remote DC is empty"
                fi
                ;;
            *) 
                die "Configure cascade failed, Paramter error, $@"
             ;;
        esac
    done
}

configureCascade()
{
    local role=""
    local remoteDcIps=""
    
    getParametes "$@"
    
    configCascade "$role" "$remoteDcIps"
    
    echo "Configure cascade success."
}

changeRole()
{
    local curRole=$(cat "$CASCADE_CONF")
    
    if [ "$role" != "$STANDBY_CASCADE_STATE" ] && [ "$role" != "$PRIMARY_CASCADE_STATE" ] ; then
        die "The role($role) is invalid"
    fi
    
    if [ "$curRole" == "$role" ]; then
        LOG_INFO "The state is in role($role) now, no need to change"
        echo "The state is in role($role) now, no need to change"
        return 0
    fi
    
    if [ "$role" == "$STANDBY_CASCADE_STATE" ]; then
        setRole2Standby
    else
        setRole2Active
    fi
    
    echo "$role" > $CASCADE_CONF
    
    LOG_INFO "stop ha process"
    # 停止HA
    $STOP_HA_PROC_TOOL
}

changeConfigure()
{
    [ -f "$CASCADE_CONF" ] || die "Please configure cascade first"
    
    local role=""
    local remoteDcIps=""
    
    getParametes "$@"
    
    if [ -n "$role" ]; then
        changeRole "$role"
    fi
    
    if [ -n "$remoteDcIps" ]; then
        REMOTE_DC_NODE1_IP=$(echo "$remoteDcIps" | awk -F: '{print $1}')
        REMOTE_DC_NODE2_IP=$(echo "$remoteDcIps" | awk -F: '{print $2}')
        
        saveRemoteDcIps
    fi
    
    echo "Modify cascade configuration success."
}

deleteConfigure()
{
    # 删除标记文件
    rm -f "$CASCADE_CONF"

    # 删除双机容灾链路
    configDbConfig "" ""
    
    # 执行设置角色为主角色操作，取消容灾功能
    setRole2Active
    
    sleep 2
    
    LOG_INFO "stop ha process"
    # 停止HA
    $STOP_HA_PROC_TOOL  

    echo "Delete cascade configuration success."
}

queryConfigure()
{
    if ! isCascadeMode ; then
        printf "%-32s : %s\n" "cascade role" "none"
        return 0
    fi
    
    local role=""
    
    if isCascadePrimaryRole ; then
        role="$PRIMARY_CASCADE_STATE"
    else
        role="$STANDBY_CASCADE_STATE"
    fi
    
    printf "%-32s : %s\n" "cascade role" "$role"
   
    local nodeIndex=1
    if [ -n "$REMOTE_DC_NODE1_IP" ]; then
        printf "%-32s : %s\n" "node$nodeIndex of remote dc" "$REMOTE_DC_NODE1_IP"
        ((++nodeIndex))
    fi
    
    if [ -n "$REMOTE_DC_NODE2_IP" ]; then
        printf "%-32s : %s\n" "node$nodeIndex of remote dc" "$REMOTE_DC_NODE2_IP"
    fi
    
    eval "$(QueryHaState)"
    
    local dbinfo=$($DB_SCRIPT query 2>/dev/null)
    getDBState "$dbinfo"; retVal=$?
    
    nodeStatus=""
    syncStatus=""

    if [ "$LOCAL_STATE" == "active" ]; then
        getActiveNodeStatus "$role"
    elif [ "$LOCAL_STATE" == "standby" ]; then
        getStandbyNodeStatus "$role"
    else
        nodeStatus="abnormal"
        syncStatus="abnormal"
    fi

    printf "%-32s : %s\n" "node status" "$nodeStatus"
    printf "%-32s : %s\n" "sync status" "$syncStatus"
}

getActiveNodeStatus()
{
    local role="$1"
    
    if [ "$role" == "$PRIMARY_CASCADE_STATE" ]; then
        # 如果数据库角色不是期待的，则节点异常
        if [ "$LOCAL_ROLE" != "$gs_r_primary" ]; then
            nodeStatus="abnormal"
            syncStatus="abnormal"
        else
            nodeStatus="normal"
            syncStatus="normal"
        fi
    else 
        if [ "$LOCAL_ROLE" != "$gs_r_cstandby" ]; then
            nodeStatus="abnormal"
            syncStatus="abnormal"
        else
            nodeStatus="normal"
            if echo "$dbinfo" | grep -sqE "CHANNEL.*<--($REMOTE_DC_NODE1_IP|$REMOTE_DC_NODE2_IP):"; then
                syncStatus="normal"
            else
                syncStatus="abnormal"
            fi
        fi
    fi
}

getStandbyNodeStatus()
{
    local role="$1"
    
    if [ "$role" == "$PRIMARY_CASCADE_STATE" ]; then
        # 如果数据库角色不是期待的，则节点异常
        if [ "$LOCAL_ROLE" != "$gs_r_standby" ]; then
            nodeStatus="abnormal"
            syncStatus="abnormal"
        else
            nodeStatus="normal"
            if echo "$dbinfo" | grep -sq "CHANNEL.*$LOCAL_GMN_EX_IP:[0-9]\+ <--"; then
	            if echo "$dbinfo" | grep -sqE "CHANNEL.*-->($REMOTE_DC_NODE1_IP|$REMOTE_DC_NODE2_IP):"; then
	                syncStatus="normal"
	            else
	                syncStatus="abnormal"
	            fi
            else
                syncStatus="abnormal"
            fi
        fi
    else 
        if [ "$LOCAL_ROLE" != "$gs_r_cstandby1" ]; then
            nodeStatus="abnormal"
            syncStatus="abnormal"
        else
            nodeStatus="normal"
            if echo "$dbinfo" | grep -sq "CHANNEL.*$LOCAL_GMN_EX_IP:[0-9]\+ <--"; then
                syncStatus="normal"
            else
                syncStatus="abnormal"
            fi
        fi
    fi
}

main()
{
    LOG_INFO "enter cascadeTool $*"

    local action="$1"
    shift
    
    getDoubleConfig "$_CONF_FILE_"

    case "$action" in
        "add")
            configureCascade "$@"
            ;;
        "mod")
            changeConfigure "$@"
            ;;
        "del")
            deleteConfigure "$@"
            ;;
        "query")
            queryConfigure "$@"
            ;;
        *)
            usage
            ;;
    esac
    
    local ret=$?
    LOG_INFO "leave cascadeTool return $?"
    
    return $ret
}

HA_TOOLS_DIR=$HA_DIR/tools
HA_CONF_DIR=$HA_DIR/conf

HA_RM_CONF=$HA_DIR/module/harm/plugin/conf
HA_RM_CASCADE_CONF=$HA_DIR/module/harm/plugin/conf.backup4cascade
DB_SCRIPT=$HA_DIR/module/harm/plugin/script/rcommgsdb

HA_OMSCRIPT_PATH=$HA_TOOLS_DIR/omscript

RUN_TIME_CONF_FILE=$HA_CONF_DIR/runtime/gmn.cfg

DB_SYS_USER=dbadmin

# 检查是否是root用户执行的
checkUserRoot

############################## main ######################################
#
##########################################################################

main "$@"

exit 0
