#!/bin/bash

cd `dirname ${BASH_SOURCE}`
BIN_PATH="$PWD"
. color.sh || die "$LINENO failed."
. main_menu.sh || die "$LINENO failed."
. gmn_prompt.sh || die "$LINENO failed."
. gmn_install_response.sh || die "$LINENO failed."
. gmn_resp_vars.sh || die "$LINENO failed."
cd - > /dev/null


confirmConfigInfos()
{
    # 用户确认输入是否正确，不正确则重新输入
    while :; do
        TITLE="Showing the configured informations"
        MenuHead "$TITLE"
        if ! confirmInfo; then
            continue
        fi
        
        # 补足变量
        FLOAT_GMN_EX_MASK=$LOCAL_GMN_EX_MASK
        FLOAT_GMN_EX_GW=$LOCAL_GMN_EX_GW
        REMOTE_GMN_EX_MASK=$LOCAL_GMN_EX_MASK
        REMOTE_GMN_EX_GW=$LOCAL_GMN_EX_GW
        
        if ! checkLocalInfo4Other; then
            ECHOANDLOG_ERROR "check the configure informations failed, please modify it"
            
            changeConfigParameters "$DIFF_PARAMETER_LIST"
            break
        fi
        
        if [ "$haMode" == "2" ]; then
            if ! checkRemoteInfo4Other; then
                ECHOANDLOG_ERROR "check the configure informations failed, please modify it"
                
                changeConfigParameters "$DIFF_PARAMETER_LIST"
                break
            fi
        fi
        break
    done

    # 将用户输入的信息写到响应文件中
    writeResp "$NONE_FC_CFG" || die "Save configured informations failed."
}

getConfigParameters()
{
    # 给打印函数使用
    declare -a READ_A_CMP_STR
    ReadPrintInit

    # 存储响应文件的变量和简要说明的数组
    declare -a CGP_RESP_VARS
    declare -a CGP_RESP_INFO

    # 需要用户输入但不存储在响应文件中的变量和简要说明的数组
    declare -a CGP_RESP_SHOW_VARS
    declare -a CGP_RESP_SHOW_INFO

    # 载入原来的响应中默认的配置
    # . "$RESP_FILENAME"
    getDoubleConfig "$NONE_FC_CFG"

    # 根据环境变量设置响应文件的部分配置
    LoadEnv

    if [ -z "$haMode" ]; then
        # 没有从响应文件中获取到信息，则让用户输入
        # 打印欢迎信息
        TITLE="Welcome to configure" 
        MenuHead "$TITLE"
        
        # 获取安装模式，并根据安装模式请求不同的输入
        gethaMode
    else
        # 已从响应文件中获取到信息，则直接进入下一步显示配置信息。
        getRespVars
    fi
    
    confirmConfigInfos
}

changeConfigParameters()
{
    # 给打印函数使用
    ReadPrintInit
    local changedList=""
    local var
    for var in $@; do
        # 对于
        var=$(echo "$var" | sed -r "s/(FLOAT|REMOTE)_GMN_EX_(MASK|GW)/LOCAL_GMN_EX_\2/")
        if echo "$changedList" | grep -w "$var" > /dev/null ; then
            continue
        fi
        
        changeInfo "$var"
        changedList="$changedList $var"
    done
    
    confirmConfigInfos
}
