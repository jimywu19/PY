#!/bin/bash

################################################
# init log
################################################
cd "$(dirname $0)"
CUR_PATH=$(pwd)
declare -r ScriptName=`basename $0`

. $CUR_PATH/func/func.sh || { echo "fail to load $CUR_PATH/func/func.sh"; exit 1; }

#add for adapting IPV6
. $CUR_PATH/../install/common_var.sh || { echo "load $HA_DIR/install/common_var.sh failed."; exit 1; }

#add for adapting IPV6

LOG_BASE_DIR=$(dirname $_HA_SH_LOG_DIR_)
mkdir -p $LOG_BASE_DIR
chmod 700 $LOG_BASE_DIR
chown $GMN_USER: $LOG_BASE_DIR
mkdir -p $_HA_SH_LOG_DIR_
LOG_FILE=$_HA_SH_LOG_DIR_/config.log

#################################################

checkIsVm()
{
    if [ -n "$(dmidecode | grep -E 'xen|Xen|VMware')" ]; then
        return 0
    else
        return 1
    fi
}

checkConditionList()
{
    local input="$1"
    local condition="$2"
    
    local ret=1
    local locIfs="$IFS"
    IFS=":"
    for cond in $condition; do
        if echo "$input" | grep -i "^$cond$" > /dev/null;then
            ret=0
            break
        fi
    done
    
    echo "$input  $condition $ret" 
    IFS="$locIfs"
    return $ret
}

checkQuit()
{
    local input=$1
    if echo "$input" | grep -iE "^q|quit$" >/dev/null;then
        echo "quit init"
        exit 1
    fi
    return 0    
}

readInput()
{
    local info="$TIP_INFO"
    local checkFun="$1"
    local condition="$2"
    local default="$3"

    INPUT="$default"

    echo -en "$info"
    local input=""
    while read input; do
        input=$(echo $input)

        checkQuit
    
        if [ -z "$input" -a -n "$default" ];then
            INPUT="$default"
            return
        fi
    
        if eval "$checkFun \"$input\" \"$condition\"";then
            break
        fi
        
        echo -en "\n\n$info"
    done
    
    INPUT="$input"
}

getValue()
{
    local info="$1"
    local key="$2"
    values=$(echo "$info" | grep "$key=" | awk -F= '{print $2}' | awk -F"#" '{print $1}')
    values=$(echo $values)
    echo $values
}

initCfgIP()
{
    local key="$1"
    local info="$2"
    
    local ip=$(echo "$info" | awk -F"/" '{print $1}')
    local mask=$(echo "$info" | awk -F"/" '{print $2}')
    local gateway=$(echo "$info" | awk -F"/" '{print $3}')

    eval "${key}_IP=$ip"
    eval "${key}_MASK=$mask"
    eval "${key}_GW=$gateway"
}

checkIpsByType()
{
    local prefix="$1"
    local type="$2"
    if [ "$type" == "EX" -o "$type" == "IN" -o "$type" == "ESCAPE" ];then
        eval "checkIps $(getIpsByType "$prefix" "$type")" || return 1
    fi
}


# 非一体机场景校验本端信息
checkLocalInfo4Other()
{
    # 单机不需要浮动IP地址
    if ! echo "$haMode" | grep -iE "^true|2$" > /dev/null; then
        # 单机设置浮动IP等于物理IP
        FLOAT_GMN_EX_IP="$LOCAL_GMN_EX_IP"
    else
        if ! checkIpsByType "FLOAT_GMN_" "EX";then
            DIFF_PARAMETER_LIST="$(getIpParasByType "FLOAT_GMN_" "EX")"
            ECHOANDLOG_ERROR "the float ip information is invalid"
            return 1
        fi
        
        # 本端ip不能等于浮动IP
        if [ "$LOCAL_GMN_EX_IP" == "$FLOAT_GMN_EX_IP" ];then
            DIFF_PARAMETER_LIST="LOCAL_GMN_EX_IP FLOAT_GMN_EX_IP"
            ECHOANDLOG_ERROR "the FLOAT_GMN_EX_IP:$FLOAT_GMN_EX_IP can not same as LOCAL_GMN_EX_IP:$LOCAL_GMN_EX_IP"
            return 1
        fi
    fi

    # 本端
    if ! checkIpsByType "LOCAL_GMN_" "EX"; then
        DIFF_PARAMETER_LIST="$(getIpParasByType "LOCAL_GMN_" "EX")"
        ECHOANDLOG_ERROR "the ip information of local host is invalid"
        return 1
    fi

    # 非一体机部署，主机名可以由用户指定，可以不为 GMN01/GMN02
    if ! checkHostnameValid "$LOCAL_nodeName"; then
        DIFF_PARAMETER_LIST="LOCAL_nodeName"
        ECHOANDLOG_ERROR "the LOCAL_nodeName:$LOCAL_nodeName is invalid"
        return 1
    fi
    
    # Vlan可选，如果为空，则返回成功
    if ! checkVlan "$LOCAL_GMN_EX_VLAN"; then
        ECHOANDLOG_ERROR "the vlan of local host is invalid"
        return 1
    fi

}

