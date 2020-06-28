#!/bin/bash

cd "$(dirname $0)"
CUR_PATH=$(pwd)
. $CUR_PATH/func.sh

getDoubleConfig "$_CONF_FILE_"

echo ${LOCAL_GMN_EX_IP}

echo ${REMOTE_GMN_EX_IP}

# configure file
_CONF_FILE_=$CUR_PATH/../conf/runtime/gmn.cfg

