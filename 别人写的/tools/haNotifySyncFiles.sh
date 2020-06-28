#!/bin/bash 

########################################
# 错误码
# 2：使用心跳IP无法连上对端
# 其他：内部错误
#############################################

################################################
# init log
################################################
cd "$(dirname $0)"
CUR_PATH=$(pwd)
declare -r ScriptName=`basename $0`

. $CUR_PATH/func/func.sh
. $CUR_PATH/func/dblib.sh

mkdir -p $_HA_SH_LOG_DIR_
chown $DB_USER: $_HA_SH_LOG_DIR_
LOG_FILE=$_HA_SH_LOG_DIR_/haNotifySyncFiles.log

#############

ERR_CONNECT=2
###

getFullPath()
{
    if ! echo "$notifyPath" | grep '\.\.' ; then
        notifyPath=$(echo "$notifyPath" | sed -r 's|/{2,}|/|g' | sed 's|/\.||g')
    else
        local tmpSyncDir=$GM_PATH/data/ha/tmp
        mkdir -p $tmpSyncDir/$notifyPath
        cd $tmpSyncDir/$notifyPath
        notifyPath=$(pwd | sed -r "s|^$tmpSyncDir||")
        cd - > /dev/null 2>&1
    fi
}

usage()
{
    echo "sync file
    [file] sync the file to standby node, if file is empty sync all files which monitor by HA
"
}

main()
{
    local path="$1"

    # 修改日志属组
    [ -e "$LOG_FILE" ] && sudo chown $DB_USER: "$LOG_FILE"

    # if it is single, not to sync file.
    if [ "-${DUALMODE}" = "-0" ]; then
        LOG_INFO "current mode is single mode, not need to notify to sync file then exit..."
        echo "current mode is single mode, not need to notify to sync file then exit..."
        exit 0
    fi
    
    if [ "$path" == "-h" ]; then
        usage
        return 0
    fi
        
    LOG_INFO "enter haNotifySyncFiles path:$(basename $path)"

    if [ -z "$path" ];then
        $HA_CLIENT --syncallfile
        local ret=$?
        LOG_INFO "syncallfile return $ret"
        return $ret
    fi
    
    notifyPath="$path"
    getFullPath
    
    $HA_CLIENT --syncfile --name="$notifyPath"
    local ret=$?
    LOG_INFO "syncfile $(basename $path) return $ret"
    return $ret
}

main "$@"
exit $?
