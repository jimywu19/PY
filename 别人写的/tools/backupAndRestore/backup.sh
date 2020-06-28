#!/bin/bash
set +x
. /etc/profile 2>/dev/null

backupPath="$HA_DIR/tools/backupAndRestore"
. $backupPath/backup_db_restore_fun.sh
. $backupPath/log.sh

COM_VAR_PATH=$backupPath/com_var.sh
. $COM_VAR_PATH

fpr1nt="$fpr1nt@$$"
__dig__=`md5sum $0|awk '{print $1}'`

. $HA_DIR/tools/func/globalvar.sh || { echo "fail to load $HA_DIR/tools/func/globalvar.sh"; exit 1; }

g_psql_passwd_file="$BASE_DIR/data/config/DBKey.cfg"
g_psql_passwd_e=""
g_psql_passwd_d=""

ALARM_USER="zabbix"
ALARM_DATA_DIR=/home/$ALARM_USER/dbAlarmData
alarmFile="backup_zabbix_alarm"

db_backup_alarm_tag="b1(backup fail)"
db_upload_alarm_tag="u1(upload fail)"

die()
{
    LOG_ERROR "$BACKUP_LOG_FILE" "$@"
    sendResourceAlarm "$alarmFile" "${db_backup_alarm_tag}${db_upload_alarm_tag}"
    LOG_INFO "$BACKUP_LOG_FILE" "${db_backup_alarm_tag}${db_upload_alarm_tag}"
    echo "ERROR" "$@"
    exit 1
}
upload_die()
{
    LOG_ERROR "$BACKUP_LOG_FILE" "$@"
    sendResourceAlarm "$alarmFile" "${db_backup_alarm_tag}${db_upload_alarm_tag}"
    echo "ERROR" "$@"
    exit 2
}

