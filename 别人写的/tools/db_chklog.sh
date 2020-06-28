#!/bin/bash

LOG_INIT_SIZE=300
LOG_MAX_SIZE=60

# 判断是否需要压缩，需要将已经压缩的压缩包tar.gz排除掉
EXCLUE_OPTS4TAR="--exclude=pg_audit --exclude=db_*.tar.gz"
# 判断是否需要删除老的压缩包，不需要排除压缩包
EXCLUE_OPTS4DEL="--exclude=pg_audit"

alias log='loginner [INFO ] [$$] [$(basename ${BASH_SOURCE}):${LINENO}]'
shopt -s expand_aliases
loginner()
{
    echo "[$(date +'%Y-%m-%d %H:%M:%S,%N %z')] $*"
}

# 压缩老日志
zipOldLog()
{
    # 用于循环遍历日志文件的临时变量
    local logFile=""
    
    # 用于保存打开日志文件的进程pid
    local fileUser=""
    
    # 获取各个日志列表
    local postgresLogList=`ls gaussdb*log 2>/dev/null | sort -g -t"_" | sort -g -t"-" | sort -r | sed 1d `  

    local ctlLogList=`ls gs_ctl*log 2>/dev/null | sort -g -t"_" | sort -g -t"-" | sort -r | sed 1d `   
    
    local gucLogList=`ls gs_guc*log 2>/dev/null | sort -g -t"_" | sort -g -t"-" | sort -r | sed 1d `   

    # 获取压缩的日志序号
    local lastZipSeq=`ls db_*_log.tar.gz | sort -g -t"_" | awk -F_ '{print $2}' | sort -g | tail -n 1`
    
    local newZipSeq=`expr $lastZipSeq + 1`
    
    if ! tar --remove-files -zcf db_${newZipSeq}_log.tar.gz $postgresLogList $ctlLogList $gucLogList; then
        log "zip log list failed, start to delete the following log file:$postgresLogList  $ctlLogList $gucLogList"
        ls $postgresLogList $ctlLogList $gucLogList | xargs -i rm -f {}
    fi
    
    chmod 600 db_${newZipSeq}_log.tar.gz
 
    return 0
}

# 删除老的压缩日志文件
delOldZipLog()
{
    # 删除日志压缩文件，使得总大小小于LOG_INIT_SIZE
    local size=`du -ms $EXCLUE_OPTS4DEL . | awk '{print $1}'`
    local zipLogList=`ls db_*_log.tar.gz | sort -g -t"_" -k 2`
    local zipNum
    local zipToDel
    
    while [ $size -gt $LOG_INIT_SIZE ]; do
        zipNum=`echo "$zipLogList" | wc -l`
        if [ $zipNum -le 1 ]; then
            break
        fi
        
        # 删除最老的压缩文件
        zipToDel=`echo "$zipLogList" | head -n 1`
        log "Delete zip file $zipToDel"
        find . -name "$zipToDel" | xargs rm -rf "$zipToDel"
        zipLogList=`echo "$zipLogList" | sed '1'd`
        
        size=`du -ms $EXCLUE_OPTS4DEL . | awk '{print $1}'`
    done
    
}

# 重新调整压缩日志文件序号
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
    
    # 滚动日志序号
    while [ -n "$zipLogSeqList" ]; do
        curNum=`echo "$zipLogSeqList" | head -n 1`
        if [ -z "$curNum" ]; then
            log "curNum is empty, no zip file to delete."
            break
        fi
        
        smallNum=`expr $curNum - $diffNum`
        
        mv db_${curNum}_log.tar.gz db_${smallNum}_log.tar.gz  # 失败无法处理，不返回
        
        zipLogSeqList=`echo "$zipLogSeqList" | sed '1'd `
    done
}

#####################################################################
##       Main process
#####################################################################
LOCAL_DB_DATA=$GAUSSDATA

#获取配置文件中的日志目录
RUNLOGDIR=$(grep "^log_directory\>" $LOCAL_DB_DATA/postgresql.conf | awk -F"=" '{print $2}' | awk -F"'" '{print $2}')
#可能使用的是相对路径
if [ ! -d $RUNLOGDIR ]; then
    RUNLOGDIR=$LOCAL_DB_DATA/$RUNLOGDIR
fi
log "log directory is $RUNLOGDIR"

cd "$RUNLOGDIR"
if  [ $? -eq 0 ] ; then
    SIZE=`du -ms $EXCLUE_OPTS4TAR . | awk '{print $1}'`
    
    # 大小不足则先不压缩，直接退出
    if [ $SIZE -lt $LOG_MAX_SIZE ]; then
        log "total log size is ${SIZE}M, no need to zip."        
    else    
        # 压缩老日志
        zipOldLog

        # 删除老的压缩日志文件
        delOldZipLog

        # 重新调整压缩日志文件序号
        seqZipLog
    fi
fi

log "End of db_chklog"

exit 0
