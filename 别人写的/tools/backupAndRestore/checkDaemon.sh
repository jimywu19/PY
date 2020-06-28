#!/bin/bash

SWITCHOVER_CHECK_SCRIPT="/opt/gaussdb/ha/tools/backupAndRestore/switchoverCheck.sh"
PROCESS_INFO_STRING="switchoverCheck"

ps -efww | grep ${PROCESS_INFO_STRING} | grep -v grep | grep -v su > /dev/null 2>&1
if [[ $? -eq 1 ]]
then
     sh ${SWITCHOVER_CHECK_SCRIPT} &
else
    ps_count=`ps -efww | grep ${PROCESS_INFO_STRING} | grep -v grep | wc -l`
    if [[ ${ps_count} -gt 1 ]]
    then
        pid_list=`echo $(ps -efww | grep ${PROCESS_INFO_STRING} | grep -v grep | awk '{print $2}')`
        kill -9 ${pid_list}
        sh ${SWITCHOVER_CHECK_SCRIPT} &
    fi
fi