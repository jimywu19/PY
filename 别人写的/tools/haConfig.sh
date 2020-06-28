#!/bin/bash

################################################
# init log
################################################
cd "$(dirname $0)"
CUR_PATH=$(pwd)
declare -r ScriptName=`basename $0`

. $CUR_PATH/func/func.sh || { echo "fail to load $CUR_PATH/func/func.sh"; exit 1; }
. $CUR_PATH/func/dblib.sh 

#add for adapting IPV6
. $HA_DIR/install/common_var.sh || { echo "load $HA_DIR/install/common_var.sh failed."; exit 1; }
echo "haConfig.sh $IP_TYPE ">> /var/log/ip_type.log
#add for adapting IPV6 

mkdir -p $_HA_SH_LOG_DIR_
LOG_FILE=$_HA_SH_LOG_DIR_/config.log

#################################################

die()
{
    ECHOANDLOG_ERROR "$*"
    exit 1
}

######################################################################
#   FUNCTION   : getPara
#   DESCRIPTION: 
#   INPUT      : -U
#                -R
#                -D
#                -I
#                -C
######################################################################
getPara()
{
    while getopts m:l:r:b:g:f:d:o:e: option
    do
        case "$option"
        in
            r) REMOTE_HOST=$OPTARG
                if [ -z "$REMOTE_HOST" ]; then
                    exit 1;
                fi
                ;;
            l) LOCAL_HOST=$OPTARG
                if [ -z "$LOCAL_HOST" ]; then
                    exit 1;
                fi
                ;;
            b) HEARTBEAT_IP="$OPTARG"
                if [ -z "$HEARTBEAT_IP" ]; then
                    exit 1;
                fi
                ;;    
            m) HA_MODE="$OPTARG"
                if [ -z "$HA_MODE" ]; then
                    exit 1;
                fi
                ;;  
            g) GATEWAY_IP="$OPTARG"
                if [ -z "$GATEWAY_IP" ]; then
                    exit 1;
                fi
                ;;
            f) FLOART_IP="$OPTARG"
                if [ -z "$FLOART_IP" ]; then
                    exit 1;
                fi
                ;;
            d) fmDeployMode="$OPTARG"
                if [ -z "$fmDeployMode" ]; then
                    exit 1;
                fi
                ;;
            o) OM_FLOART_IP="$OPTARG"
                ;;
            e) EXTERNAL_LISTEN="$OPTARG"
                ;;
            \?) 
             echo "Paramter error, $@"
             exit 1
             ;;
        esac
    done
    
    LOG_INFO "Get parameter: the HA_MODE=$HA_MODE, GATEWAY_IP=$GATEWAY_IP, LOCAL_HOST=$LOCAL_HOST, REMOTE_HOST=$REMOTE_HOST, HEARTBEAT_IP=$HEARTBEAT_IP, FLOART_IP=$FLOART_IP, OM_FLOART_IP=$OM_FLOART_IP"
    return 0
}

modifyHostName()
{
    local localHost="$1"
    [ -n "$localHost" ] || return 1

    oldHost=$(uname -n)
    echo "`cat /etc/hosts | sed -r \"s/\<${oldHost}\>/$localHost/g\"`" > /etc/hosts

    echo "$localHost" > /etc/HOSTNAME || return 1
    hostname "$localHost" || return 1
}

modifyGlobalVar()
{
    local cfgFile="$1"
    local key="$2"
    local value="$3"
    
    [ -f $cfgFile ] || return 1
    [ -n $key ] || return 2
   
    sed -ri "s/^($key)=.*$/\1=$value/" "$cfgFile"
}