checkHaArbitrateIpValid()
{
    local ipList="$1"
    
    [ -n "$ipList" ] || return 1
    
    local ifs="$IFS"
    IFS=","
    local ip=""
    
    local ret=0
    for ip in $ipList; do
        ip=$(echo $ip)
        if ! checkIp "$ip"; then
            LOG_INFO "ip:$ip is invalid"
            ret=1
            break
        fi
    done
    
    IFS="$ifs"
    
    return $ret
}

# 非一体机场景校验对端信息
checkRemoteInfo4Other()
{
    # 公共，只有双机才需要这个配置
    if ! checkHaArbitrateIpValid "$haArbitrateIP"; then
        ECHOANDLOG_ERROR "the ha arbitrate ip:$haArbitrateIP is invalid"
        return 1
    fi
    
    # 对端
    if ! checkIpsByType "REMOTE_GMN_" "EX"; then
        DIFF_PARAMETER_LIST="$(getIpParasByType "REMOTE_GMN_" "EX")"
        ECHOANDLOG_ERROR "the ip information of remote host is invalid"
        return 1
    fi
    
    # 对端ip不能等于本端IP
    if [ "$REMOTE_GMN_EX_IP" == "$LOCAL_GMN_EX_IP" ];then
        DIFF_PARAMETER_LIST="LOCAL_GMN_EX_IP REMOTE_GMN_EX_IP"
        ECHOANDLOG_ERROR "the LOCAL_GMN_EX_IP:$LOCAL_GMN_EX_IP can not same as REMOTE_GMN_EX_IP:$REMOTE_GMN_EX_IP"
        return 1
    fi
    
    # 对端ip不能等于浮动IP
    if [ "$REMOTE_GMN_EX_IP" == "$FLOAT_GMN_EX_IP" ];then
        DIFF_PARAMETER_LIST="REMOTE_GMN_EX_IP FLOAT_GMN_EX_IP"
        ECHOANDLOG_ERROR "the FLOAT_GMN_EX_IP:$FLOAT_GMN_EX_IP can not same as REMOTE_GMN_EX_IP:$REMOTE_GMN_EX_IP"
        return 1
    fi
    
    # 非一体机部署，主机名可以由用户指定，可以不为 GMN01/GMN02
    if ! checkHostnameValid "$REMOTE_nodeName"; then
        DIFF_PARAMETER_LIST="REMOTE_nodeName"
        ECHOANDLOG_ERROR "the REMOTE_nodeName:$REMOTE_nodeName is invalid"
        return 1
    fi
    
    if echo "$REMOTE_nodeName" | grep -i "^${LOCAL_nodeName}$" > /dev/null; then
        DIFF_PARAMETER_LIST="LOCAL_nodeName REMOTE_nodeName"
        ECHOANDLOG_ERROR "the LOCAL_nodeName:$LOCAL_nodeName can not same as REMOTE_nodeName:$REMOTE_nodeName"
        return 1
    fi
    
    # Vlan可选，如果为空，则返回成功
    if ! checkVlan "$REMOTE_GMN_EX_VLAN"; then
        ECHOANDLOG_ERROR "the vlan of remote host is invalid"
        return 1
    fi
}

checkVlan()
{
    local vlan="$1"
    vlan=$(echo $vlan)
    if [ -z "$vlan" ];then
        LOG_INFO "the vlan is empty, no need to config vlan"
        return 0
    fi
    
    if ! echo "$vlan" | grep "^[-]\{0,1\}[0-9]\+$" > /dev/null;then
        ECHOANDLOG_ERROR "the vlan is not a number"
        return 1
    fi
    
    local -i iVlan="$vlan"
    
    if [ $iVlan -gt 4096 -o $iVlan -lt 0 ];then
        ECHOANDLOG_ERROR "the vlan:$vlan is out of bound, it must be [0-4096]"
        return 1
    fi
}

