#!/bin/bash

# 
# 对外函数列表：
#   getMode
# 

if [ -z "$CGP_INSTALL_RESPONSE_SH" ]; then
CGP_INSTALL_RESPONSE_SH=CGP_INSTALL_RESPONSE_SH

. color.sh
. gmn_prompt.sh
. gmn_resp_vars.sh

######################################################################
#   FUNCTION   : GetIPEndSeg
#   DESCRIPTION: 根据框槽号获取IP的最后一个字段
#   CALLS      : 无
#   CALLED BY  : 无
#   INPUT      : 框号：  FN     槽号：  SN
#   OUTPUT     : 打印算出的字段
#   RETURN     : 0：成功  1：失败
#   CHANGE DIR : 无
######################################################################
GetIPEndSeg()
{
    local seg1="$1"
    local seg2="$2"
    
    [ "$seg1" -ge 0 -a "$seg2" -ge 0 ] || return 1
    
    local -i iEnd1
    local -i iEnd2
    ((iEnd1=seg1+128))
    ((iEnd2=seg2*8))
    
    echo "${iEnd1}.${iEnd2}"
    return 0
}

######################################################################
#   FUNCTION   : GetBackDev
#   DESCRIPTION: 获取BACK平面的物理IP以及虚拟IP的网口号
#   CALLS      : 无
#   CALLED BY  : 无
#   INPUT      : BACKn(n为数字)
#   OUTPUT     : 修改响应文件变量LOCAL_GMN_EX_INTF
#   RETURN     : 0：成功  1：失败
#   CHANGE DIR : 无
######################################################################
GetBackDev()
{
    local -i i
    local -i max=8
    
    for((i=0; $i<=$max; i++)); do
        if eval "[ -n \"\$CONFIG_BACK$i\" ]"; then
            LOCAL_GMN_EX_INTF="BACK$i"
            break
        fi
    done
    return 0
}

######################################################################
#   FUNCTION   : GetBackPip
#   DESCRIPTION: 获取BACK平面的物理IP以及虚拟IP的网口号
#   CALLS      : 无
#   CALLED BY  : 无
#   INPUT      : ESP_VIR_DEV
#   OUTPUT     : 修改响应文件变量 RESP_LOCAL_PIP LOCAL_GMN_EX_IP
#   RETURN     : 0：成功  1：失败
#   CHANGE DIR : 无
######################################################################
GetBackPip()
{
    [ -z "$LOCAL_GMN_EX_INTF" ] && return 1
    
    local ips=`eval echo "\\\$CONFIG_$LOCAL_GMN_EX_INTF"`
    
    local tmpPip="$RESP_LOCAL_PIP"
    RESP_LOCAL_PIP=`echo "$ips" | awk '{print $1}'`
    if ! chkIP "$RESP_LOCAL_PIP"; then
    	RESP_LOCAL_PIP="$tmpPip"
    	return 1
    fi
    
    local tmpPnm="$LOCAL_GMN_EX_IP"
    LOCAL_GMN_EX_IP=`echo "$ips" | awk '{print $2}'`
    if ! chkNetMask "$LOCAL_GMN_EX_IP"; then
        LOCAL_GMN_EX_IP="$tmpPnm"
    	RESP_LOCAL_PIP="$tmpPip"
    	return 1
    fi
    
    return 0
}
checkIsVm()
{
    if [ -n "$(dmidecode | grep -E 'xen|Xen|VMware')" ]; then
        return 0
    else
        return 1
    fi
}
######################################################################
#   FUNCTION   : LoadEnv
#   DESCRIPTION: 根据环境变量设置响应文件的部分配置
#   CALLS      : 无
#   CALLED BY  : 无
#   INPUT      : 环境变量：
#                   框号：      FN
#                   槽号：      SN
#                   主机名：    CONFIG_HOSTNAME
#   OUTPUT     : 无
#   RETURN     : 0：成功  1：失败
#   CHANGE DIR : 无
######################################################################
LoadEnv()
{
    RESP_FN="$FN"                   # 框号
    RESP_SN="$SN"                   # 槽号
    GetBackDev                      # 获取BACK平面的物理IP以及虚拟IP的网口号

	checkIsVm
	IS_VM=$?

    return 0
}

