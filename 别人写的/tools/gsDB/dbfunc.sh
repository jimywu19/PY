#!/bin/bash


if [ "$__INSTALL_FUNCTION_SH__" == "" ]; then
    
    # 输出的颜色定义。
    declare -r BOLD="\033[1m"
    declare -r UNDERLINE="\033[4m"
    declare -r RESET="\033[0m"
    declare -r red="\033[1;31m"
    declare -r green="\033[1;32m"
    declare -r yellow="\033[1;33m"
    declare -r blue="\033[32;36m"
    declare -r underline="\033[4m"
    declare -r bold="\033[1m"
    declare -r normal="\033[0m"


    # 输出的日志级别
    declare -i ERROR="2"
    declare -i NOTICE="1"
    declare -i INFO="0"
    declare -i DEBUG_LEVEL="0"
    declare -a LOG_LEVEL=("INFO" "NOTICE" "ERROR")

    declare needOutScreen="no"                              # 日志是否需要输出到屏幕


    # 从数据库中查出的状态值
    declare -r gs_s_normal="Normal"                         # 表示数据库双机状态正常。
    declare -r gs_s_unknown="Unknown"                       # 表示未知的数据库双机状态。
    declare -r gs_s_needrepair="NeedRepair"                 # 表示数据库需要重建。
    declare -r gs_s_starting="Starting"                     # 表示数据库正在启动。
    declare -r gs_s_waiting="Waiting"                       # 表示正在等待主机降备（备机才有此状态）。
    declare -r gs_s_demoting="Demoting"                     # 表示主机正在进行降备过程（主机才有此状态）。
    declare -r gs_s_promoting="Promoting"                   # 表示备机正在进行升主过程（备机才有此状态）。
    declare -r gs_s_rebuilding="Rebuilding"                 # 表示备机正在进行重建过程（备机才有此状态）。

    # 从数据库中查出的数据库角色值
    declare -r gs_r_primary="Primary"                       # 表示本端数据库作为主机使用。
    declare -r gs_r_standby="Standby"                       # 表示本端数据库作为备机使用。
    declare -r gs_r_cstandby="$gs_r_standby"               # 表示本端数据库作为级联备机使用。
    declare -r gs_r_cstandby1="CascadeStandby"               # 表示本端数据库作为级联备机使用。
    declare -r gs_r_pending="Pending"                       # 表示本端数据库处于等待状态，此时可等待通知命令使其成为主机或备机。
    declare -r gs_r_normal="Normal"                         # 表示本端数据库作为单机使用。
    declare -r gs_r_unknown="UNKNOWN"                       # 表示本端数据库以未知的方式使用。

    # 从数据库中查出的详细重建原因
    declare -r gs_d_normal="Normal"                         # 表示双机关系正常，不需重建
    declare -r gs_d_connecting="Connecting"                 # 表示正在尝试进行连接
    declare -r gs_d_disconnected="Disconnected"             # 表示未连接
    declare -r gs_d_walremoved="WalSegmentRemoved"          # 表示日志段已删除
    declare -r gs_d_vernotmatched="VersionNotMatched"       # 表示版本不匹配
    declare -r gs_d_modenotmatched="ModeNotMatched"         # 表示模式不匹配
    declare -r gs_d_sysIDnotmatched="SystemIDNotMatched"    # 表示数据不是同源的，即双机间的数据目录不是同一个数据库初始化创建的
    declare -r gs_d_timenotmatched="TimeLineNotMatched"     # 表示时间线不匹配

    # 启动数据库时，指定角色的值
    declare -r gs_c_pending="pending"                       #
    declare -r gs_c_primary="primary"                       #
    declare -r gs_c_standby="standby"                       #
    declare -r gs_c_cstandby="$gs_c_standby"                       #
    declare -r gs_c_cstandby1="cascadestandby"                       #
    declare -r gs_c_normal="normal"                         #

    declare -i r_success=0
    declare -i r_failure=1

    # 高斯DB，能够进行重建的原因，其中gs_d_timenotmatched必须使用全量重建
    declare -r gs_r_canrepair="$gs_d_walremoved|$gs_d_sysIDnotmatched|$gs_d_timenotmatched"

    declare -r gs_notneedinfo="SENDER_SENT_LOCATION|SENDER_WRITE_LOCATION|SENDER_FLUSH_LOCATION|SENDER_REPLAY_LOCATION|RECEIVER_RECEIVED_LOCATION|RECEIVER_WRITE_LOCATION|RECEIVER_FLUSH_LOCATION|RECEIVER_REPLAY_LOCATION"

    # 返回码
    declare -i db_normal=0           #   正常运行
    declare -i db_abnormal=1         #   运行异常
    declare -i db_stopped=2          #   停止
    declare -i db_unknown=3          #   状态未知
    declare -i db_starting=4         #   正在启动
    declare -i db_stopping=5         #   正在停止
    declare -i db_primary=6          #   主正常运行
    declare -i db_standby=7          #   备正常运行
    declare -i db_activating=8       #   正在升主
    declare -i db_deactivating=9     #   正在降备
    declare -i db_notsupported=10    #   动作不存在
    declare -i db_repairing=11       #   正在修复

    # 返回值对应的字符串
    declare -a outRetString=("normal" "abnormal" "stopped" "unknown" "starting" "stopping"\
                             "primary" "standby" "activating" "deactivating" "notsupported" "repairing")

    declare gsCurMode=""                    # 当前数据库配置
    declare gsdbSingle="single"             # 高斯DB，单机配置
    declare gsdbDouble="double"             # 高斯DB，双机配置


    declare scriptName=""

    [ -z "$OMS_RUN_PATH" ] && OMS_RUN_PATH="/opt/omm/oms"
    if [ -n "$gCurPath" ]; then
        OMS_CUR_WORKSPACE=$(readlink -e "$gCurPath" | awk -F"$OMS_RUN_PATH" '{print $2}' | awk -F'/' '{print $2}')
    fi
    [ -z "$OMS_CUR_WORKSPACE" ] && OMS_CUR_WORKSPACE="workspace"

    LOG_TOOL="${OMS_RUN_PATH}/tools/omm_log"
    logFile="$logPath/gsDB/omm_gaussdba.log"

    OMM_GS_CTL="gs_ctl"

    # 因为数据库总是不会太完美的，总是需要管理脚本做这样那样的特殊处理，以下就是特殊处理需要使用的临时文件。
    declare START_FAIL_RECORD="$gCurPath/.startGS.fail"                      # 数据库启动失败的记录
    declare -i TIMES_TO_REBUILD=3                                            # 连续启动失败这么多次后，需要进行重建

    declare BUILD_FAIL_RECORD="$gCurPath/.buildGS.fail"                      # 数据库重建失败的记录
    declare -i TIMES_TO_START=1                                            # 连续启动重建这么多次后，需要进行重启


    __INSTALL_FUNCTION_SH__='initialized'
