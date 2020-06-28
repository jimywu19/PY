#!/bin/bash
# ����Ŀ¼ѹ������С��������ֵ
LOG_INIT_SIZE=120
# ��־��С���������Ŀ��ʱ��ѹ��
LOG_MAX_SIZE=30

LOG_PREFIX="ha_"
# �ж��Ƿ���Ҫѹ������Ҫ���Ѿ�ѹ����ѹ����tar.gz�ų���
EXCLUE_OPTS4TAR="--exclude=ommonitor.* --exclude=runlog --exclude=core --exclude=scriptlog --exclude=ha_*.tar.gz"
# �ж��Ƿ���Ҫɾ���ϵ�ѹ����������Ҫ�ų�ѹ����
EXCLUE_OPTS4DEL="--exclude=ommonitor.* --exclude=runlog --exclude=core --exclude=scriptlog"

. /etc/profile 2>/dev/null
. $HA_DIR/tools/func/func.sh

LOG_FILE=$_HA_LOG_DIR_/haChklog.log
_CHKLOG_LOCK_FILE_=$_HA_LOG_DIR_/haChklog.lock
LOGMAXSIZE=1024

#######################################################################
# shell�ļ�����װ������
# ����1���ļ���·����
# ����2����Ҫ������ʵ��ִ�ж�����
# ����3~n������ʵ�ʶ��������в���
lockWrapCall()
{
    local lockFile=$1
    local action=$2
    
    [ -n "$lockFile" -a -n "$action" ] || return 102
    
    shift 2
        
    ####################################
    ## �ļ�����ֻ����һ������ִ��
    ####################################
    {
        flock -no 100
        if [ $? -eq 1 ]; then
            log "can't get lock file:$lockFile, no need to run $action"
            return 101
        fi
        $action "$@"
        local ret=$?
        
        # ɾ���ļ�����ʹ�����������������ӽ��̲��ٳ�����
        rm -f $lockFile
        return $ret
    } 100<>$lockFile
}

alias log='loginner [INFO ] [$$] [$(basename ${BASH_SOURCE}):${LINENO}]'
shopt -s expand_aliases
loginner()
{
    local  logsize=0
    local  logFile=${LOG_FILE}
    if [ -e "$logFile" ]; then
        logsize=$(du -sk $logFile|awk '{print $1}')
    else
        touch $logFile
    fi
    
    chmod 600 $logFile
    chown $GMN_USER: $logFile
    
    if [ "$logsize" -gt "$LOGMAXSIZE" ]; then
        # ÿ��ɾ��5000�У�Լ150K
        sed -i '1,5000d' $logFile
    fi
    
    echo "[$(date +'%Y-%m-%d %H:%M:%S,%N %z')] $*" >> $logFile
}

