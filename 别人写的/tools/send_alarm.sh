#!/bin/bash

##############################################
# HA接口
##############################################

. /etc/profile 2>/dev/null
nohup $HA_DIR/tools/sendAlarm.sh "$@" > /dev/null 2>&1 < /dev/null &
