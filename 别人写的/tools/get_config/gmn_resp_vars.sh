
# 
# �����ṩ�ĺ�����
#      getRespVars
# 
# �����ȫ�ֱ�����
#      CGP_RESP_HIDE_VARS     �洢����Ӧ�ļ��в���Ҫ�û�����ı�����
# 


if [ -z "$CGP_RESP_VARS_INFO_SH" ]; then

CGP_RESP_VARS_INFO_SH=CGP_RESP_VARS_INFO_SH

# CGP_RESP_HIDE_VARS     �洢����Ӧ�ļ��в���Ҫ�û�����ı�����
unset CGP_RESP_HIDE_VARS
declare -a CGP_RESP_HIDE_VARS

# ����Щ������Ĭ��ֵ
RESP_IS_CHK=n

######################################################################
#   FUNCTION   : getRespVars
#   DESCRIPTION: ��ȡ��Ӧ�ļ��ı�����Ϣ
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : CGP_RESP_VARS          �洢����Ӧ�ļ�����Ҫ�û�����ı�����
#                CGP_RESP_INFO          �洢����Ӧ�ļ�����Ҫ�û�����ı�������Ӧ�ļ�Ҫ˵��
#                CGP_RESP_SHOW_VARS     �洢����Ҫ�û����뵫����д����Ӧ�ļ��еı�����
#                CGP_RESP_SHOW_INFO     �洢����Ҫ�û����뵫����д����Ӧ�ļ��еı�������Ӧ�ļ�Ҫ˵��
#   RETURN     : NULL
######################################################################
getRespVars()
{
    # ��Ҫ�û������һ�д����Ӧ�ļ���ȥ�ı���
    local -a CGP_RESP_VARS_INFO
    if ! echo "$haMode" |grep -iwE "true|2" > /dev/null; then
        haMode=1
        CGP_RESP_VARS_INFO=(\
            haMode        "configuration mode"\
            LOCAL_nodeName	    "local node name"\
            LOCAL_GMN_EX_IP      "management IP address of the local node"\
            LOCAL_GMN_EX_MASK      "subnet mask of the local node management IP address"\
            LOCAL_GMN_EX_GW      "gateway of the local node management IP address"\
        )
#            LOCAL_GMN_EX_INTF        "the net card of floating IP on local node"
    else
        haMode=2
        CGP_RESP_VARS_INFO=(\
            haMode        "configuration mode"\
            LOCAL_nodeName	    "local node name"\
            REMOTE_nodeName     "remote node name"\
            LOCAL_GMN_EX_IP      "management IP address of the local node"\
            LOCAL_GMN_EX_MASK      "subnet mask of the management IP address"\
            LOCAL_GMN_EX_GW      "gateway of the management IP address"\
            REMOTE_GMN_EX_IP     "management IP address of the remote node"\
            FLOAT_GMN_EX_IP         "floating IP address"\
            haArbitrateIP        "HA arbitration IP address"\
        )
#            LOCAL_GMN_EX_INTF        "the net card of floating IP on local node"
#            REMOTE_GMN_EX_INTF        "the net card of floating IP on remote node"
    fi
    
    unset CGP_RESP_VARS
    unset CGP_RESP_INFO
    local -i i
    local -i j
    local -i num="${#CGP_RESP_VARS_INFO[@]}"
    for ((i=0; $i<$num; i=$i+2)); do
        j=$i/2
        CGP_RESP_VARS[$j]=${CGP_RESP_VARS_INFO[$i]}
        CGP_RESP_INFO[$j]=${CGP_RESP_VARS_INFO[$i+1]}
    done
    
    IS_VM=0
    # ��Ҫ�û����뵫����д����Ӧ�ļ���ȥ�ı���
    local -a CGP_RESP_SHOW_VARS_INFO
    if [ "$haMode" = "1" ]; then
        CGP_RESP_SHOW_VARS_INFO=()
    if [ "$IS_VM" != "0" ]; then
        CGP_RESP_SHOW_VARS_INFO=(\
            RESP_LOCAL_VLAN     "the vlan of local node"\
        )
    fi    
    elif [ "$haMode" = "2" -o "$haMode" = "3" ]; then
        CGP_RESP_SHOW_VARS_INFO=()
    if [ "$IS_VM" != "0" ]; then
        CGP_RESP_SHOW_VARS_INFO=(\
            RESP_LOCAL_VLAN     "the vlan of local node"\
            RESP_REMOTE_VLAN	"the vlan of remote node"\
        )
    fi
    fi

    unset CGP_RESP_SHOW_VARS
    unset CGP_RESP_SHOW_INFO
    num="${#CGP_RESP_SHOW_VARS_INFO[@]}"
    for ((i=0; $i<$num; i=$i+2)); do
        j=$i/2
        CGP_RESP_SHOW_VARS[$j]=${CGP_RESP_SHOW_VARS_INFO[$i]}
        CGP_RESP_SHOW_INFO[$j]=${CGP_RESP_SHOW_VARS_INFO[$i+1]}
    done
    
    # ����Ҫ�û����뵫��д����Ӧ�ļ���ȥ�ı���
    if [ "$haMode" = "1" ]; then
        CGP_RESP_HIDE_VARS=(\
            FLOAT_GMN_EX_MASK\
            FLOAT_GMN_EX_GW\
        )
    
    elif [ "$haMode" = "2" -o "$haMode" = "3" ]; then
        CGP_RESP_HIDE_VARS=(\
            FLOAT_GMN_EX_MASK\
            FLOAT_GMN_EX_GW\
            REMOTE_GMN_EX_MASK\
            REMOTE_GMN_EX_GW\
        )
    fi
}

fi
