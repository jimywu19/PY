#!/bin/bash

# 
# 对外函数列表：
#   ReadPrint
# 

if [ -z "$CGP_PROMPT_SH" ]; then
CGP_PROMPT_SH=CGP_PROMPT_SH

. color.sh

######################################################################
#   FUNCTION   : ReadPrint
#   DESCRIPTION: 请求用户输入一个字符串
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : 读取的vars:（要求PROMPT_INFO不为空）
#                       READ_PROMPT_INFO        要求用户输入时，打印的提示信息
#                       READ_A_CMP_STR          用于比较用户输入是否正确的字符串数组
#                       （如果此变量不为空，用户的输入必须是这个字符串数组中的其中一个字符串）
#                       （如果设置了 READ_A_CMP_STR ，则 READ_CHK_CMD 被忽略）
#                       READ_CHK_CMD            检验用户输入合法性的命令或函数
#                       READ_DEFAULT_STR        用户直接按回车所取的默认值（该值必须为空或在READ_A_CMP_STR内）
#                       READ_WRONG_INFO         用户输错时的提示信息
#                       READ_HELP_INFO          用户输入 ? 时打印的帮助信息
#                       READ_SILENT             是否为不显示输入？ y 表示是，否则不是
#                       READ_TIME_OUT           超时时间
#                       READ_LOWER_UPPER        取消区分大小写，y 表示取消，否则不是
#   OUTPUT     : 修改的vars：
#                       READ_VAR_TO_GET         需要赋值的变量
#                       （用户最终的输入赋值到此变量所保存的变量中，例如）
#   RETURN     :    0 正常结束
#                   1 打印信息为空
#                   2 正常结束（获取了默认值）
######################################################################
ReadPrint()
{
    # 提示信息不能为空
    [ -z "$READ_PROMPT_INFO" ] && return 1
    
    # 不能没有需要赋值的变量
    [ -z "$READ_VAR_TO_GET" ] && return 1
    
    local -i rc=0
    local printStr="$READ_PROMPT_INFO"
    
    # 如果变量原先已经赋值，则默认值为原先的值
    if eval "[ -n \"\$$READ_VAR_TO_GET\" ]"; then
        READ_DEFAULT_STR=`eval echo "\\\$$READ_VAR_TO_GET"`
    fi
    # 打印默认值提示信息
    if [ -n "$READ_DEFAULT_STR" -o "$READ_DEFAULT_STR_IS_EMPTY" = "y" ]; then
        printStr="${printStr} [default:${COLOR_BOLD}${READ_DEFAULT_STR}${COLOR_RESET}]"
    fi
    
    # 打印帮助提示信息
    if [ -n "$READ_HELP_INFO" ]; then
        printStr="${printStr} (${COLOR_BOLD}?${COLOR_RESET})"
    fi
    
    printStr="${printStr} "
    
    # 参数：超时
    local arg=''
    if [ "$READ_TIME_OUT" -gt 0 ] 2>/dev/null; then
        arg="-t ${READ_TIME_OUT}"
    fi
    
    # 参数：不显示输入
    local diviStr=""
    if [ "$READ_SILENT" = "y" ]; then
        arg="${arg} -s"
        diviStr="\n"
    fi
    
    # 读取用户输入的字符串
    local readStr
    if [ "${#READ_A_CMP_STR[@]}" -gt 0 ]; then
        local -i cmpNum=${#READ_A_CMP_STR[@]}-1
        local -i i
    fi
    while :; do
        echo -e -n "${printStr}"
        read $arg readStr
        
        # 用户输入空值，则取默认值或重新输入
        if [ -z "$readStr" ]; then
            if [ -z "$READ_DEFAULT_STR" -a "$READ_DEFAULT_STR_IS_EMPTY" != "y" ]; then
                echo -e "${diviStr}$READ_WRONG_INFO"
                continue
            else
                readStr="$READ_DEFAULT_STR"
                rc=2
            fi
        fi
        
        # 打印帮助信息
        if [ "$readStr" = "?" -a -n "$READ_HELP_INFO" ]; then
            echo -e "${diviStr}$READ_HELP_INFO"
            echo -e -n "Press any key to continue ..."
            read -n 1
            echo ""         # 打印一个回车符
            continue
        fi
        
        # 用范围判断输入是否合法，合法则执行对应的命令
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
            
            # 输入错误则报错，否则正常结束
            if [ $i -gt $cmpNum ]; then
                echo -e "${diviStr}$READ_WRONG_INFO"
                continue
            else
                break
            fi
        
        # 用函数判断输入是否合法，合法则执行对应的命令
        elif [ -n "$READ_CHK_CMD" ]; then
            eval '$READ_CHK_CMD $readStr' >> $LOG_FILE 2>&1
            if [ $? -eq 0 ]; then
                # 不需要判断则直接返回成功
                eval "$READ_VAR_TO_GET"='$readStr'
                break
            else
                echo -e "${diviStr}$READ_WRONG_INFO"
                continue
            fi
        else
            # 不需要判断则直接返回成功
            eval "$READ_VAR_TO_GET"='$readStr'
            break
        fi
    done
    
    echo -e -n "${diviStr}"
    
    unset READ_PROMPT_INFO          # 打印的提示信息
    unset READ_A_CMP_STR            # 用于比较用户输入是否正确的字符串数组
    unset READ_CHK_CMD              # 检验用户输入合法性的命令或函数
    unset READ_DEFAULT_STR_IS_EMPTY
    unset READ_DEFAULT_STR          # 用户直接按回车所取的默认值（该值必须为空或在READ_A_CMP_STR内）
    unset READ_WRONG_INFO           # 用户输错时的提示信息
    unset READ_HELP_INFO            # 用户输入 ? 时打印的帮助信息
    unset READ_SILENT               # 是否为不显示输入？ y 表示是，否则不是
    unset READ_TIME_OUT             # 超时时间
    unset READ_LOWER_UPPER          # 取消区分大小写，y 表示取消，否则不是
    unset READ_VAR_TO_GET           # 需要赋值的变量（用户最终的输入赋值到此变量中）
    
    return $rc
}

######################################################################
#   FUNCTION   : ReadPrint
#   DESCRIPTION: 请求用户输入一个字符串
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : NULL
#   OUTPUT     : 修改的vars:（要求PROMPT_INFO不为空）
#                       READ_PROMPT_INFO        打印的提示信息
#                       READ_A_CMP_STR          用于比较用户输入是否正确的字符串数组
#                       READ_DEFAULT_STR        用户直接按回车所取的默认值（该值必须为空或在READ_A_CMP_STR内）
#                       READ_WRONG_INFO         用户输错时的提示信息
#                       READ_HELP_INFO          用户输入 ? 时打印的帮助信息
#                       READ_SILENT             是否为不显示输入？ y 表示是，否则不是
#                       READ_TIME_OUT           超时时间
#                       READ_LOWER_UPPER        取消区分大小写，y 表示取消，否则不是
#                       READ_VAR_TO_GET         需要赋值的变量
#   RETURN     : NULL
######################################################################
ReadPrintInit()
{
    unset READ_PROMPT_INFO          # 打印的提示信息
    unset READ_A_CMP_STR            # 用于比较用户输入是否正确的字符串数组
    unset READ_CHK_CMD              # 检验用户输入合法性的命令或函数
    unset READ_DEFAULT_STR          # 用户直接按回车所取的默认值（该值必须为空或在READ_A_CMP_STR内）
    unset READ_WRONG_INFO           # 用户输错时的提示信息
    unset READ_HELP_INFO            # 用户输入 ? 时打印的帮助信息
    unset READ_SILENT               # 是否为不显示输入？ y 表示是，否则不是
    unset READ_TIME_OUT             # 超时时间
    unset READ_LOWER_UPPER          # 取消区分大小写，y 表示取消，否则不是
    unset READ_VAR_TO_GET           # 需要赋值的变量（用户最终的输入赋值到此变量中）
    
    return 0
}

fi

