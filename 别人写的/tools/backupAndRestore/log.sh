#/bin/bash
set +x

getCurPath()
{
    if [ "` dirname "$0" `" = "" ] || [ "` dirname "$0" `" = "." ]; then
        CURRENT_PATH="`pwd`"
    else
        cd ` dirname "$0" `
        CURRENT_PATH="`dirname "$0"`"
        cd - > /dev/null 2>&1
    fi
}

getCurPath
scriptsDir="${CURRENT_PATH}/"
DB_USER=dbadmin

LOG_LEVEL="DEBUG"

logMaxSize=100

alias LOG_DEBUG='log "[DEBUG] [${BASH_SOURCE} ${LINENO}]"'
alias LOG_INFO='log "[INFO ] [${BASH_SOURCE} ${LINENO}]"'
alias LOG_WARN='log "[WARN ] [${BASH_SOURCE} ${LINENO}]"'
alias LOG_ERROR='log "[ERROR] [${BASH_SOURCE} ${LINENO}]"'
alias ECHOANDLOG_DEBUG='echoAndLog "[DEBUG] [${BASH_SOURCE} ${LINENO}]"'
alias ECHOANDLOG_INFO='echoAndLog "[INFO ] [${BASH_SOURCE} ${LINENO}]"'
alias ECHOANDLOG_WARN='echoAndLog "[WARN ] [${BASH_SOURCE} ${LINENO}]"'
alias ECHOANDLOG_ERROR='echoAndLog "[ERROR] [${BASH_SOURCE} ${LINENO}]"'
shopt -s expand_aliases

