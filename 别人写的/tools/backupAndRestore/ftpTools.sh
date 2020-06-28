#!/bin/bash
set +x
. /etc/profile 2>/dev/null

ftpIP="$1"
ftpPort="$2"
ftpUser="$3"
ftpPwd="$4"
ftpAction="$5"  #upload, delete, download, list
remoteDir=$6
filename=$7
localBKDir=$8

#global vars
logPath="/var/log/ha/shelllog"
if [ -d $logPath ]; then
    lftpOutputPath="${logPath}/lftp_action.log"
else
    lftpOutputPath="/tmp/lftp_action.log"
fi

function die()
{
    echo "ERROR:" "$*"
    exit 1
}

#check the connection to FTP server
function checkFTP()
{
    # set timeout
    timeout -k 3 10 lftp -u "${ftpUser}","${ftpPwd}" -e "ls; exit" "${ftpHost}":"${ftpPort}" >>/dev/null 2>&1
    return $?
}

#set the translation protocal
function setProtocal()
{
    ftpHost="ftp://${ftpIP}"
    checkFTP && echo "INFO: choose ftp" && return 0

    ftpHost="ftps://${ftpIP}"
    checkFTP && echo "INFO: choose ftps" && return 0
    
    ftpHost="${ftpIP}"
    checkFTP && return 0

    echo "ERROR:" "FTP connection failed"
    exit 1
}

function judgeLftpRes()
{   
    local lftpRes=$(cat "${lftpOutputPath}" | grep "<\-\-\- 530")
    if [ ! -z "${lftpRes}" ]
    then
        echo "ERROR:" "The ftp user or password is wrong"
    fi
    
    local lftpRes=$(cat "${lftpOutputPath}" | grep "<\-\-\- 451")
    if [ ! -z "${lftpRes}" ]
    then
        echo "ERROR:" "FTP_ERROR_CODE: 451. Requested action aborted. Local error in processing"
    fi
    
    local lftpRes=$(cat "${lftpOutputPath}" | grep "<\-\-\- 550")
    if [ ! -z "${lftpRes}" ]
    then   
        echo "ERROR:" "FTP_ERROR_CODE: 550.  Remote file unavailable (e.g., file not found, no access)"
    fi
    
    local lftpRes=$(cat "${lftpOutputPath}" | grep "<\-\-\- 553")
    if [ ! -z "${lftpRes}" ]
    then    
        echo "ERROR:" "FTP_ERROR_CODE: 553. Requested action not taken. File name not allowed"
    fi
    
    local lftpRes=$(cat "${lftpOutputPath}" | grep "No such file or directory")
    if [ ! -z "${lftpRes}" ]
    then
        echo "ERROR:" "Fail to operate the local file, no such file or directory"
    fi
    
    local lftpRes=$(cat "${lftpOutputPath}" | grep "Permission denied")
    if [ ! -z "${lftpRes}" ]
    then
        echo "ERROR:" "Fail to operate the local file, permission denied"
    fi
    
    local lftpRes=$(cat "${lftpOutputPath}" | grep "server does not support or allow SSL")
    if [ ! -z "${lftpRes}" ]
    then
        echo "ERROR:" "The ftp server does not support or allow SSL"
    fi
    
    local lftpRes=$(cat "${lftpOutputPath}" | grep "Fatal error: max-retries exceeded")
    if [ ! -z "${lftpRes}" ]
    then
        echo "ERROR:" "The ftp server is unreachable"
    fi
}

#create the remote dir if not exist
function mkRemoteDir()
{
    rm -f "${lftpOutputPath}"
 
    lftp << EOF 2>> "${lftpOutputPath}"
        debug -o "${lftpOutputPath}" 4
        open -u "$ftpUser","$ftpPwd" -p $ftpPort "$ftpHost"
        cd "$remoteDir" || mkdir -p "$remoteDir"
        bye
EOF

    if [ $? -ne 0 ]; then
        judgeLftpRes
        die "Prepare remote dir <$remoteDir> failed"
    fi
    return 0
}

listRemoteFile()
{
    check_filename=$1
    rm -f "${lftpOutputPath}"

    lftp << EOF 2>> "${lftpOutputPath}"
        debug -o "${lftpOutputPath}" 4
        open -u "$ftpUser","$ftpPwd" -p $ftpPort "$ftpHost"
        cd "$remoteDir"
        cls ${check_filename}*
        bye
EOF
}

function uploadLocalFile()
{
    rm -f "${lftpOutputPath}"
    if [ ! -f ${localBKDir}/${filename} ]; then
        die "local file ${localBKDir}/${filename} not exist!"
    fi
    lftp << EOF 2>> "${lftpOutputPath}"
        debug -o "${lftpOutputPath}" 4
        open -u "$ftpUser","$ftpPwd" -p $ftpPort "$ftpHost"
        cd "$remoteDir"
        rm -rf ${filename}
        put -c "${localBKDir}/${filename}" -o "${remoteDir}/${filename}"
        bye
EOF
    
    local lftpExitCode=$?
    if [ ${lftpExitCode} -ne 0 ]; then
        judgeLftpRes
        die "Upload "${localBKDir}" failed"
    fi
    return 0
}

function deleteRemoteFile()
{
    # check, if delte file exist, do not delete
    retFileName=`listRemoteFile ${filename}`
    if [ -z ${retFileName} ]; then
        return 0
    fi

    remoteFilename=${remoteDir}/${filename}
    rm -f "${lftpOutputPath}"
    lftp << EOF 2>> "${lftpOutputPath}"
        debug -o "${lftpOutputPath}" 4
        open -u "$ftpUser","$ftpPwd" -p $ftpPort "$ftpHost"
        rm -rf "${remoteFilename}"
        bye
EOF

    local lftpExitCode=$?
    if [ ${lftpExitCode} -ne 0 ]; then
        judgeLftpRes
        die "Delete remote file ${remoteFilename} failed"
    fi
    return 0
}

function downloadRemoteFile()
{
    remoteFilename=${remoteDir}/${filename}
    if [ ! -d $localBKDir ]; then 
        mkdir -p $localBKDir
    fi
    echo "INFO: " "Downloading remote file ${remoteFilename} to $localBKDir ..."
    rm -f "${lftpOutputPath}"
    lftp << EOF 2>> "${lftpOutputPath}"
        debug -o "${lftpOutputPath}" 4
        open -u "$ftpUser","$ftpPwd" -p $ftpPort "$ftpHost"
        cd "$remoteDir"
        get -c "${remoteFilename}" -o "${localBKDir}/${filename}"
        bye
EOF

    local lftpExitCode=$?
    if [ ${lftpExitCode} -ne 0 ]; then
        judgeLftpRes
        die "Download remote file ${remoteFilename} to $localBKDir failed"
    fi
    return 0
}

##main
if [ $# -lt 7 ] || [ $# -gt 8 ]; then
    die "Input param number<$#> error, not equal to 7 or 8"
fi

# check lftp
command -v lftp >/dev/null 2>&1 || die "Upload NAS requires lftp but it's not installed. Aborting."

# auto chose the protocal
setProtocal

# FTP action
case $ftpAction in
    upload)
        mkRemoteDir
        uploadLocalFile
    ;;
    delete)
        deleteRemoteFile
    ;;
    download)
        downloadRemoteFile
    ;;
    *)
        die "Parameters error: $ftpAction is not allowed, just support upload, delete, download"
    ;;
esac
