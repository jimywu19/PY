#!/bin/bash 

LOGMAXSIZE=4096
alias LOG_INFO='loginner [INFO ] [$$] [$(basename ${BASH_SOURCE}):${LINENO}]'
alias LOG_WARN='loginner [WARN ] [$$] [$(basename ${BASH_SOURCE}):${LINENO}]'
alias LOG_ERROR='loginner [ERROR] [$$] [$(basename ${BASH_SOURCE}):${LINENO}]'
alias ECHOANDLOG_INFO='echoAndLog "[INFO ]" [$$]  "[$(basename ${BASH_SOURCE}):${LINENO}]"'
alias ECHOANDLOG_WARN='echoAndLog "[WARN ]" [$$] "[$(basename ${BASH_SOURCE}):${LINENO}]"'
alias ECHOANDLOG_ERROR='echoAndLog "[ERROR]" [$$] "[$(basename ${BASH_SOURCE}):${LINENO}]"'
alias DIE_LOG_ERROR='echoAndLog "[ERROR]" [$$] '
shopt -s expand_aliases


STATUS_OK=0
STATUS_NOT_OK=1

. /etc/profile 2>/dev/null

. $HA_DIR/tools/func/globalvar.sh || { echo "load $HA_DIR/tools/func/globalvar.sh failed."; exit 1; }