fi


######################################################################
#   FUNCTION   : log
#   DESCRIPTION: 打印错误
######################################################################
log()
{
    local -i LogLevel=$1
    [ $LogLevel -lt $DEBUG_LEVEL ] && return $r_success
    shift

    local status=$1
    shift

    # 日志工具： 日志文件 日志级别 日志内容 日志标识

    LOG_INFO "$*" "[$scriptName $optCommand]($$)"
    if [ "$needOutScreen" == "yes" ];then
        echo -e "${status}[$$]${LOG_LEVEL[$LogLevel]}: $* $normal"
    fi
}


######################################################################
#   FUNCTION   : OMM_EXIT
#   DESCRIPTION: 退出函数，用于退出脚本，并输出日志
######################################################################
OMM_EXIT()
{
    local -i retVal=$1
    shift 2
    LOG_WARN "Exit: $retVal[${outRetString[$retVal]}]."
    exit $retVal
}

######################################################################
#   FUNCTION   : isPrimary
#   DESCRIPTION: 检查当前调用的脚本的HA角色是否为主用
######################################################################
isPrimary()
{
    if [ "$runState" == "active" ]; then
        return $r_success
    fi

    return $r_failure
}

######################################################################
#   FUNCTION   : getDBstate
#   DESCRIPTION: 获取数据库状态，从数据库的查询结果中分离出各项信息
#                LOCAL_ROLE, DB_STATE, DETAIL_INFORMATION, PEER_ROLE
######################################################################
getDBState()
{
    local dbinfo="$1"

    LOCAL_ROLE=""; DB_STATE=""; DETAIL_INFORMATION=""; PEER_ROLE="";

    # 目前比较简单的做法，直接从结果中转换，没有再做其他处理
    eval $(echo "$dbinfo" | sed -e 's/:/=/g' | sed -e 's/ //g' | grep -Ew "LOCAL_ROLE|DB_STATE|DETAIL_INFORMATION|PEER_ROLE")

    return $r_success
}

