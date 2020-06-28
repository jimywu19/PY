#!/bin/bash
set +x

. /etc/profile
cd "$(dirname $0)"
CUR_PATH=$(pwd)
. $CUR_PATH/common.sh

# 如果备份正在进行,直接返回成功
procInfo=$(ps -efww | grep 'gs_rman' | grep -v grep)
[ -n "$procInfo" ] && exit $successTag

# f: Full
# i: Incremental
backupMode=$1

if [ -f $back4showlog ]; then
    rm $back4showlog
fi

echo $backupProcessing > $backStatus
{
    sudo $HA_DIR/tools/backupAndRestore/dbBackupCron.sh $backupMode > $back4showlog 2>&1; ret=$?
    if [ $ret -eq 0 ]; then
        currentTime=`date +'%Y/%m/%d %H:%M'`
        echo "Last successful backup time: $currentTime" > $lastSuccessTimeFile
        echo $successTag > $backStatus
    else
        echo $failedTag > $backStatus
    fi
}&
exit $successTag