if [ $# -ne 3 ]
then
    echo "ERROR" "The num of input parameter is not equal to 3" 
    exit 1
fi

BACKUP_LOG_FILE=$1
BACKUP_MODE=$2
backup_strategy=$3

function isNull()
{
    if [ -z "$1" ]
    then
        echo "Input parameter $1 is NULL."
        exit 1
    fi
}

isNull ${BACKUP_LOG_FILE}
isNull ${BACKUP_MODE}
isNull ${backup_strategy}

sendResourceAlarm()
{
    local res="$1"
    local status="$2"

    [ -n "$res" ] || return 1
    zabbix_home=/home/$ALARM_USER
    if [ ! -d $zabbix_home ]; then
        mkdir $zabbix_home && chown $ALARM_USER: $zabbix_home >> "${BACKUP_LOG_FILE}" 2>&1
    fi

    if [ ! -d $ALARM_DATA_DIR ]; then
        mkdir $ALARM_DATA_DIR && chown $ALARM_USER: $ALARM_DATA_DIR >> "${BACKUP_LOG_FILE}" 2>&1
    fi

    local resFile="$ALARM_DATA_DIR/$res"
    echo $status > $resFile
    chown $ALARM_USER: $resFile >>/dev/null 2>&1
}

function getPasswd()
{
    if [ ! -f ${g_psql_passwd_file} ]
    then
        echo "g_psql_passwd_file not exit"
        exit 1
    fi

	if [ -z $GSDB_ROLE ]; then
	    GSDB_ROLE=$DB_USER
	fi
    g_psql_passwd_e=$(grep "^$GSDB_ROLE:" $g_psql_passwd_file | sed "s/^$GSDB_ROLE://")
    g_psql_passwd_d=$(/usr/local/bin/pwswitch -d "$g_psql_passwd_e" -fp "$fpr1nt")
    if [ -z $g_psql_passwd_d ]; then
        die "Decrypt failed" 
    fi
}
getPasswd

BAK_CONF_PATH=$backupPath/backup.conf


BACKUP_PATH_DB="$BACKUP_PATH/DB"
temp_gs_dump_path="$BACKUP_PATH/tempPath"
if [ ! -d ${BACKUP_PATH_DB} ]
then
    mkdir -p ${BACKUP_PATH_DB}
    mkdir -p ${temp_gs_dump_path}
    chmod 700 ${BACKUP_PATH}
    chmod 700 ${BACKUP_PATH_DB}
    chmod 750 ${temp_gs_dump_path}
    chown $DB_USER: $BACKUP_PATH
    chown $DB_USER: $BACKUP_PATH_DB
    chown $DB_USER: $temp_gs_dump_path
fi

UPLOAD_FTP_MODE=$(cat "${BAK_CONF_PATH}" 2>>"${BACKUP_LOG_FILE}" | grep "UPLOAD_FTP_MODE" 2>>"${BACKUP_LOG_FILE}" | awk -F "=" '{print $2}' 2>> "${BACKUP_LOG_FILE}")
modeResRest=$?
if [ -z $UPLOAD_FTP_MODE ]; then
    UPLOAD_FTP_MODE=0
fi
if [ $modeResRest -eq 0 ]
then
    LOG_INFO "$BACKUP_LOG_FILE" "UPLOAD_FTP_MODE=${UPLOAD_FTP_MODE}"
else
    die " Get UPLOAD_FTP_MODE failed ! "
fi

db_backup_tar_name=""

function fn_sn_num_update()
{
    SN_TMP=$(cat "${BAK_CONF_PATH}" 2>>"${BACKUP_LOG_FILE}" | grep "SN_BACKUP_NUM" 2>>"${BACKUP_LOG_FILE}" | awk -F "=" '{print $2}' 2>> "${BACKUP_LOG_FILE}")
    echo "${SN_TMP}" | grep -Eq "^([0-9]{3})$"
    if [ $? -eq 0 ]
    then
        sn_num=${SN_TMP}
        LOG_INFO "$BACKUP_LOG_FILE" "sn=${SN_TMP}"
    else
        die "sequence num need xxx digital, ${SN_TMP} is illegal"
    fi

    oldSN_Num=$sn_num
    if [ $oldSN_Num -eq 999 ]; then
        newSN_Num=001
    else
        oldSN_Num=`expr $oldSN_Num + 1`
        newSN_Num=$(printf "%03d" $oldSN_Num)
    fi
    sed -i "s/SN_BACKUP_NUM=.*/SN_BACKUP_NUM=$newSN_Num/" "$BAK_CONF_PATH"
    sn=$newSN_Num
}

function fn_rmbackup_file_num()
{
    if [ ! -d $RMAN_BACKUP_PATH ]; then 
        LOG_INFO "$BACKUP_LOG_FILE" "$RMAN_BACKUP_PATH is not exits"
        return 0
    fi
    date_path=`date "+%Y%m%d"`
    rmbackup_file_path=${RMAN_BACKUP_PATH}/${date_path}
    if [ ! -d $rmbackup_file_path ]; then
        LOG_INFO "$BACKUP_LOG_FILE" "today full backup file $rmbackup_file_path is not exits"
        return 0
    fi
    
    if [ -d $rmbackup_file_path ]; then
        current_rmbackup_num=$(ls $rmbackup_file_path | grep -E "^([0-9]{6}_[0-9]{4})$" | wc -l | awk '{print $1}')
        LOG_INFO "$BACKUP_LOG_FILE" "current_rmbackup_num=$current_rmbackup_num"
        return $current_rmbackup_num
    fi 
}

theLatestName=""
function fn_incremental_get_name()
{
    fn_rmbackup_file_num
    rmbackupFileNum=$?
    if [ $rmbackupFileNum -eq 0 ]; then
         die "Backup file num is 0,Incremental backup failed!"
    fi

    date_path=`date "+%Y%m%d"`
    theLatestName=$(ls -lcr ${RMAN_BACKUP_PATH}/${date_path} | awk '{print $9}' | grep -E "^([0-9]{6}_[0-9]{4})$" | head -1)
}

function fn_incremental_process()
{
    fn_rmbackup_file_num
    rmbackupFileNum=$?
    if [ $rmbackupFileNum -eq 0 ]; then
         die "Backup file num is 0,Incremental backup failed!"
    fi

    date_path=`date "+%Y%m%d"`

    rmbackup_file_database=$RMAN_BACKUP_PATH/$date_path/$theLatestName/file_database.txt
    ECHOANDLOG_INFO "$BACKUP_LOG_FILE" "rmbackup_file_database=$rmbackup_file_database"

    if [ -f $rmbackup_file_database ]; then
        sed -i "/^server./d" $rmbackup_file_database
    fi
}

function fn_backfile_tarAnd_rename()
{
    cd $RMAN_BACKUP_PATH
    date_string=$(date -d today +%Y%m%d)
    db_full_tar_name=${patern_string}${date_string}${backup_cycle}${sn}
    db_backup_tar_name=$db_full_tar_name
    tar -zcf ${BACKUP_PATH_DB}/${db_backup_tar_name}.tar.gz -C ${BACKUP_PATH} rmanBackup >/dev/null 2>&1; ret=$?
    if [ $ret -eq 0 ]; then
        chmod 600 ${BACKUP_PATH_DB}/${db_backup_tar_name}.tar.gz
        chown $DB_USER: ${BACKUP_PATH_DB}/${db_backup_tar_name}.tar.gz
        LOG_INFO "$BACKUP_LOG_FILE" "Tar rmanBackup dir successfully"
    else
        LOG_ERROR "$BACKUP_LOG_FILE" "Failed: tar -zcf ${BACKUP_PATH_DB}/${db_backup_tar_name}.tar.gz -C $BACKUP_PATH rmanBackup"
        echo "Error: tar GaussDB package Failed"
    fi
    return $ret
}

# path backup_mode max_num
function fn_delOld_file() 
{
    if [ -d $BACKUP_PATH_DB ]; then
        current_backup_num=$(ls ${BACKUP_PATH_DB} | grep -E "^($reg_string)$" | wc -l | awk '{print $1}')
        LOG_INFO "$BACKUP_LOG_FILE" "current backup number: $current_backup_num,  backup max number: $BACKUP_MAX_NUMBER"
        while [[ $current_backup_num -gt ${BACKUP_MAX_NUMBER} ]]
        do
            LOG_INFO "$BACKUP_LOG_FILE" "The store number hit the max number, remove oldest file."
            theOldestFileName=$(ls -lt $BACKUP_PATH_DB | awk '{print $9}' | grep -E "^($reg_string)$" | tail -1)
            if [ -n $theOldestFileName ]; then
                rm -f $BACKUP_PATH_DB/$theOldestFileName
            fi
            LOG_INFO "$BACKUP_LOG_FILE" "Remove oldest file $BACKUP_PATH_DB/$theOldestFileName"
            current_backup_num=$(ls ${BACKUP_PATH_DB} | grep -E "^($reg_string)$" | wc -l | awk '{print $1}')
            LOG_INFO "$BACKUP_LOG_FILE" "Current backup number: $current_backup_num"
        done
    fi
}

function fn_upload_UDS()
{
    # check java
    command -v java >/dev/null 2>&1 || upload_die "Upload UDS requires java but it's not installed. Aborting." 
      
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
    
    if [ -z $ak_value_d ] || [ -z $sk_value_d ]; then
        upload_die "Decrypt failed"
    fi

    action=$1
    uploadFilename=$2
    
    info=`cd $BACKUP_PATH_DB && java -jar $backupPath/udstools.jar $endpoint_value $ak_value_d $sk_value_d $action $bucket_value $uploadFilename`
    
    LOG_INFO "$BACKUP_LOG_FILE" "cd $BACKUP_PATH_DB"
    LOG_INFO "$BACKUP_LOG_FILE" "UDS, action=$action, uploadFilename=$uploadFilename"
    LOG_INFO "$BACKUP_LOG_FILE" "$info"
     
    if [ -d $BACKUP_PATH_DB/logs ]; then
        rm -r $BACKUP_PATH_DB/logs
    fi
    
    failureCode1="InArrearOrInsufficientBalance"
    failureCode2="InvalidAccessKeyId"
    failureCode3="timed out"
    failureCode4="SignatureDoesNotMatch"
    failureCode5="NoSuchBucket"
    failureCode6="File not exist"
    failureCode7="The specified key does not exist"
    successCode="responseCode: 200"
    successCodeDel="responseCode: 204"
    case $info in
        *$successCode*)
            LOG_INFO "$BACKUP_LOG_FILE" "$action full backup file to UDS successfully";
            return 0
        ;;
        *$successCodeDel*)
            LOG_INFO "$BACKUP_LOG_FILE" "$action remote backup file successfully";
            if [ "$action" == "delete" ]; then
               return 0
            fi
            return 1
        ;;
        *$failureCode1*)
            ECHOANDLOG_ERROR "$BACKUP_LOG_FILE" "UDS $action failure! InArrearOrInsufficientBalance";
        ;;
        *$failureCode2*)
            ECHOANDLOG_ERROR "$BACKUP_LOG_FILE" "UDS $action failure! InvalidAccesskey";
        ;;
        *$failureCode3*)
            ECHOANDLOG_ERROR "$BACKUP_LOG_FILE" "UDS $action failed! time out!";
        ;;
        *$failureCode4*)
            ECHOANDLOG_ERROR "$BACKUP_LOG_FILE" "UDS $action failed! SignatureDoesNotMatch";
        ;;
        *$failureCode5*)
            ECHOANDLOG_ERROR "$BACKUP_LOG_FILE" "UDS $action failed! The specified bucket does not exist";
        ;;
        *$failureCode6*)
            ECHOANDLOG_ERROR "$BACKUP_LOG_FILE" "UDS $action failed! File not exist!";
        ;;
        *$failureCode7*)
            ECHOANDLOG_ERROR "$BACKUP_LOG_FILE" "UDS $action failed! Incorrected target download file name !";
        ;;
        *)
            ECHOANDLOG_ERROR "$BACKUP_LOG_FILE" "UDS $action failure";
        ;;
    esac
    
    return 2
}

