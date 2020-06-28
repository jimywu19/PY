#!/bin/bash

################################################
# init log
################################################
cd "$(dirname $0)"
CUR_PATH=$(pwd)
declare -r ScriptName=`basename $0`
LOG_DIR=$HA_LOG_DIR/shelllog
mkdir -p $LOG_DIR
LOG_FILE=$LOG_DIR/config.log

HA_DIR=$CUR_PATH/../
. $HA_DIR/tools/func/func.sh || { echo "fail to load $HA_DIR/tools/func/func.sh"; exit 1; }
. "$HA_DIR/tools/arb/commfunc.sh"

#add for adapting IPV6
. $HA_DIR/install/common_var.sh || { echo "load $HA_DIR/install/common_var.sh failed."; exit 1; }
#add for adapting IPV6

GMN_INIT_CFG=$HA_DIR/conf/noneAllInOne/gmninit.cfg
chmod 640 $GMN_INIT_CFG

export CONFIG_RESULT=$CUR_PATH/config.result
chmod 600 $CONFIG_RESULT
#################################################

die()
{
    ECHOANDLOG_ERROR "$*"
    echo 999 >> $CONFIG_RESULT
    exit 1
}

usage()
{
    script=$(basename $0)
    echo -e "\n    usage:\n\t./$script false floatIp floatMask floatGetway itfName
\t./$script true floatIp floatMask floatGetway localIp remoteIp itfName haArbitrationIP \n"
}

getHaParameterFromFile()
{
    . $GMN_INIT_CFG
    fmDeployMode="$deployMode"
    haMode="$haMode"
    floatIp="$floatIP"
    floatMask="$localMask"
    floatGw="$localGateWay"
    localIp="$localIP"
    
    # om float IP
    omFloatIp="$omFloatIp"
    omFloatMask="$omLocalMask"
    omFloatGw="$omLocalGw"
    omLocalIp="$omLocalIp"
    omRemoteIp="$omRemoteIp"
    
    if [ "$haMode" == "1" ]; then
        floatIp="$localIp"
        omFloatIp="$omLocalIp"
    fi

    remoteIp="$remoteIp"
    haArbitrationIP="$haArbitrationIP"
    localHost="$nodeName"
    remoteHost="$remoteNodeName"
    itfName="${itfName:-GmnEx}"
    externDb="${externDb:-y}"

    ommha_ca_cert="$ommha_ca_cert"
    ommha_ca_passwd="$ommha_ca_passwd"
    ommha_server_cert="$ommha_server_cert"
    ommha_server_passwd="$ommha_server_passwd"

    arb_enable="$(echo $arb_enable | tr '[:upper:]' '[:lower:]')"
    arb_ips="$arb_ips"
    arb_username="$arb_username"
    arb_password="$arb_password"
    arb_localDC="$arb_localDC"
    arb_remoteDC="$arb_remoteDC"
    arb_privatepwd="$arb_privatepwd"
    arb_ca_crt="$arb_ca_crt"

    arbInterval="$arbInterval"
    arbValidTime="$arbValidTime"
    fIPNetmask="$fIPNetmask"
    fIPName="$fIPName"
}

getHaParameterFromInput()
{
    haMode="$1"
    floatIp="$2"
    floatMask="$3"
    floatGw="$4"
    
    if [ -z "$haMode" ];then
        LOG_INFO "haMode:$haMode is invalid"
    fi
    
    haMode=$(echo $haMode)
    if ! echo "$haMode" | grep -Ewi "^$HA_MODE$" > /dev/null; then
        haMode="$SINGLE_MODE_NUM"
        
        localIp="$floatIp"
        itfName="$5"
    else
        haMode="$HA_MODE_NUM"
        
        localIp="$5"
        remoteIp="$6"
        itfName="$7"
        haArbitrationIP="$8"
        fmDeployMode="$9"
        
        if [ -z "$haArbitrationIP" ]; then
            if [ -n "$floatGw" ]; then
                haArbitrationIP="$floatGw"
            else
                echo "please input the haArbitrationIP"
                usage
                exit 1
            fi
        fi
    fi
    
    localHost="GMN01"
}

