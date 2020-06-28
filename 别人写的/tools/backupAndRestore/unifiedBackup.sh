#!/bin/bash

. /etc/profile 2>/dev/null
method="$1"
server_param="$2"

. ${HA_DIR}/tools/func/func.sh || { echo "fail to load $HA_DIR/tools/func/func.sh"; exit 1; }
. ${HA_DIR}/tools/func/dblib.sh || { echo "fail to load $HA_DIR/tools/func/dblib.sh"; exit 1; }
. ${HA_DIR}/tools/gsDB/dbfunc.sh || { echo "fail to load $HA_DIR/tools/gsDB/dbfunc.sh"; exit 1; }
[[ -d "$_HA_SH_LOG_DIR_" ]] || mkdir -m 700 -p ${_HA_SH_LOG_DIR_}
chown ${DB_USER}: ${_HA_SH_LOG_DIR_}
LOG_FILE=${_HA_SH_LOG_DIR_}/unifiedBackup.log

backupPath="$HA_DIR/tools/backupAndRestore"
BAK_CONF_PATH=${backupPath}/backup.conf
BAK_SCRIPT_PATH=${backupPath}/unifiedBackup.sh
BACKUP_RESTORE_FUN=${backupPath}/backup_db_restore_fun.sh
BAK_COM_FUNC=${backupPath}/com_fun.sh
COM_VAR_PATH=${backupPath}/com_var.sh
. ${BACKUP_RESTORE_FUN}
. ${BAK_COM_FUNC}
. ${COM_VAR_PATH}

die()
{
    msg="$@"
    LOG_ERROR $msg
    echo $msg
    exit 1
}

main()
{
    LOG_INFO "UNIFIED BACKUP $method START ..."

    PRIMARY_NODE_CODE=0
    STANDBY_NODE_CODE=1
    UNKNOWN_NODE_CODE=2
    service_name="SERVICE_NAME"

    is_primary
    retRes=$?

    if [[ "$method"x = "BAK_EXEC"x ]]; then
        if [[ ${retRes} -eq 1 ]]; then
            echo "This is standby node, backup should execute in primary node." && exit 0
        elif [[ ${retRes} -eq 2 ]]; then
            die "Make sure this node is primary, active and stable"
        fi

        fn_checkIsAnotherProcess
        is_running=$?
        if [[ ${is_running} -eq 1 ]]; then
            LOG_ERROR "Another backup process is running"
            echo "Another backup process is running, after a few minutes and try again"
            exit 1
        else
            ${backupPath}/dbBackupManual.sh >/dev/null 2>&1 &
            echo "backup is started"
        fi
    elif [[ "$method"x = "BAK_TASK_QUERY"x ]]; then
        if [[ ${retRes} -eq 1 ]]; then
            echo "This is standby node, backup task query should execute in primary node" && exit 0
        elif [[ ${retRes} -eq 2 ]]; then
            die "Make sure this node is primary, active and stable !"
        fi

        LOG_INFO "Checking if backup is running"
        fn_checkIsAnotherProcess
        another=$?

        if [[ ${another} -eq 1 ]]; then
            echo "{'state':'DOING','taskId':'','errorMsg':'backup is doing'}"
            exit 0
        fi

        sftpPs=`ps -ef | grep backupAndRestore/backup.sh | grep -v grep | wc -l`
        if [[ ${sftpPs} -gt 0 ]];then
           LOG_INFO "uploading to remote sftp server"
           echo "{'state':'DOING','taskId':'','errorMsg':'backup is doing'}"
           exit 0
        fi

        ${backupPath}/backupExecResultQuery.sh ${_HA_SH_LOG_DIR_}/manualBackup.log
    elif [[ "$method"x = "REG"x ]]; then
        service_name_value=$(grep "^$service_name=" ${BAK_CONF_PATH} | sed "s/^$service_name=//")
        md5ServerParam=`${backupPath}/md5ServerParam.sh`

        if [[ -z ${service_name_value} || "$service_name_value"x = "FUSIONSERVICEDB"x ]]; then
            die "service_name is null"
        fi
        if [[ ${retRes} -eq 0 ]]; then
            ${backupPath}/backupRegisterToOMM.sh ${service_name_value} ${PRIMARY_NODE_CODE} ${BAK_SCRIPT_PATH} "${md5ServerParam}"
        elif [[ ${retRes} -eq 1 ]]; then
            ${backupPath}/backupRegisterToOMM.sh ${service_name_value} ${STANDBY_NODE_CODE} ${BAK_SCRIPT_PATH} "${md5ServerParam}"
        else
            ${backupPath}/backupRegisterToOMM.sh ${service_name_value} ${UNKNOWN_NODE_CODE} ${BAK_SCRIPT_PATH} "${md5ServerParam}"
        fi
    elif [[ "$method"x = "REG_ROLE_UNKNOWN"x ]]; then
        service_name_value=$(grep "^$service_name=" ${BAK_CONF_PATH} | sed "s/^$service_name=//")
        md5ServerParam=`${backupPath}/md5ServerParam.sh`

        if [[ -z ${service_name_value} ]]; then
            service_name_value="FUSIONSERVICEDB"
        fi
        ${backupPath}/backupRegisterToOMM.sh ${service_name_value} ${UNKNOWN_NODE_CODE} ${BAK_SCRIPT_PATH} "${md5ServerParam}"
    elif [[ "$method"x = "BAK_RES_SERVER_SET"x ]]; then
        local param="$server_param"
        ${backupPath}/updateServerConfig.sh ${param}
    else
        echo "Params feature is error!"
    fi
}

main