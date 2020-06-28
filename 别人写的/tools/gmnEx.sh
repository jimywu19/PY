#!/bin/bash

ACTION=$1
shift

# cd work dir
cd $(dirname $0)
CUR_PATH=$(pwd)
. /etc/profile 2>/dev/null
. $CUR_PATH/func/globalvar.sh
. $CUR_PATH/func/func.sh
. $CUR_PATH/func/gmnfunc.sh

RM_PLUGIN_DIR=$HA_DIR/module/harm/plugin
RM_CONF_DIR=$RM_PLUGIN_DIR/conf
RM_SCRIPT_DIR=$HA_DIR/module/harm/plugin/script

LOG_FILE=$_HA_SH_LOG_DIR_/gmn.log

# exit with msg printed
die()
{
    [ -n "$*" ] && echo $*
    exit 1
}

# print help
usage()
{
    echo "usage: status "
}

getStatusOneByOne()
{
    PROC_LIST=$(get_process_list)
    STATES=""
    local procScript=""
    local ret=0
    for proc in $PROC_LIST; do
        if [ "$proc" != "gsdb" ] ; then
            procScript="$RM_SCRIPT_DIR/${proc}.sh"
            normalCode=0
        else
            proc="gaussDB"
            procScript="$RM_SCRIPT_DIR/rcommgsdb"
            normalCode=6
        fi
        
        if [ "$DUALMODE" == "0" ] && echo "$proc" | grep "floatip$" > /dev/null; then
            continue
        fi

        $procScript status >/dev/null
        ret=$?
        # 6表示主进程正常
        if [ $ret -eq $normalCode ]; then
            STATES="$STATES\n${proc}\tnormal" 
        else
            STATES="$STATES\n${proc}\tabnormal"
        fi
    done
    
    STATES=$(echo -e "$STATES" | sed "1d")
}
status()
{
    # R5针对OMM HA，如果本机HA未运行，此处查询为 NULL
    HA_STATES=$($HA_STATUS_TOOL 2> /dev/null)
    local getHaStatesRet=$?
    if [ $getHaStatesRet -ne 0 ] ; then
        getStatusOneByOne
    else
        getDoubleConfig "$_CONF_FILE_"
        LOCAL_HOST="$LOCAL_nodeName"
        STATES=$(echo "$HA_STATES" | awk '{if ($1 == "'$LOCAL_HOST'") print $2,$3}' | sed "1d" | awk '{ if ($2 ~ /\<Normal\>|\<Active_normal\>/) print $1,"normal"; else print $1,"abnormal"}')
    fi

    # 单机排除浮动IP资源
    if [ "$DUALMODE" == "0" ]; then
        STATES=$(echo -e "$STATES" | awk '{if ($1 !~ /floatip$/) print $0}')
    fi

    echo -e "$STATES" | awk '{printf "%-16s%s\n", $1, $2}'
}

restart()
{
    do_action restart
}

stop()
{
    do_action stop
}

# check empty
[ -z "$ACTION" ] && { usage; die; }
case "$ACTION" in
    status)
    status
    ;;
    stop)
    stop
    ;;
    *)
    usage;
    die; 
esac
exit 0