function fn_FTP_operation()
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

    if [ -z $sftp_passwd_value_d ]; then
        upload_die "Decrypt failed"
    fi

    if [ -z $sftp_port_value ]; then
        sftp_port_value=21
    fi

    action=$1
    filename=$2
    if [ $action == "upload" ]; then
        LOG_INFO "$BACKUP_LOG_FILE" "upload to FTP, remote uploadFilePath=$sftp_remote_filepath, local uploadFilename=$BACKUP_PATH_DB/$localFilename"
        sh $backupPath/sftpTools.sh $sftp_ip_value $sftp_port_value $sftp_user_value $sftp_passwd_value_d $action $sftp_remote_filepath $filename $BACKUP_PATH_DB | tee -a "${BACKUP_LOG_FILE}"
    elif [ $action == "delete" ]; then
        LOG_INFO "$BACKUP_LOG_FILE" "delete from FTP, remote deleteFilename=$sftp_remote_filepath/$filename"
        sh $backupPath/sftpTools.sh $sftp_ip_value $sftp_port_value $sftp_user_value $sftp_passwd_value_d $action $sftp_remote_filepath $filename | tee -a "${BACKUP_LOG_FILE}"
    fi
    retRes=${PIPESTATUS[0]}
    if [ $retRes -eq 0 ];then
        return 0
    else
        return 2
    fi
}


