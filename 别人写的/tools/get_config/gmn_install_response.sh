#!/bin/bash

# 
# ���⺯���б�
#   getMode
# 

if [ -z "$CGP_INSTALL_RESPONSE_SH" ]; then
CGP_INSTALL_RESPONSE_SH=CGP_INSTALL_RESPONSE_SH

. color.sh
. gmn_prompt.sh
. gmn_resp_vars.sh

######################################################################
#   FUNCTION   : GetIPEndSeg
#   DESCRIPTION: ���ݿ�ۺŻ�ȡIP�����һ���ֶ�
#   CALLS      : ��
#   CALLED BY  : ��
#   INPUT      : ��ţ�  FN     �ۺţ�  SN
#   OUTPUT     : ��ӡ������ֶ�
#   RETURN     : 0���ɹ�  1��ʧ��
#   CHANGE DIR : ��
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
#   DESCRIPTION: ��ȡBACKƽ�������IP�Լ�����IP�����ں�
#   CALLS      : ��
#   CALLED BY  : ��
#   INPUT      : BACKn(nΪ����)
#   OUTPUT     : �޸���Ӧ�ļ�����LOCAL_GMN_EX_INTF
#   RETURN     : 0���ɹ�  1��ʧ��
#   CHANGE DIR : ��
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
#   DESCRIPTION: ��ȡBACKƽ�������IP�Լ�����IP�����ں�
#   CALLS      : ��
#   CALLED BY  : ��
#   INPUT      : ESP_VIR_DEV
#   OUTPUT     : �޸���Ӧ�ļ����� RESP_LOCAL_PIP LOCAL_GMN_EX_IP
#   RETURN     : 0���ɹ�  1��ʧ��
#   CHANGE DIR : ��
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
#   DESCRIPTION: ���ݻ�������������Ӧ�ļ��Ĳ�������
#   CALLS      : ��
#   CALLED BY  : ��
#   INPUT      : ����������
#                   ��ţ�      FN
#                   �ۺţ�      SN
#                   ��������    CONFIG_HOSTNAME
#   OUTPUT     : ��
#   RETURN     : 0���ɹ�  1��ʧ��
#   CHANGE DIR : ��
######################################################################
LoadEnv()
{
    RESP_FN="$FN"                   # ���
    RESP_SN="$SN"                   # �ۺ�
    GetBackDev                      # ��ȡBACKƽ�������IP�Լ�����IP�����ں�

	checkIsVm
	IS_VM=$?

    return 0
}

######################################################################
#   FUNCTION   : GetFSIP
#   DESCRIPTION: ���ݿ�ۺ�����ȡIP��Ϣ
#   CALLS      : ��
#   CALLED BY  : ��
#   INPUT      : ��ţ�  RESP_FN             �ۺţ�  RESP_FN
#   OUTPUT     : ��
#   RETURN     : 0���ɹ�
#   CHANGE DIR : ��
######################################################################
GetFSIP()
{
    [ -n "$RESP_FN" -a -n "$RESP_SN" ] || return 1
    
    # ���ݿ�ۺŻ�ȡ��������BASEƽ���IP����Ϣ
    local seg
    seg=`GetIPEndSeg $RESP_FN $RESP_SN`
    [ -z "$seg" ] && return 1
    
    RESP_LOCAL_HB_IP1="172.17.$seg"
    RESP_LOCAL_HB_IP2="172.16.$seg"
    
    return 0
}

######################################################################
#   FUNCTION   : GetRemoteFSIP
#   DESCRIPTION: ���ݿ�ۺ�����ȡIP��Ϣ
#   CALLS      : ��
#   CALLED BY  : ��
#   INPUT      : ��ţ�  RESP_REMOTE_FN             �ۺţ�  RESP_REMOTE_FN
#   OUTPUT     : ��
#   RETURN     : 0���ɹ�
#   CHANGE DIR : ��
######################################################################
GetRemoteFSIP()
{
    [ -n "$RESP_REMOTE_FN" -a -n "$RESP_REMOTE_SN" ] || return 1
    
    # ���ݿ�ۺŻ�ȡ��������BASEƽ���IP����Ϣ
    local seg
    seg=`GetIPEndSeg $RESP_REMOTE_FN $RESP_REMOTE_SN`
    [ -z "$seg" ] && return 1
    
    RESP_REMOTE_HB_IP1="172.17.$seg"
    RESP_REMOTE_HB_IP2="172.16.$seg"
    
    return 0
}

