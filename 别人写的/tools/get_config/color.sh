# shell ������ɫ�Ķ���

if [ -z "$COLOR_SH" ]; then

declare -r COLOR_SH=COLOR_SH

# ����ǰ��ɫ
declare -r COLOR_FRONT_BLACK="\033[30m"
declare -r COLOR_FRONT_RED="\033[31m"
declare -r COLOR_FRONT_GREEN="\033[32m"
declare -r COLOR_FRONT_YELLOW="\033[33m"
declare -r COLOR_FRONT_BLUE="\033[34m"
declare -r COLOR_FRONT_PURPLE="\033[35m"       # ��ɫ
declare -r COLOR_FRONT_TURQUOISE="\033[36m"    # ����ɫ
declare -r COLOR_FRONT_WHILE="\033[36m"

# ���ñ���ɫ
declare -r COLOR_BACK_BLACK="\033[40m"
declare -r COLOR_BACK_RED="\033[41m"
declare -r COLOR_BACK_GREEN="\033[42m"
declare -r COLOR_BACK_YELLOW="\033[43m"
declare -r COLOR_BACK_BLUE="\033[44m"
declare -r COLOR_BACK_PURPLE="\033[45m"       # ��ɫ
declare -r COLOR_BACK_TURQUOISE="\033[46m"    # ����ɫ
declare -r COLOR_BACK_WHILE="\033[46m"

# ������ʾ
declare -r COLOR_BOLD="\033[1m"      # ������
declare -r COLOR_UNDERLINE="\033[4m" # �»���
declare -r COLOR_SHADOW="\033[5m"    # ��Ӱ�ӵ�
declare -r COLOR_REVER="\033[7m"     # ǰ���뱳������

# �ָ�Ĭ��
declare -r COLOR_CLOSE="\033[0m"         # �ر���������
declare -r COLOR_RESET="\033[0m"         # �ر���������

fi
