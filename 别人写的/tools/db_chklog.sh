#!/bin/bash

LOG_INIT_SIZE=300
LOG_MAX_SIZE=60

# �ж��Ƿ���Ҫѹ������Ҫ���Ѿ�ѹ����ѹ����tar.gz�ų���
EXCLUE_OPTS4TAR="--exclude=pg_audit --exclude=db_*.tar.gz"
# �ж��Ƿ���Ҫɾ���ϵ�ѹ����������Ҫ�ų�ѹ����
EXCLUE_OPTS4DEL="--exclude=pg_audit"

alias log='loginner [INFO ] [$$] [$(basename ${BASH_SOURCE}):${LINENO}]'
shopt -s expand_aliases
loginner()
{
    echo "[$(date +'%Y-%m-%d %H:%M:%S,%N %z')] $*"
}

# ѹ������־
zipOldLog()
{
    # ����ѭ��������־�ļ�����ʱ����
    local logFile=""
    
    # ���ڱ������־�ļ��Ľ���pid
    local fileUser=""
    
    # ��ȡ������־�б�
    local postgresLogList=`ls gaussdb*log 2>/dev/null | sort -g -t"_" | sort -g -t"-" | sort -r | sed 1d `  

    local ctlLogList=`ls gs_ctl*log 2>/dev/null | sort -g -t"_" | sort -g -t"-" | sort -r | sed 1d `   
    
    local gucLogList=`ls gs_guc*log 2>/dev/null | sort -g -t"_" | sort -g -t"-" | sort -r | sed 1d `   

    # ��ȡѹ������־���
    local lastZipSeq=`ls db_*_log.tar.gz | sort -g -t"_" | awk -F_ '{print $2}' | sort -g | tail -n 1`
    
    local newZipSeq=`expr $lastZipSeq + 1`
    
    if ! tar --remove-files -zcf db_${newZipSeq}_log.tar.gz $postgresLogList $ctlLogList $gucLogList; then
        log "zip log list failed, start to delete the following log file:$postgresLogList  $ctlLogList $gucLogList"
        ls $postgresLogList $ctlLogList $gucLogList | xargs -i rm -f {}
    fi
    
    chmod 600 db_${newZipSeq}_log.tar.gz
 
    return 0
}

# ɾ���ϵ�ѹ����־�ļ�
delOldZipLog()
{
    # ɾ����־ѹ���ļ���ʹ���ܴ�СС��LOG_INIT_SIZE
    local size=`du -ms $EXCLUE_OPTS4DEL . | awk '{print $1}'`
    local zipLogList=`ls db_*_log.tar.gz | sort -g -t"_" -k 2`
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
    local zipLogList=`ls db_*_log.tar.gz | sort -g -t"_"`
    local zipLogSeqList=`echo "$zipLogList" | awk -F_ '{print $2}' | sort -g`
    local smallNum
    local curNum
    local diffNum
    
    curNum=`echo "$zipLogSeqList" | head -n 1`
    diffNum=`expr $curNum - 1`
    log "diffNum is ${diffNum} ."
    
    if [ $diffNum -eq 0 ]; then
        return 0
    fi
    
    # ������־���
    while [ -n "$zipLogSeqList" ]; do
        curNum=`echo "$zipLogSeqList" | head -n 1`
        if [ -z "$curNum" ]; then
            log "curNum is empty, no zip file to delete."
            break
        fi
        
        smallNum=`expr $curNum - $diffNum`
        
        mv db_${curNum}_log.tar.gz db_${smallNum}_log.tar.gz  # ʧ���޷�����������
        
        zipLogSeqList=`echo "$zipLogSeqList" | sed '1'd `
    done
}

#####################################################################
##       Main process
#####################################################################
LOCAL_DB_DATA=$GAUSSDATA

#��ȡ�����ļ��е���־Ŀ¼
RUNLOGDIR=$(grep "^log_directory\>" $LOCAL_DB_DATA/postgresql.conf | awk -F"=" '{print $2}' | awk -F"'" '{print $2}')
#����ʹ�õ������·��
if [ ! -d $RUNLOGDIR ]; then
    RUNLOGDIR=$LOCAL_DB_DATA/$RUNLOGDIR
fi
log "log directory is $RUNLOGDIR"

cd "$RUNLOGDIR"
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

log "End of db_chklog"

exit 0
