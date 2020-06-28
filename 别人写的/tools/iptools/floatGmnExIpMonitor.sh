#!/bin/bash
# To Check whether the Float Escape IP information already exist, or config IP
# --------------------------------------------------------------------
# exit code meanings :
# 0:success                --->at lease on check point isn't correct
# 1:failed                 --->at lease on check point op failed
# --------------------------------------------------------------------

# Internal variable
ACTION=$1

BASH="$(which sh)"

getCurPath()
{
    if [ "` dirname "$0" `" = "" ] || [ "` dirname "$0" `" = "." ]; then
        CUR_PATH="`pwd`"
    else
        cd $( dirname "$0" )
        CUR_PATH="`pwd`"
        cd - > /dev/null 2>&1
    fi
}

# change to cur path
getCurPath
cd "$CUR_PATH"

. ./ipMonitor.sh              || { echo "Can't load ./ipMonitor.sh"; exit 1; }
#add for adapting IPV6
. ./network.conf || { echo "Can't load network.conf in floatGmnExIpMonitor.sh "; exit 1; }
#add for adapting IPV6
Main_Process()
{
    case "$ACTION" in
        "start"|"stop"|"status"|"restart")
        ip_Monitor "${ACTION}" FLOAT_GMN_EX
        exit $?
        ;;
        *)
        echo $"Usage: $0 {start|stop|status|restart}"
        exit $EXIT_CODE_FAILED
    esac

}

Main_Process