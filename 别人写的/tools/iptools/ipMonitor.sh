#!/bin/bash
# Shell script to provide create bond.
# To Check whether the IP information already exist, or config IP
# --------------------------------------------------------------------
# exit code meanings :
# 0:success                --->at lease on check point isn't correct
# 1:failed                 --->at lease on check point op failed
# --------------------------------------------------------------------

###############################################################
#for example
#sh ipMonitor.sh start|stop|status FLOAT_GMN_EX
#sh ipMonitor.sh start|stop|status LOCAL_GMN_EX
#sh ipMonitor.sh start|stop|status FLOAT_GMN_IN
#sh ipMonitor.sh start|stop|status LOCAL_GMN_IN
#sh ipMonitor.sh start|stop|status LOCAL_ESCAPE
#sh ipMonitor.sh start|stop|status LOCAL_GMN_DBFC
###############################################################

. ../func/globalvar.sh
. ./network.conf               || { echo "Can't load ./network.conf"; exit 1; }

#add for adapting IPV6
. ../../install/common_var.sh || { echo "load $HA_DIR/install/common_var.sh failed."; exit 1; }

# define exit code
EXIT_CODE_SUCCESS=0
EXIT_CODE_FAILED=1

# use counter record op times on check points
# Local op times on check points
LOCAL_OP_TIMES=0

# Linux bin paths, change this if it can not be autodetected via which command
DATE="$(which date)"
IFUP="$(which ifup)"
IFDOWN="$(which ifdown)"
IFCONFIG="$(which ifconfig)"
ETHTOOL="$(which ethtool)"
PING="$(which ping)"
if [ -z "$IP_TYPE" ] ||  [ "IPV4" == "$IP_TYPE" ]; then
    PING6="$(which ping6)"
fi
# Main directory where backup will be stored
MBD="${_HA_SH_LOG_DIR_/:-/var/log/ha/shelllog/}"
[ ! -d $MBD ] && mkdir -p $MBD ||:

# Debug block
DEBUG_MACRO="false"
LOGFILE=$MBD"/ipMonitor.log"

alias DEBUG='loginner [INFO ] [$$] [$(basename ${BASH_SOURCE}):${LINENO}]'
shopt -s expand_aliases
loginner()
{
    if [ "$DEBUG_MACRO" = "false" ];
    then
        echo "[$(date +'%Y-%m-%d %H:%M:%S,%N %z')] $*[$ITF_KEY]" >> $LOGFILE
    else
        echo "[$ITF_KEY] "$*
    fi
}

# exit with error message
die()
{
    DEBUG "$*"
    echo "$*"
    exit $EXIT_CODE_FAILED
}

# check is VM or not
checkIsVm()
{
    if [ -n "$(dmidecode | grep -E 'xen|Xen|VMware|OpenStack')" ]; then
       return 0
    else
       return 1
    fi
}

function Check_Param()
{
    ITF=$(eval echo \${"${ITF_KEY}"})
    IP=$(eval echo \${"${ITF_KEY}"_IP})
    MASK=$(eval echo \${"${ITF_KEY}"_MASK})
    GW=$(eval echo \${"${ITF_KEY}"_GW})
    VLAN=$(eval echo \${"${ITF_KEY}"_VLAN})

    if [ -z "$IP" ] || [ -z "$MASK" ] || [ -z "$GW" ] || [ -z "$ITF" ];
    then
        die "Input Param Error, pls check"
    fi
}

function ping_gateway()
{   
    #adapting for IPV6
    if [ -z "$IP_TYPE" ] ||  [ "IPV4" == "$IP_TYPE" ]; then
        if ! $PING -c 4 -i 0.1 -w 3 "$1" > /dev/null 2>&1
        then 
            DEBUG "ping gateway failed with eth: ${LOCAL_ITF}."
            die "abnormal"
        fi
    else
        if ! $PING6 -c 4 -i 0.1 -w 3 "$1" > /dev/null 2>&1
        then 
            DEBUG "$PING6 gateway failed with eth: ${LOCAL_ITF}."
            die "abnormal"
        fi
    fi
}

