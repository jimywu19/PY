#/bin/bash
set +x

. /etc/profile 2>/dev/null

# log
. $HA_DIR/tools/func/func.sh || { echo "fail to load $HA_DIR/tools/func/func.sh"; exit 2; }
. $HA_DIR/tools/func/dblib.sh || { echo "fail to load $HA_DIR/tools/func/dblib.sh"; exit 2; }
. $HA_DIR/tools/gsDB/dbfunc.sh || { echo "fail to load $HA_DIR/tools/gsDB/dbfunc.sh"; exit 2; }
[ -d "$_HA_SH_LOG_DIR_" ] || mkdir -m 700 -p $_HA_SH_LOG_DIR_
chown $DB_USER: $_HA_SH_LOG_DIR_
LOG_FILE=$_HA_SH_LOG_DIR_/autoBackup.log

backupPath="$HA_DIR/tools/backupAndRestore"
BAK_CONF_PATH=$backupPath/backup.conf
BACKUP_RESTORE_FUN=$backupPath/backup_db_restore_fun.sh
BAK_COM_FUNC=$backupPath/com_fun.sh
COM_VAR_PATH=$backupPath/com_var.sh
. $BACKUP_RESTORE_FUN
. $BAK_COM_FUNC
. $COM_VAR_PATH

ALARM_USER="zabbix"
ALARM_DATA_DIR=/home/$ALARM_USER/dbAlarmData
alarmFile="backup_zabbix_alarm"

export db_backup_alarm_tag="b1(backup fail)"

sendResourceAlarm()
{
    local res="$1"
    local status="$2"

    [ -n "$res" ] || return 1

    zabbix_home=/home/$ALARM_USER
    if [ ! -d $zabbix_home ]; then
        mkdir $zabbix_home && chown $ALARM_USER: $zabbix_home >> "${LOG_FILE}" 2>&1
    fi

    if [ ! -d $ALARM_DATA_DIR ]; then
        mkdir $ALARM_DATA_DIR && chown $ALARM_USER: $ALARM_DATA_DIR >> "${LOG_FILE}" 2>&1
    fi

    local resFile="$ALARM_DATA_DIR/$res"
    echo $status > $resFile
    chown $ALARM_USER: $resFile >>/dev/null 2>&1
}

die()
{
    LOG_ERROR "$@"
    sendResourceAlarm "$alarmFile" "${db_backup_alarm_tag}${db_upload_alarm_tag}"
    echo "$@"
    exit 2
}
LOG_ERROR_ECHO()
{
    LOG_ERROR "$@"
    echo "$@"
    exit 2
}

if [ $# -gt 1 ]
then
    LOG_ERROR_ECHO "Parameter Error: The num of input is not greater than 1"
fi

backup_input=$1
backup_strategy=""
if [ -z $backup_input ]; then
    backup_strategy=f
else
    parasStirng="f full i incremental c cumulative a archive d"
    echo "$parasStirng" | grep -wqF $backup_input
    retRes=$?
    if [ $retRes -ne 0 ]; then
        LOG_ERROR_ECHO "Parameter Error: Input parameter $backup_input is invalid"
    else
        backup_strategy=$backup_input
    fi
fi

if [ $backup_strategy = "f" -o $backup_strategy = "full" ]; then
    echo "INFO: Full Backuping"
else
    echo "INFO: Incremental Backuping"
fi

curUser=`/usr/bin/whoami | /usr/bin/awk '{print $1}'`
if [ "${curUser}" != "root" ]
then
    LOG_ERROR_ECHO "Excuter Error: The user must be root to excute"
fi

BACKUP_PATH_DB="$BACKUP_PATH/DB"
if [ ! -d ${BACKUP_PATH_DB} ]
then
    mkdir -p ${BACKUP_PATH_DB}
    chmod 700 ${BACKUP_PATH}
    chmod 700 ${BACKUP_PATH_DB}
    chown $DB_USER: $BACKUP_PATH
    chown $DB_USER: $BACKUP_PATH_DB
fi

is_primary
retRes=$?
if [ $retRes -eq 1 ]; then
    sendResourceAlarm "$alarmFile" "standby no need backup"
    LOG_ERROR_ECHO "Not Active Error: This is standby node, backup should execute in primary node, exit "
fi

if [ $retRes -eq 2 ]; then
    die "Not Active Error: Make sure this host is active and stable, exit "
fi

LOG_INFO " Checking active task ... "
fn_checkIsAnotherProcess || LOG_ERROR_ECHO "IsRunning Error: Backup process is running, please try again later."

checkDir="$BACKUP_PATH"
spaceLowLimit=4000
fn_checkLocalDiskSpace $checkDir $spaceLowLimit || LOG_ERROR_ECHO "System Error: AvailSpace is less than $spaceLowLimit"

LOG_INFO " Auto backuping GaussDB ... "

backup_mode="AT"
sh $backupPath/backup.sh $LOG_FILE $backup_mode $backup_strategy; retRes=$? 

LOG_INFO " backup_mode: $backup_mode , backup_strategy: $backup_strategy"

if [ $retRes -eq 2 ]; then
    LOG_ERROR_ECHO "Result: Backup successfully, Upload backup file failed."
elif [ $retRes -eq 3 ]; then
    LOG_ERROR_ECHO "Result: Backup and Upload successfully, Delete remote old backup file failed."
fi

if [ $retRes -ne 0 ]; then
    if [ -d $RMAN_BACKUP_PATH ]; then
        rm -r $RMAN_BACKUP_PATH
    fi
    die "Result: Backup failed, no need Upload."
fi

if [ $backup_strategy = "f" -o $backup_strategy = "full" ]; then
    echo "INFO:" "Full backup and Upload Successfully."
else
    echo "INFO:" "Incremental backup and Upload Successfully."
fi

LOG_INFO " Auto Backup and Upload Successfully."
LOG_INFO " Backup file is in $BACKUP_PATH_DB like xxx.tar.gz " 

echo "  " >> $LOG_FILE
