#!/bin/bash

# 
# ���⺯���б�
#   MenuHead
# 


if [ -z "$MAIN_MENU_SH" ]; then
declare -r MAIN_MENU_SH=MAIN_MENU_SH

LIB_SH_PATH="$PWD"

. "$LIB_SH_PATH"/color.sh
. "$LIB_SH_PATH"/cursor.sh

######################################################################
#   FUNCTION   : repeatStr
#   DESCRIPTION: ��ӡ $1 �� $2
#   CALLS      : EVERYONE
#   CALLED BY  : NULL
#   INPUT      :    ����һ���ظ��Ĵ���
#                   ���������ظ����ַ�������
#   OUTPUT     : ��ӡ���ظ� $1 �ε� $2
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
#   DESCRIPTION: ��ӡ���ߵĽ���ͷ
#   CALLS      : NULL
#   CALLED BY  : NULL
#   INPUT      : ��Ҫ��ӡ���ַ���
#   OUTPUT     : NULL
#   RETURN     : NULL
######################################################################
MenuHead()
{
    # ����
    echo -e -n "\f"
    
    # δ���������ֻ����
    [ -z "$1" ] && return 0
    
    local markChar='#'          # �ָ���ַ�
    local printStr="$1"         # ��Ҫ��ӡ���ַ���
    local bottomTopStr=""       # ���к�β��
    local wholeStr=""           # ��Ҫ��ӡ����������
    
    # ��ȡ��Ļ��Ⱥͳ���
    if [ -z "$LINES" -o -z "$COLUMNS" ]; then
    eval `stty size 2>/dev/null | (read L C; \
          echo LINES=${L:-24} COLUMNS=${C:-80})`
    fi
    [ $LINES   -eq 0 ] && LINES=24
    [ $COLUMNS -eq 0 ] && COLUMNS=80

    [ $LINES -le 5 ] && return 0

    # ��Ҫ��ӡ����С���ȣ�ǰ�����һ���ո���$markChar��
    local -i minStrLeng=${#printStr}+${#markChar}+${#markChar}+2
    
    [ $minStrLeng -gt $COLUMNS ] && return 0

    # ��ӡ�ַ������еĿո�
    local -i totalBlankNum=$COLUMNS-${#printStr}-${#markChar}-${#markChar}  # �ո�����
    local -i leftBlandNum=$totalBlankNum/2                  # ��ߵĿո���
    local -i rightBlandNum=$totalBlankNum-$leftBlandNum     # �ұߵĿո���

    # �ڶ��к͵����ڶ��еĿո���
    local -i blankHeadNum=$COLUMNS-2

    # ��Ҫ��ӡ����������
    wholeStr="${wholeStr}${COLOR_FRONT_BLUE}`repeatStr $COLUMNS $markChar`\n"
    wholeStr="${wholeStr}$markChar`repeatStr $blankHeadNum ' '`$markChar\n"
    
    wholeStr="${wholeStr}$markChar`repeatStr $leftBlandNum ' '`${COLOR_FRONT_GREEN}$printStr"
    wholeStr="${wholeStr}${COLOR_FRONT_BLUE}`repeatStr $rightBlandNum ' '`$markChar\n"
    
    wholeStr="${wholeStr}$markChar`repeatStr $blankHeadNum ' '`$markChar\n"
    wholeStr="${wholeStr}`repeatStr $COLUMNS $markChar`${COLOR_CLOSE}\n"
    
    echo -e -n "$wholeStr"
}

fi
