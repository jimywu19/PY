#!/bin/bash

# ��������������
HOST1NAME=FMN1
HOST2NAME=FMN2

# ����������Сд����
HOST1NAME_LOW=fmn1
HOST2NAME_LOW=fmn2

# ָ����ʱ�䣬һСʱ
SWITCH_INTERVAL_TIME=3600
# ������ָ��ʱ���ڣ����������������ƣ�Ŀǰ����Ϊ1Сʱ������ص���4��
MAX_SWITCH_NUM=4

# �����ж϶�ú󣬱�����������λ����
HA_DEAD_TM=30
# �����ж϶�ú󣬱�����������λ������
HA_ALL_SYNC_TM=3

_HA_LOG_DIR_=/var/log/ha
_HA_SH_LOG_DIR_=$_HA_LOG_DIR_/shelllog
DB_USER=dbadmin
GSDB_ROLE=dbadmin
GMN_USER=gaussdb
GM_PATH=/opt/gaussdb

# 1��allinone��2��top��3��local��4��elb��5��SC
ALL_FM=1
TOP_FM=2
LOCAL_FM=3
ELB_FM=4
SC_FM=5

# �����ļ��е���ģʽ�ı��
SINGLE_FLAG_IN_CONF=1

# �����ļ���˫��ģʽ�ı��
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
