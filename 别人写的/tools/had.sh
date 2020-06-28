#!/bin/bash

HA_MOUDLE_PATH="$HA_DIR/module"
HA_COM_SCRIPT_PATH="$HA_MOUDLE_PATH/hacom/script"
HA_MON_SCRIPT_PATH="$HA_MOUDLE_PATH/hamon/script"

declare -i logMaxSize=2*1024*1024

function gettime()
{
    echo "$(date -d 'today' '+%Y-%m-%d %H:%M:%S')"
}

do_start() {
    sh ${HA_COM_SCRIPT_PATH}/functions/start_habin.sh
    sh /opt/galax/gms/common/ha/functions/start_habin.sh > /dev/null 2>&1
    return $?
}

do_stop() {
    sed -i -e '/had-monitor.sh/d' /etc/crontab  > /dev/null 2>&1
    sh ${HA_MON_SCRIPT_PATH}/stop_ha_monitor.sh
    sh ${HA_COM_SCRIPT_PATH}/stop_ha_process.sh
    return $?
}

do_status() {
    sh ${HA_COM_SCRIPT_PATH}/status_ha.sh > /dev/null 2>&1
    return $?
}

do_query()
{
    sh ${HA_COM_SCRIPT_PATH}/functions/status_habinV2.sh
    return $?
}
