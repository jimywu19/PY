#!/bin/bash

cd "$(dirname $0)"
CUR_PATH=$(pwd)
. $CUR_PATH/func.sh

getDoubleConfig "$_CONF_FILE_"

echo ${FLOAT_GMN_EX_IP}

# configure file
_CONF_FILE_=$CUR_PATH/../conf/runtime/gmn.cfg

