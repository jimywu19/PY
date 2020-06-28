#!/bin/bash
# Shell script to provide maintain GMN external IP info.
# To Check whether the param valid;
# To Create External Vlan
# To Create External Bridge(GmnEx)
# To Create Policy_Routing
# To Clear all external network conf
# --------------------------------------------------------------------
# exit code meanings :
# 0:success                --->at lease on check point isn't correct
# 1:failed                 --->at lease on check point op failed
# 2:record already exist   --->all check point are correct
# --------------------------------------------------------------------

#Cache Input param and local variable
ACTION=$1
DEST=$2
MASK=$3

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
. ../func/globalvar.sh
. ./network.conf               || { echo "Can't load ./network.conf"; exit 1; }

BOND="eth0"

#add for adapting ipv6
if [ -z "$IP_TYPE" ] || [ "IPV4" == "$IP_TYPE" ]; then
    if [ "${LOCAL_GMN_EX_INTF:0:3}" != "Gmn" ]
    then
        BRIDGE_EX_FLOAT="${LOCAL_GMN_EX_INTF}:1"
        ITF_EX_FLOAT="$LOCAL_GMN_EX_INTF"
    else
        BRIDGE_EX_FLOAT="${LOCAL_GMN_EX}:1"
        ITF_EX_FLOAT="$LOCAL_GMN_EX"
    fi
else
    if [ "${LOCAL_GMN_EX_INTF:0:3}" != "Gmn" ]
    then
        BRIDGE_EX_FLOAT="${LOCAL_GMN_EX_INTF}"
        ITF_EX_FLOAT="$LOCAL_GMN_EX_INTF"
    else
        BRIDGE_EX_FLOAT="${LOCAL_GMN_EX}"
        ITF_EX_FLOAT="$LOCAL_GMN_EX"
    fi
fi


# Linux bin paths, change this if it can not be autodetected via which command
ROUTE="$(which route)"
IFCONFIG="$(which ifconfig)"
CAT="$(which cat)"
DATE="$(which date)"
GREP="$(which grep)"
BASH="$(which sh)"
NOHUP="$(which nohup)"
ARPING="$(which arping)"
#define exit code
EXIT_CODE_SUCCESS=0
EXIT_CODE_FAILED=1
EXIT_CODE_RECORD_EXIST=2

#use counter record op times on check points
#Local op times on check points
LOCAL_OP_TIMES=0

getCurPath()
{
    if [ "` dirname "$0" `" = "" ] || [ "` dirname "$0" `" = "." ]; then
        CUR_PATH="`pwd`"
    else
        cd ` dirname "$0" `
        CUR_PATH="`pwd`"
        cd - > /dev/null 2>&1
    fi
}

# change to cur path
getCurPath
cd "$CUR_PATH"

# Main directory where backup will be stored
MBD="${_HA_SH_LOG_DIR_/:-/var/log/ha/shelllog/}"
[ ! -d $MBD ] && mkdir -p $MBD ||:

#Debug block
DEBUG_MACRO="false"
LOGFILE=$MBD"/ipMonitor.log"

alias DEBUG='loginner [INFO ] [$$] [$(basename ${BASH_SOURCE}):${LINENO}]'
shopt -s expand_aliases
loginner()
{
    if [ "$DEBUG_MACRO" = "false" ];
    then
        echo "[$(date +'%Y-%m-%d %H:%M:%S,%N %z')] $*" >> $LOGFILE
    else
        echo $*
    fi
}

#Check input params
function Check_Param()
{
    DEBUG "Action:$ACTION, IP:$DEST, Netmask:$MASK"
    
    #add for adapting ipv6
    if [ -z "$IP_TYPE" ] || [ "IPV4" == "$IP_TYPE" ]; then
        if [ -z $ACTION ] || [ -z $DEST ] || [ -z $MASK ] ;
        then
            DEBUG "Input Param Error, pls check IPV4"
            exit $EXIT_CODE_FAILED
        fi
    else
        if [ -z $ACTION ] || [ -z $DEST ];
        then
            DEBUG "Input Param Error, pls check IPV6"
            exit $EXIT_CODE_FAILED
        fi
    fi
}

checkIpExsitOnOther()
{
    local ip="$1"
    local itf="$2"
    
    [ -n "$ip" ] || return 2
    [ -n "$itf" ] || return 3
    
    #add for adapting ipv6
    if [ -z "$IP_TYPE" ] || [ "IPV4" == "$IP_TYPE" ]; then
        if arping -w 1 -c 1 "$ip" -I "$itf"  >> $LOG_FILE; then
            DEBUG "arping -w 1 -c 1 "$ip" -I "$itf" return true"
            return 0
        fi
        
        DEBUG "arping -w 1 -c 1 "$ip" -I "$itf" return false"
        
        return 1
    else
        if ndisc6 $ip $itf  >> $LOG_FILE; then
            DEBUG "ndisc6 $ip $itf return true"
            return 0
        else
            DEBUG "ndisc6 $ip $itf return false"
            return 1
        fi
    fi
}

