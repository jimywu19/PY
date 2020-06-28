#!/bin/bash

PYTHON=/usr/bin/python2.7

sub_system="$1"
mode="$2"
path="$3"
md5ServerParam="$4"
CUR_PATH="/opt/gaussdb/ha/tools/backupAndRestore"
BACKUP_SCRIPT_PATH="/opt/gaussdb/ha/tools/backupAndRestore/unifiedBackup.sh"

param=$(${PYTHON} ${CUR_PATH}/generate_register_param.py ${sub_system} ${mode} ${path} "${md5ServerParam}")

registerBackup -subsystem ${sub_system} -feature BAK_RES -function REG -call_path ${BACKUP_SCRIPT_PATH} -params "${param}"
