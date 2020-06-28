#!/bin/bash
cd "$(dirname $0)"
CUR_PATH=$(pwd)

successTag=0
backupProcessing=1
failedTag=2

back4showlog=$CUR_PATH/backProcessInfo
backStatus=$CUR_PATH/backupStatus
lastSuccessTimeFile=$CUR_PATH/lastSuccessTimeRecord
backupPolicy=$CUR_PATH/backupPolicy.conf