deleteCasecadeInfo()
{
    local ip="$1"
    [ -n "$ip" ] || return 0
    while echo "$dbinfo" | grep -sq "CHANNEL.*\<$ip:" ; do
        local end=$(echo "$dbinfo" | sed -n "/CHANNEL.*\<$ip:/=" | head -1)
        [ -n "$end" ] || continue
        local begin=$(echo "$dbinfo" | sed -n "1,${end}p" | sed -rn "/(SENDER_|RECEIVER_)/=" | tail -1)
        [ -n "$begin" ] || continue
        dbinfo=$(echo "$dbinfo" | sed "$begin,${end}d")
    done
}

# 将数据库详情中容灾站点的链路信息删除
getDBStateWithoutCasecade()
{
    local dbinfo="$1"

    for a in $REMOTE_DC_NODE1_IP $REMOTE_DC_NODE2_IP ; do
        deleteCasecadeInfo "$a"
    done

    getDBState "$dbinfo"
}

retryReloadIp4Db()
{
    local externDb=$(grep ^externDb $HA_DIR/conf/runtime/gmn.cfg |awk -F= '{print $2}')
    if [ "$externDb" != "y" ]; then
        return 0
    fi

    local port=$(grep ^port $GAUSSDATA/postgresql.conf | awk '{print $3}')
    local floatIp=$(grep ^FLOAT_GMN_EX_IP $HA_DIR/conf/runtime/gmn.cfg |awk -F= '{print $2}')
    if lsof -ni :$port | grep -w "LISTEN" | grep -w "$floatIp" > /dev/null ; then
        LOG_INFO "bind $floatIp listen now"
        return 0
    fi

    LOG_INFO "no bind $floatIp, retry to reload IP"
    reloadIp4Db
}