function fn_update_backuplist()
{
    LOG_INFO "$BACKUP_LOG_FILE" "into func update_backuplist"
    backupFilename=$1
    backuplistFile=$backupPath/backuplist
    reg_sn_string="$patern_string.*${backup_cycle}${sn}.tar.gz"
    sed -i "/^${reg_sn_string}$/d" $backuplistFile
    echo $backupFilename >> $backuplistFile
    LOG_INFO "$BACKUP_LOG_FILE" "Update remote file record in backuplist"
}

function fn_delete_remote_oldfile()
{
    # remote keep MAX_BACKUP_NUM latest backup file
    LOG_INFO "$BACKUP_LOG_FILE" "into func fn_delete_remote_oldfile"
    backuplistFile=$backupPath/backuplist
    local current_backup_num=$(cat ${backuplistFile} | grep -E "^($reg_string)$" | wc -l | awk '{print $1}')
    while [[ $current_backup_num -gt ${BACKUP_MAX_NUMBER} ]]
    do
         LOG_INFO "$BACKUP_LOG_FILE" "The backuplist number=$current_backup_num hit the max number=$BACKUP_MAX_NUMBER, remove oldest file."
         theOldestFileName=$(sed -n "1p" $backuplistFile)
         if [ -n $theOldestFileName ]; then
             if [ $UPLOAD_FTP_MODE -eq 0 ];then
                 uds_delete_action="delete"
                 fn_upload_UDS $uds_delete_action $theOldestFileName >> "${BACKUP_LOG_FILE}"
             elif [ $UPLOAD_FTP_MODE -eq 1 ];then
                 ftp_delete_action="delete"
                 fn_FTP_operation $ftp_delete_action $theOldestFileName >> "${BACKUP_LOG_FILE}"
             fi
         fi   
         if [ $? -eq 0 ]; then
             sed -i "1d" $backuplistFile
             LOG_INFO "$BACKUP_LOG_FILE" "Remove remote oldest file $theOldestFileName successfully"
         else
             ECHOANDLOG_ERROR "$BACKUP_LOG_FILE" "Remove remote oldest file $theOldestFileName failed"
             return 3
         fi
         current_backup_num=$(cat ${backuplistFile} | grep -E "^($reg_string)$" | wc -l | awk '{print $1}')
         LOG_INFO "$BACKUP_LOG_FILE" "The backuplist number=$current_backup_num."
    done
}

