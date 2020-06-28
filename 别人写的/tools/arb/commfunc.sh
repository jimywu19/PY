#!/bin/bash

COMM_SCRIPTDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_TOOL="${SCRIPTDIR}/../../../ha/module/hacom/tools/ha_config_tool"
COMM_BCMANAGER_PATH="${COMM_SCRIPTDIR}/../.."
G_IFCONFIG="$(which ifconfig)"
G_ARPING="$(which arping)"
G_RUNNING=0
G_STOPED=2
G_STARTING=4
G_STOPING=5
G_RUNNING_ACTIVE=6
G_RUNNING_STANDBY=7
ha_properties="$COMM_SCRIPTDIR/../ha/conf/arb/ha.properties"

#add for adapting IPV6
. $COMM_SCRIPTDIR/../../install/common_var.sh || { echo "load $COMM_SCRIPTDIR/../../install/common_var.sh failed."; exit 1; }
echo "commfunc.sh $IP_TYPE"
#add for adapting IPV6

declare CURDIR=`dirname $0`
declare CURPATH=`readlink -f $CURDIR`

function changeLogsAuth()
{
    local userFile=$COMM_SCRIPTDIR/config/conf/startInfo.properties
    local wccLog4j=$COMM_SCRIPTDIR/../LegoRuntime/conf/wcc/log4j.properties
    local RuntimePath=$COMM_BCMANAGER_PATH/Runtime/logs
    local binPath=$COMM_BCMANAGER_PATH/Runtime/bin/logs
    local groupName=`cat "$userFile" | grep -v '^#' | grep "custom.user.group" | awk -F = '{print $2}' | tr -d '\r\n'`
    if [ -d "$binPath" ];then
        chmod g+s "$binPath" &>/dev/null
        chmod -R 750 "$binPath" &>/dev/null
        chmod 640 `find "$binPath" -type f` &>/dev/null
        chgrp -R $groupName "$binPath" &>/dev/null
    fi
  
    if [ -d "$RuntimePath" ];then
        chmod g+s "$RuntimePath" &>/dev/null
        chmod 770 "$RuntimePath" &>/dev/null
        chmod 640 `find "$RuntimePath" -type f` &>/dev/null
        chmod 660 "$RuntimePath"/DataCollect.log &>/dev/null
        chgrp -R $groupName "$RuntimePath" &>/dev/null
    fi

    #wcc log file will be writed by Tomcat,ICUser and root
    local wccLogFile=`cat "$wccLog4j" | grep log4j.appender.FILE.File | awk -F= '{print $2}'` 
    if [ ! -f "$wccLogFile" ];then
        touch "$wccLogFile" &>/dev/null
    fi
    chgrp $groupName "$wccLogFile" &>/dev/null
    chmod 660 "$wccLogFile"  &>/dev/null
}

function zipLog()
{
    local logName=$1
    if [ ! -f "$logName" ];then
        return
    fi

    local MAXLOGSIZE=10485760
    local LOGFILE_SUFFIX="gz"
    local LOG_FILE_PATH=`dirname "$logName"`
    local LOG_FILE_NAME_USE=`basename "$logName"`
    local BACKLOGCOUNT=`ls -l ${LOG_FILE_PATH} | grep "${LOG_FILE_NAME_USE}" | grep ${LOGFILE_SUFFIX}$ |wc -l`

    local LOGFILESIZE=`ls -l "$logName" | awk -F " " '{print $5}'`
    if [ ${LOGFILESIZE} -gt ${MAXLOGSIZE} ]
    then
        gzip -f -q -9 "$logName"
        local FILENAME_DATE=`date +"%y-%m-%d-%H:%M:%S"`
        local srcName="$logName.${LOGFILE_SUFFIX}"
        local destName="$logName.${FILENAME_DATE}.${LOGFILE_SUFFIX}" 
        mv "$srcName" "$destName"
        chmod 440 "$destName" &>/dev/null 
    fi
    
    if [ $BACKLOGCOUNT -gt 10 ]
    then
        local cur_path=`pwd`
        cd "${LOG_FILE_PATH}"
        local deleteLogName=`ls ${LOG_FILE_NAME_USE}* |sort | sed -n "2p"`
        rm -rf ${deleteLogName}
        pushd "$cur_path" &>/dev/null
    fi
}

function Log()
{
    LOG_FILE_PATH=`dirname ${LOG_FILE_NAME}`
    if [ ! -x "${LOG_FILE_PATH}" ]
    then
        mkdir ${LOG_FILE_PATH}
        chmod 750 "${LOG_FILE_PATH}"
        chmod g+s "${LOG_FILE_PATH}"
    fi
    
    if [ ! -f "${LOG_FILE_NAME}" ]
    then
        touch "${LOG_FILE_NAME}" 
    fi
    chmod 640 "${LOG_FILE_NAME}"
    
    DATE=[`date +"%Y/%m/%d %H:%M:%S"`]
    USER_NAME=`whoami`
    echo "${DATE}:[$$][${USER_NAME}] $1" >> "${LOG_FILE_NAME}"
    zipLog "$LOG_FILE_NAME"
}

function getLegoFile()
{
    local legoFile=/etc/profile.d/lego.sh
    local installFile=/home/ICUser/RDInstalled.xml
    if [ -z "$LEGO_HOME" ] || [ ! -d "$LEGO_HOME" ];
    then
        if [ -f "$legoFile" ];
        then
            . $legoFile
        elif [ -f "$installFile" ];
        then
            LEGO_HOME=`cat $installFile | grep installpath | cut -f2 -d "\""`
        else
            echo "get LEGO_HOME failed." 1>> "$LOG_FILE_NAME" 2>&1
        fi
    fi
    legoHome=$LEGO_HOME
    #find properties in config/conf/startInfo.properties while install eReplication
    local confileFile=config/conf/startInfo.properties
    #find properties in $COMM_SCRIPTDIR while management eReplication
    if [ -f "$COMM_SCRIPTDIR/$confileFile" ];then
        confileFile=$COMM_SCRIPTDIR/$confileFile
    fi
    
    if [ ! -f "$confileFile" ];then
        return
    fi
    G_SYS_USER_NAME=`cat "$confileFile" | grep -v '^#' | grep "custom.user.name" | awk -F = '{print $2}' | tr -d '\r\n'`
    G_USER_GROUP_NAME=`cat "$confileFile" | grep -v '^#' | grep "custom.user.group" | awk -F = '{print $2}' | tr -d '\r\n'`
    G_TOMCAT_USER_NAME=`cat "$confileFile" | grep -v '^#' | grep tomcat.user.name | awk -F = '{print $2}'| tr -d '\r\n'`
}

function GetFloatIP()
{
    if [ -z "${G_BCMANAGER_RUNTIME_PATH}" ]
    then
        G_BCMANAGER_RUNTIME_PATH="${COMM_SCRIPTDIR}/../"
    fi
    local HAARB_XML=$G_BCMANAGER_RUNTIME_PATH/ha/module/haarb/conf/haarb.xml

    local L_IP=$(sed -n "s/.*arpip.*value=\"\(.*\)\".*/\1/p" ${HAARB_XML})
    echo "$L_IP"
}

