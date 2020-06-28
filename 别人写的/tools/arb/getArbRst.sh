#!/bin/sh 
######################################################
#    Huawei Technologies Co.Ltd. All rights reserved.
######################################################
#  filename       : getArbRst.sh
#  time          : 2017-03-1
#  description   : get arbitrated result from arbitration.
######################################################
set +x
SCRIPTDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LOG_FILE_NAME=/var/log/ha/runlog/getArbRst.log
HA_PATH=$SCRIPTDIR/../../../ha
HA_CONF=$HA_PATH/conf/arb/ha.properties
RST_FILE=$HA_PATH/conf/arb/arbRst
HA_ARB_CONF=$HA_PATH/module/haarb/conf/haarb.xml
JRE=$SCRIPTDIR/jre6.0.18/bin/java
. "$SCRIPTDIR/commfunc.sh"

libs="arbitration_center_main;activemq-all;async-http-client;commons-logging;guava;log4j;netty;wcc_common;wcc_crypt;wcc_log;arbitration_center_monitor;com.springsource.slf4j.api;com.springsource.slf4j.log4j"
getClassPath "$libs" "$SCRIPTDIR/lib"
CLASS_PATH_TMP=$CLASSPATH

getClassPath "commons-collections;jackson-annotations;jackson-core;jackson-databind;commons-codec" "$SCRIPTDIR/lib"
CLASSPATH=$CLASS_PATH_TMP:$CLASSPATH

declare -i g_arbInterval
declare -i g_arbValidTime
declare -i g_arbFreq
declare -i g_arbKeepalive
g_localDcStatus=
g_remoteDcStatus=
g_match=

#****************************************#
# Function: get the arbitration interval
# Usage: getArbInterval
# Parameters:
# None
# Return: return 0 on success, non 0 on failed
#****************************************#
function getArbInterval()
{
    local queryType=$1
    g_arbInterval=`cat $HA_CONF | grep "arbInterval=" | awk -F "=" '{print $2}'`
    g_arbValidTime=`cat $HA_CONF | grep "arbValidTime=" | awk -F "=" '{print $2}'`
    if [ $g_arbInterval -eq 0 ] || [ "$g_arbInterval" = "0" ] || [ $g_arbValidTime -eq 0 ] || [ "$g_arbValidTime" = "0" ]
    then
        Log "Get arbitration configration failed."
        return 1
    fi
    
    g_arbKeepalive=`cat $HA_ARB_CONF | grep "keepalive" | awk -F "value=" '{print $2}' | awk -F "\"" '{print $2}'`
    if [ $g_arbKeepalive -eq 0 ] || [ "$g_arbKeepalive" = "0" ]
    then
        Log "Get HA value of keepalive configration failed."
        return 1
    fi
    
    if [ "$queryType" -eq "1" ]
    then
        # heartbeat break, query arbitration result, when heartbeat break, have spend some seconds, configured in haarb.xml
        # when computing interval, must minus this seconds 
        local num=`expr ${g_arbValidTime} - ${g_arbKeepalive}`
        g_arbFreq=`expr ${num}/${g_arbInterval}`
        #由于keepalive为7，间隔时间20s减去7后除5秒得到结果为2，不满足3次查询结果的设计要求，故而+1
        g_arbFreq=`expr ${g_arbFreq} + 1`
    else
        g_arbFreq=`expr ${g_arbValidTime}/${g_arbInterval}`
    fi
    
    if [ $g_arbFreq -eq 0 ] || [ "$g_arbFreq" = "0" ]
    then
        Log "Compute freqency failed, validtime:$g_arbValidTime, g_arbKeepalive:$g_arbKeepalive, g_arbInterval:$g_arbInterval."
        return 1
    fi
    
    return 0
}