configHa4Single()
{
    local localHost=$(uname -n)
    #add for adapting ipv6
    if [ -z "$IP_TYPE" ] ||  [ "IPV4" == "$IP_TYPE" ]; then
        $HA_CFG_TOOL -m single -l "$localHost" -r "127.0.0.1:61806"
    else
        $HA_CFG_TOOL -m single -l "$localHost" -r "[::1]:61806"
    fi
    ret=$?
    LOG_INFO "$HA_CFG_TOOL -m single -l "$localHost" return $?"
    
    # clear guassdb config for replacation
    su - $DB_USER -c "gs_guc reload -c replconninfo1=\"''\" " >> $LOG_FILE 2>&1
    LOG_INFO "gs_guc reload -c replconninfo1=\"''\" return $?"
    
    modifyIp4DbLink "$FLOART_IP"
    LOG_INFO "modifyIp4DbLink $FLOART_IP return $?"
    
    return $ret
}

configRmConf()
{
    if ! [ -d "$RM_CONF_DIR" ];then
        LOG_ERROR "RM_CONF_DIR:$RM_CONF_DIR not exsit"
        return 1
    fi
    
    rm -f "$EXTERN_RM_CONF_FILE"
    
    local ret=0
    cd $RM_CONF_DIR
    local confFile=""
    local file=""
    for confFile in $(ls *.xml 2>/dev/null); do
        file=$(sed -n "/\<script name\s*=/p" "$confFile" | awk -F= '{print $2}' | sed -r "s/\"(.*)\".*$/\1/")
        if [ -z "$file" ];then
            continue
        fi
        
        local resource=${confFile%.xml}
        file=$(echo $file)
        
        if ! [ -f "$RM_SCRIPT_DIR/$file" ];then
            continue
        fi
        
        echo "${resource},$RM_SCRIPT_DIR/$file" >> $EXTERN_RM_CONF_FILE || ret="$1"
    done
    cd - >/dev/null
    
    return $ret
}

configHaParameter()
{
    # 
    local haDeadTime=5
    sed -ri "s/(<deadtime value)=.*/\1=\"$haDeadTime\"\/>/" $HA_DIR/module/haarb/conf/haarb.xml
    
    # 
    local keepaliveValue=3
    sed -ri "s/(<keepalive value)=.*/\1=\"$keepaliveValue\"\/>/" $HA_DIR/module/haarb/conf/haarb.xml
    
    # swapjudge
    local swapjudgeValue=3
    sed -ri "s/(<swapjudge value)=.*/\1=\"$swapjudgeValue\"\/>/" $HA_DIR/module/haarb/conf/haarb.xml
    
    # 
    local arbjudgeValue=3
    sed -ri "s/(<arbjudge value)=.*/\1=\"$arbjudgeValue\"\/>/" $HA_DIR/module/haarb/conf/haarb.xml

    # 
    local haAllSyncTime=${HA_ALL_SYNC_TM:-3}
    sed -ri "s/(<all-sync interval)=.*/\1=\"$haAllSyncTime\"\/>/" $HA_DIR/module/hasync/conf/hasync.xml
    
    return 0
}

modifyIp4DbLink()
{
    local localIp="$1"
    
    [ -n "$localIp" ] || return 1
    
    sed -ri "s/^(replconninfo2 = 'localhost=)[^ ]*/\1${localIp}/" $DB_DATA_DIR/postgresql.conf
    sed -ri "s/^(replconninfo3 = 'localhost=)[^ ]*/\1${localIp}/" $DB_DATA_DIR/postgresql.conf
    
    su - $DB_USER -c "gs_ctl reload" >> $LOG_FILE 2>&1
}