######################################################################
#ok1
#   FUNCTION   : log
#   DESCRIPTION: 按照一定的格式记录日志
#   CALLS      : 无
#   CALLED BY  : 需要打印日志的函数
#   INPUT      : 参数1：        日志要打印的内容
#                参数2：        日志打印的形式：0.函数开始  1.函数结尾  其他.函数中间
#                参数3：        要记录的日志文件对应的变量的前缀
#   OUTPUT     : 打印格式日志
#   LOCAL VAR  : logFile        完整的日志文件名
######################################################################
# 定义打印日志的函数
loginner()
{
    local  logsize=0
    local  logFile=${LOG_FILE}
    if [ -e "$logFile" ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S,%N %z')] $*" >> $logFile
    else
        touch $logFile
        chmod 600 $logFile    
    fi
}

######################################################################
#ok1
#   FUNCTION   : echoAndLog
#   DESCRIPTION: 打印到控制台并记录到日志文件中
#   CALLS      : 无
#   CALLED BY  : main
#   INPUT      : 无
#   RETURN     : 无
#   CHANGE DIR : 无
######################################################################
echoAndLog()
{
    # 打印日志
    loginner "$*"
    local level=$1
    shift 3
    echo "$level $*"
}

die()
{
    local pos="$1"
    shift
    DIE_LOG_ERROR "$pos " "$*"
    exit 1
}

checkUserRoot()
{
    local dest="root"
    
    if [ "$(whoami)" != "$dest" ];then
        echo "It must use 'root' to run the script."
        exit 1
    fi
    
    return 0
}

########################################################################################
#
#   检查主机名合法性，大小写字母，连字符，数字，必须字母开头，最多32个字符
#
########################################################################################
checkHostnameValid()
{
    local host="$1"
    
    if [ -z "$host" ]; then
        ECHOANDLOG_ERROR "hostname can't be empty"
        return 1
    fi
    
    if ! echo "$host" | grep "^[a-zA-Z_][0-9a-zA-Z_\-]*$" > /dev/null; then
        ECHOANDLOG_ERROR "The node name must begin with a letter or underscore and can contain only letters, numbers, hyphens, and underscores."
        return 1
    fi
    
    local MAX_CHARS_NUM=32
    local -i num=$(echo -ne "$host" | wc -c)
    if [ $num -gt $MAX_CHARS_NUM ];then
        ECHOANDLOG_ERROR "hostname must less than $MAX_CHARS_NUM characters"
        return 1
    fi
    
    return 0
}

########################################################################################
#
# 检查IP合法性
#
########################################################################################
checkIp()
{
    local ip="$1"
    ip=$(echo $ip)
    if [ -z "$ip" ];then
        ECHOANDLOG_ERROR "the ip is empty"
        return 1
    fi
    
    #add for adapting ipv6
    if [ -z "$IP_TYPE" ] ||  [ "IPV4" == "$IP_TYPE" ]; then    
        if ! echo "$ip" | grep -wq "^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}$" ; then
            ECHOANDLOG_ERROR "the ip is invalid"
            return 1
        fi
    
        local i=0
        local -i ipSeg=0
        for ((i=1; i <= 4; i++)); do
            ipSeg=$(echo "$ip" | awk -F. '{print $i}' "i=$i")
            if [ $ipSeg -gt 255 ] || [ $ipSeg -lt 0 ]; then
                ECHOANDLOG_ERROR "the ip:$ip invalid"
                return 1
            fi
        done
        
        return 0
    else
        ipcalc -6 -c $ip
        ret1=$?
        if [ 0 -ne "$ret1" ];then
            ECHOANDLOG_ERROR "the ip $ip is invalid"
            return 1
        fi

        return 0
    fi
}

########################################################################################
#
# 检查掩码合法性
########################################################################################
checkMask()
{   
    #add for adapting ipv6
    if [ -z "$IP_TYPE" ] ||  [ "IPV4" == "$IP_TYPE" ]; then
        # 不是XXX.XXX.XXX.XXX形式，则返回失败
        if [ -z "`echo $1 | grep -w \"^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}$\"`" ]; then
            return 1
        else
            local -i rc=0      # 本函数返回码
            local masks=`echo $1 | tr '.' ' '`       # 存取IP的所有节点
            local mask             # 存取IP的每一个节点
            
            local maskOK=y         # $maskOK为y，则下个节点可以为255|254|252|248|240|224|192|128|0中的一个
                                # $maskOK为n，则下个节点只能为0
            local -i nodeRet=0     # 检查一个节点后的返回值
            local -i i=0
            for mask in $masks; do
                # $maskOK为y，当前节点可以为255|254|252|248|240|224|192|128|0中的一个
                if [ "$maskOK" = "y" ]; then
                    if [ $mask -eq 255 ]; then
                        continue     # 节点为255，则继续检查下一个
                    elif [ -n "`echo $mask | grep -E \"^254|252|248|240|224|192|128|0$\"`" ]; then
                        maskOK=n     # 节点为254|252|248|240|224|192|128|0，则后续节点只能为0
                        continue
                    else
                        rc=1
                        break
                    fi
                
                # $maskOK为n，当前节点只能为0
                else
                    if [ $mask -eq 0 ]; then
                        continue
                    else
                        rc=1
                        break
                    fi
                fi
            done
        fi
        
        return $rc
    else
        prefix=`echo $1`
        var1=`expr $prefix + 0` || { echo "func.sh Args must be integer";exit 1;}
        if [ 0 -ne $? ];then
            return 1
        fi
        
        return $rc
    fi
}

########################################################################################
#
# 检查掩码合法性
########################################################################################
getNetworkSeg()
{
    local ip="$1"
    local mask="$2"
    
    #add for adapting ipv6
    if [ -z "$IP_TYPE" ] ||  [ "IPV4" == "$IP_TYPE" ]; then 
        # 不是XXX.XXX.XXX.XXX形式，则返回失败
        if [ -z "`echo $ip | grep -w \"^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}$\"`" ]; then
            return 1
        fi
        
        if [ -z "`echo $mask | grep -w \"^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}$\"`" ]; then
            return 1
        fi
        
        local ips=`echo $ip | tr '.' ' '`       # 存取IP的所有节点
    
        local i=1
        local network=""
        for ipSeg in $ips; do
            local maskSeg=$(echo "$mask" | awk -F'.' '{print $i}' "i=$i")
            ((net=ipSeg&maskSeg))
            network="${network}.${net}"
            ((++i))
        done
    
        iMask=$(echo "obase=2;$mask" | sed 's/\./;/g' | bc | paste -s -d '' | grep -E '^1[1]*[0]*$' | grep -o '1' | wc -l)
        echo "$network/$iMask" | sed 's/^\.//'
    else
        ipcalc -6 -c $ip
        ret1=$?
        prefix=`echo $mask`
        var1=`expr $prefix + 0` || { echo "func.sh Args must be integer";exit 1;}
        ret2=$?
        
        if [ 0 -ne "$ret1" ] || [ 0 -ne "$ret2" ]; then
            ECHOANDLOG_ERROR "invalid ip $ip prefix_len $mask"
            return 1
        fi
    
        #prefix_ipv6=`ifconfig -a | grep inet6 | grep -v "::1" | grep "$ip" | awk '{print $4}' | head -1 `
        echo "$ip/$prefix"
    fi
}

########################################################################################
#
# 使用掩码检查IP合法性
#
########################################################################################
checkIpWithMask()
{
    local ip="$1"
    local mask="$2"
    
    local ipInfo=""
            
    #add for adapting ipv6
    if [ -z "$IP_TYPE" ] ||  [ "IPV4" == "$IP_TYPE" ]; then 
        #修改适配EulerOS,IPV6不存在广播地址概念
        ipInfo=$(ipcalc -b "$ip" "$mask")
        local broadCast=$(echo "$ipInfo" | grep "^Broadcast" | awk -F= '{print $2}')
    
        # 检查IP是否与广播IP冲突
        if [ "$ip" == "$broadCast" ];then
            ECHOANDLOG_ERROR "invalid ip:$ip, the ip cann't == Broadcast"
            return 1
        fi
    fi
}


########################################################################################
#
# 使用掩码检查IP合法性
#
########################################################################################
checkIpAndGateway()
{
    local ip="$1"
    local mask="$2"
    
    #add for adapting ipv6 适配EulerOS
    if [ -z "$IP_TYPE" ] ||  [ "IPV4" == "$IP_TYPE" ]; then
        local getway=$(echo "$3"|sed 's/ *$//g'|sed 's/^ *//g')
        local ipInfo=""
        ipInfo=$(ipcalc -n "$getway" "$mask")
        local broadCast=$(echo "$ipInfo" | grep "^Broadcast" | awk -F= '{print $2}')   
    
        # 检查getway是否与广播IP冲突
        if [ "$getway" == "$broadCast" ];then
            ECHOANDLOG_ERROR "invalid getway:$getway, the getway cann't == Broadcast"
            return 1
        fi
        
        # 获取网段
        local network=$(echo "$ipInfo" | grep "^Network" | awk -F= '{print $2}')
        local network2=$(ipcalc -n "$ip" "$mask" | grep "^Network" | awk -F= '{print $2}')
        
        # IP与网关不同网段
        if [ "$network" != "$network2" ];then
            ECHOANDLOG_ERROR "the getway($getway/$mask) and IP($ip/$mask) are not in same network"
            return 1
        fi
    fi
}

checkIps()
{
    local ip="$1"
    local mask="$2"
    local getway="$3"
    
    checkIp "$ip" || return 1
    checkMask "$mask" || return 1

    if [ "$getway" != "255.255.255.255" ];then
        checkIp "$getway" || return 1
    fi
}

#
getIpsByType()
{
    local prefix="$1"
    local type="$2"
    eval "echo \\\"$"${prefix}${type}_IP"\\\" \\\"$"${prefix}${type}_MASK"\\\" \\\"$"${prefix}${type}_GW"\\\" "
}

getIpParasByType()
{
    local prefix="$1"
    local type="$2"
    eval " echo ${prefix}${type}_IP ${prefix}${type}_MASK ${prefix}${type}_GW "
}

savePara2NetworkConf()
{
    local key=$1
    local cfgFile=$2
    local value=""
    
    eval "value=\$$key"
    
    if grep "^$key=" "$cfgFile"> /dev/null; then
        sed -i "s/^$key=.*$/$key=$value/" $cfgFile
    else
        echo "$key=$value" >> $cfgFile
    fi
}

saveIps2NetworkConf()
{
    local key=""
    for key in $@;do
        savePara2NetworkConf "$key" "$NETWORK_CONF"
    done
}

check_ip_connect()
{
    local ip="$1"
    [ -n "$ip" ] || return 1
    
    #add for adapting ipv6
    if [ -z "$IP_TYPE" ] ||  [ "IPV4" == "$IP_TYPE" ]; then
        switch_lost_rate=$(ping -c 2 -i 0.5 -w 1 ${ip} | grep 'packet loss' | awk -F'packet loss' '{print $1}' | awk '{print $NF}' | sed 's/%//g')
        LOG_INFO "for ip:${ip}, switch_lost_rate=${switch_lost_rate}"
        if [ "-${switch_lost_rate}" = "-100" -o "-${switch_lost_rate}" = "-" ]; then
            return 1
        fi
    else
        switch_lost_rate=$(ping6 -c 2 -i 0.5 -w 1 ${ip} | grep 'packet loss' | awk -F'packet loss' '{print $1}' | awk '{print $NF}' | sed 's/%//g')
        LOG_INFO "for ip:${ip}, switch_lost_rate=${switch_lost_rate}"
        if [ "-${switch_lost_rate}" = "-100" -o "-${switch_lost_rate}" = "-" ]; then
            return 1
        fi
    fi
    
    return 0
}

checkHaArbitrateIP()
{
    local ipList="$haArbitrateIP"
    
    if [ -z "$ipList" ];then
        LOG_WARN "haArbitrateIP:$haArbitrateIP is empty"
        return 0
    fi
    
    local -i retryPingCount="$1"
    
    local ifs="$IFS"
    IFS=","
    local ip=""
    
    local ret=1
    for ip in $ipList; do
        ip=$(echo $ip)
        if check_ip_connect "$ip" "$retryPingCount"; then
            LOG_INFO "ip:$ip is connect"
            ret=0
            break
        fi
        
        LOG_WARN "ip:$ip is not connect"
    done
    
    IFS="$ifs"
    
    return $ret
}

checkExfloatIpConnect()
{
    local ip="$FLOAT_GMN_EX_IP"
    local itf="$LOCAL_GMN_EX_INTF"
    
    checkIpExsitOnOther "$ip" "$itf" || return 1
    
    return 0
}

checkIpExsitOnOther()
{
    local ip="$1"
    local itf="$2"
    
    [ -n "$ip" ] || return 2
    [ -n "$itf" ] || return 3
    
    #add for adapting ipv6
    if [ -z "$IP_TYPE" ] ||  [ "IPV4" == "$IP_TYPE" ]; then
        if arping -w 1 -c 1 "$ip" -I "$itf"  >> $LOG_FILE; then
            LOG_WARN "arping -w 1 -c 1 "$ip" -I "$itf" return true"
            return 0
        fi
        
        LOG_INFO "arping -w 1 -c 1 "$ip" -I "$itf" return false"
        
        return 1
    else
        NDISC6="$(which ndisc6)"
        if $NDISC6 $ip $itf  >> $LOG_FILE; then
            LOG_WARN "$NDISC6 $ip $itf return true"
            return 0
        fi
        
        LOG_INFO "$NDISC6 $ip $itf return false"
        
        return 1
    fi
}

# 检测内网IP是否存在IP冲突，是：0 否：1
checkHeartbeatIpCollision()
{
    local ret=1
    
    if [ "$DEPLOY_MODE" == "1" ];then
        if checkIpExsitOnOther "$LOCAL_GMN_EX_IP" "$LOCAL_GMN_EX_INTF" ; then
            IP_COLLISION_LIST="$LOCAL_GMN_EX_IP"
            LOG_WARN "LOCAL_GMN_EX_IP:$LOCAL_GMN_EX_IP, LOCAL_GMN_EX_INTF:$LOCAL_GMN_EX_INTF is collision with another node"
            return 0
        fi
    else
        if checkIpExsitOnOther "$LOCAL_GMN_ESCAPE_IP" "$LOCAL_GMN_ESCAPE_INTF" ; then
            IP_COLLISION_LIST="$LOCAL_GMN_ESCAPE_IP"
            LOG_WARN "LOCAL_GMN_ESCAPE_IP:$LOCAL_GMN_ESCAPE_IP, LOCAL_GMN_ESCAPE_INTF:$LOCAL_GMN_ESCAPE_INTF is collision with another node"
            ret=0
        fi
        
        if checkIpExsitOnOther "$LOCAL_GMN_IN_IP" "$LOCAL_GMN_IN_INTF" ; then
            IP_COLLISION_LIST="$IP_COLLISION_LIST $LOCAL_GMN_IN_IP"
            LOG_WARN "LOCAL_GMN_IN_IP:$LOCAL_GMN_IN_IP, LOCAL_GMN_IN_INTF:$LOCAL_GMN_IN_INTF is collision with another node"
            ret=0
        fi
    fi
    
    return $ret
}

function check_network()
{
    # 1.check dual_mode==1
    if [ "-${DUALMODE}" = "-0" ]; then
        #in single mode, return
        LOG_INFO "check_network: not need to check, return STATUS_OK, reason: IN_SINGLE_MODE"
        return ${STATUS_OK}
    fi

    . $HA_DIR/tools/func/dblib.sh
    
    getDoubleConfig "$_CONF_FILE_"
    
    RETRY_PING_COUNT="$1"
    IS_CONNECT_PEER="no"

    local -i retryPingCount="$RETRY_PING_COUNT"
    if [ $retryPingCount -eq 0 ];then
        retryPingCount=3
    fi
    
    #access switch ok
    #2.check peeromip
    if [ "$DEPLOY_MODE" == "1" ];then
        LOG_INFO "check_network: step 2.0: check gmn ex ip connectivity, ip=${REMOTE_GMN_EX_IP}"
        if ! check_ip_connect "$REMOTE_GMN_EX_IP" "$retryPingCount"; then
            LOG_ERROR "check_network: can not access to gmn ex ip, try to check ha arbitrate ip"
            if checkHaArbitrateIP "$retryPingCount"; then
                if ! checkExfloatIpConnect; then
                    return ${STATUS_OK}
                else
                    return ${STATUS_NOT_OK}
                fi
            else
                LOG_ERROR "check_network: check ha arbitrate ip failed, return STATUS_NOT_OK"
                return ${STATUS_NOT_OK}
            fi
        fi
    else
        LOG_INFO "check_network: step 2.0: check gmn esc and gmn in ip connectivity, escIp=${REMOTE_GMN_ESCAPE_IP}, inIp=${REMOTE_GMN_IN_IP}"
        if ! check_ip_connect "$REMOTE_GMN_ESCAPE_IP" "$retryPingCount"; then
            if ! check_ip_connect "$REMOTE_GMN_IN_IP" "$retryPingCount"; then
                LOG_ERROR "check_network: can not access to escape or gmn in ip, try to check ha arbitrate ip"
                if checkHaArbitrateIP "$retryPingCount"; then
                    if ! checkExfloatIpConnect; then
                        return ${STATUS_OK}
                    else
                        return ${STATUS_NOT_OK}
                    fi
                else
                    LOG_ERROR "check_network: check ha arbitrate ip failed, return STATUS_NOT_OK"
                    return ${STATUS_NOT_OK}
                fi
            fi
        fi
    fi
    
    IS_CONNECT_PEER="yes"
    
    # access heartbeat ip ok
    # 3.check exfloatip
    LOG_INFO "check_network: step 5: check peer exfloatip"
    RESPONSE_CODE=$(get_remote_status "${QUERY_FLOATIP_URL}")
    if [ "-${RESPONSE_CODE}" = "-0" ];
    then
        LOG_ERROR "check_network: peer node is primary, return STATUS_NOT_OK, reason: FLOAT_IP_ON_REMOTE"
        return ${STATUS_NOT_OK}
    else
        LOG_INFO "check_network: exfloatip does not start on peer node, try to arping exfloat ip"
        if ! checkExfloatIpConnect; then
            return ${STATUS_OK}
        else
            return ${STATUS_NOT_OK}
        fi
    fi
}

getSectionInfo()
{
    local cfgFile="$1"
    local key="$2"
    local prefix="$3"
    
    if ! [ -f "$cfgFile" ];then
        LOG_ERROR "$cfgFile is not exsit"
        return 1
    fi

    if ! grep "^\[$key\]" $cfgFile > /dev/null;then
        LOG_WARN "grep "^\[$key\]" $cfgFile return 1"
        return 0
    fi
    
    local oldPrefix="$prefix"
    if [ -n "$prefix" ];then
        prefix="${prefix}_${key}"
    else
        prefix="${key}"
    fi
    
    if [ "$key" != "GLOBAL" ];then
        sed -n "/^\[$key\]/,/\[/p" $cfgFile | grep '=' | grep -v "^[\s]*#" | sed "s/^/${prefix}_/"
    else
        if [ -n "$oldPrefix" ];then
            sed -n "/^\[$key\]/,/\[/p" $cfgFile | grep '=' | grep -v "^[\s]*#" | sed "s/^/${oldPrefix}_/"
        else
            sed -n "/^\[$key\]/,/\[/p" $cfgFile | grep '=' | grep -v "^[\s]*#"
        fi
    fi
}

CFG_LABELS="LOCAL REMOTE GLOBAL"
HA_INNER_PREFIX="hainner_"
HA_CONF_MODULE4RSYNC="${HA_INNER_PREFIX}conf"

getDoubleConfig()
{
    local cfgFile="$1"

    [ -f "$cfgFile" ] || die "$cfgFile is not exist"
    
    local lable
    local sectionInfo
    for lable in $CFG_LABELS; do
        sectionInfo=$(getSectionInfo "$cfgFile" "$lable")
        eval "$sectionInfo"
    done
}

getOldDoubleConfig()
{
    local cfgFile="$1"
    local prefix="${2:-OLD}"
    
    [ -f "$cfgFile" ] || die "$cfgFile is not exist"
    
    LOG_INFO "the content of cfg file is: $(cat "$cfgFile")"
    
    local lable
    local sectionInfo
    for lable in $CFG_LABELS; do
        sectionInfo=$(getSectionInfo "$cfgFile" "$lable" "$prefix")
        eval "$sectionInfo"
    done
}

isConfigSame()
{
    local cfgFile="$1"
    local cfgFile2="$2"
    
    [ -f "$cfgFile" ] || die "$cfgFile is not exist"
    [ -f "$cfgFile2" ] || die "$cfgFile2 is not exist"

    DIFF_PARAMETER_LIST=""
    
    local lable
    local sectionInfo
    local sectionInfo2
    for lable in $CFG_LABELS; do
        sectionInfo=$(getSectionInfo "$cfgFile" "$lable")
        eval "$sectionInfo"
        
        sectionInfo2=$(getSectionInfo "$cfgFile2" "$lable" "RIGHT")
        eval "$sectionInfo2"
        
        for var in $(echo "$sectionInfo" | awk -F= '{print $1}'); do
            if echo "$var" | grep -i "^haMode$" > /dev/null; then
                continue
            fi
        
            eval "value=\$$var"
            var2=RIGHT_${var}
            eval "value2=\$$var2"
            if [ -z "$value" -o -z "$value2" ]; then
                LOG_WARN "$var:$value or $var2:$value2 is empty"
                continue
            fi
            
            if [ "$value" != "$value2" ]; then
                DIFF_PARAMETER_LIST="$DIFF_PARAMETER_LIST $var"
            fi
        done
    done
}

isForbidByApp()
{
    local appName="$1"
    local curTime="$2"

    local appForbidFlag=""
    local appBeginTime=""
    local appTimeout=""
    
    local forbidLabel="FORBID_${appName}"
    local beginTimeLabel="BEGIN_TIMESTAMP_${appName}"
    local timeoutLabel="TIMEOUT_${appName}"
    
    eval "appForbidFlag=\$$forbidLabel"
    eval "appBeginTime=\$$beginTimeLabel"
    eval "appTimeout=\$$timeoutLabel"
    
    if [ "$appForbidFlag" != "yes" ];then
        LOG_INFO "appName:$appName, appForbidFlag:$appForbidFlag is not yes, it is not forbid state"
        return 1
    else
        if [ "$appTimeout" == "0" ];then
            LOG_WARN "appName:$appName, FORBID is yes, and HA_TIMEOUT is 0, it is forbid state forever"
            return 0
        fi
        
        if (($curTimestamp - $appBeginTime > $appTimeout)); then
            LOG_WARN "appName:$appName, FORBID is yes, but $curTimestamp - $appBeginTime > $appTimeout, so it is not forbid state"
            return 1
        fi
        
        LOG_INFO "appName:$appName, FORBID is yes, it is forbid state"
        return 0
    fi
}

isForbidByOneApp()
{
    if ! [ -f "$_HA_SWITCH_CONF_" ];then
        LOG_INFO "$_HA_SWITCH_CONF_ is not exsit, it is not forbid state"
        return 1
    fi
    
    . "$_HA_SWITCH_CONF_"
    
    local curTimestamp=$(date +"%s")
    
    local appName="$1"
    isForbidByApp "$appName" "$curTimestamp" && return 0

    LOG_INFO "not in forbid state by $appName"
    
    return 1
}

isForbidSwitch()
{
    if ! [ -f "$_HA_SWITCH_CONF_" ];then
        LOG_INFO "$_HA_SWITCH_CONF_ is not exsit, it is not forbid state"
        return 1
    fi
    
    . "$_HA_SWITCH_CONF_"
    
    local curTimestamp=$(date +"%s")
    
    local appName="$1"
    if [ -n "$appName" ];then
        APP_LISTS="$appName"
    fi

    for appName in $APP_LISTS ; do
        isForbidByApp "$appName" "$curTimestamp" && return 0
    done
    
    rm -f "$_HA_SWITCH_CONF_"
    LOG_INFO "not in forbid state, rm -f $_HA_SWITCH_CONF_"
    
    return 1
}

# 判断当前站点是否是容灾主站点
isCascadePrimaryRole()
{
    [ -f "$CASCADE_CONF" ] || return 1
    
    local curRole=$(cat "$CASCADE_CONF")
    
    if [ "$curRole" == "$PRIMARY_CASCADE_STATE" ]; then
        return 0
    fi
    
    return 1
}

# 判断当前站点是否是容灾备站点
isCascadeStandbyRole()
{
    [ -f "$CASCADE_CONF" ] || return 1
    
    local curRole=$(cat "$CASCADE_CONF")
    
    if [ "$curRole" == "$STANDBY_CASCADE_STATE" ]; then
        return 0
    fi
    
    return 1
}

# 判断当前是否处于容灾模式
isCascadeMode()
{
    if isCascadePrimaryRole || isCascadeStandbyRole ; then
        return 0
    fi
    
    return 1
}

haStart4PowerMgr()
{
    local appName="HWM_POWER_MGR"
    if ! isForbidByOneApp "$appName"; then
        LOG_INFO "it is not forbid by appName:$appName"
        return 1
    fi
    
    local curTimestamp=$(date +"%s")
    sed -i "/^TM_AFT_POWERON/d" "$_HA_SWITCH_CONF_"
    echo "TM_AFT_POWERON=$curTimestamp" >> "$_HA_SWITCH_CONF_"
    LOG_INFO "echo "TM_AFT_POWERON=$curTimestamp" >> "$_HA_SWITCH_CONF_""
    
    return 0
}

haMonitor4PowerMgr()
{
    local appName="HWM_POWER_MGR"
    if ! isForbidByOneApp "$appName"; then
        return 1
    fi
    
    . "$_HA_SWITCH_CONF_"
    if [ -z "$TM_AFT_POWERON" ]; then
        return 0
    fi
    
    getDoubleConfig "$_CONF_FILE_"
    local queryInfo=$(queryHaState)
    eval "$queryInfo"
    if [ "$REMOTE_STATE" == "$ACTIVE_STATE" ]; then
        LOG_INFO "remote is active, so cancle the forbid switch for appName:$appName"
        cancelForbid "$appName"
        sed -i "/^TM_AFT_POWERON/d" "$_HA_SWITCH_CONF_"
        return 0
    fi
    
    local -i diff=0
    local curTimestamp=$(date +"%s")
    ((diff = $curTimestamp - $TM_AFT_POWERON))
    
    if [ $diff -gt 300 ];then
        LOG_INFO "at last after sleep 300, so cancle the forbid switch for appName:$appName"
        cancelForbid "$appName"
        sed -i "/^TM_AFT_POWERON/d" "$_HA_SWITCH_CONF_"
        return 0
    fi
    LOG_INFO "$curTimestamp - $TM_AFT_POWERON: $diff less then 300"
    
    return 0
}

ERR_GET_LOCK=101
ERR_PARAMETERS=102

#######################################################################
# shell文件锁封装函数，
# 参数1：文件锁路径，
# 参数2，需要上锁的实际执行动作，
# 参数3~n，传给实际动作的所有参数
lockWrapCall()
{
    local lockFile=$1
    local action=$2
    
    [ -n "$lockFile" -a -n "$action" ] || return $ERR_PARAMETERS
    
    local dirName=$(dirname $lockFile)
    [ -d "$dirName" ] || return $ERR_PARAMETERS
    
    shift 2
    
    # 定义信号捕捉流程，异常停止进程时清除文件锁
    trap 'rm -f $lockFile; LOG_WARN "trap a stop singal"' 1 2 3 15
    
    ####################################
    ## 文件锁，只允许一个进程执行
    ####################################
    {
        flock -no 100
        if [ $? -eq 1 ]; then
            local lockPid=$(cat $lockFile)
            lockPid=$(echo $lockPid)
            if [ -z "$lockPid" ]; then
                LOG_WARN "can't get lock file:$lockFile, lockPid is empty, no need to run $action"
                return $ERR_GET_LOCK
            else
                lockPid=$(echo $lockPid)
                local openPids=$(lsof -Fp $lockFile)
                if echo "$openPids" | grep "^p${lockPid}$" > /dev/null; then
                    LOG_WARN "can't get lock file:$lockFile, lockPid:$lockPid is running, no need to run $action"
                    return $ERR_GET_LOCK                
                fi
            fi
            LOG_INFO "success get lock file:$lockFile, lockPid:$lockPid is not running"
        fi
        echo $$ > $lockFile

        $action "$@"
        local ret=$?
        
        # 删除文件锁，使得上述动作参数的子进程不再持有锁
        rm -f $lockFile
        return $ret
    } 100<>$lockFile
    
    # 恢复为默认信号处理
    trap '-' 1 2 3 15 
}

lockWrapCallWithRetry()
{
    local -i retryTimes="$1"
    shift
    
    local ret=0
    
    local i=1
    for ((i=1; i <= $retryTimes; ++i)); do
        lockWrapCall "$@"
        ret=$?
        if [ $ret -ne 101 ] && [ $ret -ne 102 ]; then
            return $ret
        fi
        
        if [ $ret -eq 102 ]; then
            break
        fi
        
        LOG_INFO "retrytime:$i, maybe another process lock file"
        
        if [ $i -lt $retry ]; then
            sleep 1
        fi
    done
    
    return $ret
}

# configure file
_CONF_FILE_=$HA_DIR/conf/runtime/gmn.cfg

HA_DATA_DIR=$HA_DIR/data
[ -d "$HA_DATA_DIR" ] || mkdir -p $HA_DATA_DIR

OMSCRIPT=$HA_DIR/tools/omscript
_HA_SWITCH_CONF_=$HA_DATA_DIR/ha_switch.cfg
_HBSTART_FORBIDSW_LOCK_=$HA_DATA_DIR/hbstart_forbidsw.lock

RM_SCRIPT_DIR=$HA_DIR/module/harm/plugin/script

CASCADE_CONF=$HA_DATA_DIR/cascade.cfg
PRIMARY_CASCADE_STATE="primary"
STANDBY_CASCADE_STATE="standby"

STOP_HA_MON_TOOL=$HA_DIR/module/hamon/script/stop_ha_monitor.sh
STOP_HA_PROC_TOOL=$HA_DIR/module/hacom/script/stop_ha_process.sh
STATUS_HA_MON_TOOL=$HA_DIR/module/hamon/script/status_ha_monitor.sh
START_HA_MON_TOOL=$HA_DIR/module/hamon/script/start_ha_monitor.sh

HA_STOP_TOOL=$HA_DIR/module/hacom/script/stop_ha.sh
HA_STATUS_TOOL=$HA_DIR/module/hacom/script/status_ha.sh
HA_STOP_PROC_TOOL=$HA_DIR/module/hacom/script/stop_ha_process.sh
HA_CLIENT_TOOL=$HA_DIR/module/hacom/tools/ha_client_tool
if [ -z "$IP_TYPE" ] ||  [ "IPV4" == "$IP_TYPE" ]; then
    HA_CLIENT="$HA_DIR/module/hacom/tools/ha_client_tool --ip=127.0.0.1 --port=61806"
else
    HA_CLIENT="$HA_DIR/module/hacom/tools/ha_client_tool --ip=::1 --port=61806"
fi

HA_COM_RPC_SUCC=0           #  Congratulations! exec successfully
HA_COM_RPC_FAILED=1         #  Sorry, exec failed
HA_COM_RPC_CONNECT_ERR=2    #  Connect failed, maybe server is down or thrift failed
HA_COM_RPC_PARAM_ERR=3      #  Input para is invaild
HA_COM_RPC_MEM_LACK_ERR=4   #  System memory is not enough
HA_COM_RPC_INNER_ERR=5      #  HA inner error, contact with HA's staff please
HA_COM_RPC_SYNCFILE_WAIT=6  #  File is syncing now
HA_COM_RPC_HAROLE_REFUSE=7  #  HA role incorrect
HA_COM_RPC_LINK_UNUSABLE=8  #  There is no usable link
HA_COM_RPC_SENDMSG_ERR=9    #  Send msg failed between active and standby
HA_COM_RPC_TIMEOUT=10       #  Failed for time out
HA_COM_RPC_HAMODE_REFUSE=11 #  HA mode incorrect
HA_COM_RPC_SWAP_FORDID=12   #  HA has been forbidden switchover before
HA_COM_RPC_NONSTEADY_RES=13 #  HA is in nonsteady status
HA_COM_RPC_LOCAL_BETTER=14  #  Local resources situation is better than peer's
HA_COM_RPC_SYNCCMD_FAIL=15  #  Timeout when set forbid between active and standby
HA_COM_RPC_NO_RESOURCE=16   #  There is not single active resource exist
HA_COM_RPC_STATE_REFUSE=17  #  Local is not in HA(active-standby) state