function fn_backupdb()
{
    backup_strategy=$1
   echo $g_psql_passwd_d | su - $DB_USER -l -c "gsql -c 'select pg_stop_backup();'"  >> "${BACKUP_LOG_FILE}" 2>&1

    fn_rmbackup_file_num
    rmbackupFileNum=$?
    LOG_INFO "$BACKUP_LOG_FILE" "rmbackupFileNum=$rmbackupFileNum"
    if [ $rmbackupFileNum -eq 0 ]; then
        LOG_WARN "$BACKUP_LOG_FILE" "$RMAN_BACKUP_PATH has no base full backup file"
        LOG_INFO "$BACKUP_LOG_FILE" "set backup strategy full"
        backup_strategy="f"
    fi

    if [ $backup_strategy = "f" -o $backup_strategy = "full" ]; then
        do_init >> "${BACKUP_LOG_FILE}" 2>&1
        retRes=$?
        if [ $retRes -ne 0 ]; then
            die "cmd [gs_rman init] failed!"
        fi
    fi

    LOG_INFO "$BACKUP_LOG_FILE" "Backuping DB ..."

    do_backup $g_psql_passwd_d $backup_strategy >> "${BACKUP_LOG_FILE}" 2>&1; retRes=$?
    LOG_INFO "$BACKUP_LOG_FILE" "backup_strategy: $backup_strategy, return value: $retRes"
    if [[ $retRes -ne 0 ]]; then
        sleep 15
        do_init >> "${BACKUP_LOG_FILE}" 2>&1
        retRes=$?
        if [ $retRes -ne 0 ]; then
            die "cmd [gs_rman init] failed!"
        fi
        LOG_WARN "$BACKUP_LOG_FILE" "Backup Gauss DB failed, will sleep 15s and retry..."
        backup_strategy="f"
        do_backup $g_psql_passwd_d $backup_strategy >> "${BACKUP_LOG_FILE}" 2>&1; retRes=$?
        if [[ $retRes -ne 0 ]]; then
            die "retry full backup GaussDb failed"
	fi
    fi

    if [ $backup_strategy = "f" -o $backup_strategy = "full" ]; then
        fn_sn_num_update
        if [ $? -ne 0 ]
        then
            die "Update sequence number Failed"
        fi
    fi

    do_validate >> "${BACKUP_LOG_FILE}" 2>&1; retRes=$?
    if [ $retRes -ne 0 ]; then
        die "cmd [gs_rman validate] failed!"
    fi
    
    LOG_INFO "$BACKUP_LOG_FILE" "Backup and Validate Successfully!"
    LOG_INFO "$BACKUP_LOG_FILE" "Begin to Tar and Compress backup package"
    
    fn_backfile_tarAnd_rename $backup_strategy
    if [ $? -ne 0 ]; then
        #retry
        LOG_ERROR "$BACKUP_LOG_FILE" "Warn: Tar Gauss DB abnormal, will sleep 15s and retry..."
        sleep 15

        fn_backfile_tarAnd_rename $backup_strategy
        if [ $? -eq 0 ]
        then
            LOG_INFO "$BACKUP_LOG_FILE" "Tar Gauss DB Successfully"
        else
            die "Retry tar GaussDB package Failed"
        fi
    fi

    if [ $backup_strategy = "f" -o $backup_strategy = "full" ]; then 
        fn_delOld_file
        if [ $? -ne 0 ]
        then
            die "Delete old file Failed"
        fi
    fi
    db_backup_alarm_tag="b0(backup success)"
    upload_action="upload"
    LOG_INFO "$BACKUP_LOG_FILE" "Storage server action: $upload_action"
    if [ $UPLOAD_FTP_MODE -eq 0 ];then
        fn_upload_UDS $upload_action "${db_backup_tar_name}.tar.gz"
    elif [ $UPLOAD_FTP_MODE -eq 1 ];then
        fn_FTP_operation $upload_action "${db_backup_tar_name}.tar.gz"
    fi
    if [ $? -ne 0 ];then
        ECHOANDLOG_ERROR "$BACKUP_LOG_FILE" "Upload backup file: ${db_backup_tar_name}.tar.gz failed"
        sendResourceAlarm "$alarmFile" "${db_backup_alarm_tag}${db_upload_alarm_tag}"
        exit 2
    else
        LOG_INFO "$BACKUP_LOG_FILE" "Upload backup file: ${db_backup_tar_name}.tar.gz successfully"
        db_upload_alarm_tag="u0(upload success)"
    fi

    LOG_INFO "$BACKUP_LOG_FILE" "Full backup strategy need update backuplist and delete remote old file"
    fn_update_backuplist "${db_backup_tar_name}.tar.gz"
    if [ $? -ne 0 ]; then
        upload_die "Update backup list file Failed"
    fi
    	
    fn_delete_remote_oldfile
    if [ $? -ne 0 ]; then
        ECHOANDLOG_ERROR "$BACKUP_LOG_FILE" "Delete remote old file Failed"
        exit 3
    fi

    chown -R $DB_USER: $BACKUP_PATH_DB
    chmod 600 $BACKUP_PATH_DB/${db_backup_tar_name}.tar.gz  
	
    LOG_INFO "$BACKUP_LOG_FILE" "Change ${db_backup_tar_name}.tar.gz authority " 
    return 0
}

