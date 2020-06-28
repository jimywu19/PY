#/bin/bash
set +x

source /etc/profile 2>/dev/null

. $HA_DIR/tools/func/globalvar.sh || { echo "fail to load $HA_DIR/tools/func/globalvar.sh"; exit 1; }

backupPath="$HA_DIR/tools/backupAndRestore"

# log
. $HA_DIR/tools/func/func.sh || { echo "fail to load $HA_DIR/tools/func/func.sh"; exit 1; }
. $HA_DIR/tools/func/dblib.sh || { echo "fail to load $HA_DIR/tools/func/dblib.sh"; exit 1; }
. $HA_DIR/tools/gsDB/dbfunc.sh || { echo "fail to load $HA_DIR/tools/gsDB/dbfunc.sh"; exit 1; }
[ -d "$_HA_SH_LOG_DIR_" ] || mkdir -m 700 -p $_HA_SH_LOG_DIR_
chown $DB_USER: $_HA_SH_LOG_DIR_
LOG_FILE=$_HA_SH_LOG_DIR_/gsRmanRestore.log

BAK_CONF_PATH=$backupPath/backup.conf
BACKUP_RESTORE_FUN=$backupPath/backup_db_restore_fun.sh
BAK_COM_FUNC=$backupPath/com_fun.sh
COM_VAR_PATH=$backupPath/com_var.sh
. $BACKUP_RESTORE_FUN
. $BAK_COM_FUNC
. $COM_VAR_PATH

error_exit()
{
    LOG_ERROR "$@"
    echo "ERROR" "$@"
    exit 1
}

die()
{
    if [ -d $RMAN_BACKUP_PATH ]; then
        rm -r $RMAN_BACKUP_PATH
    fi
    error_exit "$@"
}


SPECIFY_RESTORE_FILE=""
function ShowHelp()
{
    echo -e "
    Usage: 
    dbRestore [options]
    
    Options:
    (null)  : Recovery with the latest backupfile in $RMAN_BACKUP_PATH
    -f      : Recovery with specified file
    -t      : Recovery to target time 
    -h      : Show help    

    Examples:
    dbRestore
    dbRestore -f xxx.tar.gz, (relative path)
    dbRestore -f /opt/backup/DB/xxx.tar.gz, (absolute path)
    dbRestore -t '1111-11-11 11:11:11'
    dbRestore -h
"  
    return 0
}