# sudo config set
function setsudocfg
{
    local userName="$1"
    local sudocfg="$2"
             
    chmod 755 /etc/sudoers
    local getOldCfg=`sed -n "/^$userName ALL=(root) NOPASSWD:/p" /etc/sudoers`
    if [ "-" == "-${getOldCfg}" ] 
    then
        sudocfg=$(echo "$sudocfg" |sed 's/ /,/g')
        getOldCfg="$userName ALL=(root) NOPASSWD:$sudocfg"
    fi
    for i in ${sudocfg}
    do
        echo ${getOldCfg} | grep ${i} > /dev/null 2>&1
        if [ $? -ne 0 ] 
        then
            getOldCfg="${getOldCfg}, ${i}"
        fi
    done
    /bin/sed -i "/^$userName/d" /etc/sudoers
    /bin/echo ${getOldCfg} >> /etc/sudoers
    if [ $? -ne 0 ] 
    then
        chmod 400 /etc/sudoers
        echo "error: set sudo cfg fail ..."
        return 1
    fi
    chmod 400 /etc/sudoers
    return 0
}

setsudocfg4AllUser()
{
    setsudocfg dbadmin "/usr/local/bin/pwswitch"
    chmod 500 /usr/local/bin/pwswitch
}

cfgGmnIP4Other()
{
    if [ -f "$HA_RUNTIME_CONF" ];then
        LOG_INFO "the content of old cfg file: $(cat $HA_RUNTIME_CONF)"
        getOldDoubleConfig "$HA_RUNTIME_CONF"
        
        local oldLocalIpInfo=$(getIpsByType "OLD_LOCAL_GMN_" "EX")
        local newLocalIpInfo=$(getIpsByType "LOCAL_GMN_" "EX")
    fi

    mkdir -p $HA_RUNTIME_CONF_DIR
    rm -f $HA_RUNTIME_CONF
    cp -af $HA_CONF_USER $HA_RUNTIME_CONF
    
    # 保存部署信息，ip配置脚本需要使用到
    savePara2NetworkConf "DEPLOY_MODE" "$NETWORK_CONF" 
    savePara2NetworkConf "LOCAL_GMN_EX_INTF" "$NETWORK_CONF" 
    
    eval "saveIps2NetworkConf $(getIpParasByType "LOCAL_GMN_" "EX")"

    eval "saveIps2NetworkConf $(getIpParasByType "FLOAT_GMN_" "EX")"

    savePara2NetworkConf "LOCAL_GMN_EX_VLAN" "$NETWORK_CONF"

    return 0
}

