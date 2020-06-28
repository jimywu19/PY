#!/bin/bash
set +x

source /etc/profile 2>/dev/null

. $HA_DIR/tools/func/globalvar.sh || { echo "fail to load $HA_DIR/tools/func/globalvar.sh"; exit 1; }
. $HA_DIR/tools/func/func.sh || { echo "fail to load $HA_DIR/tools/func/func.sh"; exit 1; }
. $HA_DIR/tools/func/dblib.sh || { echo "fail to load $HA_DIR/tools/func/dblib.sh"; exit 1; }
. $HA_DIR/tools/gsDB/dbfunc.sh || { echo "fail to load $HA_DIR/tools/gsDB/dbfunc.sh"; exit 1; }

mkdir -p $_HA_SH_LOG_DIR_
chown $DB_USER: $_HA_SH_LOG_DIR_
LOG_FILE=$_HA_SH_LOG_DIR_/downloadUDSFile.log

fpr1nt="$fpr1nt@$$"
__dig__=`md5sum $0|awk '{print $1}'`

g_psql_passwd_file="$BASE_DIR/data/config/DBKey.cfg"
g_psql_passwd_e=""
g_psql_passwd_d=""

function getPasswd()
{
    if [ ! -f ${g_psql_passwd_file} ]
    then
        echo "g_psql_passwd_file not exit"
        exit 1
    fi

    g_psql_passwd_e=$(grep "^$GSDB_ROLE:" $g_psql_passwd_file | sed "s/^$GSDB_ROLE://")
    g_psql_passwd_d=$(/usr/local/bin/pwswitch -d "$g_psql_passwd_e" -fp "$fpr1nt")
}
getPasswd

backupPath="$HA_DIR/tools/backupAndRestore"

COM_VAR_PATH=$backupPath/com_var.sh
. $COM_VAR_PATH

BACKUP_TMP=$RMAN_BACKUP_PATH
CONST_DOWNLOAD_PATH="$BACKUP_PATH/downloadPath"

if [ ! -d ${CONST_DOWNLOAD_PATH} ]
then
    mkdir -p ${CONST_DOWNLOAD_PATH}
    chmod 640 ${CONST_DOWNLOAD_PATH}
    chown $DB_USER: $BACKUP_PATH
    chown $DB_USER: $CONST_DOWNLOAD_PATH
fi

SPECIFY_DOWNLOAD_FILE=""

function assignDownloadFileName()
{
    if [ $# -ne 1 ]; then
        LOG_ERROR "downloadUDSFile input file name error, [$@] "
        echo "input parameter wrong"
        echo "Usage:" 
        echo "downloadUDSFile xxx.tar.gz"
        echo "Get upload file list on UDS server: cat $backupPath/backuplist"
        exit 1
    fi
    SPECIFY_DOWNLOAD_FILE=$1
}

function logErrorAndEcho()
{
    LOG_ERROR "$@"
    error_string=$@
    return 1
}

function fu_upload_UDS()
{
   #UDS info
   Upload_cfg=$backupPath/Upload_Server.cfg
   endpoint_name="endpoint"
   ak_name="ak"
   sk_name1="sk1"
   sk_name2="sk2"
   bucket_name="bucket"
   endpoint_value=$(grep "^$endpoint_name:" $Upload_cfg | sed "s/^$endpoint_name://")
   ak_value_e=$(grep "^$ak_name:" $Upload_cfg | sed "s/^$ak_name://")
   sk_value_e1=$(grep "^$sk_name1:" $Upload_cfg | sed "s/^$sk_name1://")
   sk_value_e2=$(grep "^$sk_name2:" $Upload_cfg | sed "s/^$sk_name2://")
   bucket_value=$(grep "^$bucket_name:" $Upload_cfg | sed "s/^$bucket_name://") 

   ak_value_d=""
   sk_value_d1=""
   sk_value_d2=""
   
   ak_value_d=$(pwswitch -d "$ak_value_e" -fp "$fpr1nt")
   sk_value_d1=$(pwswitch -d "$sk_value_e1" -fp "$fpr1nt")
   sk_value_d2=$(pwswitch -d "$sk_value_e2" -fp "$fpr1nt")
   sk_value_d=${sk_value_d1}${sk_value_d2}

   action=$1
   uploadFilename=$2
   info=`cd $CONST_DOWNLOAD_PATH && java -jar $backupPath/udstools.jar $endpoint_value $ak_value_d $sk_value_d $action $bucket_value $uploadFilename`
   LOG_INFO "UDS action=$action, uploadFilename=$uploadFilename"
   LOG_INFO "$LOG_FILE" "$info"
   if [ -d $CONST_DOWNLOAD_PATH/logs ]; then
       rm -rf $CONST_DOWNLOAD_PATH/logs
   fi
    
   failureCode1="InArrearOrInsufficientBalance"
   failureCode2="InvalidAccessKeyId"
   failureCode3="timed out"
   failureCode4="SignatureDoesNotMatch"
   failureCode5="NoSuchBucket"
   failureCode6="File not exist"
   failureCode7="The specified key does not exist"
   successCode="responseCode: 200"
   case $info in
       *$successCode*)
           LOG_INFO "$action download backup file to local successfully";
           return 0
       ;;
       *$failureCode1*)
           logErrorAndEcho "$action failure! InArrearOrInsufficientBalance";
       ;;
       *$failureCode2*)
           logErrorAndEcho "$action failure! InvalidAccesskey";
       ;;
       *$failureCode3*)
           logErrorAndEcho "$action failed! time out!";
       ;;
       *$failureCode4*)
           logErrorAndEcho "$action failed! SignatureDoesNotMatch";
       ;;
       *$failureCode5*)
           logErrorAndEcho "$action failed! The specified bucket does not exist";
       ;;
       *$failureCode6*)
           logErrorAndEcho "$action failed! File not exist!";
       ;;
       *$failureCode7*)
           echo "$action failed! Incorrected target download file name !"
           logErrorAndEcho "$action failed! Incorrected target download file name !";
       ;;
       *)
           logErrorAndEcho "$action failure";
       ;;
   esac
   return 1
}

function fn_download_uds_file()
{
    uds_download_action="download"
    fu_upload_UDS $uds_download_action $SPECIFY_DOWNLOAD_FILE >> "${LOG_FILE}" 2>&1
    downloadRes=$?
    if [ $downloadRes -eq 0 ]; then
        chmod 600 $CONST_DOWNLOAD_PATH -R
        chown $DB_USER: $CONST_DOWNLOAD_PATH -R
    fi
}

echo "Please wait, downloading..."
assignDownloadFileName $@
fn_download_uds_file
if [ $downloadRes -eq 0 ]; then
    LOG_INFO "download $SPECIFY_DOWNLOAD_FILE from UDS to $CONST_DOWNLOAD_PATH"
    echo "Download $SPECIFY_DOWNLOAD_FILE from UDS to $CONST_DOWNLOAD_PATH successfully! "
else
    echo $error_string
fi
