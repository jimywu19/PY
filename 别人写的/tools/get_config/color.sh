# shell 关于颜色的定义

if [ -z "$COLOR_SH" ]; then

declare -r COLOR_SH=COLOR_SH

# 设置前景色
declare -r COLOR_FRONT_BLACK="\033[30m"
declare -r COLOR_FRONT_RED="\033[31m"
declare -r COLOR_FRONT_GREEN="\033[32m"
declare -r COLOR_FRONT_YELLOW="\033[33m"
declare -r COLOR_FRONT_BLUE="\033[34m"
declare -r COLOR_FRONT_PURPLE="\033[35m"       # 紫色
declare -r COLOR_FRONT_TURQUOISE="\033[36m"    # 青绿色
declare -r COLOR_FRONT_WHILE="\033[36m"

# 设置背景色
declare -r COLOR_BACK_BLACK="\033[40m"
declare -r COLOR_BACK_RED="\033[41m"
declare -r COLOR_BACK_GREEN="\033[42m"
declare -r COLOR_BACK_YELLOW="\033[43m"
declare -r COLOR_BACK_BLUE="\033[44m"
declare -r COLOR_BACK_PURPLE="\033[45m"       # 紫色
declare -r COLOR_BACK_TURQUOISE="\033[46m"    # 青绿色
declare -r COLOR_BACK_WHILE="\033[46m"

# 特殊显示
declare -r COLOR_BOLD="\033[1m"      # 高亮度
declare -r COLOR_UNDERLINE="\033[4m" # 下划线
declare -r COLOR_SHADOW="\033[5m"    # 带影子的
declare -r COLOR_REVER="\033[7m"     # 前景与背景反显

# 恢复默认
declare -r COLOR_CLOSE="\033[0m"         # 关闭所有属性
declare -r COLOR_RESET="\033[0m"         # 关闭所有属性

fi