# ѹ������־
zipOldLog()
{
    # ����ѭ��������־�ļ�����ʱ����
    local logFile=""
    
    # ���ڱ������־�ļ��Ľ���pid
    local fileUser=""
    
    local logList=""
    cd "$_HA_LOG_DIR_"
    local logsufix=`date +%Y-%m-%d_%H-%M-%S`
    for logFile in $(ls shelllog/*.log 2>/dev/null); do
        if [ -e "$logFile" -a -f "$logFile" ]; then
            local baseFile=${logFile%.log}
            mv "$logFile" "$baseFile-$logsufix.log"
            chown dbadmin: "$logFile"
            chmod 600 "$logFile"
            
            logList="$logList\n$baseFile-$logsufix.log"
        fi
    done
    cd - > /dev/null

    logList=`echo -e "$logList" | sort -g -t"_" | sort -g -t"-" | sort -r`

    # ��ȡѹ������־���
    local lastZipSeq=`ls ${LOG_PREFIX}*_log.tar.gz | sort -g -t"_" | awk -F_ '{print $2}' | sort -g | tail -n 1`
    
    local newZipSeq=`expr $lastZipSeq + 1`
    
    if ! tar --remove-files -zcf ${LOG_PREFIX}${newZipSeq}_${logsufix}_log.tar.gz $logList; then
        log "zip log list failed, start to delete the following log file:$logList"
        rm -f $logList
    fi
    
    chown $GMN_USER: ${LOG_PREFIX}${newZipSeq}_${logsufix}_log.tar.gz
    
    return 0
}

# ɾ���ϵ�ѹ����־�ļ�
delOldZipLog()
{
    # ɾ����־ѹ���ļ���ʹ���ܴ�СС��LOG_INIT_SIZE
    local size=`du -ms $EXCLUE_OPTS4DEL . | awk '{print $1}'`
    local zipLogList=`ls ${LOG_PREFIX}*_log.tar.gz | sort -g -t"_" -k 2`
    local zipNum
    local zipToDel
    
    while [ $size -gt $LOG_INIT_SIZE ]; do
        zipNum=`echo "$zipLogList" | wc -l`
        if [ $zipNum -le 1 ]; then
            break
        fi
        
        # ɾ�����ϵ�ѹ���ļ�
        zipToDel=`echo "$zipLogList" | head -n 1`
        log "Delete zip file $zipToDel"
        find . -name "$zipToDel" | xargs rm -rf "$zipToDel"
        zipLogList=`echo "$zipLogList" | sed '1'd`
        
        size=`du -ms $EXCLUE_OPTS4DEL . | awk '{print $1}'`
    done
    
}

# ���µ���ѹ����־�ļ����
seqZipLog()
{
    local zipLogList=`ls ${LOG_PREFIX}*_log.tar.gz | sort -g -t"_" -k 2`
    local zipLogSeqList=`echo "$zipLogList" | awk -F_ '{print $2}' | sort -g`
    local smallNum
    local curNum
    local diffNum
    local preNum=0
    
    curNum=`echo "$zipLogSeqList" | head -n 1`
    diffNum=`expr $curNum - 1`
    log "diffNum is ${diffNum} ."
    
    if [ $diffNum -eq 0 ]; then
        return 0
    fi
    
    # ������־���
    while [ -n "$zipLogList" ]; do
        zipLog=`echo "$zipLogList" | head -n 1`
        if [ -z "$zipLog" ]; then
            log "zipLog is empty, no zip file to delete."
            break
        fi

        ((curNum = preNum + 1))
        preNum=$curNum
        
        newZipLog=$(echo "$zipLog" | sed -r "s/^${LOG_PREFIX}[0-9]+/${LOG_PREFIX}${curNum}/")
        mv "$zipLog" "$newZipLog"  # ʧ���޷�����������
        
        zipLogList=`echo "$zipLogList" | sed '1'd `
    done
}

sec_log_process()
{
    sed  -i   '/key/d' $_HA_LOG_DIR_/scriptlog/ha.log
    sed  -i   '/password/d' $_HA_LOG_DIR_/scriptlog/ha.log
    sed  -i   '/key/d' $_HA_LOG_DIR_/scriptlog/ha_monitor.log
    sed  -i   '/password/d' $_HA_LOG_DIR_/scriptlog/ha_monitor.log
}

handleLogDir()
{
    # clean log
    sec_log_process
    su - $DB_USER -c "bash $HA_DIR/tools/db_chklog.sh" >> $LOG_FILE 2>&1
    
    cd "$_HA_LOG_DIR_"
    if  [ $? -eq 0 ] ; then
        SIZE=`du -ms $EXCLUE_OPTS4TAR . | awk '{print $1}'`
        
        # ��С�������Ȳ�ѹ����ֱ���˳�
        if [ $SIZE -lt $LOG_MAX_SIZE ]; then
            log "total log size is ${SIZE}M, no need to zip."        
        else    
            # ѹ������־
            zipOldLog
            
            # ɾ���ϵ�ѹ����־�ļ�
            delOldZipLog
            
            # ���µ���ѹ����־�ļ����
            seqZipLog
        fi
    fi
    
    cd - >/dev/null
}

#####################################################################
##       Main process
#####################################################################

lockWrapCall "$_CHKLOG_LOCK_FILE_" handleLogDir

find $_HA_LOG_DIR_ -type f -name "*.gz" -o -name "*.log" | xargs -i chmod 600 {}
log "End of ha_chklog"

exit 0
