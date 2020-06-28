#!/bin/bash
set +x

. $HA_DIR/tools/func/globalvar.sh || { echo "fail to load $HA_DIR/tools/func/globalvar.sh"; exit 1; }
DB_ARCHIVE_LOG_PATH="$BASE_DIR/dbprogram/archive"
DB_GAUSSDATA_PATH="$BASE_DIR/data/db"
DB_SERVER_LOG_PATH="$BASE_DIR/data/db/pg_log/"

backupPath="$HA_DIR/tools/backupAndRestore"
. ${backupPath}/com_var.sh

if [ ! -d ${RMAN_BACKUP_PATH} ]
then
    mkdir -p ${RMAN_BACKUP_PATH}
    chmod 700 ${BACKUP_PATH}
    chown $DB_USER: $BACKUP_PATH
    chmod 750 ${RMAN_BACKUP_PATH}
    chown $DB_USER: $RMAN_BACKUP_PATH
fi

# backup
do_init() {
    if [ -d ${RMAN_BACKUP_PATH} ]
    then
        rm -rf ${RMAN_BACKUP_PATH}
        mkdir -p ${RMAN_BACKUP_PATH}
        chmod 700 ${BACKUP_PATH}
        chown $DB_USER: $BACKUP_PATH
        chmod 750 ${RMAN_BACKUP_PATH}
        chown $DB_USER: $RMAN_BACKUP_PATH
    fi
    su - $DB_USER -c "gs_rman -B $RMAN_BACKUP_PATH -A $DB_ARCHIVE_LOG_PATH -D $DB_GAUSSDATA_PATH -S $DB_SERVER_LOG_PATH init"
}

do_backup() {
    # $2 == f: full | i: incremental | c: cumulative | a: archive
   echo $1 | su - $DB_USER -c "gs_rman -B $RMAN_BACKUP_PATH -U $GSDB_ROLE -b $2 backup --print-progress"
}

do_validate() {
    su - $DB_USER -c "gs_rman -B $RMAN_BACKUP_PATH validate"
}

do_show() {
    su - $DB_USER -c "gs_rman -B $RMAN_BACKUP_PATH show $@"
}

do_restore() {
    restore_command=gs_rman -B $RMAN_BACKUP_PATH restore $@ --print-progress
    su - $DB_USER -c "$restore_command"
}

do_delete()
{
    su - $DB_USER -c "gs_rman -B $RMAN_BACKUP_PATH delete $@"
}