######################################################################
#   FUNCTION   : getRESP_FN
#   DESCRIPTION: ��ȡ���˿��
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getRESP_FN()
{
    
    # ����ַ����Ϸ��Եĺ���
    READ_CHK_CMD="chkNum 0 99"
    
    # ������Ϣ
    READ_WRONG_INFO="Invalid frame number:[0-99]."
    
    # ������Ϣ
    READ_HELP_INFO=""
    
    # ��ȡ�û�����
    ReadPrint
    
    # ���ݿ�ۺ��Զ���ȡ��Ӧ��IP��Ϣ
    GetFSIP
}

######################################################################
#   FUNCTION   : getRESP_SN
#   DESCRIPTION: ��ȡ���˲ۺ�
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getRESP_SN()
{
    
    # ����ַ����Ϸ��Եĺ���
    READ_CHK_CMD="chkSlotNum"    
    
    # Ĭ��ֵ
    #READ_DEFAULT_STR="0"
    
    # ������Ϣ
    READ_WRONG_INFO="Invalid frame number:[0-5],[8-13]."
    
    # ������Ϣ
    READ_HELP_INFO=""
    
    # ��ȡ�û�����
    ReadPrint
    
    # ���ݿ�ۺ��Զ���ȡ��Ӧ��IP��Ϣ
    GetFSIP
}

######################################################################
#   FUNCTION   : getRESP_REMOTE_FN
#   DESCRIPTION: ��ȡ���˿��
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getRESP_REMOTE_FN()
{
    
    # ����ַ����Ϸ��Եĺ���
    READ_CHK_CMD="chkNum 0 99"
    
    # Ĭ��ֵ
    #READ_DEFAULT_STR="0"
    
    # ������Ϣ
    READ_WRONG_INFO="Invalid frame number:[0-99]."
    
    # ������Ϣ
    READ_HELP_INFO=""
    
    # ��ȡ�û�����
    ReadPrint
    
    # ���ݿ�ۺ��Զ���ȡ��Ӧ��IP��Ϣ
    GetRemoteFSIP
}

######################################################################
#   FUNCTION   : getRESP_REMOTE_SN
#   DESCRIPTION: ��ȡ���˲ۺ�
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getRESP_REMOTE_SN()
{
    
    # ����ַ����Ϸ��Եĺ���
    READ_CHK_CMD="chkSlotNum"
    
    # Ĭ��ֵ
    #READ_DEFAULT_STR="0"
    
    # ������Ϣ
    READ_WRONG_INFO="Invalid frame number:[0-5],[8-13]."
    
    # ������Ϣ
    READ_HELP_INFO=""
    
    # ��ȡ�û�����
    ReadPrint
    
    # ���ݿ�ۺ��Զ���ȡ��Ӧ��IP��Ϣ
    GetRemoteFSIP
}

######################################################################
#ok1
#   FUNCTION   : chkIP
#   DESCRIPTION: ���IP�Ķ��Ƿ���Ϲ淶
#   CALLS      : ��
#   CALLED BY  : inputIP, inputNtpIP
#   INPUT      : ����1����Ҫ����IP��ַ
#   OUTPUT     : ��
#   RETURN     : 0���ɹ�  1��ʧ��
#   CHANGE DIR : ��
######################################################################
chkIP()
{
    local -i rc=0
    
    # ����XXX.XXX.XXX.XXX��ʽ���򷵻�ʧ��
    if [ -z "`echo $1 | grep -w \"^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}$\"`" ]; then
        rc=1
    else
        local ips=`echo "$1" | tr '.' ' '`      # ��ȡIP�����нڵ�
        local ip                                # ��ȡIP��ÿһ���ڵ�
        
        for ip in $ips; do
            if [ "$ip" -gt 255 ]; then
                rc=1     # �ڵ㲻�Ϸ����򷵻�ʧ��
                break
            fi
            # �ڵ�Ϸ�������������һ��
        done
    fi
    
    return $rc
}

