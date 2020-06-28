#!/bin/bash
set +x

#########################################################
#    Description: is_primary
#    Input: none
#    Return: 
#    ���ڵ�����ڵ�   primary
#    ����ڵ㱸�ڵ�   secondary
#    ��had���� unknown
#########################################################
#-------------------------------------------------------------------------
# �жϵ�ǰ�ڵ������ڵ㻹�Ǳ��ڵ�
# 1����had����ok��   ʹ��get_harole.sh�ж�
# 2����had���̲�ok�� unknown
#------------------------------------------------------------------------

haRoleScript="$HA_DIR/module/hacom/script/get_harole.sh"

# trim begin and end blank space
# ' foo bar ' will be trimed to 'foo bar'ce
function trim()
{
    local in="$1"
    local out=$(echo "$in" | sed 's/^ *//;s/ *$//')

    echo "$out"
}

function useHA()
{
    if [ ! -f $haRoleScript ]; then
        echo "unknown"
        return 1
    fi

    local harole=$(sh $haRoleScript)
    harole=$(trim $harole)
    case "${harole}" in
        active)
        echo "primary"
        ;;
        standby)
        echo "secondary"
        ;;
        *)
        echo "unknown"
        ;;
    esac
}

useHA