fn_backup_increment()
{
    another_db_name=$1
    default_db=$(su - dbadmin -c 'echo $PGDATABASE')
    
    if [ -z $default_db ]; then
        LOG_INFO "$BACKUP_LOG_FILE" "default_db(PGDATABASE) is null "
    fi
    LOG_INFO "$BACKUP_LOG_FILE" "default database is $default_db"

    if [ -d $temp_gs_dump_path ]; then
        rm -r $temp_gs_dump_path
    fi
    mkdir -p $temp_gs_dump_path
    chmod -R 750 $temp_gs_dump_path
    chown -R $DB_USER: $temp_gs_dump_path

    echo $g_psql_passwd_d | su - $DB_USER -l -c "gsql -c 'select pg_stop_backup();'"  >> "${BACKUP_LOG_FILE}" 2>&1
    LOG_INFO "$BACKUP_LOG_FILE" "pg_dump database:$default_db, backup to path: $temp_gs_dump_path"
    LOG_INFO "$BACKUP_LOG_FILE" "pg_dump database:$another_db_name, backup to path: $temp_gs_dump_path"

    date_string=$(date -d today +%Y%m%d%H%M%S)
    db_incremental_tar_name="${serviceName}${date_string}"

    defaultRes=0
    anotherRes=0
    su - $DB_USER -c "gs_dump -W $g_psql_passwd_d --pg-format --quote-all-identifier ${default_db} | gzip > $temp_gs_dump_path/${db_incremental_tar_name}${default_db}.gz"
    defaultRes=$?
    if [ $defaultRes -ne 0 ]
    then
        sleep 5
        su - $DB_USER -c "gs_dump -W $g_psql_passwd_d --pg-format --quote-all-identifier ${default_db} | gzip > $temp_gs_dump_path/${db_incremental_tar_name}${default_db}.gz"
        defaultRes=$?
    fi

    if [ ! -z $another_db_name ]; then 
        su - $DB_USER -c "gs_dump -W $g_psql_passwd_d --pg-format --quote-all-identifier ${another_db_name} | gzip > $temp_gs_dump_path/${db_incremental_tar_name}${another_db_name}.gz"
        anotherRes=$?
        if [ $anotherRes -ne 0 ]; then
            sleep 5
            su - $DB_USER -c "gs_dump -W $g_psql_passwd_d --pg-format --quote-all-identifier ${another_db_name} | gzip > $temp_gs_dump_path/${db_incremental_tar_name}${another_db_name}.gz"
            anotherRes=$?
        fi
    fi

    if [ $defaultRes -eq 0 -a $anotherRes -eq 0 ]; then
        LOG_INFO "$BACKUP_LOG_FILE" "backup database:$default_db $another_db_name success."
    else
        die "backupGaussDb Failed"
    fi
    db_backup_alarm_tag="b0(backup success)"
	
    today_hour=$(date -d today +%H)
    db_inc_tar="${location}F${BACKUP_MODE}${serviceName}GsDump${today_hour}Backup.tar.gz"
    cd $temp_gs_dump_path && tar -zcf $BACKUP_PATH_DB/$db_inc_tar *
    if [ $? -ne 0 ]
    then
        die "tar gs_dump GaussDb file Failed"
    fi

    upload_action="upload"
    if [ $UPLOAD_FTP_MODE -eq 0 ];then
        fn_upload_UDS $upload_action "${db_inc_tar}" | tee -a "${BACKUP_LOG_FILE}"
    elif [ $UPLOAD_FTP_MODE -eq 1 ];then
        fn_FTP_operation $upload_action "${db_inc_tar}" | tee -a "${BACKUP_LOG_FILE}"
    fi

    retRes=${PIPESTATUS[0]}
    if [ $retRes -ne 0 ]
    then
        ECHOANDLOG_ERROR "$BACKUP_LOG_FILE" "Upload backup file: $db_inc_tar failed"
        exit 2
    else
        LOG_INFO "$BACKUP_LOG_FILE" "Upload backup file: $db_inc_tar successfully"
	db_upload_alarm_tag="u0(upload success)"
    fi
    
    chown -R $DB_USER: $BACKUP_PATH_DB
    chmod 600 $BACKUP_PATH_DB/${db_inc_tar}

    rm -r $temp_gs_dump_path
    LOG_INFO "$BACKUP_LOG_FILE" "remove $temp_gs_dump_path"
}
SN_TMP=$(cat "${BAK_CONF_PATH}" 2>>"${BACKUP_LOG_FILE}" | grep "SN_BACKUP_NUM" 2>>"${BACKUP_LOG_FILE}" | awk -F "=" '{print $2}' 2>> "${BACKUP_LOG_FILE}")
echo "${SN_TMP}" | grep -Eq "^([0-9]{3})$"
if [ $? -eq 0 ]
then
    sn=${SN_TMP}
    LOG_INFO "$BACKUP_LOG_FILE" "sn=${SN_TMP}"