# check input
function checkInput()
{
    if [ $# -eq 1 ]; then
        if [ ! -f $1 ]; then
            LOG_ERROR " Invalid backup file name, check the backup path: $BACKUP_PATH ! "
            echo "ERROR" "filename wrong"
            echo "Usage:" 
            echo "dbRestore -f xxx.tar.gz, (relative path)"
            echo "dbRestore -f /opt/backup/DB/xxx.tar.gz, (absolute path)"
            exit 1
        else
            SPECIFY_RESTORE_FILE=$1
            LOG_INFO "restore file: $SPECIFY_RESTORE_FILE"
            return 1
        fi
    else
        LOG_ERROR "Restore input error, [$@] "
        echo "ERROR" "input parameter wrong"
        echo "Usage:" 
        echo "dbRestore xxx.tar.gz"
        return 0
    fi
}

function fn_get_timelineID()
{
    if [ -z "${recoveryTime}" ];then
        error_exit "Input recoveryTime is null"
    fi
    tmpDBPrint=`do_show timeline 2>/dev/null | tail -n 1`
    if [ -z "${tmpDBPrint}" ];then
        error_exit "No backup file"
    fi

    LOG_INFO "get timelineID, tmpDBPrint: $tmpDBPrint"
    backupMethod=`do_show timeline 2>/dev/null | tail -n 1 | awk '{print $3}'`
    if [ $backupMethod == 'FULL' ];then
        timelineID=`do_show timeline 2>/dev/null | tail -n 1 | awk '{print $4}'` 
        if [ -z "${timelineID}" ];then
            error_exit "Get timelineID failed"
        fi
        LOG_INFO "timelineID: $timelineID"
    else
        die "No FULL backup file"
    fi
}

function fn_get_recoverTime_and_timelineID()
{
    tmpDBPrint=`do_show 2>/dev/null | head -n4 | tail -n 1 | awk '{print $1" "$2}'`
    if [ -z "${tmpDBPrint}" ]; then
        echo "TIPS: showbackup [t], check backup history"
        die "No backup file, use [CMD] dbRestore -f xxx.tar.gz. Show help: dbRestore -h !"
    fi

    LOG_INFO "get recoverTime and timelineID, tmpDBPrint: $tmpDBPrint"
    recoveryTime=`su - dbadmin -c "gs_rman show -B $RMAN_BACKUP_PATH ${tmpDBPrint}" 2>/dev/null | grep RECOVERY_TIME | awk -F "=" '{print $2}'`
    LOG_INFO "su - dbadmin -c \"gs_rman show -B $RMAN_BACKUP_PATH ${tmpDBPrint}\" 2>/dev/null | grep RECOVERY_TIME | awk -F \"=\" '{print $2}'"
    LOG_INFO "RECOVERY_TIME: $recoveryTime"
    timelineID=`su - dbadmin -c "gs_rman show -B $RMAN_BACKUP_PATH ${tmpDBPrint}" 2>/dev/null | grep TIMELINEID | awk -F "=" '{print $2}'`
    LOG_INFO "TIMELINEID: $timelineID"

    if [ -z "${recoveryTime}" ] || [ -z "${timelineID}" ]; then
        echo "TIPS: showbackup [t], check backup history"
        die "Get recoveryTime and timelineID failed"
    fi
}

function fn_untarRestoreFile()
{
    if [ -d $RMAN_BACKUP_PATH ]; then
        rm -r $RMAN_BACKUP_PATH
    fi
    if [ ! -f $SPECIFY_RESTORE_FILE ]; then
        die "Specified file does not exist, please check input"
    fi
    tar zxf $SPECIFY_RESTORE_FILE -C $BACKUP_PATH >> "${LOG_FILE}" 2>&1
    retRes=$?
    if [ $retRes -eq 0 ]; then
        LOG_INFO "tar zvxf $SPECIFY_RESTORE_FILE success"
    else
        LOG_WARN "tar restore file failed, will sleep 15s and retry..."
        tar zxf $SPECIFY_RESTORE_FILE -C $BACKUP_PATH >> "${LOG_FILE}" 2>&1
        retRes=$?
        if [ $retRes -eq 0 ]; then
            die "Tar restore file: $restoreFile, failed"
        fi
    fi
    return 0
}

function fn_restoreDB()
{
    fn_check_ha || error_exit " Primary and Standby need stop HA first, CMD [haStopAll -a] "
    LOG_INFO "recovery-target-time: $recoveryTime"
    LOG_INFO "recovery-target-timeline: $timelineID"
    su - dbadmin -c "gs_rman restore -B $RMAN_BACKUP_PATH --recovery-target-time ${recoveryTime} --recovery-target-timeline ${timelineID} --print-progress" | tee -a ${LOG_FILE}
    dbRestoreRes=${PIPESTATUS[0]}
    LOG_INFO "gs_rman restore -B $RMAN_BACKUP_PATH --recovery-target-time ${recoveryTime} --recovery-target-timeline ${timelineID}, return $dbRestoreRes"
    if [ $dbRestoreRes -ne 0 ]; then
        do_init >> "${LOG_FILE}" 2>&1
        die "Restore failed"
    fi
    return $do_restoreRes
}


curUser=`/usr/bin/whoami | /usr/bin/awk '{print $1}'`
if [ "${curUser}" != "root" ]
then
    error_exit "The user to excute the command must be root ! "
fi

first_parma=$1
if [ ! -z $first_parma ] && [ ${first_parma:0:1} != "-" ]; then
    ShowHelp
    exit 1
fi

while getopts "f:t:h" options;
do
    case $options in
        f)
            SPECIFY_RESTORE_FILE="${OPTARG}"
            ;;
        t)
            RECOVERY_TARGET_TIME="${OPTARG}"
            ;;
        h)
            ShowHelp
            exit 0
            ;;
        *)
            ShowHelp
            exit 1
            ;;
    esac
done

echo " " >> $LOG_FILE
echo `date` >> $LOG_FILE
echo "RESTORE START ... "  >> $LOG_FILE
LOG_INFO "Checking your input"
if [ ! -z "${SPECIFY_RESTORE_FILE}" ] && [ ! -z "${RECOVERY_TARGET_TIME}" ];then
    echo "ERROR" "Input Error. Show help: dbRestore -h"
fi
echo "INFO " "Input correct"
LOG_INFO "Checking active task ... "
echo "INFO " "Checking active task ... "
fn_checkIsAnotherProcess || error_exit "another gs_rman process is running"
echo "INFO " "No active task, restoring ... "

if [ ! -z "${SPECIFY_RESTORE_FILE}" ];then
    fn_untarRestoreFile
fi

if [ ! -z "${RECOVERY_TARGET_TIME}" ];then
    recoveryTime="'"${RECOVERY_TARGET_TIME}"'"
    fn_get_timelineID   
else
    fn_get_recoverTime_and_timelineID
fi

fn_restoreDB
if [ $? -eq 0 ]; then 
    LOG_INFO " Recovery successfully ! "
    echo "INFO " "Recovery successfully ! "
    
    LOG_INFO " This node starts as primary, check Gaussdb server, start HA by manual ! "
    echo "INFO " "This node need start as primary by manual, [CMD] gs_ctl start -M primary "
    echo "INFO " "Primary and Standby need start HA by manual, [CMD] haStartAll -a "
else
    die "Recovery failed ! "
fi 

if [ -d $RMAN_BACKUP_PATH ]; then
        rm -r $RMAN_BACKUP_PATH
fi
exit 0