function status_network()
{   
    #adapting for IPV6
    if [ -z "$IP_TYPE" ] ||  [ "IPV4" == "$IP_TYPE" ]; then
        local LOCAL_ITF="$ITF"
        if [ "$ITF" == "GmnEx" ] && [ "${LOCAL_GMN_EX_INTF:0:3}" != "Gmn" ]
        then
            LOCAL_ITF="${LOCAL_GMN_EX_INTF}"
        fi
        
        if [ "$ITF" == "GmnEx:1" ] && [ "${LOCAL_GMN_EX_INTF:0:3}" != "Gmn" ]
        then
            LOCAL_ITF="${LOCAL_GMN_EX_INTF}:1"
        fi
        
        if [ "$LOCAL_ITF" == "GmnEx" ] && !( checkIsVm ) && [ -n "$VLAN" ]
        then
            $IFCONFIG "vlan${VLAN}" >>$LOGFILE 2>&1
            if [ $? != 0 ];
            then
                DEBUG "ip check failed with vlan: ${VLAN}."
                die "abnormal"
            else
                DEBUG "ip check success with vlan: ${VLAN}."
            fi
        fi
    
        $ETHTOOL "$LOCAL_ITF" 2>>$LOGFILE | grep "Link detected" | grep "yes" 2>>$LOGFILE
        if [ $? != 0 ];
        then
            DEBUG "ip check failed with eth: ${LOCAL_ITF}. eth: ${LOCAL_ITF} is not linked."
            die "abnormal"
        fi
        
        #Check whether configuration error or not
        $IFCONFIG "$LOCAL_ITF" 2>>$LOGFILE|grep -w "$IP"|grep "$MASK" 2>>$LOGFILE
        if [ $? != 0 ];
        then
            DEBUG "ip check failed with eth: ${LOCAL_ITF}."
            die "abnormal"
        fi
        
        #Check whether interface up or not
        $IFCONFIG "$LOCAL_ITF"|grep -w "UP" 2>>$LOGFILE
        if [ $? != 0 ];
        then
            DEBUG "ip check failed, eth: ${LOCAL_ITF} is down."
            die "abnormal"
        else
            #call add route config 
    
            if ([ "$ITF" == "GmnEx" ] || [ "$ITF" == "GmnEx:1" ]) && [ "${LOCAL_GMN_EX_INTF:0:3}" == "Gmn" ]
            then
                $IFCONFIG "$LOCAL_GMN_EX_ITF" 2>>$LOGFILE | grep -w "UP" 2>>$LOGFILE
                if [ $? != 0 ];
                then
                    DEBUG "check GmnEx base interface failed, eth: ${LOCAL_GMN_EX_ITF} is down."
                    $IFCONFIG "${LOCAL_GMN_EX_ITF}" up 2>>$LOGFILE
                    if [ $? != 0 ];
                    then
                        DEBUG "up GmnEx base interface failed, eth: ${LOCAL_GMN_EX_ITF} is abnormal."
                        die "abnormal"
                    fi
                fi
            fi
            if [ "$ITF" == "GmnIn" ] || [ "$ITF" == "GmnIn:1" ]
            then
                $IFCONFIG "$LOCAL_GMN_IN_ITF" 2>>$LOGFILE | grep -w "UP" 2>>$LOGFILE
                if [ $? != 0 ];
                then
                    DEBUG "check GmnIn base interface failed, eth: ${LOCAL_GMN_IN_ITF} is down."
                    $IFCONFIG "${LOCAL_GMN_IN_ITF}" up 2>>$LOGFILE
                    if [ $? != 0 ];
                    then
                        DEBUG "up GmnIn base interface failed, eth: ${LOCAL_GMN_IN_ITF} is abnormal."
                        die "abnormal"
                    fi
                fi
            fi
            
            # 如果是浮动IP正常，每三分钟广播一次浮动IP的arp
            if echo "$ITF" | grep ":" > /dev/null; then
                local -i minute=$(date +"%M" | sed 's/^0//')
                local -i second=$(date +"%S" | sed 's/^0//')
                ((minute%=3))
                
                if [ $minute -eq 0 ] && [ $second -lt 5 ];then
                    local floatItf=$(echo "$ITF" | sed 's/:.*$//')
                    arping -q -U -c 1 -w 1 -I "$floatItf" "$IP"
                    DEBUG "second:$second arping -q -U -c 1 -w 1 -I "$floatItf" "$IP""
                fi
            fi
            
            DEBUG "normal"
            echo "normal"
            exit $EXIT_CODE_SUCCESS
        fi
    else
        #ipv6
        local LOCAL_ITF="$ITF"
        if [ "$ITF" == "GmnEx" ] && [ "${LOCAL_GMN_EX_INTF:0:3}" != "Gmn" ]
        then
            LOCAL_ITF="${LOCAL_GMN_EX_INTF}"
        fi
        
        if [ "$LOCAL_ITF" == "GmnEx" ] && !( checkIsVm ) && [ -n "$VLAN" ]
        then
            $IFCONFIG "vlan${VLAN}" >>$LOGFILE 2>&1
            if [ $? != 0 ];
            then
                DEBUG "ip check failed with vlan: ${VLAN}."
                die "abnormal"
            else
                DEBUG "ip check success with vlan: ${VLAN}."
            fi
        fi
    
        $ETHTOOL "$LOCAL_ITF" 2>>$LOGFILE | grep "Link detected" | grep "yes" 2>>$LOGFILE
        if [ $? != 0 ];
        then
            DEBUG "ip check failed with eth: $LOCAL_ITF eth: $LOCAL_ITF is not linked."
            die "abnormal"
        fi
        
        #Check whether configuration error or not
        $IFCONFIG "$LOCAL_ITF" 2>>$LOGFILE | grep -w "$IP" 2>>$LOGFILE
        if [ $? != 0 ];
        then
            DEBUG "ip check failed with eth: $LOCAL_ITF."
            die "abnormal"
        fi
        
        #Check whether interface up or not
        $IFCONFIG "$LOCAL_ITF" 2>>$LOGFILE | grep -w "UP" 2>>$LOGFILE
        if [ $? != 0 ];
        then
            DEBUG "ip check failed, eth: $LOCAL_ITF is down."
            die "abnormal"
        else
            #call add route config 
    
            if [ "$ITF" == "GmnEx" ] && [ "${LOCAL_GMN_EX_INTF:0:3}" == "Gmn" ]
            then
                $IFCONFIG "$LOCAL_GMN_EX_ITF" 2>>$LOGFILE | grep -w "UP" 2>>$LOGFILE
                if [ $? != 0 ];
                then
                    DEBUG "check GmnEx base interface failed, eth: $LOCAL_GMN_EX_ITF is down."
                    $IFCONFIG "${LOCAL_GMN_EX_ITF}" up 2>>$LOGFILE
                    if [ $? != 0 ];
                    then
                        DEBUG "up GmnEx base interface failed, eth: $LOCAL_GMN_EX_ITF is abnormal."
                        die "abnormal"
                    fi
                fi
            fi
            if [ "$ITF" == "GmnIn" ]
            then
                $IFCONFIG "$LOCAL_GMN_IN_ITF" 2>>$LOGFILE | grep -w "UP" 2>>$LOGFILE
                if [ $? != 0 ];
                then
                    DEBUG "check GmnIn base interface failed, eth: ${LOCAL_GMN_IN_ITF} is down."
                    $IFCONFIG "${LOCAL_GMN_IN_ITF}" up 2>>$LOGFILE
                    if [ $? != 0 ];
                    then
                        DEBUG "up GmnIn base interface failed, eth: ${LOCAL_GMN_IN_ITF} is abnormal."
                        die "abnormal"
                    fi
                fi
            fi
            
            # 如果是浮动IP正常，每三分钟广播一次浮动IP的arp
            if echo "$ITF" > /dev/null; then
                local -i minute=$(date +"%M" | sed 's/^0//')
                local -i second=$(date +"%S" | sed 's/^0//')
                ((minute%=3))
                
                if [ $minute -eq 0 ] && [ $second -lt 5 ];then
                    local floatItf=$(echo "$ITF" | sed 's/:.*$//')
                    ndisc6 "$IP" "$floatItf"
                    DEBUG "second:$second ndisc6 "$IP" "$floatItf""
                fi
            fi
            
            DEBUG "normal"
            echo "normal"
            exit $EXIT_CODE_SUCCESS
        fi
    fi
}