######################################################################
#   FUNCTION   : GetFSIP
#   DESCRIPTION: 根据框槽号来获取IP信息
#   CALLS      : 无
#   CALLED BY  : 无
#   INPUT      : 框号：  RESP_FN             槽号：  RESP_FN
#   OUTPUT     : 无
#   RETURN     : 0：成功
#   CHANGE DIR : 无
######################################################################
GetFSIP()
{
    [ -n "$RESP_FN" -a -n "$RESP_SN" ] || return 1
    
    # 根据框槽号获取主机名、BASE平面的IP等信息
    local seg
    seg=`GetIPEndSeg $RESP_FN $RESP_SN`
    [ -z "$seg" ] && return 1
    
    RESP_LOCAL_HB_IP1="172.17.$seg"
    RESP_LOCAL_HB_IP2="172.16.$seg"
    
    return 0
}

######################################################################
#   FUNCTION   : GetRemoteFSIP
#   DESCRIPTION: 根据框槽号来获取IP信息
#   CALLS      : 无
#   CALLED BY  : 无
#   INPUT      : 框号：  RESP_REMOTE_FN             槽号：  RESP_REMOTE_FN
#   OUTPUT     : 无
#   RETURN     : 0：成功
#   CHANGE DIR : 无
######################################################################
GetRemoteFSIP()
{
    [ -n "$RESP_REMOTE_FN" -a -n "$RESP_REMOTE_SN" ] || return 1
    
    # 根据框槽号获取主机名、BASE平面的IP等信息
    local seg
    seg=`GetIPEndSeg $RESP_REMOTE_FN $RESP_REMOTE_SN`
    [ -z "$seg" ] && return 1
    
    RESP_REMOTE_HB_IP1="172.17.$seg"
    RESP_REMOTE_HB_IP2="172.16.$seg"
    
    return 0
}

######################################################################
#   FUNCTION   : getRESP_FN
#   DESCRIPTION: 获取本端框号
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getRESP_FN()
{
    
    # 检查字符串合法性的函数
    READ_CHK_CMD="chkNum 0 99"
    
    # 错误信息
    READ_WRONG_INFO="Invalid frame number:[0-99]."
    
    # 帮助信息
    READ_HELP_INFO=""
    
    # 获取用户输入
    ReadPrint
    
    # 根据框槽号自动获取对应的IP信息
    GetFSIP
}

######################################################################
#   FUNCTION   : getRESP_SN
#   DESCRIPTION: 获取本端槽号
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getRESP_SN()
{
    
    # 检查字符串合法性的函数
    READ_CHK_CMD="chkSlotNum"    
    
    # 默认值
    #READ_DEFAULT_STR="0"
    
    # 错误信息
    READ_WRONG_INFO="Invalid frame number:[0-5],[8-13]."
    
    # 帮助信息
    READ_HELP_INFO=""
    
    # 获取用户输入
    ReadPrint
    
    # 根据框槽号自动获取对应的IP信息
    GetFSIP
}

######################################################################
#   FUNCTION   : getRESP_REMOTE_FN
#   DESCRIPTION: 获取本端框号
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getRESP_REMOTE_FN()
{
    
    # 检查字符串合法性的函数
    READ_CHK_CMD="chkNum 0 99"
    
    # 默认值
    #READ_DEFAULT_STR="0"
    
    # 错误信息
    READ_WRONG_INFO="Invalid frame number:[0-99]."
    
    # 帮助信息
    READ_HELP_INFO=""
    
    # 获取用户输入
    ReadPrint
    
    # 根据框槽号自动获取对应的IP信息
    GetRemoteFSIP
}

######################################################################
#   FUNCTION   : getRESP_REMOTE_SN
#   DESCRIPTION: 获取本端槽号
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getRESP_REMOTE_SN()
{
    
    # 检查字符串合法性的函数
    READ_CHK_CMD="chkSlotNum"
    
    # 默认值
    #READ_DEFAULT_STR="0"
    
    # 错误信息
    READ_WRONG_INFO="Invalid frame number:[0-5],[8-13]."
    
    # 帮助信息
    READ_HELP_INFO=""
    
    # 获取用户输入
    ReadPrint
    
    # 根据框槽号自动获取对应的IP信息
    GetRemoteFSIP
}

######################################################################
#ok1
#   FUNCTION   : chkIP
#   DESCRIPTION: 检查IP四段是否符合规范
#   CALLS      : 无
#   CALLED BY  : inputIP, inputNtpIP
#   INPUT      : 参数1：需要检查的IP地址
#   OUTPUT     : 无
#   RETURN     : 0：成功  1：失败
#   CHANGE DIR : 无
######################################################################
chkIP()
{
    local -i rc=0
    
    # 不是XXX.XXX.XXX.XXX形式，则返回失败
    if [ -z "`echo $1 | grep -w \"^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}$\"`" ]; then
        rc=1
    else
        local ips=`echo "$1" | tr '.' ' '`      # 存取IP的所有节点
        local ip                                # 存取IP的每一个节点
        
        for ip in $ips; do
            if [ "$ip" -gt 255 ]; then
                rc=1     # 节点不合法，则返回失败
                break
            fi
            # 节点合法，则继续检查下一个
        done
    fi
    
    return $rc
}