cfgHA()
{
    local mode="$1"
    local heartIpList=""
    
    ECHOANDLOG_INFO "start configure ha, it will take about 1~2 minutes"
    
    if [ -z "$IP_TYPE" ] ||  [ "IPV4" == "$IP_TYPE" ]; then
        if [ -f /etc/rsyncd.conf ]; then
            local oldListenIp=$(grep "^address" /etc/rsyncd.conf | awk '{print $3}')
            if [ -n "oldListenIp" ] && [ "$oldListenIp" != "127.0.0.1"  ]; then
                LOG_INFO "maybe in cascade mode, modify rsyncd listen IP from $oldListenIp to $LOCAL_GMN_EX_IP"
                sed -ri "s/^(address = ).*$/\1${LOCAL_GMN_EX_IP}/" /etc/rsyncd.conf || die "sed /etc/rsyncd.conf failed"
                $RYNCD_TOOL stop
            fi
        fi
        
        fmDeployMode=${fmDeployMode:-$ALL_FM}
    
        local externListen=""
    
        # modify pg_hba.conf access network
        if [ "$externDb" == "y" ]; then
            local network=$(getNetworkSeg $FLOAT_GMN_EX_IP $FLOAT_GMN_EX_MASK)
            externListen="$network"
        fi
        
        local ret=0
        if [ "$mode" == "$GMN_MODE_SINGLE" ];then
            $HA_CONFIG_TOOL -m "$mode" -l "$LOCAL_nodeName" -o "$FLOAT_GMN_OM_IP" -f "$FLOAT_GMN_EX_IP" -e "$externListen" >> $LOG_FILE 2>&1
            ret=$?
            LOG_INFO "configHa -m \"$mode\" -l \"$LOCAL_nodeName\" -o "$FLOAT_GMN_OM_IP" -f "$FLOAT_GMN_EX_IP" -e "$externListen" return $ret"
        else
            if [ "$DEPLOY_MODE" == "$FC_MODE" ]; then
                heartIpList="$LOCAL_nodeName:$LOCAL_GMN_ESCAPE_IP:eth2,$REMOTE_nodeName:$REMOTE_GMN_ESCAPE_IP:eth2;$LOCAL_nodeName:$LOCAL_GMN_IN_IP:GmnIn,$REMOTE_nodeName:$REMOTE_GMN_IN_IP:GmnIn"
            else
                if [ -z "$LOCAL_GMN_EX_INTF" ];then
                    LOCAL_GMN_EX_INTF="GmnEx"
                fi
                
                if [ -z "$REMOTE_GMN_EX_INTF" ];then
                    REMOTE_GMN_EX_INTF="GmnEx"
                fi
                heartIpList="$LOCAL_nodeName:$LOCAL_GMN_EX_IP:$LOCAL_GMN_EX_INTF,$REMOTE_nodeName:$REMOTE_GMN_EX_IP:$REMOTE_GMN_EX_INTF"
            fi
            
            $HA_CONFIG_TOOL -m "$mode" -l "$LOCAL_nodeName" -r "$REMOTE_nodeName" -b "$heartIpList" -g "$haArbitrateIP" -f "$FLOAT_GMN_EX_IP" -d "$fmDeployMode" -o "$FLOAT_GMN_OM_IP" -e "$externListen" >> $LOG_FILE 2>&1
            ret=$?
            LOG_INFO "configHa -m \"$mode\" -l \"$LOCAL_nodeName\" -r \"$REMOTE_nodeName\" -b \"$heartIpList\" -g \"$haArbitrateIP\" -f "$FLOAT_GMN_EX_IP" -d "$fmDeployMode" -o "$FLOAT_GMN_OM_IP" -e "$externListen" return $ret"
        fi
        
        return $ret
    else
        if [ -f /etc/rsyncd.conf ]; then
            local oldListenIp=$(grep "^address" /etc/rsyncd.conf | awk '{print $3}')
            if [ -n "oldListenIp" ] && [ "$oldListenIp" != "::1"  ]; then
                LOG_INFO "maybe in cascade mode, modify rsyncd listen IP from $oldListenIp to $LOCAL_GMN_EX_IP"
                sed -ri "s/^(address = ).*$/\1${LOCAL_GMN_EX_IP}/" /etc/rsyncd.conf || die "sed /etc/rsyncd.conf failed"
                $RYNCD_TOOL stop
            fi
        fi
        
        fmDeployMode=${fmDeployMode:-$ALL_FM}
    
        local externListen=""
    
        # modify pg_hba.conf access network
        if [ "$externDb" == "y" ]; then
            local network=$(getNetworkSeg $FLOAT_GMN_EX_IP $FLOAT_GMN_EX_MASK)
            externListen="$network"
        fi
        
        local ret=0
        if [ "$mode" == "$GMN_MODE_SINGLE" ];then
            $HA_CONFIG_TOOL -m "$mode" -l "$LOCAL_nodeName" -o "$FLOAT_GMN_OM_IP" -f "$FLOAT_GMN_EX_IP" -e "$externListen" >> $LOG_FILE 2>&1
            ret=$?
            LOG_INFO "configHa -m \"$mode\" -l \"$LOCAL_nodeName\" -o "$FLOAT_GMN_OM_IP" -f "$FLOAT_GMN_EX_IP" -e "$externListen" return $ret"
        else
            if [ "$DEPLOY_MODE" == "$FC_MODE" ]; then
                heartIpList="$LOCAL_nodeName:[$LOCAL_GMN_ESCAPE_IP]:eth2,$REMOTE_nodeName:[$REMOTE_GMN_ESCAPE_IP]:eth2;$LOCAL_nodeName:[$LOCAL_GMN_IN_IP]:GmnIn,$REMOTE_nodeName:[$REMOTE_GMN_IN_IP]:GmnIn"
            else
                if [ -z "$LOCAL_GMN_EX_INTF" ];then
                    LOCAL_GMN_EX_INTF="GmnEx"
                fi
                
                if [ -z "$REMOTE_GMN_EX_INTF" ];then
                    REMOTE_GMN_EX_INTF="GmnEx"
                fi
                heartIpList="$LOCAL_nodeName:[$LOCAL_GMN_EX_IP]:$LOCAL_GMN_EX_INTF,$REMOTE_nodeName:[$REMOTE_GMN_EX_IP]:$REMOTE_GMN_EX_INTF"
            fi
            
            $HA_CONFIG_TOOL -m "$mode" -l "$LOCAL_nodeName" -r "$REMOTE_nodeName" -b "$heartIpList" -g "$haArbitrateIP" -f "$FLOAT_GMN_EX_IP" -d "$fmDeployMode" -o "$FLOAT_GMN_OM_IP" -e "$externListen" >> $LOG_FILE 2>&1
            ret=$?
            LOG_INFO "configHa -m \"$mode\" -l \"$LOCAL_nodeName\" -r \"$REMOTE_nodeName\" -b \"$heartIpList\" -g \"$haArbitrateIP\" -f "$FLOAT_GMN_EX_IP" -d "$fmDeployMode" -o "$FLOAT_GMN_OM_IP" -e "$externListen" return $ret"
        fi
        
        return $ret
    fi
}

