function is_primary()
{
    local backupPath="$HA_DIR/tools/backupAndRestore"
    if [ ! -f $backupPath/is_primary.sh ]; then
        LOG_INFO "ckupPath/is_primary.sh not exists, please check file integrity!"
        exit -1
    fi
    local type=$(sh $backupPath/is_primary.sh)
    if [ $type = "secondary" ]; then
        return 1
    fi
    
    if [ $type = "unknown" ]; then
        return 2
    fi
    return 0
}

function fn_checkIsAnotherProcess()
{
    process_info_string="gs_rman"
    ps -efww | grep $process_info_string | grep -v grep > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        return 1
    fi
    return 0
}

function fn_checkLocalDiskSpace()
{
    local checkDir="$1"
    local spaceLowLimit="$2"
    local availSpace=$(df -mP $checkDir | grep -v '^Filesystem' |  awk '{print $4}')

    LOG_INFO "availSpace=${availSpace}"
    LOG_INFO "spaceLowLimit=${spaceLowLimit}"

    if [[ ${availSpace} -lt ${spaceLowLimit} ]]; then
        return 1
    fi
}

function fn_check_ha()
{
    ps -efww | grep "ha.bin" | grep -v grep > /dev/null 2>&1
    haCheckRes=$?
    if [ $haCheckRes -eq 0 ]; then
         LOG_WARN " HA is running, stop it before restore ! "
         return 1
    fi

    ps -efww | grep -E 'dbprogram/bin/gaussdb$' | grep -v 'grep' > /dev/null 2>&1
    dbCheckRes=$?
    if [ $dbCheckRes -eq 0 ]; then
         LOG_WARN " Gaussdb is running, stop it before restore ! "
         return 2
    fi
}

function fn_start_gaussdb_process()
{
    su - dbadmin -c "gs_ctl start -M primary" >> ${LOG_FILE} 2>&1
    if [ $? -ne 0 ]
    then
        LOG_INFO "start gaussdb failed, cycle check it."
        for ((i=0; i<10; i++ ))
        do
            service gaussdb status | grep "no server running"  >> ${LOG_FILE} 2>&1
            if [ $? -eq 0 ]
            then
                LOG_INFO "check gaussdb ${i} times failed."
            else
                return 0
            fi
            sleep 10
        done
        return 1
    fi

    LOG_INFO "sleep 120S, To ensure the success of the data to read from gaussdb."
    sleep 60

    LOG_INFO " This node starts as primary, check Gaussdb server, start HA by manual! "

    return 0
}