function GetHAMode()
{
    if [ -z "${G_BCMANAGER_RUNTIME_PATH}" ]
    then
        G_BCMANAGER_RUNTIME_PATH="${COMM_SCRIPTDIR}/../"
    fi
    local HACOM_XML=$G_BCMANAGER_RUNTIME_PATH/ha/module/hacom/conf/hacom.xml
    
    local L_HA_MODE=$(sed -n 's/.*hamode.*value=\"\(.*\)\".*/\1/p' ${HACOM_XML})
    echo "$L_HA_MODE"
}

function getHARole()
{
    if [ -z "${G_BCMANAGER_RUNTIME_PATH}" ]
    then
        G_BCMANAGER_RUNTIME_PATH="${COMM_SCRIPTDIR}/../"
    fi
    
    local L_HA_ROLE=`${G_BCMANAGER_RUNTIME_PATH}/ha/module/hacom/script/get_harole.sh`
    echo "$L_HA_ROLE"
}

checkPortUsed()
{
    usedPortFile="$COMM_SCRIPTDIR"/usedPortTmp
    if [ -f "$usedPortFile" ];then
        rm -f usedPortFile
    fi
    inUse="false"
    portsList=`cat "$PortFile" | grep -v '^#' | grep -v 'windows'`
    for str in $portsList
    do
       Lport=`echo $str | awk -F = '{print $2}' | tr -d '\r\n'`
       keyName=`echo $str | awk -F = '{print $1}' | tr -d '\r\n'`
       gaussPort=`echo $keyName | grep "gauss"`
       if [ -z "$Lport" ] || [ ! -z "$gaussPort" ];then
           continue
       fi
       ports=(`netstat -ntul | awk '{print $4}' | awk -F: '{print $2 $4}' | grep $Lport`)
       for port in "${ports[@]}"
       do
           if [ "$port" = "$Lport" ]; then
               echo $keyName=$port  >> "$usedPortFile"
               break
           fi
       done       

    done

    if [ -f "$usedPortFile" ];then
       Log "$1"
       Log "used port: `cat $usedPortFile`" 
       rm -f $usedPortFile 1>/dev/null 2>&1
       return 1
    fi
    return 0
}

function getClassPath()
{
    local LIBS="$1"
    local LIBS_PATH="$2"
    classList=
    if [ "$LIBS_PATH" = "" ]
    then
        LIBS_PATH=lib
    fi
    
    if [ -z "$LIBS" ];then
        return 1
    fi 
    local cur=`pwd`
    pushd "$COMM_SCRIPTDIR" &>/dev/null
    libsList=`echo $LIBS | sed 's/ /\*/g' | sed 's/;/ /g'`
    for libFile in  $libsList
    do
        fileName=`ls "$LIBS_PATH/$libFile"*`
        classList=$classList:$fileName    
    done
    CLASSPATH=`echo ${classList:1}`
    pushd "$cur" &>/dev/null
}


function checkPort()
{
    #Isure the server of eReplication was stopped before check port.
    local startInfoFile="$COMM_SCRIPTDIR/config/conf/startInfo.properties"
    local OSGI_USER=`cat "$startInfoFile" | grep -v '^#' | grep "custom.user.name" | awk -F = '{print $2}' | tr -d '\r\n'`
    local TOMCAT_USER=`cat "$startInfoFile" | grep -v '^#' | grep "tomcat.user.name" | awk -F = '{print $2}'| tr -d '\r\n'`
    local installPath=`cat "$COMM_SCRIPTDIR/config/conf/config.properties" | grep linux.default.install.path | awk -F= '{print $2}'`
    local backPid=`ps -ef | grep java | grep "$OSGI_USER" | grep jre6.0.18 | grep equinox | awk  '{print $2}'`
    local frontPid=`ps -ef | grep java | grep "$TOMCAT_USER" | grep "$installPath" | awk '{print $2}'`
    if [ ! -z "$backPid" ];then
        Log "[INFO] find the back progress[$backPid] is running, kill it before check port."
        kill -9 $backPid 1>> "$LOG_FILE_NAME"  2>&1
    fi
    if [ ! -z "$frontPid" ];then
        Log "[INFO] find the front progress[$frontPid] is running, kill it before check port."
        kill -9 $frontPid 1>> "$LOG_FILE_NAME"  2>&1
    fi

    local CUR_PATH=`pwd`
    local PortFile=$COMM_SCRIPTDIR/config/conf/port.ini
    local confFile=$COMM_SCRIPTDIR/lego.properties
    local language=$COMM_SCRIPTDIR/config/lauguages/common_en.properties
    local illegalFile="$COMM_SCRIPTDIR/illegalTmpFile"
    local oldPort=`cat "$confFile" | grep -v '^#' | grep http.port |awk -F = '{print $2}'| tr -d '\r\n'`
    local oldRedirectPort=`cat "$confFile" | grep -v '^#' | grep http.redirect.port |awk -F = '{print $2}'| tr -d '\r\n'`
    local newHttpPort=`cat "$PortFile"| grep -v '^#' | grep http.port |awk -F = '{print $2}'| tr -d '\r\n'`
    local newHttpRedirectPort=`cat "$PortFile"| grep -v '^#' | grep linux.http.to.https.redirect.port |awk -F = '{print $2}'| tr -d '\r\n'`
    local port_illegal=`cat "$language"| grep -v '^#' | grep start.err.10011 |awk -F = '{print $2}'| tr -d '\r\n'`
    local port_used=`cat "$language"| grep -v '^#' | grep start.err.10012 |awk -F = '{print $2}'| tr -d '\r\n'`
    local updatePortFailed=`cat "$language"| grep -v '^#' | grep start.err.10013 |awk -F = '{print $2}'| tr -d '\r\n'`
    local CHECK_CLASSPATH="install;commons-codec;com.springsource.slf4j.api;wcc_common;wcc_crypt;wcc_log;com.springsource.slf4j.log4j;commons-lang;dom4j;framework;jaxen;legoLog;log4j.osgi;tar.jar;Lego-Core-Log-Bundle;Lego-Core-SDK-Bundle;spring;commons-logging;org.eclipse.osgi;gsjdbc"
    getClassPath "$CHECK_CLASSPATH"
    rm -fr "$illegalFile" 1>/dev/null 2>&1
    cd "$COMM_SCRIPTDIR"
    "$COMM_SCRIPTDIR/../jre6.0.18/bin/java" -cp "$CLASSPATH" com.huawei.lego.common.changeport.ChangePort checkPort 1>/dev/null 2>&1
    if [ $? != 0 ];then
        if [ -f "$illegalFile" ];then
            Log "checkPort failed, port: `cat $illegalFile`"
            rm -fr "$illegalFile" 1>/dev/null 2>&1
            return 1
        fi
    fi

    checkPortUsed "$port_used"
    if [ $? != 0 ];then
        return 1
    fi
    "$COMM_SCRIPTDIR/../jre6.0.18/bin/java" -cp "$CLASSPATH" com.huawei.lego.common.changeport.ChangePort updatePort 1>/dev/null 2>&1
    if [ $? != 0 ];then
        Log "$updatePortFailed"
        return 1
    fi

    if [ "$oldPort" != "$newHttpPort" ] || [ "$oldRedirectPort" != "$newHttpRedirectPort" ];then
        iptables -D PREROUTING -t nat -p tcp --dport $oldPort -j REDIRECT --to-port $oldRedirectPort >/dev/null 2>&1
        iptables -t nat -A PREROUTING -p tcp --dport $newHttpPort -j REDIRECT --to-port $newHttpRedirectPort
        sed -i -r "/http.port=/s/(http.port=)[^ ](.*)/\1$newHttpPort/" "$confFile"
        sed -i -r "/http.redirect.port=/s/(http.redirect.port=)[^ ](.*)/\1$newHttpRedirectPort/" "$confFile"
    fi
    cd "$CUR_PATH"
    return 0
}

