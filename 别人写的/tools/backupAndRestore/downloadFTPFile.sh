#!/bin/bash
set +x

source /etc/profile 2>/dev/null

. $HA_DIR/tools/func/func.sh || { echo "fail to load $HA_DIR/tools/func/func.sh"; exit 1; }
. $HA_DIR/tools/func/dblib.sh || { echo "fail to load $HA_DIR/tools/func/dblib.sh"; exit 1; }
. $HA_DIR/tools/gsDB/dbfunc.sh || { echo "fail to load $HA_DIR/tools/gsDB/dbfunc.sh"; exit 1; }

mkdir -p $_HA_SH_LOG_DIR_
chown $DB_USER: $_HA_SH_LOG_DIR_
LOG_FILE=$_HA_SH_LOG_DIR_/downloadFTPFile.log

fpr1nt="$fpr1nt@$$"
__dig__=`md5sum $0|awk '{print $1}'`

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
        LOG_ERROR "downloadFTPFile input file name error, [$@] "
        echo "input parameter wrong"
        echo "Usage:" 
        echo "downloadFTPFile xxx.tar.gz"
        echo "Get upload file list on FTP server: cat $backupPath/backuplist"
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

function fn_download_FTP()
{
   #FTP info
   Upload_cfg=$backupPath/Upload_Server.cfg
   sftp_ip_name="FTP_SERVER_IP"
   sftp_port_name="FTP_SERVER_PORT"
   sftp_user_name="FTP_SERVER_USER"
   sftp_passwd_name="FTP_SERVER_PASSWD"
   remote_path_name="FTP_SERVER_FILEPATH"
   sftp_ip_value=$(grep "^$sftp_ip_name:" $Upload_cfg | sed "s/^$sftp_ip_name://")
   sftp_port_value=$(grep "^$sftp_port_name:" $Upload_cfg | sed "s/^$sftp_port_name://")
   sftp_user_value=$(grep "^$sftp_user_name:" $Upload_cfg | sed "s/^$sftp_user_name://")
   sftp_passwd_value_e=$(grep "^$sftp_passwd_name:" $Upload_cfg | sed "s/^$sftp_passwd_name://")
   sftp_passwd_value_d=$(pwswitch -d "$sftp_passwd_value_e" -fp "$fpr1nt")
   sftp_remote_filepath=$(grep "^$remote_path_name:" $Upload_cfg | sed "s/^$remote_path_name://")

   if [ -z $sftp_port_value ]; then
       sftp_port_value=21
   fi
   action="download"
   filename=$SPECIFY_DOWNLOAD_FILE
   LOG_INFO "download from FTP, remote uploadFilePath=$sftp_remote_filepath, local downloadFilename=$CONST_DOWNLOAD_PATH/$filename"
   echo "INFO " "download from FTP, remote uploadFilePath=$sftp_remote_filepath, local downloadFilename=$CONST_DOWNLOAD_PATH/$filename"
   sh $backupPath/sftpTools.sh $sftp_ip_value $sftp_port_value $sftp_user_value $sftp_passwd_value_d $action $sftp_remote_filepath $filename $CONST_DOWNLOAD_PATH >> $LOG_FILE 2>&1
   return $? 
}

assignDownloadFileName $@
fn_download_FTP
echo "INFO " "Please wait, downloading file from FTP ..."
if [ $? -eq 0 ]; then
    LOG_INFO "Download $SPECIFY_DOWNLOAD_FILE from FTP to $CONST_DOWNLOAD_PATH successfully!"
    echo "INFO " "Download successfully, check $CONST_DOWNLOAD_PATH/$SPECIFY_DOWNLOAD_FILE"
else
    echo "ERROR" "Download failed, check $LOG_FILE"
fi