else
    die "sequence num need xxx digital, ${SN_TMP} is illegal"
fi

get_db_name_sql="select '1111111111',pg_database.DATNAME,pg_user.USENAME from pg_database,pg_user where pg_user.USESYSID = pg_database.DATDBA;"
get_db_name_result=$(echo $g_psql_passwd_d | su - $DB_USER -l -c "gsql -c '${get_db_name_sql}'")
ServiceName_TMP=`echo "$get_db_name_result"|grep 1111111111 | grep -v TEMPLATE0 | grep -v TEMPLATE1 | grep -v POSTGRES|awk -F '|' '{print $2}'|tr -d ' '|tr '\n' ' '|tr -d '\r'| sed 's/ /-/g'`
if [ $? -eq 0 ]
then
    serviceName=-${ServiceName_TMP}
    LOG_INFO "$BACKUP_LOG_FILE" "serviceName=${ServiceName_TMP}"
else
    die " Get service name failed ! "
fi

Location_TMP=$(cat "${BAK_CONF_PATH}" 2>>"${BACKUP_LOG_FILE}" | grep "LOCATION" 2>>"${BACKUP_LOG_FILE}" | awk -F "=" '{print $2}' 2>> "${BACKUP_LOG_FILE}")
if [ $? -eq 0 ]
then
    location=${Location_TMP}
    LOG_INFO "$BACKUP_LOG_FILE" "location=${Location_TMP}"
