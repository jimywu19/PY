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
    # �û�ȷ�������Ƿ���ȷ������ȷ����������
    while :; do
        TITLE="Showing the configured informations"
        MenuHead "$TITLE"
        if ! confirmInfo; then
            continue
        fi
        
        # �������
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

    # ���û��������Ϣд����Ӧ�ļ���
    writeResp "$NONE_FC_CFG" || die "Save configured informations failed."
}

getConfigParameters()
{
    # ����ӡ����ʹ��
    declare -a READ_A_CMP_STR
    ReadPrintInit

    # �洢��Ӧ�ļ��ı����ͼ�Ҫ˵��������
    declare -a CGP_RESP_VARS
    declare -a CGP_RESP_INFO

    # ��Ҫ�û����뵫���洢����Ӧ�ļ��еı����ͼ�Ҫ˵��������
    declare -a CGP_RESP_SHOW_VARS
    declare -a CGP_RESP_SHOW_INFO

    # ����ԭ������Ӧ��Ĭ�ϵ�����
    # . "$RESP_FILENAME"
    getDoubleConfig "$NONE_FC_CFG"

    # ���ݻ�������������Ӧ�ļ��Ĳ�������
    LoadEnv

    if [ -z "$haMode" ]; then
        # û�д���Ӧ�ļ��л�ȡ����Ϣ�������û�����
        # ��ӡ��ӭ��Ϣ
        TITLE="Welcome to configure" 
        MenuHead "$TITLE"
        
        # ��ȡ��װģʽ�������ݰ�װģʽ����ͬ������
        gethaMode
    else
        # �Ѵ���Ӧ�ļ��л�ȡ����Ϣ����ֱ�ӽ�����һ����ʾ������Ϣ��
        getRespVars
    fi
    
    confirmConfigInfos
}

changeConfigParameters()
{
    # ����ӡ����ʹ��
    ReadPrintInit
    local changedList=""
    local var
    for var in $@; do
        # ����
        var=$(echo "$var" | sed -r "s/(FLOAT|REMOTE)_GMN_EX_(MASK|GW)/LOCAL_GMN_EX_\2/")
        if echo "$changedList" | grep -w "$var" > /dev/null ; then
            continue
        fi
        
        changeInfo "$var"
        changedList="$changedList $var"
    done
    
    confirmConfigInfos
}
