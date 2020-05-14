#!/bin/bash
# Copyright Huawei Technologies Co., Ltd. 1998-2015. All rights reserved.
# description:
# The script can start for nginx process.

######################################################################
#   DESCRIPTION: 切换到当前目录
#   CALLS      : 无
#   CALLED BY  : main
#   INPUT      : 无
#   OUTPUT     : 无
#   LOCAL VAR  : 无
#   USE GLOBVAR: 无
#   RETURN     : 无
#   CHANGE DIR : 无
######################################################################
getCurPath()
{
    # 1 如果当前目录就是install文件所在位置，直接pwd取得绝对路径
    # 2 而如果是从其他目录来调用install的情况，先cd到install文件所在目录,再取得install的绝对路径，并返回至原目录下
    # 3 使用install调用该文件，使用的是当前目录路径
    if [ "` dirname "$0" `" = "" ] || [ "` dirname "$0" `" = "." ] ; then
        CURRENT_PATH="`pwd`"
    else
        cd ` dirname "$0" `
        CURRENT_PATH="`pwd`"
        cd - > /dev/null 2>&1
    fi
}

. /etc/profile

##切换到当前路径
getCurPath
cd "${CURRENT_PATH}"

#引入公共模块
. ./util.sh
#初始化
#执行日志目录初始化
initLogDir

##检查用户
chkUser

# 程序无法正常启动时,尝试次数
NGINX_LOOP_COUNTER=3

# action
ACTION=$1
shift

# init ret value for exit
RETVAL=0

# ensure action is specficed
[ -z "$ACTION" ] && die "no action is specficed"
logger_without_echo "Action is $ACTION"

# status
status()
{
    local pid=`ps -ww -eo pid,cmd | grep -w "nginx:" | grep -vwE "grep|vi|vim|tail|cat" | awk '{print $1}' | head -1`
    RETVAL=1
    [ -n "$pid" ] && RETVAL=0
    if [ "$RETVAL" -eq 0 ]; then
        # nginx is running
        logger "normal"
    else
        # nginx is not running
        logger "abnormal"
    fi
    return "$RETVAL"
}

# start
start()
{
    # do singleton protect
    if status >/dev/null ; then
        logger "process is running, no need to start"
        return ${RETURN_CODE_ERROR}
    fi

    RETVAL=0

    # start process
    #. ./pass_decrypt.sh
    #expect nginx_start.exp ${pass[*]} > /dev/null 2>&1
    /opt/onframework/nginx/sbin/nginx > /dev/null 2>&1
    sleep 2;
    procnum=$(ps -wwef | grep "nginx: master" | grep -cv grep)
    if [ "$procnum" -ne "1" ]; then
        die "start fail"
    else
        logger "start success"
    fi

}

# stop
stop()
{
    # check if nginx start or not
    if status >/dev/null ; then
        logger "process is running, try to stop it"
    else
        logger "process is not running, no need to stop"
        RETVAL=0
        return 0
    fi

    # stop process
    #. ./pass_decrypt.sh
    #expect nginx_stop.exp ${pass[*]} > /dev/null 2>&1
    /opt/onframework/nginx/sbin/nginx -s stop > /dev/null 2>&1
    sleep 2;
    procnum=$(ps -wwef | grep "nginx:" | grep -cv grep)
    if [ "$procnum" -ne "0" ]; then
        logger "nginx hasn't been stopped.";
        pid=$(ps -wwef | grep "nginx:" | grep -v grep | awk '{print $2}')
        kill -9 ${pid}
        logger "force to kill all processes."
    else
        logger "stop success"
    fi

}

# restart
restart()
{
    stop
    start
}

# reload
reload()
{
    # do singleton protect
    if status >/dev/null ; then
        #. ./pass_decrypt.sh
        #expect nginx_reload.exp ${pass[*]} > /dev/null 2>&1
        /opt/onframework/nginx/sbin/nginx -s reload > /dev/null 2>&1
        if [ $? -eq 0 ] ; then
            logger "reload success"
        else
            die "reload fail"
        fi
    else
        logger "process is not running, can't reload."
    fi
}

######################################################################
#  FUNCTION     : check
#  DESCRIPTION  : 检查nginx程序状态，如果异常则启动程序，则重复${NGINX_LOOP_COUNTER}
#                 次启动后，仍然检测状态异常，则返回异常.
#  CALLS        : 无
#  CALLED BY    : 无
#  INPUT        : 无
#  OUTPUT       : 无
#  READ GLOBVAR : 无
#  WRITE GLOBVAR: 无
#  RETURN       :   成功    0
#                   失败    2
######################################################################
check()
{    
    CURRENT_NUMBER=0
    for((; CURRENT_NUMBER < ${NGINX_LOOP_COUNTER}; CURRENT_NUMBER++));
    do
        status > /dev/null 2>&1
        if [ $? -eq 0 ] ;then
            logger "Result:check success, CURRENT_NUMBER is ${CURRENT_NUMBER}"
            return 0
        else
            logger "Result:check failed, CURRENT_NUMBER is ${CURRENT_NUMBER}. it will start."
            start > /dev/null 2>&1
            sleep 2
        fi
    done
    
    logger "Result:check failed."
    return 2
}

case "$ACTION" in
    start)
    start
    ;;
    stop)
    stop
    ;;
    status)
    status
    ;;
    restart)
    restart
    ;;
    reload)
    reload
    ;;
    check)
    check
    ;;
    *)
    die $"Usage: $0 {start|stop|status|restart|reload|check}"
esac

exit $RETVAL