function start_network()
{
    DEBUG "start_network begin."
    if [ -z "$IP_TYPE" ] || [ "IPV4" == "$IP_TYPE" ]; then
        case $ITF in
        "GmnEx:1")
            sh gmnExFloatIpCfg.sh add "$IP" "$MASK" "$GW" 2>>$LOGFILE
            if [ $? == 1 ];
            then
                die "start failed: sh gmnExFloatIpCfg.sh add $IP $MASK $GW"
            fi
            ;;
        *)
            die "Interface not matched! Interface is ${ITF}"
        esac
        echo "start success"
    else
        case $ITF in
        "GmnEx")
            sh gmnExFloatIpCfg.sh add "$IP" "$MASK" 2>>$LOGFILE
            if [ $? == 1 ];
            then
                die "start failed: sh gmnExFloatIpCfg.sh add $IP MASK:$MASK "
            fi
            ;;
        *)
            die "Interface not matched! Interface is ${ITF}"
        esac
        echo "start success"
    fi
}

function stop_network()
{   
    if [ -z "$IP_TYPE" ] || [ "IPV4" == "$IP_TYPE" ]; then
        case $ITF in
        "GmnEx:1")
            sh gmnExFloatIpCfg.sh del "$IP" "$MASK" >>$LOGFILE 2>&1
            ;;
        *)
            die "Interface not matched! Interface is $ITF"
        esac
        echo "stop success"
    else
        case $ITF in
        "GmnEx")
            sh gmnExFloatIpCfg.sh del "$IP" "$MASK" >>$LOGFILE 2>&1
            ;;
        *)
            die "Interface not matched! Interface is $ITF"
        esac
        echo "stop success"
    fi
}

function restart_network()
{
    stop_network
    start_network
}

function ip_Monitor()
{
    # Internal variable
    ACTION=$1
    ITF_KEY=$2

    Check_Param

    case "$ACTION" in
    "start")
    start_network
    ;;
    "stop")
    stop_network
    ;;
    "status")
    status_network
    ;;
    "restart")
    restart_network
    ;;
    *)
    die $"Usage: $0 {start|stop|status|restart}"
    esac

}
