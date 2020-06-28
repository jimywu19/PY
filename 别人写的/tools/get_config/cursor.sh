# shell 关于光标控制的定义

if [ -z "$CURSOR_SH" ]; then
declare -r CURSOR_SH=CURSOR_SH

# 光标控制动作定义
declare -r CUR_CLEAR="\33[2J"       # 清屏
declare -r CUR_SAVE="\33[s"         # 保存光标位置
declare -r CUR_RESUME="\33[u"       # 恢复光标位置
declare -r CUR_HIDE="\33[?25l"      # 隐藏光标
declare -r CUR_SHOW="\33[?25h"      # 显示光标
declare -r CUR_DEL_TAIL="\33[K"     # 清除从光标到行尾的内容

# 光标移动函数定义
# 光标上移n行
CurMvUp()
{
    echo -en "\33[${1}A"
}

# 光标下移n行
CurMvDown()
{
    echo -en "\33[${1}B"
}

# 光标右移n行
CurMvRight()
{
    echo -en "\33[${1}C"
}

# 光标左移n行
CurMvLeft()
{
    echo -en "\33[${1}D"
}

# 设置光标位置
CurMvTo()
{
    echo -en "\33[${1};${2}H"
}

fi
