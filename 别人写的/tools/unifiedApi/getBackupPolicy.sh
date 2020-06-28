#!/bin/bash
set +x

. /etc/profile
cd "$(dirname $0)"
CUR_PATH=$(pwd)
. $CUR_PATH/common.sh

backupMode=$1

if [ -f $lastSuccessTimeFile ]; then
    cat $lastSuccessTimeFile
else
    echo 'No successful backup'
fi

if [ -f $backupPolicy ]; then
    cat $backupPolicy
else
    echo 'WARN: Backup policy file not exist'
    exit $failedTag
fi

exit $successTag