#####################################################################
## @Usage Report_alarm
## @Return 0 
## @Description 上报告警，打印相应日志,不能上报是否成功都应该给HA返回0
#####################################################################
function Report_alarm()
{   
    Log "Report_alarm start  $CREATETIME"
    if [ -z "$TYPE" ];then
        Log "TYPE is null."
        exit 0
    fi

    Log "--type $TYPE --severity $SEVERITY --alarmId $ALARMID --createTime $CREATETIME --param $PARAM"
    pushd ${CURPATH}/../../../../../bin/
    nohup sh reportAlarm.sh --type $TYPE --severity $SEVERITY --alarmId $ALARMID --createTime $CREATETIME --param $PARAM  &
    popd
     
    Log "Report_alarm over  $CREATETIME" 
    exit 0
}

######################################################################
#   DESCRIPTION: 校验IP是否合法
#   RETURN     : 无
#   CHANGE DIR : 无
######################################################################
function validIP()
{
    local ipdot=0
    local ipcount=0
    
    if [ -z "$1" ]; then
        Log "[Error] The IP address is null."
        return 1
    fi
    
    if [ "127.0.0.1" = "$1" ] || [ "::1" = "$1" ];then
        Log "[Error] The IP address $1 is invaild."
        return 1
    fi
    
    if [ -z "$IP_TYPE" ] ||  [ "IPV4" == "$IP_TYPE" ]; then
        echo "$1" | grep -E "^([0-9]{1,2}|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9]{2}|2[0-4][0-9]|25[0-5])$" >/dev/null
        if [ $? -ne 0 ]; then
            Log "[Error] The IP address $1 is invalid."
            return 1
        fi
    else
        ipcalc -6 -c $1
        if [ $? -ne 0 ]; then
            Log "[Error] The IP address $1 is invalid."
            return 1
        fi
    fi
    
    return 0
}