######################################################################
#ok1
#   FUNCTION   : chkNetMask
#   DESCRIPTION: 检查子网掩码四段是否符合规范
#   CALLS      : chkNode
#   CALLED BY  : inputNetMask
#   INPUT      : 参数1：需要检查的子网掩码
#   OUTPUT     : 无
#   LOCAL VAR  : 
#   USE GLOBVAR: 无
#   RETURN     : 0：成功  1：失败
#   CHANGE DIR : 无
######################################################################
chkNetMask()
{
    # 不是XXX.XXX.XXX.XXX形式，则返回失败
    if [ -z "`echo $1 | grep -w \"^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}$\"`" ]; then
        return 1
    else
        local -i rc=0      # 本函数返回码
        local masks=`echo $1 | tr '.' ' '`       # 存取IP的所有节点
        local mask             # 存取IP的每一个节点
        
        local maskOK=y         # $maskOK为y，则下个节点可以为255|254|252|248|240|224|192|128|0中的一个
                               # $maskOK为n，则下个节点只能为0
        local -i nodeRet=0     # 检查一个节点后的返回值
        local -i i=0
        for mask in $masks; do
            # $maskOK为y，当前节点可以为255|254|252|248|240|224|192|128|0中的一个
            if [ "$maskOK" = "y" ]; then
                if [ $mask -eq 255 ]; then
                    continue     # 节点为255，则继续检查下一个
                elif [ -n "`echo $mask | grep -E \"^254|252|248|240|224|192|128|0$\"`" ]; then
                    maskOK=n     # 节点为254|252|248|240|224|192|128|0，则后续节点只能为0
                    continue
                else
                    rc=1
                    break
                fi
            
            # $maskOK为n，当前节点只能为0
            else
                if [ $mask -eq 0 ]; then
                    continue
                else
                    rc=1
                    break
                fi
            fi
        done
    fi
    
    return $rc
}

######################################################################
#   FUNCTION   : gethaMode
#   DESCRIPTION: 获取安装模式
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : vars:（要求PROMPT_INFO不为空）
#                       READ_PROMPT_INFO        打印的提示信息
#                       READ_A_CMP_STR          用于比较用户输入是否正确的字符串数组
#                       READ_DEFAULT_STR        用户直接按回车所取的默认值（该值必须为空或在READ_A_CMP_STR内）
#                       READ_WRONG_INFO         用户输错时的提示信息
#                       READ_HELP_INFO          用户输入 ? 时打印的帮助信息
#                       READ_TIME_OUT           超时时间
#   RETURN     : NULL
######################################################################
gethaMode()
{
    # 提示信息
    READ_PROMPT_INFO=`echo -e "Please enter the mode to configure:"; \
        echo -e "1. Single mode"; \
        echo -e "2. High availability mode"; \
    `
    
    # 合法的字符串
    READ_A_CMP_STR=(1 2)
    
    # 默认值
    READ_DEFAULT_STR="2"
    
    # 错误信息
    READ_WRONG_INFO="Please enter '1' or '2'."
    
    # 帮助信息
    READ_HELP_INFO="If you type '1', this program will guide you to configuring Single mode.
If you type '2', this program will guide you to configuring High Availability mode"
    
    # 赋值的变量名
    READ_VAR_TO_GET=haMode
    
    # 获取用户输入
    ReadPrint
    
    # 获取相应安装模式下所需要的响应文件变量
    getRespValues
}

checkVlan()
{
    local vlan="$1"
    vlan=$(echo $vlan)
    if [ -z "$vlan" ];then
        return 0
    fi
    
    if ! echo "$vlan" | grep "^[-]\{0,1\}[0-9]\+$" > /dev/null;then
        return 1
    fi
    
    local -i iVlan="$vlan"
    
    if [ $iVlan -gt 4096 -o $iVlan -lt 0 ];then
        return 1
    fi
}

getRESP_LOCAL_VLAN()
{
	READ_CHK_CMD=checkVlan
	READ_DEFAULT_STR_IS_EMPTY="y"
	READ_DEFAULT_STR=""
	READ_WRONG_INFO="Please enter number [0-4096]."
	READ_HELP_INFO=""
	ReadPrint
}
getRESP_REMOTE_VLAN()
{
	READ_CHK_CMD=checkVlan
	READ_DEFAULT_STR_IS_EMPTY="y"
	READ_DEFAULT_STR=""
	READ_WRONG_INFO="Please enter number [0-4096]."
	READ_HELP_INFO=""
	ReadPrint
}