######################################################################
#ok1
#   FUNCTION   : chkNetMask
#   DESCRIPTION: ������������Ķ��Ƿ���Ϲ淶
#   CALLS      : chkNode
#   CALLED BY  : inputNetMask
#   INPUT      : ����1����Ҫ������������
#   OUTPUT     : ��
#   LOCAL VAR  : 
#   USE GLOBVAR: ��
#   RETURN     : 0���ɹ�  1��ʧ��
#   CHANGE DIR : ��
######################################################################
chkNetMask()
{
    # ����XXX.XXX.XXX.XXX��ʽ���򷵻�ʧ��
    if [ -z "`echo $1 | grep -w \"^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}$\"`" ]; then
        return 1
    else
        local -i rc=0      # ������������
        local masks=`echo $1 | tr '.' ' '`       # ��ȡIP�����нڵ�
        local mask             # ��ȡIP��ÿһ���ڵ�
        
        local maskOK=y         # $maskOKΪy�����¸��ڵ����Ϊ255|254|252|248|240|224|192|128|0�е�һ��
                               # $maskOKΪn�����¸��ڵ�ֻ��Ϊ0
        local -i nodeRet=0     # ���һ���ڵ��ķ���ֵ
        local -i i=0
        for mask in $masks; do
            # $maskOKΪy����ǰ�ڵ����Ϊ255|254|252|248|240|224|192|128|0�е�һ��
            if [ "$maskOK" = "y" ]; then
                if [ $mask -eq 255 ]; then
                    continue     # �ڵ�Ϊ255������������һ��
                elif [ -n "`echo $mask | grep -E \"^254|252|248|240|224|192|128|0$\"`" ]; then
                    maskOK=n     # �ڵ�Ϊ254|252|248|240|224|192|128|0��������ڵ�ֻ��Ϊ0
                    continue
                else
                    rc=1
                    break
                fi
            
            # $maskOKΪn����ǰ�ڵ�ֻ��Ϊ0
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
#   DESCRIPTION: ��ȡ��װģʽ
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : vars:��Ҫ��PROMPT_INFO��Ϊ�գ�
#                       READ_PROMPT_INFO        ��ӡ����ʾ��Ϣ
#                       READ_A_CMP_STR          ���ڱȽ��û������Ƿ���ȷ���ַ�������
#                       READ_DEFAULT_STR        �û�ֱ�Ӱ��س���ȡ��Ĭ��ֵ����ֵ����Ϊ�ջ���READ_A_CMP_STR�ڣ�
#                       READ_WRONG_INFO         �û����ʱ����ʾ��Ϣ
#                       READ_HELP_INFO          �û����� ? ʱ��ӡ�İ�����Ϣ
#                       READ_TIME_OUT           ��ʱʱ��
#   RETURN     : NULL
######################################################################
gethaMode()
{
    # ��ʾ��Ϣ
    READ_PROMPT_INFO=`echo -e "Please enter the mode to configure:"; \
        echo -e "1. Single mode"; \
        echo -e "2. High availability mode"; \
    `
    
    # �Ϸ����ַ���
    READ_A_CMP_STR=(1 2)
    
    # Ĭ��ֵ
    READ_DEFAULT_STR="2"
    
    # ������Ϣ
    READ_WRONG_INFO="Please enter '1' or '2'."
    
    # ������Ϣ
    READ_HELP_INFO="If you type '1', this program will guide you to configuring Single mode.
If you type '2', this program will guide you to configuring High Availability mode"
    
    # ��ֵ�ı�����
    READ_VAR_TO_GET=haMode
    
    # ��ȡ�û�����
    ReadPrint
    
    # ��ȡ��Ӧ��װģʽ������Ҫ����Ӧ�ļ�����
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
#   DESCRIPTION: ����Ƿ�ͺϷ������ں�
#   CALLS      : NULL
#   CALLED BY  : getVDev
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : 0: �Ϸ�; 1: ���Ϸ�
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
#   DESCRIPTION: ��ȡ����IP�����ں�
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getLOCAL_GMN_EX_INTF()
{
    
    # ����ַ����Ϸ��Եĺ���
    READ_CHK_CMD=chkBackEth
    
    # Ĭ��ֵ
    READ_DEFAULT_STR='eth0'
    
    # ������Ϣ
    READ_WRONG_INFO="You must enter strings like this:${COLOR_BOLD}ethXX${COLOR_RESET}\
 or ${COLOR_BOLD}inicXX${COLOR_RESET}('XX' is a valid number)"
    
    # ������Ϣ
    READ_HELP_INFO=""
    
    # ��ȡ�û�����
    ReadPrint
    
    # ���ݴ�ƽ���ȡĬ�ϵ�IP��
    GetBackPip
}

######################################################################
#   FUNCTION   : getLOCAL_GMN_EX_INTF
#   DESCRIPTION: ��ȡ����IP�����ں�
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getREMOTE_GMN_EX_INTF()
{
    
    # ����ַ����Ϸ��Եĺ���
    READ_CHK_CMD=chkBackEth
    
    # Ĭ��ֵ
    READ_DEFAULT_STR='eth0'
    
    # ������Ϣ
    READ_WRONG_INFO="You must enter strings like this:${COLOR_BOLD}ethXX${COLOR_RESET}\
 or ${COLOR_BOLD}inicXX${COLOR_RESET}('XX' is a valid number)"
    
    # ������Ϣ
    READ_HELP_INFO=""
    
    # ��ȡ�û�����
    ReadPrint
    
    # ���ݴ�ƽ���ȡĬ�ϵ�IP��
    GetBackPip
}

checkFloatIp()
{
    chkIP "$@" || return 1
    
    # ����������Ҫ��⸡��IP�Ƿ��Ѿ���ռ��
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
#   DESCRIPTION: ��ȡ����IP
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getFLOAT_GMN_EX_IP()
{
    # ����ַ����Ϸ��Եĺ���
    READ_CHK_CMD=checkFloatIp

    # Ĭ��ֵ
    READ_DEFAULT_STR=""
    
    # ������Ϣ
    READ_WRONG_INFO="Invalid IP address format or the floating IP already exists."
    
    # ������Ϣ
    READ_HELP_INFO="It will be configured when active node is starting.
The client will use this IP to connect to server.
The subnet mask of the floating IP address is the same as that of the management IP address of this node.
The gateway of the floating IP address is the same as that of the management IP address of this node."

    # ��ȡ�û�����
    ReadPrint
}

gethaArbitrateIP()
{
    # ����ַ����Ϸ��Եĺ���
    READ_CHK_CMD=chkIP
    
    # Ĭ��ֵ
    READ_DEFAULT_STR="$LOCAL_GMN_EX_GW"
    
    # ������Ϣ
    READ_WRONG_INFO="Invalid IP address format."
    
    # ������Ϣ
    READ_HELP_INFO="The HA arbitrate IP is used to arbitrate which node should be active.
The program will use the physic gateway as default value.
We suggest you to keep the default value."
    
    # ��ȡ�û�����
    ReadPrint
}

######################################################################
#   FUNCTION   : getFLOAT_GMN_EX_MASK
#   DESCRIPTION: ��ȡ����IP����������
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getFLOAT_GMN_EX_MASK()
{
    # ����ַ����Ϸ��Եĺ���
    READ_CHK_CMD=chkNetMask
    
    # Ĭ��ֵ
    READ_DEFAULT_STR="255.255.0.0"
    
    # ������Ϣ
    READ_WRONG_INFO="Invalid net mask format."
    
    # ��ȡ�û�����
    ReadPrint
}

######################################################################
#   FUNCTION   : getFLOAT_GMN_EX_GW
#   DESCRIPTION: ��ȡ����IP������
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getFLOAT_GMN_EX_GW()
{
    # ����ַ����Ϸ��Եĺ���
    READ_CHK_CMD=chkIP
    
    # Ĭ��ֵ
    READ_DEFAULT_STR=""
    
    # ������Ϣ
    READ_WRONG_INFO="Invalid gateway format."
    
    # ������Ϣ
    READ_HELP_INFO="If you configured a wrong gateway, the node may lose connection with the whole net through\
 the net card where you configured."
    
    # ��ȡ�û�����
    ReadPrint
}

######################################################################
#   FUNCTION   : chkVars
#   DESCRIPTION: ���Ϸ��ı�������Ҳʹ���ڼ��Ϸ���������
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
#   DESCRIPTION: ��ȡ�Զ�������
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getREMOTE_nodeName()
{
    # ����ַ����Ϸ��Եĺ���
    READ_CHK_CMD=checkHostnameValid
    
    # Ĭ��ֵ
    READ_DEFAULT_STR=""
    
    # ������Ϣ
    READ_WRONG_INFO="The node name must begin with a letter or underscore and \
can contain only letters, numbers, hyphens, and underscores."
    
    # ������Ϣ
    READ_HELP_INFO="This is the node name of the remote node in \
a high availability differ from local node."
    
    # ��ȡ�û�����
    ReadPrint
}
getLOCAL_nodeName()
{
    # ����ַ����Ϸ��Եĺ���
    READ_CHK_CMD=checkHostnameValid
    
    # Ĭ��ֵ
    READ_DEFAULT_STR="$(uname -n)"
    
    # ������Ϣ
    READ_WRONG_INFO="The node name must begin with a letter or underscore and \
can contain only letters, numbers, hyphens, and underscores."
    
    # ������Ϣ
    READ_HELP_INFO="This is the node name of the local node in \
a high availability differ from remote node."
    
    # ��ȡ�û�����
    ReadPrint
}

######################################################################
#   FUNCTION   : getRESP_LOCAL_PIP
#   DESCRIPTION: ��ȡ��������IP
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getLOCAL_GMN_EX_IP()
{
    # ����ַ����Ϸ��Եĺ���
    READ_CHK_CMD=chkIP
    
    # Ĭ��ֵ
    READ_DEFAULT_STR=""
    
    # ������Ϣ
    READ_WRONG_INFO="Invalid IP address format."
    
    # ������Ϣ
    READ_HELP_INFO="Management IP address of this node. You can use PuTTY to log in to this node using this IP address."

    # ��ȡ�û�����
    ReadPrint
}

######################################################################
#   FUNCTION   : getLOCAL_GMN_EX_IP
#   DESCRIPTION: ��ȡ��������IP����������
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getLOCAL_GMN_EX_MASK()
{
    # ����ַ����Ϸ��Եĺ���
    READ_CHK_CMD=chkNetMask
    
    # Ĭ��ֵ
    READ_DEFAULT_STR="255.255.0.0"
    
    # ������Ϣ
    READ_WRONG_INFO="Invalid subnet mask format."
    
    # ��ȡ�û�����
    ReadPrint
}

######################################################################
#   FUNCTION   : getLOCAL_GMN_EX_GW
#   DESCRIPTION: ��ȡ��������IP������
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getLOCAL_GMN_EX_GW()
{
    # ����ַ����Ϸ��Եĺ���
    READ_CHK_CMD=chkIP
    
    # Ĭ��ֵ
    READ_DEFAULT_STR="$FLOAT_GMN_EX_GW"
    
    # ������Ϣ
    READ_WRONG_INFO="Invalid gateway format."
    
    # ������Ϣ
    READ_HELP_INFO="If you configured a wrong gateway, the node may lose connection with the whole net."
    
    # ��ȡ�û�����
    ReadPrint
}

######################################################################
#   FUNCTION   : getREMOTE_GMN_EX_IP
#   DESCRIPTION: ��ȡ�Զ�����IP
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getREMOTE_GMN_EX_IP()
{
    # ����ַ����Ϸ��Եĺ���
    READ_CHK_CMD=chkIP
    
    # Ĭ��ֵ
    READ_DEFAULT_STR=""
    
    # ������Ϣ
    READ_WRONG_INFO="Invalid IP address format."
    
    # ������Ϣ
    READ_HELP_INFO="Management IP address of the remote node. You can use PuTTY to log in to the remote node using this IP address.
The subnet mask of the management IP address of the remote node is the same as that of the management IP address of this node.
The gateway of the management IP address of the remote node is the same as that of the management IP address of this node."
    
    # ��ȡ�û�����
    ReadPrint
}

######################################################################
#   FUNCTION   : getRESP_REMOTE_PHY_NM
#   DESCRIPTION: ��ȡ��������IP����������
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getRESP_REMOTE_PHY_NM()
{
    # ����ַ����Ϸ��Եĺ���
    READ_CHK_CMD=chkNetMask
    
    # Ĭ��ֵ
    READ_DEFAULT_STR="$LOCAL_GMN_EX_MASK"
    
    # ������Ϣ
    READ_WRONG_INFO="Invalid net mask format."
    
    # ��ȡ�û�����
    ReadPrint
}

######################################################################
#   FUNCTION   : getRESP_REMOTE_PHY_GW
#   DESCRIPTION: ��ȡ��������IP������
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getRESP_REMOTE_PHY_GW()
{
    # ����ַ����Ϸ��Եĺ���
    READ_CHK_CMD=chkIP
    
    # Ĭ��ֵ
    READ_DEFAULT_STR="$LOCAL_GMN_EX_GW"
    
    # ������Ϣ
    READ_WRONG_INFO="Invalid gateway format."
    
    READ_HELP_INFO="The program will use the default value 255.255.255.255 to configure nothing for the gateway.
We suggest you to keep the default value and not to configure any gateway.
If you configured a wrong gateway, the omu board may lose connection with the whole net through\
the net card where you configured."
    
    # ��ȡ�û�����
    ReadPrint
}

######################################################################
#   FUNCTION   : upperFirstChar
#   DESCRIPTION: ��һ���ַ����ĵ�һ���ַ�װ���ɴ�д
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
#   DESCRIPTION: ��ȡ���ְ�װģʽ����Ӧ�ļ���Ҫ�ı���
#   CALLS      : getRespVars lowFirstChar
#   CALLED BY  : retRESP_OMUMODE
#   INPUT      : CGP_RESP_INFO CGP_RESP_VARS
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
getRespValues()
{
    # ˢ�°�װģʽ����Ҫ��ȡ�ı���
    getRespVars
    local -i i
    local -i num="${#CGP_RESP_SHOW_VARS[@]}"
    local printStr
    
    # ��ȡ��Ҫ�û����뵫����д����Ӧ�ļ��е�����
    for ((i=0; $i<$num; i++)); do
        READ_PROMPT_INFO="Please enter the ${CGP_RESP_SHOW_INFO[$i]}:"
        READ_VAR_TO_GET="${CGP_RESP_SHOW_VARS[$i]}"
        eval "get${READ_VAR_TO_GET}"
    done
    
    # ��ȡ��Ҫ�û������һ�д����Ӧ�ļ��е�����
    local -i num="${#CGP_RESP_VARS[@]}"
    
    # i ��1��ʼ���������޸İ�װģʽretRESP_OMUMODE����Ϊ�������Ǳ�retRESP_OMUMODE���õ�
    for ((i=1; $i<$num; i++)); do
        READ_PROMPT_INFO="Please enter the ${CGP_RESP_INFO[$i]}:"
        READ_VAR_TO_GET="${CGP_RESP_VARS[$i]}"
        eval "get${READ_VAR_TO_GET}"
    done
}

######################################################################
#   FUNCTION   : promptConfirm
#   DESCRIPTION: ��ӡ�Ѿ������˵���Ϣ�������û�ȷ���Ƿ���ȷ
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : CGP_RESP_INFO CGP_RESP_VARS
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
promptConfirm()
{
    # 
    # ��ʾ�û��Ƿ���ȷ
    # 
    
    # ��ʾ��Ϣ
    READ_PROMPT_INFO="Is the configuration right?[y/n]"
    # �Ϸ����ַ���
    READ_A_CMP_STR=(y n)
    # Ĭ��ֵ
    READ_DEFAULT_STR="y"
    # ������Ϣ
    READ_WRONG_INFO="You can only enter 'y' or 'n'."
    # ������Ϣ
    READ_HELP_INFO="If the informations are right, you can type 'y' to configure node.
If there is any wrong information, you can type 'n' to re-enter the informations.
If you want to quit the program without saving, press 'Ctrl+C'."

    READ_LOWER_UPPER="y"
    # ��ֵ�ı�����
    local choise
    READ_VAR_TO_GET=choise
    # ��ȡ�û�����
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
    # ��ʾ�û��Ƿ���ȷ
    # 

    # ��ʾ��Ϣ
    READ_PROMPT_INFO="Are you configuring the first node?[y/n]"
    # �Ϸ����ַ���
    READ_A_CMP_STR=(y n)
    # Ĭ��ֵ
    READ_DEFAULT_STR="y"
    # ������Ϣ
    READ_WRONG_INFO="You can only enter 'y' or 'n'."
    # ������Ϣ
    READ_HELP_INFO="If you are configuring the first node, enter 'y' and press Enter to continue configuration.
If you are configuring the second node, the management IP address of the peer node you have entered may be incorrect,
enter 'n' and press Enter to modify configuration information.
If you want to quit the program without saving, press 'Ctrl+C'."

    READ_LOWER_UPPER="y"
    # ��ֵ�ı�����
    local choise
    READ_VAR_TO_GET=choise
    # ��ȡ�û�����
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
    # ��ʾ�û��Ƿ���ȷ
    # 
    
    # ��ʾ��Ϣ
    READ_PROMPT_INFO="${COLOR_FRONT_RED}The heartbeat IP address {$COLLISION_IP} of the system conflicts with another IP address.
If you forcibly enable HA before addressing the IP address conflict, system data may be damaged.${COLOR_RESET}
Are you sure you want to enable HA forcibly?[y/n]"

    # �Ϸ����ַ���
    READ_A_CMP_STR=(y n)
    # Ĭ��ֵ
    READ_DEFAULT_STR="y"
    # ������Ϣ
    READ_WRONG_INFO="You can only enter 'y' or 'n'."
    # ������Ϣ
    READ_HELP_INFO="If you have addressed the IP address conflict, press 'y' to enable HA forcibly.
If you have not addressed the IP address conflict, press 'n' to retain HA disabled.
If you press 'y' to enable HA forcibly before addressing the IP address conflict, system data may be damaged."

    READ_LOWER_UPPER="y"
    # ��ֵ�ı�����
    local choise
    READ_VAR_TO_GET=choise
    # ��ȡ�û�����
    ReadPrint

    if [ "$choise" = "y" ]; then
        return 0
    else
        return 1
    fi
}

######################################################################
#   FUNCTION   : chkSlotNum
#   DESCRIPTION: �������ۺ��Ƿ���[0-5]��[8-13]��Χ
#   CALLS      : chkNum
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : NULL
#   RETURN     : 0 �ɹ�
#                1 ʧ��
######################################################################
chkSlotNum()
{    
    #�������ۺ��Ƿ���[0-5]��[8-13]��Χ��  
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
#   DESCRIPTION: ��� $3 �Ƿ��� $1 �� $2 ֮��
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
    #�жϲ���$3�Ƿ�Ϊ����
    local cmpNum=`echo $3 | grep '^[0-9]\+$'`
    if [ -z $cmpNum ];then
         return 1
    fi           
    test "$cmpNum" -ge "$minNum" -a "$cmpNum" -le "$maxNum"
}

######################################################################
#   FUNCTION   : changeInfo
#   DESCRIPTION: ��ӡ�Ѿ������˵���Ϣ�������û�ȷ���Ƿ���ȷ
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : CGP_RESP_INFO CGP_RESP_VARS
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
changeInfo()
{
    # 
    # ��ʾ�û��Ƿ���ȷ
    # 
    local changeVar="$1"
    
    # ��ʾ��Ϣ
    READ_PROMPT_INFO="Please enter which information you want to change[1-$num]:\
(If you change the configuration mode, all the information should be configured again.)"
    
    # ����ַ����Ϸ��Եĺ���
    local -i iOpt=`expr ${#CGP_RESP_VARS[@]}+${#CGP_RESP_SHOW_VARS[@]}`
    READ_CHK_CMD="chkNum 1 $iOpt"
    # ������Ϣ
    READ_WRONG_INFO="You can only enter a number from 1 to ${iOpt}."
    # ��ֵ�ı�����
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
        # ��ȡ�û�����
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
#   DESCRIPTION: ��ӡ�Ѿ������˵���Ϣ�������û�ȷ���Ƿ���ȷ
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : CGP_RESP_INFO CGP_RESP_VARS
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
confirmInfo()
{
    # ��ӡ������Ϣ
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
    
    # �û�ȷ����Ϣ��ȷ�򷵻ش˺���
    if promptConfirm; then
        return 0
    else
        changeInfo
        return 1
    fi
}

######################################################################
#   FUNCTION   : writeRespVars
#   DESCRIPTION: ����Ӧ�ļ��ı���д����Ӧ�ļ���
#   CALLS      : writeRespVars
#   CALLED BY  : writeResp
#   INPUT      : ����1����ű����������еĸ�������
#                ��������RESP_FILENAME
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
#   DESCRIPTION: ����Ӧ�ļ��ı���д����Ӧ�ļ���
#   CALLS      : writeRespVars
#   CALLED BY  : NULL
#   INPUT      : ��������RESP_FILENAME
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
writeResp()
{
    local cfgFile="$1"
    [ -n "$cfgFile" ] || return 1

    # д��������Ϣ
    writeRespVars "$cfgFile" "${CGP_RESP_HIDE_VARS[@]}" || return 1
    writeRespVars "$cfgFile" "${CGP_RESP_SHOW_VARS[@]}" || return 1
    writeRespVars "$cfgFile" "${CGP_RESP_VARS[@]}" || return 1
    
    return 0
}

fi
