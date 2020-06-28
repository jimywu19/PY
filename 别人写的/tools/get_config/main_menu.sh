#!/bin/bash

# 
# 对外函数列表：
#   MenuHead
# 


if [ -z "$MAIN_MENU_SH" ]; then
declare -r MAIN_MENU_SH=MAIN_MENU_SH

LIB_SH_PATH="$PWD"

. "$LIB_SH_PATH"/color.sh
. "$LIB_SH_PATH"/cursor.sh

######################################################################
#   FUNCTION   : repeatStr
#   DESCRIPTION: 打印 $1 个 $2
#   CALLS      : EVERYONE
#   CALLED BY  : NULL
#   INPUT      :    参数一：重复的次数
#                   参数二：重复的字符串内容
#   OUTPUT     : 打印出重复 $1 次的 $2
#   RETURN     : NULL
######################################################################
repeatStr()
{
    local -i i=1
    local str=""
    
    while [ $i -le $1 ]; do
        str="$str$2"
        i=$i+1
    done 
    
    echo -e -n "$str"
}

######################################################################
#   FUNCTION   : MenuHead
#   DESCRIPTION: 打印工具的界面头
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : 需要打印的字符串
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
MenuHead()
{
    # 清屏
    echo -e -n "\f"
    
    # 未传入参数则只清屏
    [ -z "$1" ] && return 0
    
    local markChar='#'          # 分割的字符
    local printStr="$1"         # 需要打印的字符串
    local bottomTopStr=""       # 首行和尾行
    local wholeStr=""           # 需要打印的所有内容
    
    # 获取屏幕宽度和长度
    if [ -z "$LINES" -o -z "$COLUMNS" ]; then
    eval `stty size 2>/dev/null | (read L C; \
          echo LINES=${L:-24} COLUMNS=${C:-80})`
    fi
    [ $LINES   -eq 0 ] && LINES=24
    [ $COLUMNS -eq 0 ] && COLUMNS=80

    [ $LINES -le 5 ] && return 0

    # 需要打印的最小长度（前后各加一个空个和$markChar）
    local -i minStrLeng=${#printStr}+${#markChar}+${#markChar}+2
    
    [ $minStrLeng -gt $COLUMNS ] && return 0

    # 打印字符所在行的空格
    local -i totalBlankNum=$COLUMNS-${#printStr}-${#markChar}-${#markChar}  # 空格总数
    local -i leftBlandNum=$totalBlankNum/2                  # 左边的空格数
    local -i rightBlandNum=$totalBlankNum-$leftBlandNum     # 右边的空格数

    # 第二行和倒数第二行的空格数
    local -i blankHeadNum=$COLUMNS-2

    # 需要打印的所有内容
    wholeStr="${wholeStr}${COLOR_FRONT_BLUE}`repeatStr $COLUMNS $markChar`\n"
    wholeStr="${wholeStr}$markChar`repeatStr $blankHeadNum ' '`$markChar\n"
    
    wholeStr="${wholeStr}$markChar`repeatStr $leftBlandNum ' '`${COLOR_FRONT_GREEN}$printStr"
    wholeStr="${wholeStr}${COLOR_FRONT_BLUE}`repeatStr $rightBlandNum ' '`$markChar\n"
    
    wholeStr="${wholeStr}$markChar`repeatStr $blankHeadNum ' '`$markChar\n"
    wholeStr="${wholeStr}`repeatStr $COLUMNS $markChar`${COLOR_CLOSE}\n"
    
    echo -e -n "$wholeStr"
}

fi