######################################################################
#   FUNCTION   : chkBackEth
#   DESCRIPTION: 检查是否和合法的网口号
#   CALLS      : NULL
#   CALLED BY  : getVDev
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : 0: 合法; 1: 不合法
######################################################################
chkBackEth()
{
    local -i rc=1
    if echo "$1" | grep '^eth[0-9]\+$' >/dev/null 2>&1; then
        rc=0
    elif echo "$1" | grep '^\$\{0,1\}inic[0-9]\+$' >/dev/null 2>&1; then
        rc=0
    fi
    
    return $rc
}

######################################################################
#   FUNCTION   : getLOCAL_GMN_EX_INTF
#   DESCRIPTION: 获取虚拟IP的网口号
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getLOCAL_GMN_EX_INTF()
{
    
    # 检查字符串合法性的函数
    READ_CHK_CMD=chkBackEth
    
    # 默认值
    READ_DEFAULT_STR='eth0'
    
    # 错误信息
    READ_WRONG_INFO="You must enter strings like this:${COLOR_BOLD}ethXX${COLOR_RESET}\
 or ${COLOR_BOLD}inicXX${COLOR_RESET}('XX' is a valid number)"
    
    # 帮助信息
    READ_HELP_INFO=""
    
    # 获取用户输入
    ReadPrint
    
    # 根据此平面获取默认的IP。
    GetBackPip
}

######################################################################
#   FUNCTION   : getLOCAL_GMN_EX_INTF
#   DESCRIPTION: 获取虚拟IP的网口号
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getREMOTE_GMN_EX_INTF()
{
    
    # 检查字符串合法性的函数
    READ_CHK_CMD=chkBackEth
    
    # 默认值
    READ_DEFAULT_STR='eth0'
    
    # 错误信息
    READ_WRONG_INFO="You must enter strings like this:${COLOR_BOLD}ethXX${COLOR_RESET}\
 or ${COLOR_BOLD}inicXX${COLOR_RESET}('XX' is a valid number)"
    
    # 帮助信息
    READ_HELP_INFO=""
    
    # 获取用户输入
    ReadPrint
    
    # 根据此平面获取默认的IP。
    GetBackPip
}

checkFloatIp()
{
    chkIP "$@" || return 1
    
    # 单机场景需要检测浮动IP是否已经被占用
    if [ "$haMode" == "$GMN_MODE_SINGLE_NUM" ]; then
        FLOAT_GMN_EX_IP="$1"
        if checkExfloatIpConnect >> $LOG_FILE 2>&1 ; then
            ECHOANDLOG_ERROR "the floating ip: $FLOAT_GMN_EX_IP is exsit on the network."
            return 1
        fi
    fi
}

######################################################################
#   FUNCTION   : getFLOAT_GMN_EX_IP
#   DESCRIPTION: 获取虚拟IP
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getFLOAT_GMN_EX_IP()
{
    # 检查字符串合法性的函数
    READ_CHK_CMD=checkFloatIp

    # 默认值
    READ_DEFAULT_STR=""
    
    # 错误信息
    READ_WRONG_INFO="Invalid IP address format or the floating IP already exists."
    
    # 帮助信息
    READ_HELP_INFO="It will be configured when active node is starting.
The client will use this IP to connect to server.
The subnet mask of the floating IP address is the same as that of the management IP address of this node.
The gateway of the floating IP address is the same as that of the management IP address of this node."

    # 获取用户输入
    ReadPrint
}

gethaArbitrateIP()
{
    # 检查字符串合法性的函数
    READ_CHK_CMD=chkIP
    
    # 默认值
    READ_DEFAULT_STR="$LOCAL_GMN_EX_GW"
    
    # 错误信息
    READ_WRONG_INFO="Invalid IP address format."
    
    # 帮助信息
    READ_HELP_INFO="The HA arbitrate IP is used to arbitrate which node should be active.
The program will use the physic gateway as default value.
We suggest you to keep the default value."
    
    # 获取用户输入
    ReadPrint
}

######################################################################
#   FUNCTION   : getFLOAT_GMN_EX_MASK
#   DESCRIPTION: 获取虚拟IP的子网掩码
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getFLOAT_GMN_EX_MASK()
{
    # 检查字符串合法性的函数
    READ_CHK_CMD=chkNetMask
    
    # 默认值
    READ_DEFAULT_STR="255.255.0.0"
    
    # 错误信息
    READ_WRONG_INFO="Invalid net mask format."
    
    # 获取用户输入
    ReadPrint
}

