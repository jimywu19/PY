#! /bin/bash
################################################
# init log
################################################
cd "$(dirname $0)"
CUR_PATH=$(pwd)
declare -r ScriptName=`basename $0`

# end init log

. $CUR_PATH/../func/func.sh || { echo "fail to load $CUR_PATH/func/func.sh"; exit 1; }

mkdir -p $_HA_SH_LOG_DIR_
chown $DB_USER: $_HA_SH_LOG_DIR_

LOG_FILE=$_HA_SH_LOG_DIR_/rsync_synchronize.log
# end init log

. $HA_DIR/tools/func/dblib.sh

SYNC_FLAG_FILE=$HA_STANDBY_DATA_DIR/sync.flag

RSYNC_CONF=/etc/rsyncd.conf

# �ļ�ͬ���ϵ�������ʱ·��
SYNC_DATA_DIR=/opt/goku/data/ha/rsync
mkdir -p $SYNC_DATA_DIR

# ͬ���ļ���IO���ܳ�ʱʱ��
TIMEOUT=120
NONEED_LABEL="_noneed.cfg"

handleSyncResule()
{
    local result="$1"

    local curTime=$(date +"%s")
    # �ļ�ͬ��ʧ�ܸ澯��ָ��澯��Ҫ����֮ǰ�Ƿ��Ѿ����͹����Ѿ����͹����ٷ���
    if [ "$result" == "0" ];then
        if isNeedSendAlarm "$SYNC_FLAG_FILE" "$RESUME_ALARM_TYPE" "$SYNC_FILE_ALARM_OVERDUE_TM"; then
            sendAlarm "$FILE_SYNC_ALARM_ID" "$FILE_SYNC_ALARM_RESID" "yes"
            ret=$?
            LOG_INFO "sendAlarm \"$FILE_SYNC_ALARM_ID\" \"$FILE_SYNC_ALARM_RESID\" \"yes\" return $ret"
            if [ $ret -eq 0 ]; then
                echo -e "$RESUME_ALARM_TYPE,$curTime" > "$SYNC_FLAG_FILE"
            fi
        fi
    else
        if isNeedSendAlarm "$SYNC_FLAG_FILE" "$SEND_ALARM_TYPE" "$SYNC_FILE_ALARM_OVERDUE_TM"; then
            sendAlarm "$FILE_SYNC_ALARM_ID" "$FILE_SYNC_ALARM_RESID"
            ret=$?
            LOG_INFO "sendAlarm \"$FILE_SYNC_ALARM_ID\" \"$FILE_SYNC_ALARM_RESID\" return $ret"
            if [ $ret -eq 0 ]; then
                echo -e "$SEND_ALARM_TYPE,$curTime" > "$SYNC_FLAG_FILE"
            fi
        fi
    fi
}

# ͬ������ģ��
syncOneModule()
{
    local ip="$1"
    local name="$2"
    if [ -z "$ip" -o -z "$name" ]; then
        LOG_ERROR "syncOneModule: input ip:$ip or module name:$name is empty"
        return 1
    fi

    local secInfo=$(sed -n "/^\[$name\]/,/\[/p" $RSYNC_CONF)
    local path=$(echo "$secInfo" | grep '^path' | awk -F= '{print $2}')
    path=$(echo $path)

    if [ -z "$path" ];then
        LOG_WARN "path:$path is empty, no need to sync"
        return 0
    fi

    # ͬ��AMEģ��ǰ��������ӿ������ʱĿ¼������
    if echo "$path" | grep "^/opt/goku/data/ame/packages" > /dev/null ; then
        rm -rf /opt/goku/data/ame/packages/temp/*
    fi
    
    local partialDir=$SYNC_DATA_DIR/${name}_p
    mkdir -p $partialDir
    local tmpDir=$SYNC_DATA_DIR/${name}_t
    [ -d "$tmpDir" ] && rm -rf $tmpDir
    mkdir -p "$tmpDir"

    # ����10M/s������IO��ʱ���ϵ���������·������ʱ�ļ�·��
    local opts="--bwlimit 10240 --timeout=$TIMEOUT --partial-dir=$partialDir -T $tmpDir"
    opts="$opts --delete"
    
    # ���ģ��������include������˵����ģ�����ͬ��ָ�����ļ�����ʱ����Ҫָ��--delete������������Ҫָ�� --delete ����
    local include=$(echo "$secInfo" | grep '^include' | awk -F= '{print $2}' | sed 's/^ //')
    if [ -n "$include" ]; then
        opts="$opts --include=$include"
    fi
    
    # ���ģ��������exclude��������Ҫָ�� --exclude ����������delete�����Ὣ���ڵ��ϵ�excludeָ�����ļ�ɾ��
    local exclude=$(echo "$secInfo" | grep '^exclude' | awk -F= '{print $2}' | sed 's/^ //')
    if [ -n "$exclude" ]; then
        local totalColumn=$(echo "$exclude" | awk '{print NF}')
        for ((columnNum = 1; columnNum <= totalColumn; ++columnNum)); do
            excludeOne=$(echo "$exclude" | awk '{print $columnNum}' "columnNum=$columnNum")
            opts="$opts --exclude=$excludeOne"
        done
    fi
        
    LOG_INFO "start rsync -vzrtopgl --progress $opts nobody@${ip}::${name} ${path}"
    rsync -vzrtopgl --progress $opts nobody@${ip}::${name} ${path} 1>>${LOG_FILE} 2>&1
    ret=$?
    if [ $ret -ne 0 ];then
        LOG_ERROR "rsync -vzrtopgl --progress $opts nobody@${ip}::${name} ${path} return $ret"
        result=1
    fi
    
    return $ret
}

# ����ͬ���ļ�·����ȡrsync�µ�ͬ���ļ�ģ������
getModuleByNotifyPath()
{
    local notifyPath="$1"
    
    local nameList=$(grep -E '^\[notify_|^\[uhm_' "$RSYNC_CONF" | sed -r 's/\[(.*)\]/\1/g')
    
    local name=""
    for name in $nameList; do
        [ -n "$name" ] || continue
        local secInfo=$(sed -n "/^\[$name\]/,/\[/p" $RSYNC_CONF)
        local path=$(echo "$secInfo" | grep '^path' | awk -F= '{print $2}')
        path=$(echo $path)
        local include=$(echo "$secInfo" | grep '^include' | awk -F= '{print $2}')
        include=$(echo $include)
        
        if [ -z "$path" ];then
            LOG_WARN "path:$path is empty"
            continue
        fi
        
        path=$(echo "$path" | sed 's/\/*$//g')
        if [ -n "$include" ]; then
            include=$(echo "$include" | sed 's/*/\.*/')
            path="${path}/${include}"
        fi

        # �����notify֪ͨ��·���������ļ�ͬ��
        if echo "$notifyPath" | grep "^$path" > /dev/null ;then
            LOG_INFO "getModuleByNotifyPath notifyPath:$notifyPath return name:$name"
            echo "$name"
            return 0
        fi
    done
}