#Create External Float IP
function Create_Float_Ex()
{
    DEBUG "Create_Bridge_Ex():Enter!!!"
    DEBUG "Create External Bridge Start ......"
    
    # 如果其他节点配置了浮动IP，本节点不再配置
    if checkIpExsitOnOther "$DEST" "$ITF_EX_FLOAT" ; then
        DEBUG "another node already config the float IP: $DEST"
        return 1
    fi
    
    #Prevent off and on
    #add for adapting ipv6
    if [ -z "$IP_TYPE" ] || [ "IPV4" == "$IP_TYPE" ]; then
        $IFCONFIG lo:1 $DEST/32
    
        RESULT="$($IFCONFIG $BRIDGE_EX_FLOAT|grep -w "$DEST"|grep -w "$MASK")"
        if [ $? == 0 ];
        then
            DEBUG "$DEST already exist"
            DEBUG "Current GmnEx IpInfo is: "$RESULT
        else
            $IFCONFIG $BRIDGE_EX_FLOAT $DEST netmask $MASK up
    
            if [ $? != 0 ];
            then
                DEBUG "Create External Bridge Itf: "$BRIDGE_EX_FLOAT" failed"
                exit $EXIT_CODE_FAILED
            else
                DEBUG "Create External Bridge Itf: "$BRIDGE_EX_FLOAT" success"
                LOCAL_OP_TIMES=$((LOCAL_OP_TIMES+1))
            fi
        fi
        
        $ARPING -q -U -c 1 -w 1 -I "$ITF_EX_FLOAT" "$DEST"
    else
        $IFCONFIG lo inet6 add $DEST/128
        RESULT="$($IFCONFIG $BRIDGE_EX_FLOAT|grep -w "$DEST")"
        if [ $? == 0 ];
        then
            DEBUG "$DEST already exist"
            DEBUG "Current GmnEx IpInfo is: "$RESULT
        else
            $IFCONFIG $BRIDGE_EX_FLOAT inet6 add $DEST/$MASK
            if [ $? != 0 ];
            then
                DEBUG "Create External Bridge Itf: "$BRIDGE_EX_FLOAT" $DEST/$MASK failed"
                exit $EXIT_CODE_FAILED
            else
                DEBUG "Create External Bridge Itf: "$BRIDGE_EX_FLOAT" success"
                LOCAL_OP_TIMES=$((LOCAL_OP_TIMES+1))
            fi
        fi
        NDISC6="$(which ndisc6)"
        $NDISC6 "$DEST" "$ITF_EX_FLOAT"
        
    fi
}

#Clear External IP Info
function Clear_GmnEx_IPinfo()
{   
    #add for adapting ipv6
    if [ -z "$IP_TYPE" ] || [ "IPV4" == "$IP_TYPE" ]; then
        $IFCONFIG lo:1 0.0.0.0
    
        RESULT="$($IFCONFIG | grep $BRIDGE_EX_FLOAT)"
        if [ $? == 0 ];
        then
            $IFCONFIG $BRIDGE_EX_FLOAT down
            if [ $? != 0 ];
            then
                DEBUG "Clear $BRIDGE_EX_FLOAT config failed"
                exit $EXIT_CODE_FAILED
            else
                DEBUG "Clear $BRIDGE_EX_FLOAT config success"
                LOCAL_OP_TIMES=$((LOCAL_OP_TIMES+1))
            fi
        fi
    else
        $IFCONFIG lo inet6 del $DEST/128
    
        RESULT="$($IFCONFIG | grep $BRIDGE_EX_FLOAT)"
        if [ $? == 0 ];
        then
            $IFCONFIG $BRIDGE_EX_FLOAT inet6 del $DEST/$MASK
            if [ $? != 0 ];
            then
                DEBUG "Clear $BRIDGE_EX_FLOAT config del $DEST/$MASK failed"
                exit $EXIT_CODE_FAILED
            else
                DEBUG "Clear $BRIDGE_EX_FLOAT config success"
                LOCAL_OP_TIMES=$((LOCAL_OP_TIMES+1))
            fi
        fi
    fi
}

function Show_Help()
{
    DEBUG "Show_Help():Enter!!!"
    
cat<<EOF
Usage: GmnExternalIpInfo.sh {add|del|help} dst mask gw vlanId
        add        add GmnEx IP Info
        delete     del GmnEx IP Info
        help       show this help message
Example:
        GmnExternalIpInfo.sh add 192.168.40.2 255.255.255.0 192.168.40.1
        GmnExternalIpInfo.sh del 192.168.40.2 255.255.255.0 192.168.40.1
        GmnExternalIpInfo.sh help
EOF
    exit $EXIT_CODE_FAILED
}

Main_Process()
{
    case $ACTION in
    add)
        Check_Param
        Create_Float_Ex
        if [ $? == 1 ]; then
            DEBUG "IP config Failed"
            exit $EXIT_CODE_FAILED
        fi
        
        #conf route
        ;;
    del)
        Check_Param
        Clear_GmnEx_IPinfo
        #clear route
        ;;
    *|help)
        Show_Help
    esac

    #insert blank line for the convenience of viewing
    if [ $LOCAL_OP_TIMES == 0 ];
    then
        exit $EXIT_CODE_RECORD_EXIST
    else
        exit $EXIT_CODE_SUCCESS
    fi
}

Main_Process
