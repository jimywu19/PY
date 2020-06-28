#!/bin/bash
set +x
fpr1nt="$fpr1nt@$$"
__dig__=`md5sum $0|awk '{print $1}'` 
./etc/profile 2>/dev/null

. $HA_DIR/tools/func/func.sh || { echo "fail to load $HA_DIR/tools/func/func.sh"; exit 1; }
. $HA_DIR/tools/func/globalvar.sh || { echo "fail to load $HA_DIR/tools/func/globalvar.sh"; exit 1; }
. $HA_DIR/tools/gsDB/dbfunc.sh
DB_PWD=$(grep "^$GSDB_ROLE:" $BASE_DIR/data/config/DBKey.cfg | sed "s/^$GSDB_ROLE://")
echo $DB_PWD > key.so
dbPwd=$(sudo /usr/local/bin/pwswitch -D key.so -fp "$fpr1nt")
gs_ctl -P "$dbPwd" -L query 2>&1 | grep -vEw "$gs_notneedinfo"
unset dbPwd
unset DB_PWD
