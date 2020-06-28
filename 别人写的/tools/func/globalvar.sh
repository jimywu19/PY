#!/bin/bash

# 主备主机名定义
HOST1NAME=FMN1
HOST2NAME=FMN2

# 主备主机名小写定义
HOST1NAME_LOW=fmn1
HOST2NAME_LOW=fmn2

# 指定的时间，一小时
SWITCH_INTERVAL_TIME=3600
# 在上述指定时间内，主备倒换次数限制，目前限制为1小时最多来回倒换4次
MAX_SWITCH_NUM=4

# 心跳中断多久后，备机升主，单位：秒
HA_DEAD_TM=30
# 心跳中断多久后，备机升主，单位：分钟
HA_ALL_SYNC_TM=3

_HA_LOG_DIR_=/var/log/ha
_HA_SH_LOG_DIR_=$_HA_LOG_DIR_/shelllog
DB_USER=dbadmin
GSDB_ROLE=dbadmin
GMN_USER=gaussdb
GM_PATH=/opt/gaussdb

# 1是allinone、2是top、3是local、4是elb、5是SC
ALL_FM=1
TOP_FM=2
LOCAL_FM=3
ELB_FM=4
SC_FM=5

# 配置文件中单机模式的标记
SINGLE_FLAG_IN_CONF=1

# 配置文件中双机模式的标记
DOUBLE_FLAG_IN_CONF=2
DEPLOY_MODE=1
DUALMODE=1

#add for adapting IPV6
if [ -f "$HA_DIR/conf/noneAllInOne/gmninit.cfg" ]; then
    ip_type_res1=`cat $HA_DIR/conf/noneAllInOne/gmninit.cfg | grep ip_type | head -1 | awk -F= '{print $2}' `
    if [ -n "$ip_type_res1" ]; then
        ip_type_res2=`echo $ip_type_res1 | tr "[:lower:]" "[:upper:]" `
        if [ "$ip_type_res2" = "IPV6" ];then
            export IP_TYPE=IPV6
        fi
    fi
fi
#add for adapting IPV6

#add for upgrade flow
if [ -f "$HA_DIR/install/gmninit_new.cfg" ]; then
    ip_type_res1=`cat $HA_DIR/install/gmninit_new.cfg | grep ip_type | head -1 | awk -F= '{print $2}' `
    if [ -n "$ip_type_res1" ]; then
        ip_type_res2=`echo $ip_type_res1 | tr "[:lower:]" "[:upper:]" `
        if [ "$ip_type_res2" = "IPV6" ];then
            export IP_TYPE=IPV6
        fi
    fi
fi
#add for adapting IPV6