function initLog()
{
    if [ $# -ne 2 ]
    then
        echo "Init log error! The number of input parameters must be equal to 2"
        return 1
    fi
    
    local logDir=$1
    local logType=$2
    
    if [ -z "${logDir}" ]
    then
        echo "Init log error! log directory can not be null"
        return 1
    fi
    
    if [ -z "${logType}" ]
    then
        echo "Init log error! log type can not be null"
        return 1
    fi
    
    if [ ! -e "${logDir}" ]
    then
        echo "Init log error! ${logDir} dose not exist"
        return 1
    fi
    
    local logLockPath="${scriptsDir}/logLock/"
    local mkLogLock=0
    local mkLockRes=0
    while [ ${mkLogLock} -lt 3 ]
    do
        mkdir "${logLockPath}"
        mkLockRes=$?
        if [ ${mkLockRes} -ne 0 ]
        then
            sleep 1
            let "mkLogLock=mkLogLock+1"
            continue
        else
            break
        fi
    done
    
    if [ ${mkLockRes} -ne 0 ]
    then
        echo "Init log error! make log lock error"
        return 1
    fi
    
    local maxTotalLog=30
    local logSN=1 
    local logNameArr 
    local newestLogName="" 
    
    local logCount=0
    
    for file in $(ls -t -1 "${logDir}" | grep -E "^(([1-9][0-9][0-9][0-9])(0[1-9]|1[0-2])(0[1-9]|1[0-9]|2[0-9]|30|31)-([0-1][0-9]|2[0-4])([0-5][0-9])([0-5][0-9])-${logType}-([1-9]|[1-2][0-9]|30)(\.log))$")
    do
        logNameArr[${logCount}]=${file}
        logCount=$(expr $logCount + 1)
    done
        
    if [ ${logCount} -gt 0 ]
    then
        newestLogName=${logNameArr[0]}
        local logSNTemp=$(echo ${newestLogName} | sed "s/\./-/g" | awk -F "-" '{print $4}')
        let "logSNTemp=logSNTemp + 1"
        logSN=$(expr ${logSNTemp} % ${maxTotalLog})
        if [ ${logSN} -eq 0 ]
        then
            logSN=30
        fi
        for aLogName in ${logNameArr[@]}
        do
            logSNTemp=$(echo ${aLogName} | sed "s/\./-/g" | awk -F "-" '{print $4}')
            if [ ${logSNTemp} -eq ${logSN} ]
            then
                rm -rf "${logDir}/${aLogName}"
            fi
        done
    fi
    
    local sysTime=$(date -d today +"%Y%m%d-%H%M%S")
    local logName="${sysTime}-${logType}-${logSN}.log"
    local logPath="${logDir}/${logName}"
    touch "${logPath}"
    if [ $? -ne 0 ]
    then
        echo "Init log error! touch \"${logPath}\" error"
        return 1
    fi
    chown $DB_USER: "${logPath}"
    chmod 600 "${logPath}"
    rm -rf "${logLockPath}"
    echo "logName=${logName}"
}

function log()
{
    if [ $# -ne 3 ]
    then
        echo "log error! the number of input parameters must be equal to 3"
        exit 1
    fi
    
    local logPath="$2"
    
    if [ -z "$1" ]
    then
        echo "log error! the log level, script name and line number can not be null"
        exit 1
    fi
    
    if [ -z "${logPath}" ]
    then
        echo "log error! the log path can not be null"
        exit 1
    fi
    
    if [ -z "$3" ]
    then
        echo "log error! the log information can not be null"
        exit 1
    fi
    
    if [ ! -e "${logPath}" ]
    then
        echo "log error! ${logPath} dose not exist"
        exit 1
    fi
    
    local logSize=$(du -sk ${logPath}|awk '{print $1}')
    
    if [ "${logSize}" -gt "${logMaxSize}" ]
    then
        sed -i '1,100d' "${logPath}"
    fi
    
    local logStr="$1 $3"
    local echoStr="$3"
    
    local systemDate=$(date -d today +"%Y-%m-%d %H:%M:%S %:::z")
    local grepRes=""
    
    if [ "${LOG_LEVEL}" = "DEBUG" ]
    then
        echo "[ ${systemDate} ] ${logStr}" >> "${logPath}"
    elif [ "${LOG_LEVEL}" = "INFO" ]
    then
        grepRes=$(echo "$1" | grep "[DEBUG]")
        if [ -z "${grepRes}" ]
        then
            echo "[ ${systemDate} ] ${logStr}" >> "${logPath}"
        fi
    elif [ "${LOG_LEVEL}" = "WARN" ]
    then
        grepRes=$(echo "$1" | grep "[INFO]" | grep "[DEBUG]")
        if [ -z "${grepRes}" ]
        then
            echo "[ ${systemDate} ] ${logStr}" >> "${logPath}"
        fi
    elif [ "${LOG_LEVEL}" = "ERROR" ]
    then
        grepRes=$(echo "$1" | grep "[ERROR]")
        if [ ! -z "${grepRes}" ]
        then
            echo "[ ${systemDate} ] ${logStr}" >> "${logPath}"
        fi
    fi
}

function echoAndLog()
{
    if [ $# -ne 3 ]
    then
        echo "log error! the number of input parameters must be equal to 3"
        exit 1
    fi
    
    local logPath="$2"
    
    if [ -z "$1" ]
    then
        echo "log error! the log level, script name and line number can not be null"
        exit 1
    fi
    
    if [ -z "${logPath}" ]
    then
        echo "log error! the log path can not be null"
        exit 1
    fi
    
    if [ -z "$3" ]
    then
        echo "log error! the log information can not be null"
        exit 1
    fi
    
    if [ ! -e "${logPath}" ]
    then
        echo "log error! ${logPath} dose not exist"
        exit 1
    fi
    
    local logStr="$1 $3"
    local echoStr="$3"
    
    local grepRes=""
    
    grepRes=$(echo "$1" | grep "DEBUG")
    if [ -z "${grepRes}" ]
    then
        grepRes=$(echo "$1" | grep "INFO ")
        if [ ! -z "${grepRes}" ]
        then
            echo "[INFO ] ${echoStr}"
        fi
        
        grepRes=$(echo "$1" | grep "WARN ")
        if [ ! -z "${grepRes}" ]
        then
            yellow_echo "WARN " "${echoStr}"
        fi
        
        grepRes=$(echo "$1" | grep "ERROR")
        if [ ! -z "${grepRes}" ]
        then
            red_echo "ERROR" "${echoStr}"
        fi
    fi
    
    log "$1" "$2" "$3"
}

function color_echo()
{
	while (($#!=0))
	do
        case $1 in
			-red)
				echo -ne "\033[0;31;1m"
			;;
			-green)
				echo -ne "\033[32m"
			;;
			-yellow)
				echo -ne "\033[33m"
			;;
			-reset)
				echo -ne "\033[0m"
			;;
			*)
				echo -ne "$1 "
			;;
        esac
        shift
	done
    echo -ne "\n"
}

function red_echo()
{
    local echoLevel=$1
    local echoStr=$2
    color_echo -red [${echoLevel}] "$echoStr" -reset
}

function green_echo()
{
    local echoLevel=$1
    local echoStr=$2
    color_echo -green [${echoLevel}] "$echoStr" -reset
}

function yellow_echo()
{
    local echoLevel=$1
    local echoStr=$2
    color_echo -yellow [${echoLevel}] "$echoStr" -reset
}
