#!/bin/bash

# 
# ���⺯���б�
#   ReadPrint
# 

if [ -z "$CGP_PROMPT_SH" ]; then
CGP_PROMPT_SH=CGP_PROMPT_SH

. color.sh

######################################################################
#   FUNCTION   : ReadPrint
#   DESCRIPTION: �����û�����һ���ַ���
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : ��ȡ��vars:��Ҫ��PROMPT_INFO��Ϊ�գ�
#                       READ_PROMPT_INFO        Ҫ���û�����ʱ����ӡ����ʾ��Ϣ
#                       READ_A_CMP_STR          ���ڱȽ��û������Ƿ���ȷ���ַ�������
#                       ������˱�����Ϊ�գ��û����������������ַ��������е�����һ���ַ�����
#                       ����������� READ_A_CMP_STR ���� READ_CHK_CMD �����ԣ�
#                       READ_CHK_CMD            �����û�����Ϸ��Ե��������
#                       READ_DEFAULT_STR        �û�ֱ�Ӱ��س���ȡ��Ĭ��ֵ����ֵ����Ϊ�ջ���READ_A_CMP_STR�ڣ�
#                       READ_WRONG_INFO         �û����ʱ����ʾ��Ϣ
#                       READ_HELP_INFO          �û����� ? ʱ��ӡ�İ�����Ϣ
#                       READ_SILENT             �Ƿ�Ϊ����ʾ���룿 y ��ʾ�ǣ�������
#                       READ_TIME_OUT           ��ʱʱ��
#                       READ_LOWER_UPPER        ȡ�����ִ�Сд��y ��ʾȡ����������
#   OUTPUT     : �޸ĵ�vars��
#                       READ_VAR_TO_GET         ��Ҫ��ֵ�ı���
#                       ���û����յ����븳ֵ���˱���������ı����У����磩
#   RETURN     :    0 ��������
#                   1 ��ӡ��ϢΪ��
#                   2 ������������ȡ��Ĭ��ֵ��
######################################################################
ReadPrint()
{
    # ��ʾ��Ϣ����Ϊ��
    [ -z "$READ_PROMPT_INFO" ] && return 1
    
    # ����û����Ҫ��ֵ�ı���
    [ -z "$READ_VAR_TO_GET" ] && return 1
    
    local -i rc=0
    local printStr="$READ_PROMPT_INFO"
    
    # �������ԭ���Ѿ���ֵ����Ĭ��ֵΪԭ�ȵ�ֵ
    if eval "[ -n \"\$$READ_VAR_TO_GET\" ]"; then
        READ_DEFAULT_STR=`eval echo "\\\$$READ_VAR_TO_GET"`
    fi
    # ��ӡĬ��ֵ��ʾ��Ϣ
    if [ -n "$READ_DEFAULT_STR" -o "$READ_DEFAULT_STR_IS_EMPTY" = "y" ]; then
        printStr="${printStr} [default:${COLOR_BOLD}${READ_DEFAULT_STR}${COLOR_RESET}]"
    fi
    
    # ��ӡ������ʾ��Ϣ
    if [ -n "$READ_HELP_INFO" ]; then
        printStr="${printStr} (${COLOR_BOLD}?${COLOR_RESET})"
    fi
    
    printStr="${printStr} "
    
    # ��������ʱ
    local arg=''
    if [ "$READ_TIME_OUT" -gt 0 ] 2>/dev/null; then
        arg="-t ${READ_TIME_OUT}"
    fi
    
    # ����������ʾ����
    local diviStr=""
    if [ "$READ_SILENT" = "y" ]; then
        arg="${arg} -s"
        diviStr="\n"
    fi
    
    # ��ȡ�û�������ַ���
    local readStr
    if [ "${#READ_A_CMP_STR[@]}" -gt 0 ]; then
        local -i cmpNum=${#READ_A_CMP_STR[@]}-1
        local -i i
    fi
    while :; do
        echo -e -n "${printStr}"
        read $arg readStr
        
        # �û������ֵ����ȡĬ��ֵ����������
        if [ -z "$readStr" ]; then
            if [ -z "$READ_DEFAULT_STR" -a "$READ_DEFAULT_STR_IS_EMPTY" != "y" ]; then
                echo -e "${diviStr}$READ_WRONG_INFO"
                continue
            else
                readStr="$READ_DEFAULT_STR"
                rc=2
            fi
        fi
        
        # ��ӡ������Ϣ
        if [ "$readStr" = "?" -a -n "$READ_HELP_INFO" ]; then
            echo -e "${diviStr}$READ_HELP_INFO"
            echo -e -n "Press any key to continue ..."
            read -n 1
            echo ""         # ��ӡһ���س���
            continue
        fi
        
        # �÷�Χ�ж������Ƿ�Ϸ����Ϸ���ִ�ж�Ӧ������
        if [ "${#READ_A_CMP_STR[@]}" -gt 0 ]; then
            for((i=0; $i<=$cmpNum; i++)); do
            	local svReadSt
            	local svREAD_A_CMP_STR
                if [ "$READ_LOWER_UPPER" = "y" ]; then
                    svReadStr=` echo "$readStr" | tr '[:lower:]' '[:upper:]'`;
                    svREAD_A_CMP_STR=` echo "${READ_A_CMP_STR[$i]}" | tr '[:lower:]' '[:upper:]'`;
                 else
                    svReadStr="$readStr"
                    svREAD_A_CMP_STR="${READ_A_CMP_STR[$i]}"
                 fi
                 
                 if [ "$svReadStr" = "$svREAD_A_CMP_STR" ]; then
                    eval "$READ_VAR_TO_GET=\"${READ_A_CMP_STR[$i]}\""
                    break
                 fi
            done
            
            # ��������򱨴�������������
            if [ $i -gt $cmpNum ]; then
                echo -e "${diviStr}$READ_WRONG_INFO"
                continue
            else
                break
            fi
        
        # �ú����ж������Ƿ�Ϸ����Ϸ���ִ�ж�Ӧ������
        elif [ -n "$READ_CHK_CMD" ]; then
            eval '$READ_CHK_CMD $readStr' >> $LOG_FILE 2>&1
            if [ $? -eq 0 ]; then
                # ����Ҫ�ж���ֱ�ӷ��سɹ�
                eval "$READ_VAR_TO_GET"='$readStr'
                break
            else
                echo -e "${diviStr}$READ_WRONG_INFO"
                continue
            fi
        else
            # ����Ҫ�ж���ֱ�ӷ��سɹ�
            eval "$READ_VAR_TO_GET"='$readStr'
            break
        fi
    done
    
    echo -e -n "${diviStr}"
    
    unset READ_PROMPT_INFO          # ��ӡ����ʾ��Ϣ
    unset READ_A_CMP_STR            # ���ڱȽ��û������Ƿ���ȷ���ַ�������
    unset READ_CHK_CMD              # �����û�����Ϸ��Ե��������
    unset READ_DEFAULT_STR_IS_EMPTY
    unset READ_DEFAULT_STR          # �û�ֱ�Ӱ��س���ȡ��Ĭ��ֵ����ֵ����Ϊ�ջ���READ_A_CMP_STR�ڣ�
    unset READ_WRONG_INFO           # �û����ʱ����ʾ��Ϣ
    unset READ_HELP_INFO            # �û����� ? ʱ��ӡ�İ�����Ϣ
    unset READ_SILENT               # �Ƿ�Ϊ����ʾ���룿 y ��ʾ�ǣ�������
    unset READ_TIME_OUT             # ��ʱʱ��
    unset READ_LOWER_UPPER          # ȡ�����ִ�Сд��y ��ʾȡ����������
    unset READ_VAR_TO_GET           # ��Ҫ��ֵ�ı������û����յ����븳ֵ���˱����У�
    
    return $rc
}

######################################################################
#   FUNCTION   : ReadPrint
#   DESCRIPTION: �����û�����һ���ַ���
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : �޸ĵ�vars:��Ҫ��PROMPT_INFO��Ϊ�գ�
#                       READ_PROMPT_INFO        ��ӡ����ʾ��Ϣ
#                       READ_A_CMP_STR          ���ڱȽ��û������Ƿ���ȷ���ַ�������
#                       READ_DEFAULT_STR        �û�ֱ�Ӱ��س���ȡ��Ĭ��ֵ����ֵ����Ϊ�ջ���READ_A_CMP_STR�ڣ�
#                       READ_WRONG_INFO         �û����ʱ����ʾ��Ϣ
#                       READ_HELP_INFO          �û����� ? ʱ��ӡ�İ�����Ϣ
#                       READ_SILENT             �Ƿ�Ϊ����ʾ���룿 y ��ʾ�ǣ�������
#                       READ_TIME_OUT           ��ʱʱ��
#                       READ_LOWER_UPPER        ȡ�����ִ�Сд��y ��ʾȡ����������
#                       READ_VAR_TO_GET         ��Ҫ��ֵ�ı���
#   RETURN     : NULL
######################################################################
ReadPrintInit()
{
    unset READ_PROMPT_INFO          # ��ӡ����ʾ��Ϣ
    unset READ_A_CMP_STR            # ���ڱȽ��û������Ƿ���ȷ���ַ�������
    unset READ_CHK_CMD              # �����û�����Ϸ��Ե��������
    unset READ_DEFAULT_STR          # �û�ֱ�Ӱ��س���ȡ��Ĭ��ֵ����ֵ����Ϊ�ջ���READ_A_CMP_STR�ڣ�
    unset READ_WRONG_INFO           # �û����ʱ����ʾ��Ϣ
    unset READ_HELP_INFO            # �û����� ? ʱ��ӡ�İ�����Ϣ
    unset READ_SILENT               # �Ƿ�Ϊ����ʾ���룿 y ��ʾ�ǣ�������
    unset READ_TIME_OUT             # ��ʱʱ��
    unset READ_LOWER_UPPER          # ȡ�����ִ�Сд��y ��ʾȡ����������
    unset READ_VAR_TO_GET           # ��Ҫ��ֵ�ı������û����յ����븳ֵ���˱����У�
    
    return 0
}

fi

