#!/bin/bash
set +x

source /etc/profile 2>/dev/null

backupPath="$HA_DIR/tools/backupAndRestore"
. $HA_DIR/tools/func/globalvar.sh || { echo "fail to load $HA_DIR/tools/func/globalvar.sh"; exit 1; }
# log
. $HA_DIR/tools/func/func.sh || { echo "fail to load $HA_DIR/tools/func/func.sh"; exit 1; }
. $HA_DIR/tools/func/dblib.sh || { echo "fail to load $HA_DIR/tools/func/dblib.sh"; exit 1; }
. $HA_DIR/tools/gsDB/dbfunc.sh || { echo "fail to load $HA_DIR/tools/gsDB/dbfunc.sh"; exit 1; }
[ -d "$_HA_SH_LOG_DIR_" ] || mkdir -m 700 -p $_HA_SH_LOG_DIR_
chown $DB_USER: $_HA_SH_LOG_DIR_
LOG_FILE=$_HA_SH_LOG_DIR_/gsDumpRestore.log

die()
{
    LOG_ERROR "$@"
    echo "ERROR" "$@"
    exit 1
}
logInfoAndEcho()
{
    LOG_INFO "$@"
    echo "INFO: " "$@"
}

fpr1nt="$fpr1nt@$$"
__dig__=`md5sum $0|awk '{print $1}'`

g_psql_passwd_file="$BASE_DIR/data/config/DBKey.cfg"
g_psql_passwd_e=""
g_psql_passwd_d=""

function getPasswd()
{
    if [ ! -f ${g_psql_passwd_file} ]
    then
        logInfoAndEcho "g_psql_passwd_file not exit"
        exit 1
    fi

    g_psql_passwd_e=$(grep "^$GSDB_ROLE:" $g_psql_passwd_file | sed "s/^$GSDB_ROLE://")
    g_psql_passwd_d=$(/usr/local/bin/pwswitch -d "$g_psql_passwd_e" -fp "$fpr1nt")
}
getPasswd

COM_VAR_PATH=$backupPath/com_var.sh
. $COM_VAR_PATH

SPECIFY_RESTORE_FILE=""

