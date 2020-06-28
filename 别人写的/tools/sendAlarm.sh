#!/bin/bash

##############################################

. /etc/profile 2>/dev/null
. $HA_DIR/tools/func/func.sh
. $HA_DIR/tools/func/dblib.sh

mkdir -p $_HA_SH_LOG_DIR_
chown $DB_USER: $_HA_SH_LOG_DIR_
LOG_FILE=$_HA_SH_LOG_DIR_/sendAlarm.log

handNotifyEvent "$@"
exit $?
