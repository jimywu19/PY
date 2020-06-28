#!/bin/bash
set +x

. /etc/profile
cd "$(dirname $0)"
CUR_PATH=$(pwd)
. $CUR_PATH/common.sh

if [ ! -f $backStatus ] || [ ! -f $back4showlog ]; then
    exit $failedTag
fi

wordCount=`cat $backStatus | wc -w`
if [ $wordCount -ne 1 ];then
    exit $failedTag
fi

ret=`cat $backStatus`
cat $back4showlog

exit $ret