else
    die " Get location info failed ! "
fi

BACKUP_MAX_NUMBER=30
BACKUP_MAX_NUMBER_TMP=$(cat "${BAK_CONF_PATH}" 2>>"${BACKUP_LOG_FILE}" | grep "MAX_BACKUP_NUM" 2>>"${BACKUP_LOG_FILE}" | awk -F "=" '{print $2}' 2>> "${BACKUP_LOG_FILE}")
echo "${BACKUP_MAX_NUMBER_TMP}" | grep -Eq "(^[0-9]$)|(^[1-2][0-9]$)|(^30$)|(^31$)"
if [ $? -eq 0 ]
then
    BACKUP_MAX_NUMBER=${BACKUP_MAX_NUMBER_TMP}
    LOG_INFO "$BACKUP_LOG_FILE" "BACKUP_MAX_NUMBER=${BACKUP_MAX_NUMBER_TMP}"
else
    die "Backup max number is illegal, BACKUP_MAX_NUMBER=${BACKUP_MAX_NUMBER_TMP}"
fi

ANOTHER_DB=""
ANOTHER_DB=$(cat "${BAK_CONF_PATH}" 2>>"${BACKUP_LOG_FILE}" | grep "ANOTHER_DB" 2>>"${BACKUP_LOG_FILE}" | awk -F "=" '{print $2}' 2>> "${BACKUP_LOG_FILE}")
if [ $? -eq 0 ]
then
    LOG_INFO "$BACKUP_LOG_FILE" "ANOTHER_DB=${ANOTHER_DB}"
else
    die " Get ANOTHER_DB failed ! "
fi

backup_cycle="D"
backup_method="F"

patern_string=${location}${backup_method}${BACKUP_MODE}${serviceName}
reg_string="$patern_string[0-9]{8}${backup_cycle}[0-9]{3}(\.tar\.gz)"
if [ $backup_strategy = "f" -o $backup_strategy = "full" -o $backup_strategy = "i" ]; then
    fn_backupdb $backup_strategy
else
    fn_backup_increment $ANOTHER_DB || die "gs_dump backup db failed"
fi

sendResourceAlarm "$alarmFile" "${db_backup_alarm_tag}${db_upload_alarm_tag}"
echo "INFO:" "${db_backup_alarm_tag}${db_upload_alarm_tag}"
LOG_INFO "$BACKUP_LOG_FILE" "${db_backup_alarm_tag}${db_upload_alarm_tag}"

LOG_INFO "${BACKUP_LOG_FILE}" "Exit backup.sh"