# �ļ�ȫͬ��
function rsync_all_files()
{
    local ip="$1"
    local notifyPath="$2"
    local force="$3"

    # hainner��ͷ��ģ�鲻��Ҫͬ�������� notify_notsync �����Ĳ���ʱͬ��
    local nameList=$(grep '^\[' "$RSYNC_CONF" | sed -r 's/\[(.*)\]/\1/g' | grep -vE "^$HA_INNER_PREFIX|^notify_notsync")

    local ret=0
    local result=0
    for moduleName in $nameList; do
        [ -n "$moduleName" ] || continue
        lockFile="$SYNC_DATA_DIR/$moduleName.lock"
        lockWrapCall "$lockFile" syncOneModule "$ip" "$moduleName"
        ret=$?
        # ��ȡ����ͬ��ģ������������ļ�ͬ��ʧ��
        if [ $ret -ne 0 ] && [ $ret -ne 101 ];then
            result=1
        fi
    done
    
    # TODO ��ʱ����Ҫ���澯 ����ͬ�����
}

main()
{
    local ip="$1"
    local notifyPath="$2"
    local force="$3"
    
    if [ -z "$ip" ];then
        LOG_ERROR "input para ip:$ip is empty."
        return 1
    fi
    
    # ����ͬ�����̣�������֪ͨͬ�������ָ��ͬ����·��Ϊall������ȫͬ������
    if [ -n "$notifyPath" ] && ! echo "$notifyPath" | grep -i "^all$" > /dev/null; then
        if ! echo "$notifyPath" | grep '\.\.' ; then
            notifyPath=$(echo "$notifyPath" | sed -r 's|/{2,}|/|g' | sed 's|/\.||g')
        else
            local tmpSyncDir=/opt/goku/data/ha/tmp
            mkdir -p $tmpSyncDir/$notifyPath
            cd $tmpSyncDir/$notifyPath
            notifyPath=$(pwd | sed -r "s|^$tmpSyncDir||")
            cd - > /dev/null 2>&1
        fi
        
        local moduleName=$(getModuleByNotifyPath "$notifyPath")
        if [ -z "$moduleName" ];then
            LOG_ERROR "getModuleByNotifyPath $notifyPath return empty result"
            return 1
        fi
        
        lockFile="$SYNC_DATA_DIR/$moduleName.lock"
        lockWrapCall "$lockFile" syncOneModule "$ip" "$moduleName"
        local ret=$?
        LOG_INFO "lockWrapCall \"$lockFile\" syncOneModule \"$ip\" \"$moduleName\" return $ret"
        
        return $ret
    fi
    
    # ȫͬ������
    LOG_INFO "-------------start full rsync $*"
    lockFile="$SYNC_DATA_DIR/fullsync.lock"
    lockWrapCall "$lockFile" rsync_all_files "$@"
    local ret=$?
    LOG_INFO "lockWrapCall \"$lockFile\" rsync_all_files \"$*\" return $ret"
    
    return $ret
}

main "$@"