function excuteQuery()
{
    #localDcStatus:ok
    #remoteDcStatus:ok
    #isMatch:true

    local arbRst=`"$JRE" -cp "$CLASSPATH" -Dha.dir="$HA_PATH" -Dbeetle.application.home.path=$HA_PATH/conf/arb/wcc/ com.huawei.arb.ArbitrationCenter`
    echo $arbRst
    #changeLogsAuth
    echo $arbRst | grep "localDcStatus:" >>"$LOG_FILE_NAME" 2>&1 || return 1 
    echo $arbRst | grep "remoteDcStatus:" >>"$LOG_FILE_NAME" 2>&1 || return 1 
    echo $arbRst | grep "isMatch:" >>"$LOG_FILE_NAME" 2>&1 || return 1 
        
    for item in $arbRst
    {
        (echo $item | grep "localDcStatus:") >>"$LOG_FILE_NAME" 2>&1 && g_localDcStatus=`echo $item | awk -F ":" '{print $2}'` 
        (echo $item | grep "remoteDcStatus:") >>"$LOG_FILE_NAME" 2>&1 && g_remoteDcStatus=`echo $item | awk -F ":" '{print $2}'`
        (echo $item | grep "isMatch:") >>"$LOG_FILE_NAME" 2>&1 && g_match=`echo $item | awk -F ":" '{print $2}'`
    }

    if [ "$g_localDcStatus" = "" ] || [ "$g_remoteDcStatus" = "" ] || [ "$g_match" = "" ]
    then
        Log "Query arbitration result failed, ${arbRst}."
        return 1
    fi
    
    return 0
}

#****************************************#
# Function: get the arbitration result
# Usage: getArbRst
# Parameters:
# None
# Return: return 0 on success, non 0 on failed
#****************************************#
function getArbRst()
{
    # get query freqency and interval
    getArbInterval $1
    RTN=$?
    if [ $RTN -ne 0 ]
    then
        Log "Get arbitration interval failed."
        exit 1
    else
        Log "g_arbFreq=$g_arbFreq."
    fi
    
    #echo CLASSPATH=$CLASSPATH
    cd ${SCRIPTDIR}
    local lastLocalRst=
    local lastRemoteRst=
    local timeValue=0
    declare -i repeatTime=1
    declare -i queryTime=0
    while true
    do
        if [ $timeValue -ge 180 ]
        then
            Log "Query arbitration result timeout."
            exit 1
        fi
        
        excuteQuery
        RTN=$?
        queryTime=`expr $queryTime + 1`
        if [ $RTN -ne 0 ]
        then
            Log "Query arbitration result failed, time=${queryTime}."
            timeValue=`expr $timeValue + $g_arbInterval`
            sleep $g_arbInterval
            continue
        fi
        
        if [ "$g_match" != "true" ]
        then
            Log "Arbitration result is not match, local=$g_localDcStatus, remote=$g_remoteDcStatus, match:$g_match, time=${queryTime}."
            timeValue=`expr $timeValue + $g_arbInterval`
            sleep $g_arbInterval
            continue
        fi

        if [ "$lastLocalRst" = "$g_localDcStatus" ] && [ "$lastRemoteRst" = "$g_remoteDcStatus" ]
        then
            repeatTime=`expr $repeatTime + 1`
            timeValue=0
        else
            Log "Result have changed querytime=${queryTime}, repeattime=${repeatTime}, last local=$lastLocalRst, remote=$lastRemoteRst, new local=$g_localDcStatus, remote=$g_remoteDcStatus"
            repeatTime=1
            lastLocalRst=$g_localDcStatus
            lastRemoteRst=$g_remoteDcStatus
            timeValue=0
        fi

        if [ "$repeatTime" -ge "$g_arbFreq" ]
        then
            Log "Have get right result, local=$g_localDcStatus, remote=$g_remoteDcStatus, time=${queryTime}."
            break
        fi
        
        timeValue=`expr $timeValue + $g_arbInterval`
        sleep $g_arbInterval
    done
    
    echo "localDCStatus=$g_localDcStatus" > $RST_FILE
    echo "remoteDCStatus=$g_remoteDcStatus" >> $RST_FILE
}

# query type, 0:clear flag query   1:heartbeat break, query arbitration result 
queryType="$1"
if [ "${queryType}" = "" ]
then
    Log "queryType must be need."
    echo "queryType must be need."
    exit 1
fi

if [ "${queryType}" != "1" ] && [ "${queryType}" != "0" ]
then
    Log "queryType isn't right."
    echo "queryType isn't right."
    exit 1
fi

getArbRst ${queryType}
RTN=$?
if [ $RTN -ne 0 ]
then
    Log "Get arbitration result failed."
    exit 1
else
    Log "Get arbitration result succ."
    exit 0
fi