######################################################################
#   FUNCTION   : getFLOAT_GMN_EX_GW
#   DESCRIPTION: 获取虚拟IP的网关
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getFLOAT_GMN_EX_GW()
{
    # 检查字符串合法性的函数
    READ_CHK_CMD=chkIP
    
    # 默认值
    READ_DEFAULT_STR=""
    
    # 错误信息
    READ_WRONG_INFO="Invalid gateway format."
    
    # 帮助信息
    READ_HELP_INFO="If you configured a wrong gateway, the node may lose connection with the whole net through\
 the net card where you configured."
    
    # 获取用户输入
    ReadPrint
}

######################################################################
#   FUNCTION   : chkVars
#   DESCRIPTION: 检查合法的变量名，也使用于检查合法的主机名
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
chkVars()
{
    echo "$1" | grep '^[A-Za-z_][A-Za-z0-9_]*$' >/dev/null 2>&1
    return $?
}

######################################################################
#   FUNCTION   : getREMOTE_nodeName
#   DESCRIPTION: 获取对端主机名
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getREMOTE_nodeName()
{
    # 检查字符串合法性的函数
    READ_CHK_CMD=checkHostnameValid
    
    # 默认值
    READ_DEFAULT_STR=""
    
    # 错误信息
    READ_WRONG_INFO="The node name must begin with a letter or underscore and \
can contain only letters, numbers, hyphens, and underscores."
    
    # 帮助信息
    READ_HELP_INFO="This is the node name of the remote node in \
a high availability differ from local node."
    
    # 获取用户输入
    ReadPrint
}
getLOCAL_nodeName()
{
    # 检查字符串合法性的函数
    READ_CHK_CMD=checkHostnameValid
    
    # 默认值
    READ_DEFAULT_STR="$(uname -n)"
    
    # 错误信息
    READ_WRONG_INFO="The node name must begin with a letter or underscore and \
can contain only letters, numbers, hyphens, and underscores."
    
    # 帮助信息
    READ_HELP_INFO="This is the node name of the local node in \
a high availability differ from remote node."
    
    # 获取用户输入
    ReadPrint
}

######################################################################
#   FUNCTION   : getRESP_LOCAL_PIP
#   DESCRIPTION: 获取本端物理IP
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getLOCAL_GMN_EX_IP()
{
    # 检查字符串合法性的函数
    READ_CHK_CMD=chkIP
    
    # 默认值
    READ_DEFAULT_STR=""
    
    # 错误信息
    READ_WRONG_INFO="Invalid IP address format."
    
    # 帮助信息
    READ_HELP_INFO="Management IP address of this node. You can use PuTTY to log in to this node using this IP address."

    # 获取用户输入
    ReadPrint
}

######################################################################
#   FUNCTION   : getLOCAL_GMN_EX_IP
#   DESCRIPTION: 获取本端物理IP的子网掩码
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getLOCAL_GMN_EX_MASK()
{
    # 检查字符串合法性的函数
    READ_CHK_CMD=chkNetMask
    
    # 默认值
    READ_DEFAULT_STR="255.255.0.0"
    
    # 错误信息
    READ_WRONG_INFO="Invalid subnet mask format."
    
    # 获取用户输入
    ReadPrint
}

######################################################################
#   FUNCTION   : getLOCAL_GMN_EX_GW
#   DESCRIPTION: 获取本端物理IP的网关
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getLOCAL_GMN_EX_GW()
{
    # 检查字符串合法性的函数
    READ_CHK_CMD=chkIP
    
    # 默认值
    READ_DEFAULT_STR="$FLOAT_GMN_EX_GW"
    
    # 错误信息
    READ_WRONG_INFO="Invalid gateway format."
    
    # 帮助信息
    READ_HELP_INFO="If you configured a wrong gateway, the node may lose connection with the whole net."
    
    # 获取用户输入
    ReadPrint
}

######################################################################
#   FUNCTION   : getREMOTE_GMN_EX_IP
#   DESCRIPTION: 获取对端物理IP
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getREMOTE_GMN_EX_IP()
{
    # 检查字符串合法性的函数
    READ_CHK_CMD=chkIP
    
    # 默认值
    READ_DEFAULT_STR=""
    
    # 错误信息
    READ_WRONG_INFO="Invalid IP address format."
    
    # 帮助信息
    READ_HELP_INFO="Management IP address of the remote node. You can use PuTTY to log in to the remote node using this IP address.
The subnet mask of the management IP address of the remote node is the same as that of the management IP address of this node.
The gateway of the management IP address of the remote node is the same as that of the management IP address of this node."
    
    # 获取用户输入
    ReadPrint
}

