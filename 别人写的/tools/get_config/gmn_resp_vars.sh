
# 
# 对外提供的函数：
#      getRespVars
# 
# 对外的全局变量：
#      CGP_RESP_HIDE_VARS     存储了响应文件中不需要用户输入的变量名
# 


if [ -z "$CGP_RESP_VARS_INFO_SH" ]; then

CGP_RESP_VARS_INFO_SH=CGP_RESP_VARS_INFO_SH

# CGP_RESP_HIDE_VARS     存储了响应文件中不需要用户输入的变量名
unset CGP_RESP_HIDE_VARS
declare -a CGP_RESP_HIDE_VARS

# 给这些变量赋默认值
RESP_IS_CHK=n

######################################################################
#   FUNCTION   : getRespVars
#   DESCRIPTION: 获取响应文件的变量信息
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : CGP_RESP_VARS          存储了响应文件中需要用户输入的变量名
#                CGP_RESP_INFO          存储了响应文件中需要用户输入的变量名对应的简要说明
#                CGP_RESP_SHOW_VARS     存储了需要用户输入但不会写到响应文件中的变量名
#                CGP_RESP_SHOW_INFO     存储了需要用户输入但不会写到响应文件中的变量名对应的简要说明
#   RETURN     : NULL
######################################################################
getRespVars()
{
    # 需要用户输入且会写到响应文件中去的变量
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
    # 需要用户输入但不会写到响应文件中去的变量
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
    
    # 不需要用户输入但会写到响应文件中去的变量
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