configHa4Double()
{
    local remoteIps=""
    local remoteIp=""
    local localIps=""
    local localIp=""
    
    local ips4Db=""
    local ips4Hb=""
    local ips4Sync=""
    
    local rsyncIpList=""
    
    local itf=""
    local ucastInfoList=""
    local ucastInfo=""
    
    #adapting for IPV6
    if [ -z "$IP_TYPE" ] ||  [ "IPV4" == "$IP_TYPE" ]; then
        . $GLOBAL_VAR_FILE
        local ifs="$IFS"
        IFS=";"
        for ips in $HEARTBEAT_IP;do
            remoteIps=$(echo "$ips" | grep -o "$REMOTE_HOST:[^,]*")
            localIps=$(echo "$ips" | grep -o "$LOCAL_HOST:[^,]*")
            remoteIp=$(echo "$remoteIps" | awk -F: '{print $2}')
            itf=$(echo "$remoteIps" | awk -F: '{print $3}')
            if ! checkIp $remoteIp;then
                ECHOANDLOG_ERROR "the remoteIp:$remoteIp of $REMOTE_HOST is invalid."
                continue
            fi
            
            if [ -z "$itf" ];then
                ECHOANDLOG_ERROR "the itf:$itf of $REMOTE_HOST is invalid."
                continue
            fi
            
            localIp=$(echo "$localIps" | awk -F: '{print $2}')
            
            # 
            if [ "$DEPLOY_MODE" != "$FC_MODE" ] || [ "$itf" != "eth2" ]; then
                ips4Db="$ips4Db,localhost=$localIp localport=15210 remotehost=$remoteIp remoteport=15210"
            fi
        
            rsyncIpList="$rsyncIpList, $localIp, $remoteIp"
        
            ips4Hb="$ips4Hb;$LOCAL_HOST:$localIp:$HBPORT,$REMOTE_HOST:$remoteIp:$HBPORT"
            ips4Sync="$ips4Sync;$LOCAL_HOST:$localIp:$SYNCPORT,$REMOTE_HOST:$remoteIp:$SYNCPORT"
        done
        IFS="$ifs"
        
        ips4Hb=$(echo "$ips4Hb" | sed 's/^;//')
        ips4Sync=$(echo "$ips4Sync" | sed 's/^;//')
    
        if [ ! -z "$UPGRADE_ROLE" ]; then
            LOG_INFO "$HA_CFG_TOOL -m double -l "$LOCAL_HOST" -p "$REMOTE_HOST" -b "$ips4Hb" -s "$ips4Sync" -i "$FLOART_IP" -g "$GATEWAY_IP" -j "$UPGRADE_ROLE" -r "127.0.0.1:61806""
            $HA_CFG_TOOL -m double -l "$LOCAL_HOST" -p "$REMOTE_HOST" -b "$ips4Hb" -s "$ips4Sync" -i "$FLOART_IP" -g "$GATEWAY_IP" -j "$UPGRADE_ROLE" -r "127.0.0.1:61806"
        else
            LOG_INFO "$HA_CFG_TOOL -m double -l "$LOCAL_HOST" -p "$REMOTE_HOST" -b "$ips4Hb" -s "$ips4Sync" -i "$FLOART_IP" -g "$GATEWAY_IP" -j "$UPGRADE_ROLE" -r "127.0.0.1:61806""
            $HA_CFG_TOOL -m double -l "$LOCAL_HOST" -p "$REMOTE_HOST" -b "$ips4Hb" -s "$ips4Sync" -i "$FLOART_IP" -g "$GATEWAY_IP" -r "127.0.0.1:61806"
        fi
    
        ret=$?
        LOG_INFO "$HA_CFG_TOOL -m double -l "$LOCAL_HOST" -p "$REMOTE_HOST" -b \"$ips4Hb\" -s \"$ips4Sync\" -i "$FLOART_IP" -g "$GATEWAY_IP" return $ret"
        [ $ret -eq 0 ] || return $ret
        
        # 
        ips4Db=$(echo "$ips4Db" | sed 's/^,//')
        su - $DB_USER -c " gs_guc reload -c replconninfo1=\"'$ips4Db'\" " >> $LOG_FILE 2>&1
        LOG_INFO "gs_guc reload -c replconninfo1=\"'$ips4Db'\" return $?"
        
        modifyIp4DbLink "$localIp"
        LOG_INFO "modifyIp4DbLink $localIp return $?"
        
        # 
        configHaParameter
        
        return 0
    else
        . $GLOBAL_VAR_FILE
        local ifs="$IFS"
        IFS=";"
        for ips in $HEARTBEAT_IP;do
            remoteIps=$(echo "$ips" | grep -o "$REMOTE_HOST:[^,]*")
            localIps=$(echo "$ips" | grep -o "$LOCAL_HOST:[^,]*")
            remoteIp=$(echo "$remoteIps" | awk -F[ '{print $2}' | awk -F] '{print $1}')
            itf=$(echo "$remoteIps" | awk -F] '{print $2}' | awk -F: '{print $2}')
            if ! checkIp $remoteIp;then
                ECHOANDLOG_ERROR "the remoteIp $remoteIp of $REMOTE_HOST is invalid."
                continue
            fi
            
            if [ -z "$itf" ];then
                ECHOANDLOG_ERROR "the itf $itf of $REMOTE_HOST is invalid."
                continue
            fi
            
            localIp=$(echo "$localIps" | awk -F[ '{print $2}' | awk -F] '{print $1}')

            if [ "$DEPLOY_MODE" != "$FC_MODE" ] || [ "$itf" != "eth2" ]; then
                ips4Db="$ips4Db,localhost=$localIp localport=15210 remotehost=$remoteIp remoteport=15210"
            fi
        
            rsyncIpList="$rsyncIpList, $localIp, $remoteIp"
        
            ips4Hb="$ips4Hb;$LOCAL_HOST:[$localIp]:$HBPORT,$REMOTE_HOST:[$remoteIp]:$HBPORT"
            ips4Sync="$ips4Sync;$LOCAL_HOST:[$localIp]:$SYNCPORT,$REMOTE_HOST:[$remoteIp]:$SYNCPORT"
        done
        IFS="$ifs"
        
        ips4Hb=$(echo "$ips4Hb" | sed 's/^;//')
        ips4Sync=$(echo "$ips4Sync" | sed 's/^;//')
    
        if [ ! -z "$UPGRADE_ROLE" ]; then
            LOG_INFO "$HA_CFG_TOOL -m double -l "$LOCAL_HOST" -p "$REMOTE_HOST" -b "$ips4Hb" -s "$ips4Sync" -i "$FLOART_IP" -g "$GATEWAY_IP" -j "$UPGRADE_ROLE" -r "[::1]:61806""
            $HA_CFG_TOOL -m double -l "$LOCAL_HOST" -p "$REMOTE_HOST" -b "$ips4Hb" -s "$ips4Sync" -i "$FLOART_IP" -g "$GATEWAY_IP" -j "$UPGRADE_ROLE" -r "[::1]:61806"
        else
            LOG_INFO "$HA_CFG_TOOL -m double -l "$LOCAL_HOST" -p "$REMOTE_HOST" -b "$ips4Hb" -s "$ips4Sync" -i "$FLOART_IP" -g "$GATEWAY_IP" -r "[::1]:61806""
            $HA_CFG_TOOL -m double -l "$LOCAL_HOST" -p "$REMOTE_HOST" -b "$ips4Hb" -s "$ips4Sync" -i "$FLOART_IP" -g "$GATEWAY_IP" -r "[::1]:61806"
        fi
    
        ret=$?
        LOG_INFO "$HA_CFG_TOOL -m double -l "$LOCAL_HOST" -p "$REMOTE_HOST" -b \"$ips4Hb\" -s \"$ips4Sync\" -i "$FLOART_IP" -g "$GATEWAY_IP" return $ret"
        [ $ret -eq 0 ] || return $ret
        
        # 
        ips4Db=$(echo "$ips4Db" | sed 's/^,//')
        su - $DB_USER -c " gs_guc reload -c replconninfo1=\"'$ips4Db'\" " >> $LOG_FILE 2>&1
        LOG_INFO "gs_guc reload -c replconninfo1=\"'$ips4Db'\" return $?"
        
        modifyIp4DbLink "$localIp"
        LOG_INFO "modifyIp4DbLink $localIp return $?"
        
        # 
        configHaParameter
        
        return 0
    fi
}