######################################################################
#   FUNCTION   : getRESP_REMOTE_PHY_NM
#   DESCRIPTION: 获取本端物理IP的子网掩码
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getRESP_REMOTE_PHY_NM()
{
    # 检查字符串合法性的函数
    READ_CHK_CMD=chkNetMask
    
    # 默认值
    READ_DEFAULT_STR="$LOCAL_GMN_EX_MASK"
    
    # 错误信息
    READ_WRONG_INFO="Invalid net mask format."
    
    # 获取用户输入
    ReadPrint
}

######################################################################
#   FUNCTION   : getRESP_REMOTE_PHY_GW
#   DESCRIPTION: 获取本端物理IP的网关
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getRESP_REMOTE_PHY_GW()
{
    # 检查字符串合法性的函数
    READ_CHK_CMD=chkIP
    
    # 默认值
    READ_DEFAULT_STR="$LOCAL_GMN_EX_GW"
    
    # 错误信息
    READ_WRONG_INFO="Invalid gateway format."
    
    READ_HELP_INFO="The program will use the default value 255.255.255.255 to configure nothing for the gateway.
We suggest you to keep the default value and not to configure any gateway.
If you configured a wrong gateway, the omu board may lose connection with the whole net through\
the net card where you configured."
    
    # 获取用户输入
    ReadPrint
}

######################################################################
#   FUNCTION   : upperFirstChar
#   DESCRIPTION: 把一个字符串的第一个字符装化成大写
#   CALLS      : NULL
#   CALLED BY  : getRespValues
#   INPUT      : CGP_RESP_INFO CGP_RESP_VARS
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
upperFirstChar()
{
    local tmpVar=`echo ${1:0:1} | tr '[a-z]' '[A-Z]'`
    echo "${tmpVar}${1:1}"
}

######################################################################
#   FUNCTION   : getRespValues
#   DESCRIPTION: 获取各种安装模式下响应文件需要的变量
#   CALLS      : getRespVars lowFirstChar
#   CALLED BY  : retRESP_OMUMODE
#   INPUT      : CGP_RESP_INFO CGP_RESP_VARS
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getRespValues()
{
    # 刷新安装模式下需要获取的变量
    getRespVars
    local -i i
    local -i num="${#CGP_RESP_SHOW_VARS[@]}"
    local printStr
    
    # 获取需要用户输入但不会写到响应文件中的配置
    for ((i=0; $i<$num; i++)); do
        READ_PROMPT_INFO="Please enter the ${CGP_RESP_SHOW_INFO[$i]}:"
        READ_VAR_TO_GET="${CGP_RESP_SHOW_VARS[$i]}"
        eval "get${READ_VAR_TO_GET}"
    done
    
    # 获取需要用户输入且会写到响应文件中的配置
    local -i num="${#CGP_RESP_VARS[@]}"
    
    # i 从1开始，不包括修改安装模式retRESP_OMUMODE，因为本函数是被retRESP_OMUMODE调用的
    for ((i=1; $i<$num; i++)); do
        READ_PROMPT_INFO="Please enter the ${CGP_RESP_INFO[$i]}:"
        READ_VAR_TO_GET="${CGP_RESP_VARS[$i]}"
        eval "get${READ_VAR_TO_GET}"
    done
}

######################################################################
#   FUNCTION   : promptConfirm
#   DESCRIPTION: 打印已经配置了的信息，并让用户确认是否正确
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : CGP_RESP_INFO CGP_RESP_VARS
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
promptConfirm()
{
    # 
    # 提示用户是否正确
    # 
    
    # 提示信息
    READ_PROMPT_INFO="Is the configuration right?[y/n]"
    # 合法的字符串
    READ_A_CMP_STR=(y n)
    # 默认值
    READ_DEFAULT_STR="y"
    # 错误信息
    READ_WRONG_INFO="You can only enter 'y' or 'n'."
    # 帮助信息
    READ_HELP_INFO="If the informations are right, you can type 'y' to configure node.
If there is any wrong information, you can type 'n' to re-enter the informations.
If you want to quit the program without saving, press 'Ctrl+C'."

    READ_LOWER_UPPER="y"
    # 赋值的变量名
    local choise
    READ_VAR_TO_GET=choise
    # 获取用户输入
    ReadPrint
    
    if [ "$choise" = "y" ]; then
        return 0
    else
        return 1
    fi
}