function Substr()
{
    from=$2
    if [ $# -eq 2 ]
    then
        echo $1 | awk -v bn="$from" '{print substr($1,bn)}'
    elif [ $# -eq 3 ]
    then
        len=$3
        echo $1 | awk -v bn="$from" -v ln="$len" '{print substr($1,bn,ln)}'
    fi
}

function CheckString()
{
    local strParam="$1"
    local Ret=0
    echo "$strParam" | grep '[[:digit:]]' > /dev/null 2>&1
    [ $? -eq 0 ] && Ret=`expr $Ret + 1`
    echo "$strParam" | grep '[[:lower:]]' > /dev/null 2>&1
    [ $? -eq 0 ] && Ret=`expr $Ret + 1`
    echo "$strParam" | grep '[[:upper:]]' > /dev/null 2>&1
    [ $? -eq 0 ] && Ret=`expr $Ret + 1`
    echo "$strParam" | grep -E "[~]|[!]|[@]|[#]|[$]|[%]|[\^]|[&]|[*]|[(]|[)]|[-]|[_]|[=]|[+]|[|]|[\]|[[]|[]]|[;]|[{]|[}]|[:]|[']|[\"]|[,]|[<]|[.]|[>]|[/]|[?]" > /dev/null 2>&1
    [ $? -eq 0 ] && Ret=`expr $Ret + 1`
    
    return $Ret
}

function checkInputNumberLength()
{
    if [ `echo "$1" | wc -c` -gt 6 ]; then   # -gt 6 maybe means biger than 65536
        return 1
    fi
    return 0
}

function echoInfo()
{
    echo "$(date +'%Z %Y-%m-%d %H:%M:%S')   $1" 
    return 0
}

function getLocalIpAddr()
{   
    if [ -z "$IP_TYPE" ] ||  [ "IPV4" == "$IP_TYPE" ]; then
        local LOCALIPARRAY=`ifconfig -a|grep "inet "|awk -F " " '{print $2}' |awk -F ":" '{print $2}'`
        for ip in $LOCALIPARRAY
        do
            if [ "$ip" != "127.0.0.1" ]
            then
                echo $ip
            fi
        done
    else
        local LOCALIPARRAY=`ifconfig -a|grep "inet6 "|awk -F " " '{print $2}' |awk -F ":" '{print $2}'`
        for ip in $LOCALIPARRAY
        do
            if [ "$ip" != "::1" ]
            then
                echo $ip
            fi
        done
    fi
}

function isIpIndexRight()
{
    local input=$1
    local limit=$2
    
    checkInputNumberLength "$input"
    [ $? -eq 1 ] && return 0
    
    local check=`echo $input | grep "^[0-9]\{1,\}$"`
    if [ -z "$check" ] || [ $input -gt $limit ]; then 
        return 0
    fi
    return 1
}

function getAdapterInfoByIp()
{
    local inPutIp=$1
    local AllNetAdapter=`ip addr show | grep "inet " | grep -v "127.0.0.1" | grep -v "127.0.0.2" | awk '{print $NF}'`
    NetAdapter=""
    NetAdapterMac=""
    for ethi in $AllNetAdapter
    do
        theIp=`ifconfig $ethi | grep "inet addr:" | awk '{print $2}' | awk -F ":" '{print $2}'`
        if [ "$theIp" = "$inPutIp" ]; then
            NetAdapter="$ethi"
            break
        fi
    done
    [ "$NetAdapter" = "" ] && return 1
    NetMask=`ifconfig $NetAdapter | grep "inet addr:" | awk '{print $4}' | awk -F ":" '{print $2}'`
    NetAdapter=`echo $NetAdapter | awk -F ":" '{print $1}'`
    NetAdapterMac=`ifconfig $NetAdapter | grep "HWaddr " | awk '{print $5}'`
    return 0
}

######################################################################
#   DESCRIPTION: 校验端口是否合法
#   RETURN     : 无
#   CHANGE DIR : 无
######################################################################
function validPort()
{   
    if [ -z "$1" ]; then
        Log "[Error] The port is null."
        return 1
    fi
    #检查端口的第一个数字是否是0
    echo "$1" | grep -E "^[1-9][0-9]*$" >/dev/null
    if [ $? -ne 0 ]; then
        Log "[Error] The port $1 is invalid."
        return 1
    fi
    
    checkInputNumberLength "$1"
    [ $? -eq 1 ] && return 1
    
    if [ "$1" -lt 1024 ] || [ "$1" -gt 65535 ]; then
        Log "[Error] The port $1 is invalid."
        return 1
    fi    
    
    return 0
}


function checkUsePort()
{
    local inputPort=$1
    local chgWebMode=$2
    if [ "$chgWebMode" != "" ] && [ "$G_CLICHANGEWEB_FLAG" = "true" ];then
        local CHECK_CLASSPATH="install;commons-codec;com.springsource.slf4j.api;wcc_common;wcc_crypt;wcc_log;com.springsource.slf4j.log4j;commons-lang;dom4j;framework;jaxen;legoLog;log4j.osgi;tar.jar;Lego-Core-Log-Bundle;Lego-Core-SDK-Bundle;spring;commons-logging;org.eclipse.osgi;gsjdbc"
        getClassPath "$CHECK_CLASSPATH"
        ../jre6.0.18/bin/java -cp "$CLASSPATH" com.huawei.lego.common.changeweb.ChangeWebCommon $inputPort $chgWebMode
        if [ $? -ne 0 ];then
            echoInfo "ERROR:The port $inputPort is occupied."
            echo "Please try again."
            echo -ne "\n"
            return 1
        fi
        return 0
    fi
    
    if [ "$DATEBASE_PORT" != "" ] && [ "$inputPort" = "$DATEBASE_PORT" ];then
        echoInfo "ERROR:The port $inputPort is occupied."
        echo "Please try again."
        echo -ne "\n"
        return 1
    fi
    
    if [ "$TaskPlanePort" != "" ] && [ "$inputPort" = "$TaskPlanePort" ];then
        echoInfo "ERROR:The port $inputPort is occupied."
        echo "Please try again."
        echo -ne "\n"
        return 1
    fi
    
    if [ "$RunPlanePort" != "" ] && [ "$inputPort" = "$RunPlanePort" ];then
        echoInfo "ERROR:The port $inputPort is occupied."
        echo "Please try again."
        echo -ne "\n"
        return 1
    fi
    
 
    
    return 0
}

function checkIniPort()
{
    local inputPort=$1
    local whoUsed="$2"
    local PORT_INI_PATH="${COMM_BCMANAGER_PATH}/Runtime/bin/config/conf/port.ini"
    local portInIni=""
    if [ ! -f $PORT_INI_PATH ];then
        PORT_INI_PATH="${COMM_BCMANAGER_PATH}/Runtime/../config/conf/port.ini"
    fi
    
    if [ "$whoUsed" = "TaskManagePlane" ];then
        local OM_PLANE_PORT=`cat $PORT_INI_PATH | grep  "omplane.https.port" | awk -F "=" '{print $2}'`
        if [ "$inputPort" = "$OM_PLANE_PORT" ];then
            echoInfo "ERROR:The port $inputPort is occupied."
            echo "Please try again."
            echo -ne "\n"
            return 1
        fi
    fi
    
    if [ "$DATEBASE_PORT" = "" ];then
        portInIni=`cat $PORT_INI_PATH | grep "=" | grep -v "#" | grep -v "https.port"| awk -F "=" '{print $2}'`
        for iPort in $portInIni
        do
            if [ "$inputPort" = "$iPort" ];then
                echoInfo "ERROR:The port $inputPort is occupied."
                echo "Please try again."
                echo -ne "\n"
                return 1
            fi
        done
    else
        if [ "$inputPort" = "$DATEBASE_PORT" ];then
            echoInfo "ERROR:The port $inputPort is occupied."
            echo "Please try again."
            echo -ne "\n"
            return 1
        fi
        
        portInIni=`cat $PORT_INI_PATH | grep "=" | grep -v "#" | grep -v "https.port" | grep -v "gauss.port" | awk -F "=" '{print $2}'`
        for iPort in $portInIni
        do
            if [ "$inputPort" = "$iPort" ];then
                echoInfo "ERROR:The port $inputPort is occupied."
                echo "Please try again."
                echo -ne "\n"
                return 1
            fi
        done
    fi
    
    return 0
}

function getUserInputPort()
{
    local whoUsed="$1"
    local chgWebMode="$2"
    local TaskManagePlanePort=9443   #默认端口
    local RunManagePlanePort=9442
    local Ret=0
    local port=0
    while [ 1 ]
    do
        if [ "$whoUsed" = "TaskManagePlane" ]; then           
            echo -n "Please input the port of service management plane [$TaskManagePlanePort]:"
            echo ""
        else
            echo -n "Please input the port of O&M management plane [$RunManagePlanePort]:"
            echo ""
        fi
        read port
        if [ "$port" = "" ]; then
            if [ "$whoUsed" = "TaskManagePlane" ]; then
                port=$TaskManagePlanePort
            else
                port=$RunManagePlanePort
            fi
        fi

        if [ "$whoUsed" = "RunManagePlane" ]; then
            if [ "$port" = "$TaskManagePort" ]; then
                echoInfo "ERROR: The port of the O&M management plane must be different from that of the service management plane."
                echo "Please try again."
                echo -ne "\n"
                sleep 1
                continue
            fi
        fi
        
        validPort $port
        if [ $? -ne 0 ]; then
            echoInfo "ERROR: Your input is invalid."
            echo "Please try again."
            echo -ne "\n"
            sleep 1
            continue
        fi
        
        Ret=`lsof -i:$port`
        if [ -n "$Ret" ]
        then
            echoInfo "ERROR: The port $port is occupied."
            echo "Please try again."
            echo -ne "\n"
            sleep 1
            continue
        fi
        
        checkIniPort $port $whoUsed
        if [ $? -ne 0 ];then
            sleep 1
            continue
        fi
        
        checkUsePort $port $chgWebMode
        if [ $? -ne 0 ];then
            sleep 1
            continue
        fi
        
        Port=$port
        echo -ne "\n"
        break
    done
    return 0
}

function getUserInputPlane()
{
    local index
    local ip
    local localIpArraySize
    local right
    declare -a localAdapterInfoArry
    local PrintInfo="$1"
    while [ 1 ]
    do
        echo "$PrintInfo"
        index=1
        local i=0
        echo -e "=============================================================================="
        for ip in ${LOCALIPARRAY}
        do
            getAdapterInfoByIp "$ip"
            [ "$NetAdapterMac" = "" ] && continue
            localAdapterInfoArry[$i]="$NetAdapter  MAC=$NetAdapterMac  IP=$ip  NetMask=$NetMask"
            Log "localAdapterInfoArry[$i]: ${localAdapterInfoArry[$i]}"
            echo " [$index] ${localAdapterInfoArry[$i]}"
            index=`expr $index + 1`
            i=`expr $i + 1`
        done 
        echo -e "=============================================================================="
        
        read ipIndex
        if [ -z "$ipIndex" ] || [ "0" = "$ipIndex" ]
        then 
            echoInfo "ERROR: Your input is invalid."
            echo "Please try again."
            echo -ne "\n"
            sleep 1
            continue
        fi
        localIpArraySize=${#localAdapterInfoArry[@]}
        Log "localIpArraySize: $localIpArraySize, index: $index, i: $i"
        isIpIndexRight $ipIndex $localIpArraySize
        right=$?
        if [ 0 -eq $right ]
        then 
            echoInfo "ERROR: Your input is invalid."
            echo "Please try again."
            echo -ne "\n"
            sleep 1
            continue
        fi
        ipIndex=`expr $ipIndex - 1`
        ManageIP=`echo "${localAdapterInfoArry[$ipIndex]}" | awk -F "IP=" '{print $2}' | awk '{print $1}'`
        Log "choose the ip is : $ManageIP"
        echo -ne "\n"
        break
    done
    return 0
}

function showCurrentPlaneSetting()
{
    local TaskManagePlaneIP=$1
    local TaskManagePlaneMAC
    local RunManagePlaneIP=$2
    local RunManagePlaneMAC    
    
    if [ "$TaskManagePlaneIP" = "" ]; then  #参数为空，是重新配置
        if [ ! -f "$ha_properties" ]; then
            Log "ha/local/conf/ha.properties is not exist, please check the package of BCM."
            echo "ha/local/conf/ha.properties is not exist, please check the package of BCM."
            return 1
        fi
        local TaskManagePlane=`cat "$ha_properties" | grep "BCMProductManagementPlane" | awk -F "=" '{print $2}'`
        local RunManagePlane=`cat "$ha_properties" | grep "BCMManagementPlane" | awk -F "=" '{print $2}'`
        TaskManagePlaneIP=`echo "$TaskManagePlane" | awk -F "|" '{print $1}'`       
        TaskManagePlaneMAC=`echo "$TaskManagePlane" | awk -F "|" '{print $2}'`
        RunManagePlaneIP=`echo "$RunManagePlane" | awk -F "|" '{print $1}'`
        RunManagePlaneMAC=`echo "$RunManagePlane" | awk -F "|" '{print $2}'`
    else #参数不为空，是初次配置
        getAdapterInfoByIp "$TaskManagePlaneIP"
        TaskManagePlaneMAC="$NetAdapterMac"
        if [ "$RunManagePlaneIP" != "" ]; then
            getAdapterInfoByIp "$RunManagePlaneIP"
            RunManagePlaneMAC="$NetAdapterMac"
        fi  
    fi
    
    echo "Current plane configuration:"
    echo "----------------------------------------------------------------------------------------"
    echo -ne "\n"
    if [ "$TaskManagePlaneIP" = "" ]; then
        echo "[1] MAC=00:00:00:00:00:00  IP=127.0.0.1  plane name=Service Management Plane"
    else 
        echo "[1] MAC=$TaskManagePlaneMAC  IP=$TaskManagePlaneIP  plane name=Service Management Plane"
        G_G_TaskPlaneInfo="$TaskManagePlaneIP|$TaskManagePlaneMAC"
    fi
    
    if [ "$RunManagePlaneIP" != "" ]; then 
        echo "[2] MAC=$RunManagePlaneMAC  IP=$RunManagePlaneIP  plane name=O&M Management Plane"
        G_G_RunPlaneInfo="$RunManagePlaneIP|$RunManagePlaneMAC"
    fi
    echo -ne "\n"
    echo "----------------------------------------------------------------------------------------"
}

function SetTaskManagePlaneIp()  #业务IP设置
{
    if [ "$1" = "" ]; then
        LOCALIPARRAY=`getLocalIpAddr`
    else
        if [ "$RunManageIP" = "" ]; then
            LOCALIPARRAY=`getLocalIpAddr`
        else
            LOCALIPARRAY=`DeleteTaskManageIp $RunManageIP`
        fi
    fi
    if [ "${LOCALIPARRAY}" = "" ]
    then
        echo "Failed to obtain the IP address, Please configure the host IP."
        Log "Failed to obtain the IP address, installation aborted."
        return 1
    fi   

    local strNotice="Please select the IP address on the service management plane, and enter the serial number.(This IP address is used to interconnect with service systems, such as hosts, storage, OpenStack, and vCenter.)"
    getUserInputPlane "$strNotice"
    [ $? -ne 0 ] && return 1
    
    TaskManageIP=$ManageIP
    Log "Set plane IP($ManageIP) successfully!"
    return 0
}

function DeleteTaskManageIp() #打印除业务平面网卡上绑定的IP之外的IP
{
    local TaskManagedIp=$1
    local exist_falg=0
    LOCALIPARRAY=`getLocalIpAddr`
    getAdapterInfoByIp "$TaskManagedIp"
    local ManagedNetEthIps=`ip addr show "$NetAdapter" | grep "inet " |awk '{print $2}' | awk -F "/" '{print $1}'`

    for ip in $LOCALIPARRAY
    do
        getAdapterInfoByIp "$ip"
        [ "$NetAdapterMac" = "" ] && continue
        for taskIp in $ManagedNetEthIps
        do
            if [ "$ip" = "$taskIp" ]; then
                Log "Delete the $taskIp...task managed ip bind on this ip's netcard."
                exist_falg=1
                break;
            fi
        done
        
        if [ $exist_falg -eq 1 ]; then
            exist_falg=0
            continue
        fi
        echo "$ip"
    done
}

function SetRunManagePlaneIp()#运维IP设置
{
    local LOCALIPARRAY=`DeleteTaskManageIp $TaskManageIP`
    if [ "${LOCALIPARRAY}" = "" ]
    then
        echo "Failed to obtain the IP addresses. This may be caused by no available NIC on the host. Please configure a NIC."
        Log "Failed to obtain the IP addresses. This may be caused by no available NIC on the host. Please configure a NIC."
        exit 1
    fi 
    
    local PrintPlane="Please select the IP address on the O&M management plane, and enter the serial number.(This IP address is used to interconnect with the unified O&M management platform, for example, ManageOne OC.)"
    getUserInputPlane "$PrintPlane" 
    [ $? -ne 0 ] && return 1
    
    RunManageIP=$ManageIP
    Log "Set plane IP($IP) successfully!"
    return 0    
}

function CheckRunManagePlaneFlag()
{
    local InstallTmpFlagFile="/tmp/RunPlanTmp"
    if [ -f "$InstallTmpFlagFile" ]; then   #初次安装的标志是一个临时文件
        cat "$InstallTmpFlagFile" | grep "true" >> "$LOG_FILE_NAME" 2>&1
        if [ $? -eq 0 ]; then   
            rm -rf "/tmp/RunPlanTmp"
            return 0                 #初次安装并且需要设置运维管理平面 floatip
        fi
        rm -rf "/tmp/RunPlanTmp" >> "LOG_FILE_NAME" 2>&1
    fi
    local HA_properties="$COMM_SCRIPTDIR/../ha/local/conf/ha.properties"
    [ ! -f "$HA_properties" ] && return 1
    local SetRunPlaneFlag=`cat "$HA_properties" | grep "BCMManagementPlane" | awk -F "=" '{print $2}' | awk -F "|" '{print $1}'`
    if [ "$SetRunPlaneFlag" = "" ] || [ "$SetRunPlaneFlag" = "127.0.0.1" ]; then
        return 1
    fi
    Log "CheckRunManagePlaneFlag: $SetRunPlaneFlag, will set Run plane."
    return 0
}

######################################################################
#   DESCRIPTION: 检查网关是否配置在本地IP上 
#   RETURN     : 无
#   CHANGE DIR : 无
######################################################################
function isLocalIp()
{
    local ip_list=$(ip addr show | grep -ow "$1");ret=$?
    if [[ $ret -ne 0 ]]; then
        return $ret
    fi
    
    for ip in $ip_list
    do
        if [[ "$ip" = "$1" ]]; then
            return 0
        fi
    done

    return 1
}

function GetUserInputMonitorIP()
{
    local planeName="$1"
    local strNotice="$2"
    while [ 1 ]
    do
        echo "$strNotice"
        FloatIP=""
        read FloatIP
        isLocalIp "${FloatIP}"
        if [ $? -ne 0 ]
        then 
            echoInfo "ERROR: The IP adress is not the local IP."
            echo "Please try again."
            echo -ne "\n"
            sleep 1
            continue              
        fi
        validIP "${FloatIP}" 
        if [ $? -ne 0 ]
        then
            echoInfo "ERROR: Your input is invalid."
            echo "Please try again."
            echo -ne "\n"  
            sleep 1            
            continue
        fi
        
        if [ "$planeName" = "RunPlane" ]; then
            if [ "$TaskPlaneFloatIp" = "$FloatIP" ]; then
                echoInfo "ERROR: The monitor IP address of the O&M management plane must be different from that of the service management plane."
                echo "Please try again."
                echo -ne "\n"  
                sleep 1     
                continue
            fi
        fi
        
        echo -ne "\n"
        break
    done    
        
    return 0
}

function ip2Integer()  
{  
    echo $1 | awk '{c=256;split($0,ip,".");print ip[4]+ip[3]*c+ip[2]*c^2+ip[1]*c^3}'  
}

function GetUserInputFloatIP()
{
    local planeName="$1"
    local strNotice="$2"
    while [ 1 ]
    do
        echo "$strNotice"
        FloatIP=""
        read FloatIP
        isLocalIp "${FloatIP}"
        if [ $? -eq 0 ]
        then 
            echoInfo "ERROR: Local IP addresses cannot be used as floating IP addresses."
            echo "Please try again."
            echo -ne "\n"
            sleep 1
            continue              
        fi
        validIP "${FloatIP}" 
        if [ $? -ne 0 ]
        then
            echoInfo "ERROR: Your input is invalid."
            echo "Please try again."
            echo -ne "\n"  
            sleep 1            
            continue
        fi
        
        local HA_properties="$COMM_SCRIPTDIR/../ha/local/conf/ha.properties"
        if [ -f "$HA_properties" ];then
            if [ "$1" = "TaskPlane" ];then            
                G_LISTENER_IP=$G_TaskManageIP
                if [ -z "$G_LISTENER_IP" ];then
                    G_LISTENER_IP=`cat "$HA_properties"| grep "BCMProductManagementPlane" | awk -F "=" '{print $2}' | awk -F "|" '{ print $1 }'`
                fi
                listener_net_mask=`ifconfig | grep "$G_LISTENER_IP" | awk -F ":" '{ print $4 }'`
            fi
                
            if [ "$1" = "RunPlane" ];then
                G_LISTENER_IP=$G_RunManageIP
                if [ -z "$G_LISTENER_IP" ];then
                    G_LISTENER_IP=`cat "$HA_properties"| grep "BCMManagementPlane" | awk -F "=" '{print $2}' | awk -F "|" '{ print $1 }'`
                fi
                listener_net_mask=`ifconfig | grep "$G_LISTENER_IP" | awk -F ":" '{ print $4 }'`
            fi
        else
            local ConfigXml="$COMM_SCRIPTDIR/../../config/config.xml"
            if [ "$1" = "TaskPlane" ];then            
                G_LISTENER_IP=`grep "ipaddress=" "$ConfigXml" | grep systemip | awk -F\" '{ print $2 }'`
                listener_net_mask=`ifconfig | grep "$G_LISTENER_IP" | awk -F ":" '{ print $4 }'`        
            fi
                
            if [ "$1" = "RunPlane" ];then
                G_LISTENER_IP=`grep "ipaddress=" "$ConfigXml" | grep runmanagerip | awk -F\" '{ print $2 }'`
                listener_net_mask=`ifconfig | grep "$G_LISTENER_IP" | awk -F ":" '{ print $4 }'`
            fi
        fi    
               
        local nfIP=$(ip2Integer $FloatIP)
        local nmask=$(ip2Integer $listener_net_mask)
        local nlIP=$(ip2Integer $G_LISTENER_IP)
        
        if [ $(($nfIP & $nmask)) -ne $(($nlIP & $nmask)) ];then
            Log "[Error] floatIP $FloatIP and G_LISTENER_IP $G_LISTENER_IP is not in same subnet segment."
            echoInfo "ERROR: The floating IP address and the system communication IP address must fall within the same network segment."
            echo "Please try again."
            echo -ne "\n"
            sleep 1 
            continue 
        fi
    
        if [ "$planeName" = "RunPlane" ]; then
            if [ "$TaskPlaneFloatIp" = "$FloatIP" ]; then
                echoInfo "ERROR: The floating IP address of the O&M management plane must be different from that of the service management plane."
                echo "Please try again."
                echo -ne "\n"  
                sleep 1     
                continue
            fi
        fi
        
        echo -ne "\n"
        break
    done    
        
    return 0
}

######################################################################
#   DESCRIPTION: 设置网络平面
#   RETURN     : 无
#   CHANGE DIR : 无
######################################################################
function SetPlane()
{
    if [ "$1" = "install" ]; then   #安装的时候
        SetTaskManagePlaneIp
        [ $? -eq 1 ] && return 1
        getUserInputPort "TaskManagePlane" "false"
        [ $? -eq 1 ] && return 1
        TaskManagePort=$Port
        TaskPlanePort=$TaskManagePort
        changeTomecatFlag="true"
        while [ 1 ]
        do 
            echo -n "Do you want to enable the O&M management plane? (y/n): [n]"
            read choice
            [ "$choice" = "" ] && choice="n"
            if [ "$choice" = "n" ] || [ "$choice" = "no" ] || [ "$choice" = "No" ] || [ "$choice" = "NO" ] 
            then
                Log "not set run managed plane IP!"
                isUseTheRunManagePlane="false"
                changeTomecatFlag="false"
                echo "isUseTheRunManagePlane=false" > "/tmp/RunPlanTmp"
                showCurrentPlaneSetting "$TaskManageIP" #设置完成后立即显示平面设置内容
                G_TaskManageIP="$TaskManageIP"
                G_TaskPlaneInfo="$G_TaskManageIP|$NetAdapterMac"
                return 1
            fi
            if [ "$choice" = "y" ] || [ "$choice" = "Y" ] || [ "$choice" = "yes" ] || [ "$choice" = "Yes" ] || [ "$choice" = "YES" ]
            then
                break
            fi
            
            echoInfo "ERROR: Your input is invalid."
            echo "Please try again."
            echo -ne "\n"
            sleep 1
        done
        isUseTheRunManagePlane="true"
        touch "/tmp/RunPlanTmp"
        echo "isUseTheRunManagePlane=true" > "/tmp/RunPlanTmp"
        
        SetRunManagePlaneIp
        [ $? -eq 1 ] && return 1
        getUserInputPort "RunManagePlane" "true"
        [ $? -eq 1 ] && return 1
        RunManagePort=$Port
        RunPlanePort=$RunManagePort
        showCurrentPlaneSetting "$TaskManageIP" "$RunManageIP"  #设置完成后立即显示平面设置内容
        G_TaskManageIP="$TaskManageIP"
        G_TaskPlaneInfo="$G_TaskManageIP|$NetAdapterMac"
        G_RunManageIP="$RunManageIP"
        G_RunPlaneInfo="$G_RunManageIP|$NetAdapterMac" 
    else      #更改的时候
        showCurrentPlaneSetting
        TaskManageIP=`cat "$ha_properties" | grep "BCMProductManagementPlane" | awk -F "=" '{print $2}' | awk -F "|" '{print $1}'`
        echo "Do you want to modify the network plane information? (Enter y for yes or another letter for no.) (y/n):"
        read choice
        [ "$choice" = "" ] && choice="n"
        if [ "$choice" = "y" ] || [ "$choice" = "yes" ] || [ "$choice" = "Y" ] || [ "$choice" = "YES" ] || [ "$choice" = "Yes" ]
        then  
            if [ "$G_RunManageIP" = "" ]; then
                local RunManagePlane=`cat "$ha_properties" | grep "BCMManagementPlane" | awk -F "=" '{print $2}'`
                G_RunManageIP=`echo "$RunManagePlane" | awk -F "|" '{print $1}'`
            fi
            RunManageIP="$G_RunManageIP"
            SetTaskManagePlaneIp config 
            [ $? -eq 1 ] && return 1
            G_TaskManageIP="$TaskManageIP"
            getAdapterInfoByIp "$G_TaskManageIP"          
            showCurrentPlaneSetting "$G_TaskManageIP" "$G_RunManageIP"
            G_TaskPlaneInfo="$G_TaskManageIP|$NetAdapterMac"
            Log "Set TaskPlaneInfo($TaskPlaneInfo) success"
            
            
            local L_RunManagePlane=`cat "$ha_properties" | grep "BCMManagementPlane" | awk -F "=" '{print $2}'`
            local L_RunManageIP=`echo "$L_RunManagePlane" | awk -F "|" '{print $1}'`
            if [ ! -z "$L_RunManageIP" ];then
                SetRunManagePlaneIp
                [ $? -eq 1 ] && return 1
                G_RunManageIP="$RunManageIP"
                getAdapterInfoByIp "$G_TaskManageIP"
                if [ "$G_TaskManageIP" = "" ]; then
                    local TaskMangePlane=`cat "$ha_properties" | grep "BCMProductManagementPlane" | awk -F "=" '{print $2}'`
                    G_TaskManageIP=`echo "$TaskMangePlane" | awk -F "|" '{print $1}'`
                fi   
                TaskManageIP="$G_TaskManageIP"
                showCurrentPlaneSetting "$G_TaskManageIP" "$G_RunManageIP"
                G_RunPlaneInfo="$G_RunManageIP|$NetAdapterMac"            
                Log "Set RunPlaneInfo($RunPlaneInfo) success"
            fi                 
        else 
            return 0    
        fi    
    fi
    return 0
}

######################################################################
#   DESCRIPTION: 设置浮动IP
#   RETURN     : 无
#   CHANGE DIR : 无
######################################################################
function InPutPlaneFloatIp()
{
    echo "Please enter the service management floating IP address. This IP address will replace the service management IP address for service management."
    GetUserInputFloatIP "TaskPlane"
    [ $? -ne 0 ] && return 1
    TaskPlaneFloatIp="$FloatIP"

    CheckRunManagePlaneFlag
    if [ $? -eq 0 ]; then
        echo "Please enter the O&M management floating IP address. This IP address will replace the O&M management IP address for O&M management."
        GetUserInputFloatIP "RunPlane"
        [ $? -ne 0 ] && return 1
        RunPlaneFloatIp="$FloatIP"
    fi
    return 0 
}
######################################################################
#   DESCRIPTION: 获取单机模式下监听IP
#   RETURN     : 无
#   CHANGE DIR : 无
######################################################################
function InPutPlaneMonitorIp()
{
    echo "Please enter the service management monitor IP address. This IP address will replace the service management IP address for service management."
    GetUserInputMonitorIP "TaskPlane"
    [ $? -ne 0 ] && return 1
    TaskPlaneFloatIp="$FloatIP"

    if [ x"$isUseTheRunManagePlane" = x"true" ];then
        echo "Please enter the O&M management monitor IP address. This IP address will replace the O&M management IP address for O&M management."
        GetUserInputMonitorIP "RunPlane"
        [ $? -ne 0 ] && return 1
        RunPlaneFloatIp="$FloatIP"
    fi
    return 0 
}


function SetServiceManagerXmlFloatIP()
{
    cat "$1" | grep "serviceManager.*floatIp" > /dev/null
    if [ $? -ne 0 ]
    then
        sed -i "s#serviceManager#serviceManager floatIp=\"$TaskPlaneFloatIp\"#g" "$1"
    else 
        tmpstr=`cat "$1" | grep serviceManager | awk -F 'floatIp=\"' '{print $2}' | awk -F\" '{print $1}'`       
        local Line=`grep -n "serviceManager" "$1" | awk -F ":" '{ print $1 }'`
        if [ -z $tmpstr ]
        then            
            sed -i ""$Line"s/floatIp=\"\"/floatIp=\"$TaskPlaneFloatIp\"/g" "$1"
        else
            sed -i ""$Line"s/$tmpstr/$TaskPlaneFloatIp/g" "$1"
        fi
    fi
}

function SetOManagerXmlFloatIP()
{
    cat "$1" | grep "OManager.*floatIp" > /dev/null
    if [ $? -ne 0 ]
    then
        sed -i "s#OManager#OManager floatIp=\"$RunPlaneFloatIp\"#g" "$1"
    else 
        tmpstr=`cat "$1" | grep OManager | awk -F 'floatIp=\"' '{print $2}' | awk -F\" '{print $1}'`
        local Line=`grep -n "OManager" "$1" | awk -F ":" '{ print $1 }'`
        if [ -z $tmpstr ]
        then
            sed -i ""$Line"s/floatIp=\"\"/floatIp=\"$RunPlaneFloatIp\"/g" "$1"
        else
            sed -i ""$Line"s/$tmpstr/$RunPlaneFloatIp/g" "$1"
        fi
    fi
}

function SetServiceManagerXmlip()
{
    cat "$1" | grep "serviceManager.*ip" > /dev/null
    if [ $? -ne 0 ]
    then
        sed -i "s#serviceManager#serviceManager ip=\"$TaskPlaneIp\"#g" "$1"
    else 
        tmpstr=`cat "$1" | grep serviceManager | awk -F 'ip=\"' '{print $2}' | awk -F\" '{print $1}'`
        local Line=`grep -n serviceManager "$1" | awk -F ":" '{ print $1 }'`
        if [ -z $tmpstr ]
        then            
            sed -i ""$Line"s/ip=\"\"/ip=\"$TaskPlaneIp\"/g" "$1"
        else
            sed -i ""$Line"s/$tmpstr/$TaskPlaneIp/g" "$1"
        fi
    fi
}

function SetOManagerXmlip()
{
    cat "$1" | grep "OManager.*ip" > /dev/null
    if [ $? -ne 0 ]
    then
        sed -i "s#OManager#OManager ip=\"$RunPlaneIp\"#g" "$1"
    else 
        tmpstr=`cat "$1" | grep OManager | awk -F 'ip=\"' '{print $2}' | awk -F\" '{print $1}'`
        local Line=`grep -n OManager "$1" | awk -F ":" '{ print $1 }'`
        if [ -z $tmpstr ]
        then
            sed -i ""$Line"s/ip=\"\"/ip=\"$RunPlaneIp\"/g" "$1"
        else
            sed -i ""$Line"s/$tmpstr/$RunPlaneIp/g" "$1"
        fi
    fi
}

function CheckFileExist()
{
    if [ ! -f "$1" ]
    then
        Log "[Error] $1 is not exist, Configure HA failed."
        echoInfo "ERROR: $1 is not exist,Configure HA failed."
        exit 1
    fi
}

######################################################################
#   DESCRIPTION: 设置单机模式下监听IP
#   RETURN     : 无
#   CHANGE DIR : 无
######################################################################
function SetRDInstallXmlIP()
{
    local BCMICUserConfigMonitorIPFile="/home/ICUser/RDInstalled.xml"
    local BCMRDConfigMonitorIPFile="${COMM_BCMANAGER_PATH}/Runtime/bin/RDInstalled.xml"
    local BCMMonConfigMonitorIPFile="${COMM_BCMANAGER_PATH}/Runtime/monitor/RDInstalled.xml"
    CheckFileExist "${BCMICUserConfigMonitorIPFile}"
    CheckFileExist "${BCMRDConfigMonitorIPFile}"
    CheckFileExist "${BCMMonConfigMonitorIPFile}"
    Log "Begin set the monitor IP of eReplication Server."

    SetServiceManagerXmlip $BCMICUserConfigMonitorIPFile
    SetServiceManagerXmlip $BCMRDConfigMonitorIPFile
    SetServiceManagerXmlip $BCMMonConfigMonitorIPFile
    
    if [ ! -z $RunPlaneIp ];then     
        SetOManagerXmlip $BCMICUserConfigMonitorIPFile
        SetOManagerXmlip $BCMRDConfigMonitorIPFile 
        SetOManagerXmlip $BCMMonConfigMonitorIPFile
    fi    
}

######################################################################
#   DESCRIPTION: 设置双机模式下Xml文件的浮动IP
#   RETURN     : 无
#   CHANGE DIR : 无
######################################################################
function SetRDInstallXmlFloatIP()
{
    local BCMICUserConfigMonitorIPFile="/home/ICUser/RDInstalled.xml"
    local BCMRDConfigMonitorIPFile="${COMM_BCMANAGER_PATH}/Runtime/bin/RDInstalled.xml"
    local BCMMonConfigMonitorIPFile="${COMM_BCMANAGER_PATH}/Runtime/monitor/RDInstalled.xml"
    CheckFileExist "${BCMICUserConfigMonitorIPFile}"
    CheckFileExist "${BCMRDConfigMonitorIPFile}"
    CheckFileExist "${BCMMonConfigMonitorIPFile}"
    Log "Begin set the Float IP of eReplication Server."

    SetServiceManagerXmlFloatIP "$BCMICUserConfigMonitorIPFile"
    SetServiceManagerXmlFloatIP "$BCMRDConfigMonitorIPFile"  
    SetServiceManagerXmlFloatIP "$BCMMonConfigMonitorIPFile"
    
    if [ ! -z $RunPlaneFloatIp ];then      
        SetOManagerXmlFloatIP "$BCMICUserConfigMonitorIPFile"
        SetOManagerXmlFloatIP "$BCMRDConfigMonitorIPFile"  
        SetOManagerXmlFloatIP "$BCMMonConfigMonitorIPFile"
    fi        
}



######################################################################
#   DESCRIPTION: 设置Tomcat监听IP
#   RETURN     : 无
#   CHANGE DIR : 无
######################################################################
function SetTomecatListenIp()
{ 
   local TomcatConfFile="$COMM_SCRIPTDIR/../Tomcat6/conf/server.xml"
    if [ ! -f "$TomcatConfFile" ]; then
        echo "Tomcat6/conf/server.xml is missed."
        Log "changeTomecatListenIp: Tomcat6/conf/server.xml is missed."
        exit 1
    fi
    
    local PlaneFloatIpSetting=`cat "$TomcatConfFile" | grep -n "address="`
    local PlaneFloatIpSettingLine=`cat "$TomcatConfFile" | grep -n "address=" | awk -F ":" '{print $1}'`
 
    ######   TaskManagePlaneFloatWrite
    local TaskPlaneFloatIpXmlHeadLine=`cat "$TomcatConfFile" | grep -n -ow "<Service name=\"Catalina\">" | awk -F ":" '{print $1}'`  #xml格式头
    local TaskPlaneFloatIpXmlTailLine=`cat "$TomcatConfFile" | grep -n -ow "<\/Service>" | awk -F ":" '{print $1}' | sed -n "1p"`   #xml格式尾
    if [ "$TaskPlaneFloatIpXmlHeadLine" = "" ] || [ "$TaskPlaneFloatIpXmlTailLine" = "" ]; then
        Log "Error: TaskPlaneFloatIpXmlHeadLine is NULL or TaskPlaneFloatIpXmlTailLine is NULL, cannot find this line."
        exit 1
    fi
    if [ $TaskPlaneFloatIpXmlTailLine -lt $TaskPlaneFloatIpXmlHeadLine ]; then
        TaskPlaneFloatIpXmlTailLine=`cat "$TomcatConfFile" | grep -n -ow "<\/Service>" | awk -F ":" '{print $1}' | sed -n "2p"`   #xml格式尾
    fi
    
    for line in $PlaneFloatIpSettingLine
    do
        if [ $line -gt $TaskPlaneFloatIpXmlHeadLine ] && [ $line -lt $TaskPlaneFloatIpXmlTailLine ]; then
            Log "line: $line"
            sed -i ""$line"s/address=\".*\"/address=\"$TaskPlaneFloatIp\"/" "$TomcatConfFile"
        fi
    done
    
    CheckRunManagePlaneFlag
    [ $? -ne 0 ] && return 1
    
    ######   RunManagePlaneFloatWrite
    local RunPlaneFloatIpXmlHeadLine=`cat "$TomcatConfFile" | grep -n -ow "<Service name=\"Catalina_OM\">" | awk -F ":" '{print $1}'`  #xml格式头
    local RunPlaneFloatIpXmlTailLine=`cat "$TomcatConfFile" | grep -n -ow "<\/Service>" | awk -F ":" '{print $1}' | sed -n "1p"`   #xml格式尾
    if [ "$RunPlaneFloatIpXmlHeadLine" = "" ] || [ "$RunPlaneFloatIpXmlTailLine" = "" ]; then
        Log "Error: TaskPlaneFloatIpXmlHeadLine is NULL or TaskPlaneFloatIpXmlTailLine is NULL, cannot find this line."
        exit 1
    fi
    if [ $RunPlaneFloatIpXmlTailLine -lt $RunPlaneFloatIpXmlHeadLine ]; then
        RunPlaneFloatIpXmlTailLine=`cat "$TomcatConfFile" | grep -n -ow "<\/Service>" | awk -F ":" '{print $1}' | sed -n "2p"`   #xml格式尾
    fi
    
    for line_2 in $PlaneFloatIpSettingLine
    do
        if [ $line_2 -gt $RunPlaneFloatIpXmlHeadLine ] && [ $line_2 -lt $RunPlaneFloatIpXmlTailLine ]; then
            Log "line_2: $line_2"
            sed -i ""$line_2"s/address=\".*\"/address=\"$RunPlaneFloatIp\"/" "$TomcatConfFile"
        fi
    done

    return 0 
}

function getYesOrNo
{
    local L_YES_NO=""
    read L_YES_NO
    L_YES_NO="$(echo $L_YES_NO | tr '[:upper:]' '[:lower:]')"
    while [ "$L_YES_NO" != "yes" ] && [ "$L_YES_NO" != "no" ] && [ "$L_YES_NO" != "y" ] && [ "$L_YES_NO" != "n" ]
    do
        echo "Please input yes or no"
        read L_YES_NO
        L_YES_NO="$(echo $L_YES_NO | tr '[:upper:]' '[:lower:]')"
    done
    
    if [ "$L_YES_NO" == "yes" ] || [ "$L_YES_NO" == "y" ]
    then
        return 0
    else
        return 1
    fi
}