######################################################################
#   FUNCTION   : getPara
#   DESCRIPTION: 
#   INPUT      : -U
#                -R
#                -D
#                -I
#                -C
######################################################################
getPara4Other()
{
    while getopts m:r:f:l:n: option
    do
        case "$option"
        in
            r) REMOTE_IP=$OPTARG
                if [ -z "$REMOTE_IP" ]; then
                    exit 1;
                fi
                ;;
            l) LOCAL_IP=$OPTARG
                if [ -z "$LOCAL_IP" ]; then
                    exit 1;
                fi
                ;;
            f) FLOAT_GMN_IP="$OPTARG"
                if [ -z "$FLOAT_GMN_IP" ]; then
                    exit 1;
                fi
                ;;    
            m) HA_MODE="$OPTARG"
                if [ -z "$HA_MODE" ]; then
                    exit 1;
                fi
                ;;  
            n) NODE_NUM="$OPTARG"
                if [ -z "$NODE_NUM" ]; then
                    exit 1;
                fi
                ;;
            \?) 
             ECHOANDLOG_ERROR "Paramter error, $@"
             exit 1
             ;;
        esac
    done
    
    LOG_INFO "Get parameter: the HA_MODE=$HA_MODE, NODE_NUM=$NODE_NUM, LOCAL_IP=$LOCAL_IP, REMOTE_IP=$REMOTE_IP, FLOAT_GMN_IP=$FLOAT_GMN_IP"
    return 0
}

##########################################################################
## 
## 获取GMN节点的部署场景，一体机or非一体机场景
## 
##########################################################################
getGmnDeployMode()
{
    LOG_INFO "in noneAllInOne mode"
    DEPLOY_MODE="$OTHER_MODE"
}

##########################################################################
## 
## 非一体机场景初始化
## 
##########################################################################
gmninit_other()
{
    local first="false"
    
    if [ -f "$RESTORE_CONF_FILE" ]; then
        first="true"
        HA_CONF_USER="${RESTORE_CONF_FILE}"
    else
        . $CUR_PATH/get_config/config_parameter_get.sh
        if [ -z "$CHANGE_VAR" ]; then
            first="true"
            getConfigParameters
        else
            changeConfigParameters "$CHANGE_VAR"
        fi
        HA_CONF_USER="$NONE_FC_CFG"
    fi

    # 从配置文件获取GMN配置信息
    getDoubleConfig "$HA_CONF_USER"
    
    if echo "$haMode" | grep -iE "^false|1$" > /dev/null;  then
        # 单机
        HA_MODE="$GMN_MODE_SINGLE"
        ECHOANDLOG_INFO "configure in Single mode"
    elif echo "$haMode" | grep -iE "^true|2$" > /dev/null; then
        # 双机
        HA_MODE="$GMN_MODE_DOUBLE"
        ECHOANDLOG_INFO "configure in HA mode"
        
        checkRemoteInfo4Other || die "check the configure informations failed, please modify it"
    else
        die "haMode:$haMode is invalid, it must be 2 or 1"
    fi

    checkLocalInfo4Other || die "check the configure informations failed, please modify it"
    ECHOANDLOG_INFO "check configuration success"

    # 配置前，需要停止HA
    $HA_TOOLS_DIR/haStopAll.sh -o >> $LOG_FILE 2>&1
    
    # 需要放在配置HA之前配置sudo
    setsudocfg4AllUser
    
    # 调用IP配置工具配置GMN节点本机IP
    cfgGmnIP4Other || die "configure ip failed"
    
    if [ "$first" == "true" ]; then
        ECHOANDLOG_INFO "configure ip success"
        [ -n "$CONFIG_RESULT" ] && echo 30 >> $CONFIG_RESULT
        
        # 配置HA
        cfgHA "$HA_MODE"  || die "configure ha failed"
        ECHOANDLOG_INFO "configure ha success"
        [ -n "$CONFIG_RESULT" ] && echo 80 >> $CONFIG_RESULT
    fi
    
    return 0
}

