#!/bin/bash

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
LOG_FILE=$_HA_SH_LOG_DIR_/rsync_monitor.log

if [ "-${DUALMODE}" = "0" ];then
    LOG_INFO "current host is single modle, dual_mode:0, Don't need start, exit..."
    exit 0
fi

RSYNC_KEY="rsyncd --daemon"

function start_rsync()
{
   LOG_INFO "start rsync server!"
   service rsyncd start 1>>${LOG_FILE} 2>&1
   local -i count=$(service rsyncd status | grep "Checking for rsync daemon:.*running" |wc -l)
   LOG_INFO "monitor rsync server status:${count}"
   if [ ${count} -gt 0 ];then
        echo -e "start rsync server success."
        LOG_INFO "start rsync server success."
        return 0
   fi
   echo -e "start rsync server failed."
   LOG_INFO "start rsync server failed."
   return 1
}

function stop_rsync()
{
   LOG_INFO "stop rsync server!"
   service rsyncd stop 1>>${LOG_FILE} 2>&1
   count=$(ps -efww | grep -w "${RSYNC_KEY}" | grep -v grep |wc -l)
   LOG_INFO "monitor rsync server status:${count}"
   if [ ${count} -gt 0 ];then
        pid=$(ps -efww | grep -w "${RSYNC_KEY}" | grep -v grep |awk -F " " '{print $2}')
        kill -9 ${pid}
        rm -f /var/run/rsyncd.pid
        LOG_INFO "kill rsync server!"
        return 0
   fi
   
   rm -f /var/run/rsyncd.pid
   LOG_INFO "rsync server is not running ,Don't need kill!"
   return 0
}

function monitor_rsync()
{
   local -i count=$(service rsyncd status | grep "Checking for rsync daemon:.*running" |wc -l)
   if [ ${count} -gt 0 ];then
        echo -e "rsync server is running"
        LOG_INFO "pidCnt:$count, rsync server is running"
        return 0
   fi
   
   echo -e "rsync server is not running"
   LOG_ERROR "pidCnt:$count, rsync server is not running!"
   return 1
}

function main()
{      
    LOG_INFO "-------- start rsync server, command:${1}"
    
    if [ -z "$1" ];then
        if monitor_rsync > /dev/null; then
            LOG_INFO "monitor_rsync return 0"
        else
            stop_rsync
            start_rsync
        fi
        
        return $?
    fi
        
    case "${1}" in
        start)
            start_rsync
            exit $?
            ;;
        stop)
            stop_rsync
            exit $?
            ;;
        status)
            monitor_rsync
            exit $?
            ;;
        restart)    
            stop_rsync
            start_rsync
            exit $?
            ;;
        monitor)
            monitor_rsync
            exit $?
            ;;
        *)
            exit 0
            ;;
    esac
}

main $*