function checkInputNumberLength()
{
    if [ `echo "$1" | wc -c` -gt 6 ]; then   # -gt 6 maybe means biger than 65536
        return 1
    fi
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
        return 1
    fi
    #检查端口的第一个数字是否是0
    echo "$1" | grep -E "^[1-9][0-9]*$" >/dev/null
    if [ $? -ne 0 ]; then
        return 1
    fi

    checkInputNumberLength "$1"
    [ $? -eq 1 ] && return 1

    if [ "$1" -lt 1024 ] || [ "$1" -gt 65535 ]; then
        return 1
    fi

    return 0
}

function checkUserPwdValid()
{
    local IP="$1"
    local UserName="$2"
    local PassWd="$3"
    local UserInputKeyStorePasswd="$4"
    local jreBin=$HA_DIR/tools/arb/jre/bin/java

    libs="arbitration_center_main;activemq-all;async-http-client;commons-logging;guava;log4j;netty;wcc_common;wcc_crypt;wcc_log;arbitration_center_monitor;com.springsource.slf4j.api;com.springsource.slf4j.log4j"
    getClassPath "$libs" "$HA_DIR/tools/arb/lib"
    CLASS_PATH_TMP=$CLASSPATH

    getClassPath "commons-collections;jackson-annotations;jackson-core;jackson-databind;commons-codec" "$HA_DIR/tools/arb/lib"
    CLASSPATH=$CLASS_PATH_TMP:$CLASSPATH

    local strParam="{\"userName\": \"$UserName\", \"password\": \"$PassWd\", \"ips\": \"$IP\", \"keyStorePwd\": \"$UserInputKeyStorePasswd\"}"
    "$jreBin" -cp "$CLASSPATH" -Dha.dir="$HA_DIR" -Dbeetle.application.home.path=$HA_DIR/conf/arb/wcc/ com.huawei.arb.ArbitrationCenter "$strParam"

    local Ret=$?
    return $Ret
}

HA_MODE="true|2"
SINGLE_MODE="false|1"
HA_MODE_NUM=2
SINGLE_MODE_NUM=1