promptConfirmFirstNode()
{
    # 
    # 提示用户是否正确
    # 

    # 提示信息
    READ_PROMPT_INFO="Are you configuring the first node?[y/n]"
    # 合法的字符串
    READ_A_CMP_STR=(y n)
    # 默认值
    READ_DEFAULT_STR="y"
    # 错误信息
    READ_WRONG_INFO="You can only enter 'y' or 'n'."
    # 帮助信息
    READ_HELP_INFO="If you are configuring the first node, enter 'y' and press Enter to continue configuration.
If you are configuring the second node, the management IP address of the peer node you have entered may be incorrect,
enter 'n' and press Enter to modify configuration information.
If you want to quit the program without saving, press 'Ctrl+C'."

    READ_LOWER_UPPER="y"
    # 赋值的变量名
    local choise
    READ_VAR_TO_GET=choise
    # 获取用户输入
    ReadPrint

    if [ "$choise" = "y" ]; then
        return 0
    else
        return 1
    fi
}

promptConfirmIpCollision()
{
    # 
    # 提示用户是否正确
    # 
    
    # 提示信息
    READ_PROMPT_INFO="${COLOR_FRONT_RED}The heartbeat IP address {$COLLISION_IP} of the system conflicts with another IP address.
If you forcibly enable HA before addressing the IP address conflict, system data may be damaged.${COLOR_RESET}
Are you sure you want to enable HA forcibly?[y/n]"

    # 合法的字符串
    READ_A_CMP_STR=(y n)
    # 默认值
    READ_DEFAULT_STR="y"
    # 错误信息
    READ_WRONG_INFO="You can only enter 'y' or 'n'."
    # 帮助信息
    READ_HELP_INFO="If you have addressed the IP address conflict, press 'y' to enable HA forcibly.
If you have not addressed the IP address conflict, press 'n' to retain HA disabled.
If you press 'y' to enable HA forcibly before addressing the IP address conflict, system data may be damaged."

    READ_LOWER_UPPER="y"
    # 赋值的变量名
    local choise
    READ_VAR_TO_GET=choise
    # 获取用户输入
    ReadPrint

    if [ "$choise" = "y" ]; then
        return 0
    else
        return 1
    fi
}

######################################################################
#   FUNCTION   : chkSlotNum
#   DESCRIPTION: 检查输入槽号是否在[0-5]，[8-13]范围
#   CALLS      : chkNum
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : 0 成功
#                1 失败
######################################################################
chkSlotNum()
{    
    #检查输入槽号是否在[0-5]，[8-13]范围内  
    local SlotNum="$1"
    chkNum 0 5 $SlotNum
    if [ $? -ne 0 ];then
        chkNum 8 13 $SlotNum
        if [ $? -ne 0 ];then
            return 1
        fi
    fi
    return 0
}
######################################################################
#   FUNCTION   : chkNum
#   DESCRIPTION: 检查 $3 是否则 $1 和 $2 之间
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : CGP_RESP_INFO CGP_RESP_VARS
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
chkNum()
{
    local -i minNum="$1"
    local -i maxNum="$2"
    #判断参数$3是否为数字
    local cmpNum=`echo $3 | grep '^[0-9]\+$'`
    if [ -z $cmpNum ];then
         return 1
    fi           
    test "$cmpNum" -ge "$minNum" -a "$cmpNum" -le "$maxNum"
}