##########################################################################
## 
## ¿¿¿GMN¿¿¿¿¿¿¿¿¿¿¿¿¿¿or¿¿¿¿¿¿
## 
##########################################################################
getGmnDeployMode()
{
    if [ -f "$DEPLOY_CFG" ];then
        if grep -w "cfgScenarios=allInOne" "$DEPLOY_CFG" > /dev/null; then
            LOG_INFO "in allInOne mode"
            DEPLOY_MODE="$FC_MODE"
        elif grep -w "cfgScenarios=oraclerac" "$DEPLOY_CFG" > /dev/null; then
            LOG_INFO "in DB allInOne mode"
            DEPLOY_MODE="$FC_MODE"
        else
            LOG_INFO "in noneAllInOne mode"
            DEPLOY_MODE="$OTHER_MODE"
        fi
    fi
}

configHa2AutoSatrt()
{
    # 
    rm -f "$HA_HB_IP_COLLISION_FLAG"
    sed -i "/hbIpMonitor.sh/d" /etc/crontab
    echo "* * * * * root $HA_DIR/tools/hbIpMonitor.sh" >> /etc/crontab
    if [ -f /etc/euleros-release ]; then
        service cron reload >> $LOG_FILE 2>&1
    else
        rccron reload >> $LOG_FILE 2>&1
    fi
    # end
    
    # start ha
    if [ -z "$UPGRADE_ROLE" ]; then
        su - root -c "$HA_TOOLS_DIR/haStartAll.sh -r" >> $LOG_FILE 2>&1 || return 1
        LOG_INFO "$HA_TOOLS_DIR/haStartAll.sh -r success"
    fi
    
    return 0
}