main()
{
    LOG_INFO "enter configHa4CI: $*"
    echo > $CONFIG_RESULT
    
    #add for adapting ipv6
    echo $IP_TYPE >>  $CONFIG_RESULT
    if [ -z "$IP_TYPE" ] ||  [ "IPV4" == "$IP_TYPE" ]; then
        if [ -f $GMN_INIT_CFG ]; then
            getHaParameterFromFile
        else
            getHaParameterFromInput "$@"
        fi
        
        if [ -z "$floatGw" ]; then
            floatGw="255.255.255.255"
        fi
        
        if [ -z "$omFloatGw" ]; then
            omFloatGw="255.255.255.255"
        fi
        
        if [ -z "$floatIp" ];then
            usage
            die "floatIp:$floatIp is invalid"
        fi
        
        if [ -z "$floatMask" ];then
            usage
            die "floatMask:$floatMask is invalid"
        fi
        
        if ! checkIps "$floatIp" "$floatMask" "$floatGw" 2>> $LOG_FILE; then
            usage
            die "floating ip info: $floatIp $floatMask $floatGw is invlaid"
        fi
        
        if ! checkIps "$localIp" "$floatMask" "$floatGw" 2>> $LOG_FILE; then
            usage
            die "local ip info: $localIp $floatMask $floatGw is invlaid"
        fi
        
        if [ "$haMode" == "1" ]; then
            if [ "$arb_enable" == "true" ];then
                die "ha mode: haMode $haMode or arb_enable $arb_enable is invalid."
            fi
        fi
        
        if [ "$haMode" == "$HA_MODE" ]; then
            if [ -z "$localIp" ];then
                usage
                die "localIp:$localIp is invalid"
            fi
            
            if [ "$localIp" == "$floatIp" ];then
                usage
                die "local ip: $localIp can not same as floatIp: $floatIp"
            fi
        
            if [ -z "$remoteIp" ];then
                usage
                die "remoteIp:$remoteIp is invalid"
            fi
            
            if ! checkIps "$remoteIp" "$floatMask" "$floatGw" 2>> $LOG_FILE; then
                usage
                die "remote ip info: $remoteIp $floatMask $floatGw is invlaid"
            fi
            
            if [ "$remoteIp" == "$floatIp" ];then
                usage
                die "remoteIp: $remoteIp can not s ame as floatIp: $floatIp"
            fi
            
            if [ "$remoteIp" == "$localIp" ];then
                usage
                die "remoteIp: $remoteIp can not same as localIp: $localIp"
            fi
            
            if ! [ -f $GMN_INIT_CFG ]; then
                firstIp=$(echo -e "$localIp\n$remoteIp" | sort | head -1)
                if [ "$firstIp" == "$localIp" ];then
                    localHost="GMN01"
                    remoteHost="GMN02"
                else
                    localHost="GMN02"
                    remoteHost="GMN01"
                fi
            fi
        fi
        
        if [ -n "$itfName" ]; then
            INTF="$itfName"
        else
            INTF=$(ifconfig -a |grep 'inet addr:' -B1 | grep '^eth*' | head -1 | awk '{print $1}')
            if [ -z "$INTF" ]; then
                INTF="eth0"
            fi
        fi
        
        # ��ʱ��֧�����õ���
        echo "
[GLOBAL]
# true: HA mode(2 GMN node provider HA); false: Single Mode(only 1 GMN node)
haMode=$haMode
# Single Mode no need haArbitrateIP
# ha arbitrate ip, input ip of the switch which direct connect to GMN node or ip of GMN's gateway
haArbitrateIP=$haArbitrationIP
# fmDeployMode Top FM or Local FM
# 1��allinone��2��top��3��local��4��elb
fmDeployMode=$fmDeployMode
# y�Ǽ���IP���������127.0.0.1
externDb=$externDb

# GMN float IP information
FLOAT_GMN_EX_IP=$floatIp
# netmask
FLOAT_GMN_EX_MASK=$floatMask
# gateway
FLOAT_GMN_EX_GW=$floatGw

# GMN float IP information
FLOAT_GMN_OM_IP=$omFloatIp
# netmask
FLOAT_GMN_OM_MASK=$omFloatMask
# gateway
FLOAT_GMN_OM_GW=$omFloatGw

# local node information
[LOCAL]
# local host name
nodeName=$localHost
# local GMN node ip information
GMN_EX_IP=$localIp
# netmask
GMN_EX_MASK=$floatMask
# gateway
GMN_EX_GW=$floatGw
# GmnEx: config network bridge for eth0; eth0: no need network bridge
GMN_EX_INTF=$INTF
# Vlan ID, if gmn is a vm, it is not necessary 
GMN_EX_VLAN=

# local GMN node ip information
GMN_OM_IP=$omLocalIp
# netmask
GMN_OM_MASK=$omFloatMask
# gateway
GMN_OM_GW=$omFloatGw

# local node information
[REMOTE]
# local host name
nodeName=$remoteHost
# local GMN node ip information
GMN_EX_IP=$remoteIp
# netmask
GMN_EX_MASK=$floatMask
# gateway
GMN_EX_GW=$floatGw
# GmnEx: config network bridge for eth0; eth0: no need network bridge
GMN_EX_INTF=$INTF
# Vlan ID, if gmn is a vm, it is not necessary 
GMN_EX_VLAN=

# local GMN node ip information
GMN_OM_IP=$omRemoteIp
# netmask
GMN_OM_MASK=$omFloatMask
# gateway
GMN_OM_GW=$omFloatGw
" > $HA_DIR/conf/noneAllInOne/gmn.cfg
        
        mkdir -p $HA_DIR/conf/arb
        mkdir -p $HA_DIR/conf/arb/certs
        
        echo "
arb.enable=$arb_enable
arb.ips=$arb_ips
arb.username=$arb_username
arb.password=$arb_password
arb.localDC=$arb_localDC
arb.localAZ=
arb.remoteDC=$arb_remoteDC
arb.remoteAZ=
arb.privatepwd=$arb_privatepwd
arb.keystore=$arb_ca_crt
arbInterval=$arbInterval
arbValidTime=$arbValidTime
fIPNetmask=$fIPNetmask
fIPName=$fIPName
" > $HA_DIR/conf/arb/arb.properties
        
        echo "$arb_ca_crt" > $HA_DIR/conf/arb/certs/ca.crt

        #以下临时处理目录，安装完成，执行清理.
        #包装的加解密工具SecurityPackage已经安装在/opt/gaussdb/ha/tools/arb
        if [ -d /tmp/SecurityPackage/script ];then
            pwd1=`pwd`
            cd /tmp/SecurityPackage/script;chmod +x *.sh
        else
            ECHOANDLOG_INFO "Enter manual cp"
            if [ -f /tmp/SecurityPackage.tar.gz ];then
                pwd1=`pwd`
            else
                cp /opt/gaussdb/ha/tools/arb/SecurityPackage.tar.gz /tmp
            fi

            cd /tmp ; tar -xvf SecurityPackage.tar.gz
            cd SecurityPackage/script;chmod +x *.sh
        fi

        ECHOANDLOG_INFO "$haMode configHa4CI.sh-->config_ommha_cert.sh IPV4 Start !!" 
        if [ "2" == "$haMode" ];then
            cd $HA_DIR/install ; 
            . config_ommha_cert.sh || return 1
            if [ 0 -ne $? ];then
                die "configHa4CI.sh-->config_ommha_cert.sh IPV4 Failed"
            else
                ECHOANDLOG_INFO "configHa4CI.sh-->config_ommha_cert.sh IPV4 Successful!!" 
            fi
        fi
        # config ommha certificate  
        # ǿ�Ʒ�һ�����
        $HA_DIR/tools/gmninit.sh "1" restore $HA_DIR/conf/noneAllInOne/gmn.cfg || return 1
        [ -n "$CONFIG_RESULT" ] && echo 90 >> $CONFIG_RESULT

        cd /tmp/SecurityPackage/script;chmod +x *.sh
        # config third arbitration
        ECHOANDLOG_INFO "=======================================================IMPORTANT========================================================"
        ECHOANDLOG_INFO "Start config the third arbitration"
        ECHOANDLOG_INFO "=======================================================IMPORTANT========================================================"
        if [ "$arb_enable" = "true" ]; then
            ECHOANDLOG_INFO "Start config third arbitration,wait for ha sync ,estimate 5 Mins ."
            arb_ip1=`echo $arb_ips | sed 's/,/ /g' `
            ECHOANDLOG_INFO "arb_ip $arb_ip1"
            for ipAndPort in $arb_ip1;do
                ip=`echo $ipAndPort | awk -F: '{print $1}'`
                port=`echo $ipAndPort | awk -F: '{print $2}'`
                if ! checkIp $ip;then
                    ECHOANDLOG_ERROR "the arb servers ip $ip is invalid."
                    exit 1
                fi
                
                if ! validPort $port;then
                    ECHOANDLOG_ERROR "the arb servers port $port is invalid."
                    exit 1
                fi
            done
            
            ECHOANDLOG_INFO "Waiting For HA Cluster to synchronize"
            sleep 60
            ECHOANDLOG_INFO "Begin to config the third arbitration"



            upass=`./decrypt.sh -d "$arb_password" | awk -F: '{print $2}' | xargs echo`
            ppass=`./decrypt.sh -d "$arb_privatepwd" | awk -F: '{print $2}' | xargs echo`
            sh decrypt.sh -d "$arb_ca_crt" | sed 's/Decrypted password: //' | sed 's/last cmd result: 0//' | grep -v "^$" > $HA_DIR/conf/arb/certs/ca.crt
            if [ $? -eq 0 ];then
                ECHOANDLOG_INFO "get arb_ca_crt"
                cd $pwd1
            else
                ECHOANDLOG_ERROR "decrypt error !"
                exit 1
            fi
            
            thirddir=$HA_DIR/module/thirdArb

            $HA_DIR/module/hacom/script/config_ha.sh -y true $arb_ips $arb_localDC $arb_remoteDC
            
            if [ $? -ne 0 ] ;then
                ECHOANDLOG_ERROR "Failed $HA_DIR/module/hacom/script/config_ha.sh -y true $arb_ips $arb_localDC $arb_remoteDC"
                exit 1
            else
                source /etc/profile
                $thirddir/script/modThirdArbInfo.sh -j root
                $thirddir/script/modThirdArbInfo.sh -u $arb_username -s <<EOF
$upass
$upass
EOF
                if [ $? -ne 0 ] ;then
                    ECHOANDLOG_ERROR "Failed $thirddir/script/modThirdArbInfo.sh -u $arb_username -s"
                    exit 1
                else
                    $thirddir/script/modThirdArbInfo.sh -c $HA_DIR/conf/arb/certs/ca.crt -s <<EOF
$ppass
$ppass
EOF
                    if [ $? -ne 0 ];then
                        ECHOANDLOG_ERROR "Failed $thirddir/script/modThirdArbInfo.sh -c $HA_DIR/conf/arb/certs/ca.crt -s"
                        rm -rf /tmp/client_tools
                        rm -f /tmp/SecurityPackage.tar.gz
                        rm -rf /tmp/SecurityPackage
                        exit 1
                    else
                        #清理临时处理目录,安装完成.
                        rm -rf /tmp/client_tools
                        rm -f /tmp/SecurityPackage.tar.gz
                        rm -rf /tmp/SecurityPackage

                        $thirddir/script/thirdArbHealthCheck.sh
                        if [ $? -ne 0 ];then
                            ECHOANDLOG_ERROR "Failed $thirddir/script/thirdArbHealthCheck.sh"
                            exit 1
                        else
                            $HA_DIR/module/hacom/script/stop_ha_process.sh
                        fi
                        ECHOANDLOG_INFO "Successful Config the third arbitration"
                    fi 
                fi
            fi
        else
            ECHOANDLOG_INFO "configHa4CI successful"
        fi
        
    else    
        if [ -f $GMN_INIT_CFG ]; then
            getHaParameterFromFile
        else
            getHaParameterFromInput "$@"
        fi
        
        if [ -z "$floatGw" ]; then
            usage
            die "floatGw $floatGw is invalid !!! floatGw"
        fi
        
        if [ -z "$omFloatGw" ]; then
            omFloatGw=$floatGw
        fi
        
        if [ -z "$floatIp" ];then
            usage
            die "floatIp $floatIp is invalid !!! floatIp"
        fi
        
        if [ -z "$floatMask" ];then
            usage
            die "floatMask $floatMask is invalid !!! floatMask"
        fi
        
        if ! checkIps "$floatIp" "$floatMask" "$floatGw" 2>> $LOG_FILE; then
            usage
            die "floating ip info: $floatIp floatMask:$floatMask $floatGw is invlaid"
        fi
        
        if ! checkIps "$localIp" "$floatMask" "$floatGw" 2>> $LOG_FILE; then
            usage
            die "local ip info: $localIp floatMask:$floatMask $floatGw is invlaid"
        fi
        
        if [ "$haMode" == "1" ]; then
            if [ "$arb_enable" == "true" ];then
                die "ha mode: haMode $haMode or arb_enable $arb_enable is invalid."
            fi
        fi
        
        if [ "$haMode" == "$HA_MODE" ]; then
            if [ -z "$localIp" ];then
                usage
                die "localIp:$localIp is invalid"
            fi
            
            if [ "$localIp" == "$floatIp" ];then
                usage
                die "local ip: $localIp can not same as floatIp: $floatIp"
            fi
        
            if [ -z "$remoteIp" ];then
                usage
                die "remoteIp:$remoteIp is invalid"
            fi
            
            if ! checkIps "$remoteIp" "$floatMask" "$floatGw" 2>> $LOG_FILE; then
                usage
                die "remote ip info: $remoteIp floatMask:$floatMask $floatGw is invlaid"
            fi
            
            if [ "$remoteIp" == "$floatIp" ];then
                usage
                die "remoteIp: $remoteIp can not s ame as floatIp: $floatIp"
            fi
            
            if [ "$remoteIp" == "$localIp" ];then
                usage
                die "remoteIp: $remoteIp can not same as localIp: $localIp"
            fi
            
            if ! [ -f $GMN_INIT_CFG ]; then
                firstIp=$(echo -e "$localIp\n$remoteIp" | sort | head -1)
                if [ "$firstIp" == "$localIp" ];then
                    localHost="GMN01"
                    remoteHost="GMN02"
                else
                    localHost="GMN02"
                    remoteHost="GMN01"
                fi
            fi
        
        fi
        
        if [ -n "$itfName" ]; then
            INTF="$itfName"
        else
            INTF=$(ifconfig -a |grep 'inet addr:' -B1 | grep '^eth*' | head -1 | awk '{print $1}')
            if [ -z "$INTF" ]; then
                INTF="eth0"
            fi
        fi
        
        # ��ʱ��֧�����õ���
        echo "
[GLOBAL]
# true: HA mode(2 GMN node provider HA); false: Single Mode(only 1 GMN node)
haMode=$haMode
# Single Mode no need haArbitrateIP
# ha arbitrate ip, input ip of the switch which direct connect to GMN node or ip of GMN's gateway
haArbitrateIP=$haArbitrationIP
# fmDeployMode Top FM or Local FM
# 1��allinone��2��top��3��local��4��elb
fmDeployMode=$fmDeployMode
# y�Ǽ���IP���������127.0.0.1
externDb=$externDb

# GMN float IP information
FLOAT_GMN_EX_IP=$floatIp
# netmask
FLOAT_GMN_EX_MASK=$floatMask
# gateway
FLOAT_GMN_EX_GW=$floatGw

# GMN float IP information
FLOAT_GMN_OM_IP=$omFloatIp
# netmask
FLOAT_GMN_OM_MASK=$omFloatMask
# gateway
FLOAT_GMN_OM_GW=$omFloatGw

# local node information
[LOCAL]
# local host name
nodeName=$localHost
# local GMN node ip information
GMN_EX_IP=$localIp
# netmask
GMN_EX_MASK=$floatMask
# gateway
GMN_EX_GW=$floatGw
# GmnEx: config network bridge for eth0; eth0: no need network bridge
GMN_EX_INTF=$INTF
# Vlan ID, if gmn is a vm, it is not necessary 
GMN_EX_VLAN=

# local GMN node ip information
GMN_OM_IP=$omLocalIp
# netmask
GMN_OM_MASK=$omFloatMask
# gateway
GMN_OM_GW=$omFloatGw

# local node information
[REMOTE]
# local host name
nodeName=$remoteHost
# local GMN node ip information
GMN_EX_IP=$remoteIp
# netmask
GMN_EX_MASK=$floatMask
# gateway
GMN_EX_GW=$floatGw
# GmnEx: config network bridge for eth0; eth0: no need network bridge
GMN_EX_INTF=$INTF
# Vlan ID, if gmn is a vm, it is not necessary 
GMN_EX_VLAN=

# local GMN node ip information
GMN_OM_IP=$omRemoteIp
# netmask
GMN_OM_MASK=$omFloatMask
# gateway
GMN_OM_GW=$omFloatGw
" > $HA_DIR/conf/noneAllInOne/gmn.cfg
        
        mkdir -p $HA_DIR/conf/arb
        mkdir -p $HA_DIR/conf/arb/certs
        
        echo "
arb.enable=$arb_enable
arb.ips=$arb_ips
arb.username=$arb_username
arb.password=$arb_password
arb.localDC=$arb_localDC
arb.localAZ=
arb.remoteDC=$arb_remoteDC
arb.remoteAZ=
arb.privatepwd=$arb_privatepwd
arb.keystore=$arb_keystore
arbInterval=$arbInterval
arbValidTime=$arbValidTime
fIPNetmask=$fIPNetmask
fIPName=$fIPName
" > $HA_DIR/conf/arb/arb.properties
        
        echo "$arb_keystore" > $HA_DIR/conf/arb/certs/arb.keystore

            #以下临时处理目录，安装完成，执行清理.
            #包装的加解密工具SecurityPackage已经安装在/opt/gaussdb/ha/tools/arb
            if [ -d /tmp/SecurityPackage/script ];then
                pwd1=`pwd`
                cd /tmp/SecurityPackage/script;chmod +x *.sh
            else
                ECHOANDLOG_INFO "Enter manual cp"
                if [ -f /tmp/SecurityPackage.tar.gz ];then
                    pwd1=`pwd`
                else
                    cp /opt/gaussdb/ha/tools/arb/SecurityPackage.tar.gz /tmp
                fi

                cd /tmp ; tar -xvf SecurityPackage.tar.gz
                cd SecurityPackage/script;chmod +x *.sh
            fi

            # config ommha certificate
            ECHOANDLOG_INFO "$haMode configHa4CI.sh-->config_ommha_cert.sh IPV6 Start !!" 
            if [ "2" == "$haMode" ];then
                cd $HA_DIR/install ; 
                . config_ommha_cert.sh || return 1
                if [ 0 -ne $? ];then
                    die "configHa4CI.sh-->config_ommha_cert.sh IPV6 Failed"
                else
                    ECHOANDLOG_INFO "configHa4CI.sh-->config_ommha_cert.sh IPV6 Successful!!" 
                fi
            fi
            # config ommha certificate   
            # ǿ�Ʒ�һ�����
            $HA_DIR/tools/gmninit.sh "1" restore $HA_DIR/conf/noneAllInOne/gmn.cfg || return 1
            [ -n "$CONFIG_RESULT" ] && echo 90 >> $CONFIG_RESULT
            ECHOANDLOG_INFO "configHa4CI successful"      
    fi
}

if [ "$1" == "-h" -o "$1" == "--help" -o "$1" == "help" ];then
    usage
    exit 0
fi

# ����Ƿ���root�û�ִ�е�
checkUserRoot

main "$@" || die "configHa4CI failed"

exit 0
