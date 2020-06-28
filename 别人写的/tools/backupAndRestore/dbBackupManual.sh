#/bin/bash
set +x

# log
. $HA_DIR/tools/func/func.sh || { echo "fail to load $HA_DIR/tools/func/func.sh"; exit 1; }
. $HA_DIR/tools/func/dblib.sh || { echo "fail to load $HA_DIR/tools/func/dblib.sh"; exit 1; }
. $HA_DIR/tools/gsDB/dbfunc.sh || { echo "fail to load $HA_DIR/tools/gsDB/dbfunc.sh"; exit 1; }
[ -d "$_HA_SH_LOG_DIR_" ] || mkdir -m 700 -p $_HA_SH_LOG_DIR_
chown $DB_USER: $_HA_SH_LOG_DIR_
LOG_FILE=$_HA_SH_LOG_DIR_/manualBackup.log

backupPath="$HA_DIR/tools/backupAndRestore"
BAK_CONF_PATH=$backupPath/backup.conf
BACKUP_RESTORE_FUN=$backupPath/backup_db_restore_fun.sh
BAK_COM_FUNC=$backupPath/com_fun.sh
COM_VAR_PATH=$backupPath/com_var.sh
. $BACKUP_RESTORE_FUN
. $BAK_COM_FUNC
. $COM_VAR_PATH

die()
{
    LOG_ERROR "$@"
    echo "ERROR:" "$@"
    exit 1
}

echo " " >> $LOG_FILE
echo `date` >> $LOG_FILE
echo "MANUAL BACKUP START ..." >> $LOG_FILE

manual="MT"

curUser=`/usr/bin/whoami | /usr/bin/awk '{print $1}'`
if [ "${curUser}" != "root" ]
then
    die "The user to excute the command must be root!"
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
    die "This is standby node, backup should execute in primary node ! "
fi

if [ $retRes -eq 2 ]; then
    die "Make sure this node of gsdb is primary, active and stable ! "
fi

LOG_INFO "Checking active task ... "
echo "INFO:" "Checking active task ... "
fn_checkIsAnotherProcess || die "Another gs_rman process is running"
echo "INFO:" "No active task "

LOG_INFO " Checking local disk space ... "
echo "INFO:" "Checking local disk space ... "
checkDir="$BACKUP_PATH"
spaceLowLimit=4000
fn_checkLocalDiskSpace $checkDir $spaceLowLimit || die "AvailSpace is less than $spaceLowLimit"
echo "INFO:" "Local disk space is enough "

LOG_INFO "Start backup GaussDB ... "

backup_mode="MT"
backup_strategy="f"
sh $backupPath/backup.sh $LOG_FILE $backup_mode $backup_strategy
retRes=$?

if [ -d $RMAN_BACKUP_PATH ]; then
    rm -r $RMAN_BACKUP_PATH
fi

if [ $retRes -eq 2 ]; then
    die "Backup successfully, upload backup file failed ! "
elif [ $retRes -eq 3 ]; then
    die "Backup and upload successfully, delete remote old backup file failed ! "
fi

if [ $retRes -ne 0 ]; then
    die "Execute backup failed"
fi

LOG_INFO " Manual backup GaussDB successfully ! "
LOG_INFO " Backup file is in $BACKUP_PATH_DB like xxx.tar.gz "
echo "INFO:" "Successfullly, backup file is in $BACKUP_PATH_DB like xxx.tar.gz "
echo "  " >> $LOG_FILE