configProcess()
{
    if isCascadeStandbyRole ; then
        LOG_INFO "in standby cascade mode, no need to config process"
        return 0
    fi
    
    rm -f $RM_CONF_DIR/*.xml
    cp -a -n $RM_BASE_CONF_DIR/*.xml $RM_CONF_DIR/
    case "$fmDeployMode" in
        "$ALL_FM")
            cp -af $RM_LOCAL_CONF_DIR/*.xml $RM_CONF_DIR/
            cp -af $RM_TOP_CONF_DIR/*.xml $RM_CONF_DIR/
            LOG_INFO "configProcess allInOne fm"
        ;;
        "$LOCAL_FM")
            cp -af $RM_LOCAL_CONF_DIR/*.xml $RM_CONF_DIR/
            LOG_INFO "configProcess local fm"
        ;;
        "$TOP_FM"|"$SC_FM")
            cp -af $RM_TOP_CONF_DIR/*.xml $RM_CONF_DIR/
            LOG_INFO "configProcess top fm"
        ;;
        *)
            cp -af $RM_LOCAL_CONF_DIR/*.xml $RM_CONF_DIR/
            cp -af $RM_TOP_CONF_DIR/*.xml $RM_CONF_DIR/
            LOG_WARN "configProcess fmDeployMode:$fmDeployMode is another mode"
        ;;
    esac
    if [ -f /opt/goku/uninstall/module_path_ict.xml ] ; then
        LOG_INFO "in ict mode."
        if [ -z "$OM_FLOART_IP" ]; then
            LOG_INFO "OM_FLOART_IP is empty, rm omfloatip.xml."
            rm -f $RM_CONF_DIR/omfloatip.xml
        fi
    else
        LOG_INFO "in it mode."
        rm -f $RM_CONF_DIR/omfloatip.xml
    fi
}

main()
{
    getPara "$@"
    
    mkdir -p $_HA_LOG_DIR_ -m 700
    mkdir -p $_HA_SH_LOG_DIR_ -m 700
    chown dbadmin: $_HA_LOG_DIR_ -R
    chown dbadmin: $_HA_SH_LOG_DIR_ -R
    # end HA log init

    modifyHostName "$LOCAL_HOST"
    local ret=$?
    LOG_INFO "modifyHostName \"$LOCAL_HOST\" return $ret"
    
    if [ "$GMN_MODE_SINGLE" == "$HA_MODE" ];then
        DUALMODE=$DUALMODE_SINGLE
        configHa4Single || return $?
    else
        DUALMODE=$DUALMODE_DOUBLE
        configHa4Double || return $?
    fi

    onlyword="JustNeedToReplace@HopeNotSame"
 
    listen_addresses="localhost"
    if [ -n "$EXTERNAL_LISTEN" ]; then
        local dbDir=$(su - $DB_USER -c 'echo $GAUSSDATA')
        sed -i "s|$onlyword|$EXTERNAL_LISTEN|" "$dbDir/pg_hba.conf"
    fi
    
    su - $DB_USER -c " gs_guc reload -c listen_addresses=\"'localhost'\" " >> $LOG_FILE 2>&1
    LOG_INFO "gs_guc reload -c listen_addresses=\"'localhost'\" return $?"

    chmod 640 $HA_DIR/conf/runtime/gmn.cfg

    # 
    $HA_CFG_TOOL -f "$(dirname $_HA_LOG_DIR_)"
    $HA_CFG_TOOL -k "$(dirname $_HA_LOG_DIR_)"
    $HA_CFG_TOOL -o "$(dirname $_HA_LOG_DIR_)"
    $HA_CFG_TOOL -d local
    # config log
    $HA_CFG_TOOL -t 4
    $HA_CFG_TOOL -z 86400
    $HA_CFG_TOOL -e WARN
    
    configProcess
    ret=$?
    LOG_INFO "configProcess return $ret"

    if grep -q '^DUALMODE=' $HA_DIR/tools/func/globalvar.sh; then 
        sed -ri "s|^(DUALMODE)=.*$|\1=$DUALMODE|" $HA_DIR/tools/func/globalvar.sh
    else
        echo "DUALMODE=$DUALMODE" >> $HA_DIR/tools/func/globalvar.sh
    fi

    # config and start heartbeart temp code for IT1
    configHa2AutoSatrt || return 1
    # end
}

##########################################################
FC_MODE="0"
OTHER_MODE="1"
GMN_MODE_SINGLE="s"
GMN_MODE_DOUBLE="d"
HBPORT=6940
SYNCPORT=6941

BASE_DIR=$GM_PATH
DEPLOY_CFG=$BASE_DIR/config/deployStatus
HA_TOOLS_DIR=$HA_DIR/tools
HA_CFG_TOOL=$HA_DIR/module/hacom/script/config_ha.sh
GLOBAL_VAR_FILE=$HA_TOOLS_DIR/func/globalvar.sh
HA_OMSCRIPT_PATH=$HA_TOOLS_DIR/omscript

SYNC_CONF_DIR=$HA_DIR/module/hasync/plugin/conf
RM_PLUGIN_DIR=$HA_DIR/module/harm/plugin
RM_LOCAL_CONF_DIR=$RM_PLUGIN_DIR/conf.local
RM_TOP_CONF_DIR=$RM_PLUGIN_DIR/conf.top
RM_BASE_CONF_DIR=$RM_PLUGIN_DIR/conf.base
RM_CONF_DIR=$RM_PLUGIN_DIR/conf
EXTERN_RM_CONF_FILE=$HA_DIR/module/harm/plugin/conf/extern.conf
RM_SCRIPT_DIR=$HA_DIR/module/harm/plugin/script

RSYNC_TEMPLATE_CONF=$HA_DIR/conf/rsync/rsyncd.conf

# hb IP collision check
HA_DATA_DIR=$GM_PATH/data/ha
DB_DATA_DIR=$GM_PATH/data/db
HA_GLOBAL_DATA_DIR=$HA_DATA_DIR/global
HA_HB_IP_COLLISION_FLAG=$HA_GLOBAL_DATA_DIR/hbIpCollision.flag

FIRST_CONFIG_FLAG=$BASE_DIR/data/ha/global/firstConfig.flag

DUALMODE=0
DUALMODE_SINGLE=0
DUALMODE_DOUBLE=1

main "$@"
exit $?