######################################################################
#   FUNCTION   : changeInfo
#   DESCRIPTION: 打印已经配置了的信息，并让用户确认是否正确
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : CGP_RESP_INFO CGP_RESP_VARS
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
changeInfo()
{
    # 
    # 提示用户是否正确
    # 
    local changeVar="$1"
    
    # 提示信息
    READ_PROMPT_INFO="Please enter which information you want to change[1-$num]:\
(If you change the configuration mode, all the information should be configured again.)"
    
    # 检查字符串合法性的函数
    local -i iOpt=`expr ${#CGP_RESP_VARS[@]}+${#CGP_RESP_SHOW_VARS[@]}`
    READ_CHK_CMD="chkNum 1 $iOpt"
    # 错误信息
    READ_WRONG_INFO="You can only enter a number from 1 to ${iOpt}."
    # 赋值的变量名
    local -i choise
    READ_VAR_TO_GET=choise
    
    if [ -n "$changeVar" ]; then
        choise=$(echo "${CGP_RESP_VARS[@]}" | tr ' ' '\n' |  sed -n "/\<$changeVar\>/=")
        if [ $choise -gt 0 ]; then
            choise=$choise+${#CGP_RESP_SHOW_VARS[@]}
        else
            choise=$(echo "${CGP_RESP_SHOW_VARS[@]}" | tr ' ' '\n' |  sed -n "/\<$changeVar\>/=")
        fi
        
        if [ $choise -eq 0 ]; then
            LOG_WARN "no need to get changeVar:$changeVar"
            return
        fi
    else
        # 获取用户输入
        ReadPrint
    fi
    
    if [ $choise -gt ${#CGP_RESP_SHOW_VARS[@]} ]; then
        choise=$choise-1-${#CGP_RESP_SHOW_VARS[@]}
        READ_PROMPT_INFO="Please enter ${CGP_RESP_INFO[$choise]}:"
        READ_VAR_TO_GET="${CGP_RESP_VARS[$choise]}"
    else
        choise=$choise-1
        READ_PROMPT_INFO="Please enter ${CGP_RESP_SHOW_INFO[$choise]}:"
        READ_VAR_TO_GET="${CGP_RESP_SHOW_VARS[$choise]}"
    fi
        
    eval "get${READ_VAR_TO_GET}"
}

######################################################################
#   FUNCTION   : confirmInfo
#   DESCRIPTION: 打印已经配置了的信息，并让用户确认是否正确
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : CGP_RESP_INFO CGP_RESP_VARS
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
confirmInfo()
{
    # 打印其它信息
    local -i i
    local -i j
    local printStr
    local -i num="${#CGP_RESP_SHOW_VARS[@]}"
    for((i=0,j=1;i<$num;i++,j++)); do
        printf "%2.2s. %-45.45s " "$j" "`upperFirstChar \"${CGP_RESP_SHOW_INFO[$i]}\"`"
        eval "printStr=\"\$${CGP_RESP_SHOW_VARS[$i]}\""
        echo -e "$printStr"
    done

    num="${#CGP_RESP_VARS[@]}"
    for((i=0;i<$num;i++,j++)); do
        printf "%2.2s. %-45.45s " "$j" "`upperFirstChar \"${CGP_RESP_INFO[$i]}\"`"
        eval "printStr=\"\$${CGP_RESP_VARS[$i]}\""
        echo -e "$printStr"
    done
    
    # 用户确认信息正确则返回此函数
    if promptConfirm; then
        return 0
    else
        changeInfo
        return 1
    fi
}

######################################################################
#   FUNCTION   : writeRespVars
#   DESCRIPTION: 把响应文件的变量写到响应文件中
#   CALLS      : writeRespVars
#   CALLED BY  : writeResp
#   INPUT      : 参数1：存放变量的数组中的各个变量
#                读变量：RESP_FILENAME
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
writeRespVars()
{
    local cfgFile="$1"
    shift

    local var
    local value
    for var in "$@"; do
        savePara2GmnConf "${var}" "$cfgFile" || return 1
    done
}

savePara2GmnConf()
{
    local key=$1
    local cfgFile=$2
    local value=""
    
    if ! [ -f "$cfgFile" ]; then
        LOG_ERROR "$cfgFile is not exsit"
        return 1
    fi
    
    eval "value=\$$key"
    
    if ! echo "$key" | grep -E "^LOCAL_|REMOTE_" > /dev/null; then
        if grep "^$key=" $cfgFile > /dev/null; then
            sed -i "s/^$key=.*$/$key=$value/" $cfgFile
        else
            local type="GLOBAL"
            sed -i "/^\[$type\]/,/\[/ s/^\[$type\]$/&\n$key=$value/" "$cfgFile"
        fi
        
    else
        local relKey="${key#*_}"
        local type="${key%%_*}"

        if grep "^$relKey=" $cfgFile > /dev/null; then
            sed -i "/^\[$type\]/,/\[/ s/^$relKey=.*$/$relKey=$value/" "$cfgFile"
        else
            sed -i "/^\[$type\]/,/\[/ s/^\[$type\]$/&\n$relKey=$value/" "$cfgFile"
        fi
    fi
}

######################################################################
#   FUNCTION   : writeResp
#   DESCRIPTION: 把响应文件的变量写到响应文件中
#   CALLS      : writeRespVars
#   CALLED BY  : NULL
#   INPUT      : 读变量：RESP_FILENAME
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
writeResp()
{
    local cfgFile="$1"
    [ -n "$cfgFile" ] || return 1

    # 写入配置信息
    writeRespVars "$cfgFile" "${CGP_RESP_HIDE_VARS[@]}" || return 1
    writeRespVars "$cfgFile" "${CGP_RESP_SHOW_VARS[@]}" || return 1
    writeRespVars "$cfgFile" "${CGP_RESP_VARS[@]}" || return 1
    
    return 0
}

fi
