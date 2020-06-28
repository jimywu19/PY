#!/bin/bash

. /etc/profile 2>/dev/null
# log
. $HA_DIR/tools/func/func.sh || { echo "fail to load $HA_DIR/tools/func/func.sh"; exit 1; }
. $HA_DIR/tools/func/dblib.sh || { echo "fail to load $HA_DIR/tools/func/dblib.sh"; exit 1; }
. $HA_DIR/tools/gsDB/dbfunc.sh || { echo "fail to load $HA_DIR/tools/gsDB/dbfunc.sh"; exit 1; }
[ -d "$_HA_SH_LOG_DIR_" ] || mkdir -m 700 -p $_HA_SH_LOG_DIR_
chown $DB_USER: $_HA_SH_LOG_DIR_
LOG_FILE=$_HA_SH_LOG_DIR_/unifiedBackup.log

HA_STATUS_CHECK_SCRIPT='/opt/gaussdb/ha/module/hacom/script/status_ha.sh'
NODE_ACTIVE_STAUS_FILE='/opt/gaussdb/ha/tools/backupAndRestore/node_active_status.conf'
REGISTER_SERVICE_SCRIPT_PATH='/opt/gaussdb/ha/tools/backupAndRestore/unifiedBackup.sh'

function checkParams()
{
    checkParam="$1"
    if [[ -z ${checkParam} ]]
    then
        LOG_ERROR "Query HAactive error, Params is null, Please check status_ha.sh script!"
        return 1
    else
        node_conf_array=(${checkParam})
        conf_array_size=3
        if [[ ${#node_conf_array[*]} -ne ${conf_array_size} ]]
        then
            LOG_ERROR "Query HAactive error, Params number is not 3, Please check status_ha.sh script!"
            return 1
        fi
    fi
    return 0
}

function roleIsChanged()
{
    node_conf_array=($1)
    node_current_active=${node_conf_array[1]}
    node_current_res=${node_conf_array[2]}

    node_last_active=`cat ${NODE_ACTIVE_STAUS_FILE} | sed -n '1p' | awk '{print $2}'`
    node_last_res=`cat ${NODE_ACTIVE_STAUS_FILE} | sed -n '1p' | awk '{print $3}'`

    if [[ ${node_current_active} != ${node_last_active} || ${node_current_res} != ${node_last_res} ]]
    then
        return 0
    else
        return 1
    fi
}

function roleIsStable()
{
    node_conf_array=($1)
    node_current_res=${node_conf_array[2]}
    node_normal_res="normal"
    LOG_INFO "check if node role status is stable, the resource status is :${node_current_res}"
    if [[ ${node_current_res} = ${node_normal_res} ]]
    then
        return 0
    else
        return 1
    fi
}

function main()
{
    if [[ ! -f "${NODE_ACTIVE_STAUS_FILE}" ]]; then
        touch ${NODE_ACTIVE_STAUS_FILE}
        chmod 600 ${NODE_ACTIVE_STAUS_FILE}
        chown root:root ${NODE_ACTIVE_STAUS_FILE}

        node_active_info=`sh ${HA_STATUS_CHECK_SCRIPT} | sed -n '5,6p' | awk '{print $1,$6,$7}' | grep $(hostname)`
        checkParams "${node_active_info}"
        checkResult=$?
        if [[ ${checkResult} -eq 1 ]]
        then
            exit 1
        else
            echo "${node_active_info}" > ${NODE_ACTIVE_STAUS_FILE}
        fi

        LOG_INFO "start monitor node switchover event, create file to save node role status"
        sh ${REGISTER_SERVICE_SCRIPT_PATH} REG
        exit 0
    fi

    node_active_status=`sh ${HA_STATUS_CHECK_SCRIPT} | sed -n '5,6p' | awk '{print $1,$6,$7}' | grep $(hostname)`
    checkParams "${node_active_status}"
    checkResult=$?
    if [[ ${checkResult} -eq 1 ]]
    then
        exit 1
    fi

    roleIsChanged "${node_active_status}"
    node_isChanged=$?

    if [[ ${node_isChanged} -eq 0 ]]; then
        LOG_INFO "node role is changed,current role is ${node_active_status}"
        roleIsStable "${node_active_status}"
        node_isStable=$?
        if [[ ${node_isStable} -eq 0 ]]; then
            LOG_INFO "node resource is normal, switchover is ok, register to omm..."
            sh ${REGISTER_SERVICE_SCRIPT_PATH} REG
        else
            LOG_INFO "node resource is abnormal, switchover is not finished, notify to omm..."
            sh ${REGISTER_SERVICE_SCRIPT_PATH} REG_ROLE_UNKNOWN
        fi
    fi

    echo "${node_active_status}" > ${NODE_ACTIVE_STAUS_FILE}
}

while true
do
    main
    sleep 10
done



