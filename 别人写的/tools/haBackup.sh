#!/bin/bash

die()
{
    echo $*
    exit 1
}

cd "$(dirname $0)"
CUR_PATH=$(pwd)
. $CUR_PATH/func/func.sh

BAK_DIR="/opt/backup/files"

SRC_DIR="$HA_DIR/conf/"

BACKUP_LIST="
$SRC_DIR/runtime
$BASE_DIR/data/config/DBKey.cfg
$BASE_DIR/data/config/DBKey.xml
"

#make directory
mkdir -p $BAK_DIR$SRC_DIR

backupFile()
{
    local file="$1"
    [ -e "$file" ] || return 0
    
    local baseDir=$(dirname "$file")
    local backDir="$BAK_DIR$baseDir"
    
    # make directory
    mkdir -p "$backDir" || die "mkdir "$backDir" error."
    chown $GM_USER: "$backDir"

    cp -af $file "$backDir" 1>/dev/null 2>&1 || die "cp -af $file "$backDir" failed"
}

backupAllFile()
{
    local file=""
    for file in $BACKUP_LIST; do
        backupFile "$file"
    done
}

backupAllFile

cp -fr $HA_DIR/tools/haRestore.sh $BAK_DIR 1>/dev/null 2>&1 || die "cp haRestore.sh failed"

echo "successfull"
exit 0