##########################################################################   
#   Global var
##########################################################################
FC_MODE="0"
OTHER_MODE="1"
DBFC_MODE_NUM="2"

DBFC_MODE="NO"


GMN_MODE_SINGLE="s"
GMN_MODE_DOUBLE="d"

GMN_MODE_SINGLE_NUM="1"
GMN_MODE_DOUBLE_NUM="2"

BASE_DIR="$GM_PATH"
HA_BIN_DIR=$HA_DIR/bin
HA_TOOLS_DIR=$HA_DIR/tools
HA_CONF_DIR=$HA_DIR/conf

HA_CONFIG_TOOL=$HA_TOOLS_DIR/haConfig.sh
DEPLOY_CFG=$BASE_DIR/config/deployStatus
    
# 一体机场景，HA配置文件模板
FC_CFG_DIR=$HA_CONF_DIR/allInOne
FC_SINGLE_CFG=$FC_CFG_DIR/MODE1/gmn.cfg
FC_DOUBLE_LOCAL_CFG=$FC_CFG_DIR/MODE2/node1/gmn.cfg
FC_DOUBLE_REMOTE_CFG=$FC_CFG_DIR/MODE2/node2/gmn.cfg

# 非一体机场景，HA配置文件模板，需要用户在执行本脚本的时候先修改该配置文件模板
NONE_FC_CFG_DIR=$HA_CONF_DIR/noneAllInOne
NONE_FC_CFG=$NONE_FC_CFG_DIR/gmn.cfg

# IP工具脚本
IPTOOLS_DIR=$HA_TOOLS_DIR/iptools

HA_OMSCRIPT_PATH=$HA_TOOLS_DIR/omscript
RYNCD_TOOL=$HA_OMSCRIPT_PATH/rsync_monitor.sh

# 配置文件路径
NETWORK_CONF=$IPTOOLS_DIR/network.conf
HA_RUNTIME_CONF_DIR=$HA_CONF_DIR/runtime
HA_RUNTIME_CONF=$HA_RUNTIME_CONF_DIR/gmn.cfg
HA_CONF_USER=""

##########################################################################
#  end Global var
##########################################################################

# 检查是否是root用户执行的
checkUserRoot
##########################################################################
#
##########################################################################
DEPLOY_MODE="$1"
# 强制指定一体机or非一体机部署
if [ "$DEPLOY_MODE" == "$FC_MODE" -o "$DEPLOY_MODE" == "$OTHER_MODE" -o "$DEPLOY_MODE" == "$DBFC_MODE_NUM" ];then
    shift
else
    # 从配置文件获取虚拟机部署方式，一体机部署or非一体机部署
    getGmnDeployMode
fi

# 判断是否恢复模式
RESTORE_MODE="restore"
CONFIG_MODE="$1"
RESTORE_CONF_FILE=""
if [ "$CONFIG_MODE" == "$RESTORE_MODE" ];then
    RESTORE_CONF_FILE="$2"
    if [ -f "$RESTORE_CONF_FILE" ];then
        LOG_INFO "gmninit in restore mode, conf file:$RESTORE_CONF_FILE"
        shift 2
    else
        die "gmninit in restore mode, but conf file:$RESTORE_CONF_FILE is not exsit."
    fi
fi

if [ "$DEPLOY_MODE" == "$OTHER_MODE" ]; then
    LOG_INFO "gmninit in OTHER_MODE"
    gmninit_other "$@" || die "init failed"
else
    die "$DEPLOY_MODE is not support deploy mode."
fi

chmod 600 $_HA_SH_LOG_DIR_/installInfor.log
ECHOANDLOG_INFO "init successful"

exit 0