reloadIp4Db()
{
    local externDb=$(grep ^externDb $HA_DIR/conf/runtime/gmn.cfg |awk -F= '{print $2}')
    if [ "$externDb" != "y" ]; then
        gs_guc reload -c listen_addresses="'127.0.0.1'"
    else
        local listen_addr=$(grep ^listen_addresses $GAUSSDATA/postgresql.conf | awk '{print $3}' | awk -F\' '{print $2}')
        local floatIp=$(grep ^FLOAT_GMN_EX_IP $HA_DIR/conf/runtime/gmn.cfg |awk -F= '{print $2}')
        if echo "$listen_addr" | grep -w "$floatIp"; then
            listen_addr=$(echo "$listen_addr" | awk -F, '{print $2","$1}')
        else
            listen_addr="$listen_addr,$floatIp"
        fi

        LOG_INFO "gs_guc reload -c listen_addresses="'$listen_addr'""
        gs_guc reload -c listen_addresses="'$listen_addr'"
    fi
}

######################################################################
#   FUNCTION   : OMM_EXIT
#   DESCRIPTION: 退出函数，用于退出脚本，并输出日志
######################################################################
checkLocalRole()
{
    local checkRole="$1"
    local dbinfo=""

    if [ "$checkRole" == "$gs_r_primary" ]; then
        reloadIp4Db
    fi

    # 获取数据库状态
    dbinfo=$(getDBStatusInfo)
    if ! echo "$dbinfo" | grep -w "LOCAL_ROLE" | grep -wE "$checkRole"; then
        LOG_ERROR "[checkLocalRole] get role[$checkRole] failure. [$dbinfo]"
        return $r_failure
    fi

    return $r_success
}

######################################################################
#   FUNCTION   : recordStartResult
#   DESCRIPTION: 记录启动结果，主要是对失败的结果进行记录
#                对于备数据库，一直没能启动成功，需要考虑重建
#####################################################################
recordStartResult()
{
    local -i subRet=$1
    local -i failCount=0

    # 启动失败，则需要记录失败的次数
    if [ $subRet -ne $r_success ];then
        failCount=$(cat $START_FAIL_RECORD)
        failCount=$failCount+1
        LOG_ERROR "[recordStartResult] DB start failure for $failCount times."
    fi

    echo $failCount > $START_FAIL_RECORD

    return $r_success
}

######################################################################
#   FUNCTION   : recordBuildResult
#   DESCRIPTION: 记录重建结果，主要是对失败的结果进行记录
#                对于数据库，一直没能启动成功，需要考虑重建
#####################################################################
recordBuildResult()
{
    local -i subRet=$1
    local -i failCount=0

    # 启动失败，则需要记录失败的次数
    if [ $subRet -ne $r_success ];then
        failCount=$(cat $BUILD_FAIL_RECORD)
        failCount=$failCount+1
        LOG_ERROR "[recordBuildResult] DB build failure for $failCount times."
    fi

    echo $failCount > $BUILD_FAIL_RECORD

    return $r_success
}

######################################################################
#   FUNCTION   : restartToNormal
#   DESCRIPTION: 将数据库重启为正常角色的操作
######################################################################
restartToNormal()
{
    local -i retVal=$r_success

    restartToState "$gs_r_normal" "$gs_c_normal"; retVal=$?
    recordStartResult $retVal ; recordBuildResult 0

    return $retVal
}

######################################################################
#   FUNCTION   : restartToPending
#   DESCRIPTION: 将数据库重启为Pending角色的操作
######################################################################
restartToPending()
{
    local -i retVal=0

    restartToState "$gs_r_pending" "$gs_c_pending" ; retVal=$?
    recordStartResult $retVal ; recordBuildResult 0

    return $retVal
}

######################################################################
#   FUNCTION   : restartToPrimary
#   DESCRIPTION: 将数据库重启为主的操作
######################################################################
restartToPrimary()
{
    local -i retVal=0

    restartToState "$gs_r_primary" "$gs_c_primary" ; retVal=$?
    recordStartResult $retVal ; recordBuildResult 0

    return $retVal
}

######################################################################
#   FUNCTION   : restartToStandby
#   DESCRIPTION: 将数据库重启为备的操作
######################################################################
restartToStandby()
{
    local -i retVal=0

    restartToState "$gs_r_standby" "$gs_c_standby" ; retVal=$?
    recordStartResult $retVal ; recordBuildResult 0

    return $retVal
}

######################################################################
#   FUNCTION   : restartToStandby
#   DESCRIPTION: 将数据库重启为级联的操作
######################################################################
restartToCStandby()
{
    local -i retVal=0

    restartToState "$gs_r_cstandby" "$gs_c_cstandby" ; retVal=$?
    recordStartResult $retVal ; recordBuildResult 0

    return $retVal
}

######################################################################
#   FUNCTION   : restartToStandby
#   DESCRIPTION: 将数据库重启为次级联的操作
######################################################################
restartToCStandby1()
{
    local -i retVal=0

    restartToState "$gs_r_cstandby1" "$gs_c_cstandby1" ; retVal=$?
    recordStartResult $retVal ; recordBuildResult 0

    return $retVal
}

######################################################################
#   FUNCTION   : relaodFloatIp
#   DESCRIPTION: 备机升主了,高斯无法加载配置 OMM脚本规避:BIGDATA-2996
######################################################################
relaodFloatIp()
{
    # TODO 分布式部署时需要处理
    return 0

    # [备注]: BIGDATA-2996
    local old_conf=""
    local flip_conf=""

    # 01.读取浮动IP配置
    old_conf=$(gsql -d postgres -p 21600  -c 'show listen_addresses' | grep localhost | sed 's/ //g')
    if [ -z "$old_conf" ]; then
       LOG_ERROR "[relaodFloatIp] get old float config failed."
       return 1
    fi

    # 02.翻转配置字符串 [目前来说只简单的支持一个浮动IP配置]
    first_para=$(echo "$old_conf" | awk -F',' '{print $1}')
    second_para=$(echo "$old_conf" | awk -F',' '{print $2}')

    flip_conf="$second_para,$first_para"
    flip_conf=$(echo "$flip_conf" | sed 's/ //g')
    LOG_INFO "[relaodFloatIp] after flip the float config:[$flip_conf]."

    # 03.调用GaussDB的重配置接口，更新此配置
    gs_guc reload -c listen_addresses="'$flip_conf'" >>"$logFile" 2>&1; iRet=$?
    if [ $iRet -ne 0 ]; then
        LOG_ERROR "[relaodFloatIp] config new float ip failed return:[$iRet]."
        return 1
    fi

    return 0
}

######################################################################
#   FUNCTION   : PriToSta
#   DESCRIPTION: 主降备的操作，实际就是重启为备
######################################################################
PriToSta()
{
    local -i retVal=0
    
    restartToStandby; retVal=$?
    
    return $retVal    
}
