#!/bin/bash

. /etc/profile 2>/dev/null
. $HA_DIR/tools/func/func.sh

die()
{
    echo $*
    exit 1
}

BAK_DIR="/opt/backup/files"
SRC_DIR="$HA_DIR/conf/"

HA_TOOLS_DIR=$HA_DIR/tools
HA_CONF_DIR=$HA_DIR/conf
    
BACKUP_LIST="
$BASE_DIR/data/config/DBKey.cfg
$BASE_DIR/data/config/DBKey.xml
"

BACKUP_CONF_FILE=$BAK_DIR$SRC_DIR/runtime/gmn.cfg
RESTORE_CONF_FILE=$SRC_DIR/runtime/gmn.cfg.restore

# make directory
mkdir -p $SRC_DIR || die "mkdir failed"

cp -af "$BACKUP_CONF_FILE" $RESTORE_CONF_FILE || die "cp -af $BACKUP_CONF_FILE $RESTORE_CONF_FILE failed"

restoreFile()
{
    [ -n "$file" ] || return 0
    
    local backFile="$BAK_DIR$file"
    
    [ -e "$backFile" ] || return 0

    cp -af "$backFile" "$file" 1>/dev/null 2>&1 || die "cp -af "$backFile" "$file" failed"
}

restoreAllFile()
{
    local file=""
    for file in $BACKUP_LIST; do
        restoreFile "$file"
    done
}

restoreAllFile

echo "successfull"

exit 0