# check backup file in backup_path 
function checkInput()
{
    if [ $# -ne 1 ]; then
        LOG_ERROR "gsdumpRestore input error, [$@] "
        echo "ERROR" "input parameter wrong"
        echo "Usage:" 
        echo "gsdumpRestore xxx.tar.gz, (relative path)"
        echo "gsdumpRestore /opt/backup/DB/xxx.tar.gz, (absolute path)"
        exit 1
    fi

    if [ $# -eq 1 ]; then
        local exeScriptPath=`pwd`
        if [ ! -f $exeScriptPath/$1 ] && [ ! -f $1 ]
        then
            LOG_ERROR " Invalid backup file name, check the filename "
            echo "ERROR" "specified filename does not exsit"
            echo "Usage:" 
            echo "gsdumpRestore xxx.tar.gz, (relative path)"
            echo "gsdumpRestore /opt/backup/DB/xxx.tar.gz, (absolute path)"
            exit 1
        fi
    fi

    # just file name
    if [ -f $exeScriptPath/$1 ]; then
        SPECIFY_RESTORE_FILE=$exeScriptPath/$1
        LOG_INFO "restore file: $SPECIFY_RESTORE_FILE"
        return 0
    fi
    # full name, path/name
    if [ -f $1 ]; then
        SPECIFY_RESTORE_FILE=$1
        LOG_INFO "restore file: $SPECIFY_RESTORE_FILE"
        return 0
    fi
}

DB_USER_CMD="su - $DB_USER -c"

function checkCurrentUser()
{
    local curUser=`/usr/bin/whoami | /usr/bin/awk '{print $1}'`
    if [ "${curUser}" != "root" ]
    then
        die "The user to excute gsdumpRestore should be root"
    fi
}

function untarAndGetRestoreFileName()
{
    gsDumpBackupGZFilePATH="${BACKUP_PATH}/tmpForRestore"
    if [ -d $gsDumpBackupGZFilePATH ]; then
        rm -rf $gsDumpBackupGZFilePATH
    else
        ${DB_USER_CMD} "mkdir -p $gsDumpBackupGZFilePATH" >> $LOG_FILE 2>&1
        if [ $? -ne 0 ]; then
            die "create $gsDumpBackupGZFilePATH for restore failed"   
        fi
        chown $DB_USER: $gsDumpBackupGZFilePATH
    fi
    logInfoAndEcho "start untar $SPECIFY_RESTORE_FILE to temp path: $gsDumpBackupGZFilePATH"
    tar zxvf $SPECIFY_RESTORE_FILE -C $gsDumpBackupGZFilePATH >> $LOG_FILE 2>&1
    local untarRetValue=$?
    if [ $untarRetValue -ne 0 ]; then
        finalClean
        die "untar $SPECIFY_RESTORE_FILE to temp path: $gsDumpBackupGZFilePATH failed !"
    fi
    logInfoAndEcho "untar $SPECIFY_RESTORE_FILE to temp path: $gsDumpBackupGZFilePATH successfully"

    local backupFileString=`ls $gsDumpBackupGZFilePATH`
    backupFileArrary=($backupFileString)
}

function getDefaultDBName()
{
    DEFAULT_DB_NAME=$(${DB_USER_CMD} 'echo $PGDATABASE')
    if [ -z $DEFAULT_DB_NAME ]; then
        LOG_ERROR "/home/$DB_USER/.bashrc, DEFAULT_DB_NAME(PGDATABASE) is null"
        exit 1
    fi
    logInfoAndEcho "PGDATABASE is $DEFAULT_DB_NAME, get from /home/$DB_USER/.bashrc"
}

function getAnotherDBName()
{
    local backupConfFile=$backupPath/backup.conf 
    local anotherDBTag="ANOTHER_DB"
    ANOTHER_DB_NAME=$(grep "^$anotherDBTag=" $backupConfFile | sed "s/^$anotherDBTag=//")
    if [ -z $ANOTHER_DB_NAME ]; then
        LOG_ERROR "$backupConfFile, ANOTHER_DB_NAME is null"
        exit 1
    fi
    logInfoAndEcho "ANOTHER_DB_NAME is $ANOTHER_DB_NAME, get from $backupConfFile"
}

# $1: restore file name; $2: restore dbName
function restoreByFile()
{
    local restoreFileName=$1
    if [ ! -f $gsDumpBackupGZFilePATH/$restoreFileName ]; then
        finalClean
        exit 1
    fi
    chown $DB_USER: $gsDumpBackupGZFilePATH/$restoreFileName

    # judge if restore file is xxx.gz
    local fileTypeRetValue=`echo $restoreFileName | egrep '.gz$'`
    if [[ $fileTypeRetValue = "" ]]; then
        LOG_ERROR " func[ restoreByFile ],restore file is not xxx.gz file, exit ! "
        finalClean
        exit 1
    fi

    # judge if restore file is the specify db file
    local dbName=$2
    local fileDBRetValue=`echo $restoreFileName | grep $dbName`
    if [[ $fileDBRetValue = "" ]]; then
        LOG_ERROR " func[ restoreByFile ],$restoreFileName file is not the specify $dbName file, exit ! "
        finalClean
        exit 1
    fi

    # gs_dump restore
    logInfoAndEcho "gs_dump restore $dbName by $restoreFileName, please waiting... "
    LOG_INFO "gs_dump restore $dbName by $restoreFileName, please waiting... "
    ${DB_USER_CMD} "gunzip -c $gsDumpBackupGZFilePATH/$restoreFileName | gsql $dbName -W $g_psql_passwd_d" >> $LOG_FILE 2>&1
    local gzFileRestoreRetValue=$?
    if [ $gzFileRestoreRetValue -ne 0 ]; then
        finalClean
        die "DB-$dbName restore by $restoreFileName failed !"
    fi
}

function restoreDatabase()
{
    getDefaultDBName
    databaseCount=${#backupFileArrary[@]}
    logInfoAndEcho "restore datebase count is $databaseCount"
    if [ $databaseCount -eq 1 ]; then
        restoreByFile ${backupFileArrary[0]} $DEFAULT_DB_NAME
    elif [ $databaseCount -eq 2 ]; then
        getAnotherDBName
        local whichDBRetValue=`echo ${backupFileArrary[0]} | grep $ANOTHER_DB_NAME`
        if [[ $whichDBRetValue = "" ]]; then
             restoreByFile ${backupFileArrary[0]} $DEFAULT_DB_NAME
             restoreByFile ${backupFileArrary[1]} $ANOTHER_DB_NAME
        else
             restoreByFile ${backupFileArrary[1]} $DEFAULT_DB_NAME
             restoreByFile ${backupFileArrary[0]} $ANOTHER_DB_NAME
        fi
    else
        finalClean
        die "untar gs_dump backup file, get the wrong number database (not 1 or 2) !"
    fi
}

function finalClean()
{
    if [ -d $gsDumpBackupGZFilePATH ]; then
        rm -rf $gsDumpBackupGZFilePATH
    fi
}
 
echo " " >> $LOG_FILE
echo `date` >> $LOG_FILE
echo "GS_DUMP RESTORE START ... "  >> $LOG_FILE
logInfoAndEcho "gs_dump restore start ... "
checkCurrentUser
checkInput $@
untarAndGetRestoreFileName
restoreDatabase
finalClean
logInfoAndEcho "gs_dump restore db successfully ! "
echo "*- END -*" >> $LOG_FILE
