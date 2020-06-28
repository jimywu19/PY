#!/bin/bash
set +x

#########################################################
#    Description: is_primary
#    Input: none
#    Return: 
#    单节点或主节点   primary
#    管理节点备节点   secondary
#    无had服务 unknown
#########################################################
#-------------------------------------------------------------------------
# 判断当前节点是主节点还是备节点
# 1、若had进程ok，   使用get_harole.sh判断
# 2、若had进程不ok， unknown
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

