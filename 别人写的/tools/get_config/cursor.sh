# shell ���ڹ����ƵĶ���

if [ -z "$CURSOR_SH" ]; then
declare -r CURSOR_SH=CURSOR_SH

# �����ƶ�������
declare -r CUR_CLEAR="\33[2J"       # ����
declare -r CUR_SAVE="\33[s"         # ������λ��
declare -r CUR_RESUME="\33[u"       # �ָ����λ��
declare -r CUR_HIDE="\33[?25l"      # ���ع��
declare -r CUR_SHOW="\33[?25h"      # ��ʾ���
declare -r CUR_DEL_TAIL="\33[K"     # ����ӹ�굽��β������

# ����ƶ���������
# �������n��
CurMvUp()
{
    echo -en "\33[${1}A"
}

# �������n��
CurMvDown()
{
    echo -en "\33[${1}B"
}

# �������n��
CurMvRight()
{
    echo -en "\33[${1}C"
}

# �������n��
CurMvLeft()
{
    echo -en "\33[${1}D"
}

# ���ù��λ��
CurMvTo()
{
    echo -en "\33[${1};${2}H"
}

fi
