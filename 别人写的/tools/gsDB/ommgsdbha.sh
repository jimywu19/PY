#!/bin/bash
set +x
fpr1nt="$fpr1nt@$$"
__dig__=`md5sum $0|awk '{print $1}'` 

. ~/.bashrc
. /etc/profile 2>/dev/null

# 获取脚本所在的当前路径
cd $(dirname $0)
declare -r gCurPath="$PWD"
cd - >/dev/null

if ! . "${gCurPath}/../func/func.sh" ; then
    echo "[$(date)]ERROR: load ${gCurPath}/../func.sh failure!"
    exit 1
fi

if ! . "${gCurPath}/dbfunc.sh" ; then
    echo "[$(date)]ERROR: load ${gCurPath}/dbfunc.sh failure!"
    exit 1
fi

LOG_FILE="$_HA_SH_LOG_DIR_/dbmonitor.log"

if ! . "${gCurPath}/dbcommand.sh" ; then
    LOG_ERROR "load ${gCurPath}/dbcommand.sh failure!"
    exit 2
fi

NOTIFYSCRIPTNAME="${gCurPath}/../../../ha/module/harm/plugin/script/omm_module_notify.sh"
MODULENAME="gsdb"

######################################################################
#   FUNCTION   : getDBStatusInfo
#   DESCRIPTION: 获取数据库状态信息，去除不需要的信息。
#   0 为正在运行
######################################################################
getDBStatusInfo()
{
    local dbPwd=$(sudo /usr/local/bin/pwswitch -D key.so -fp "$fpr1nt")
    $OMM_GS_CTL -P "$dbPwd" -L query 2>&1 | grep -vEw "$gs_notneedinfo"
    unset dbPwd
}


######################################################################
#   FUNCTION   : isDBrunning
#   DESCRIPTION: 判断数据库是否正在运行
#   0 为正在运行
######################################################################
isDBRunning()
{
    local -i retVal=0
    local dbinfo=""
    local dbresult=""

    local dbPwd=$(sudo /usr/local/bin/pwswitch -D key.so -fp "$fpr1nt")
    # 获取数据运行状态，判断数据库是否正在运行
    dbinfo=$($OMM_GS_CTL -P "$dbPwd" -L status 2>&1 )
    unset dbPwd

    # 数据库正在运行
    dbresult=$(echo "$dbinfo" | grep -w "server is running" ); retVal=$?
    if [ $retVal -eq $r_success ] ; then
        LOG_INFO "db is running now. [$dbresult]."
        return $r_success
    fi

    # 数据库不在运行中
    LOG_INFO "db is not running now. [$dbinfo]."
    return $r_failure
}

######################################################################
#   FUNCTION   : doRepair_double
#   DESCRIPTION: 双机数据修复函数
######################################################################
doRepair_double()
{
    # 修复只做rebuild操作。数据库角色不正确，通过激活和去激活恢复
    # 修复操作只有数据库角色为备或级联备端，同时数据库状态为 NeedRepair
    # 而且数据库连接状态不为连接中，或是连接断开
    local dbinfo=""
    local -i retVal=$r_success

    # 查询数据库是否正常运行
    # 数据库未启动
    if ! isDBRunning; then
        LOG_WARN "[doRepair_double] db no runnig now."

        # 数据库没有运行，有可能是启动不了，检查是否需要重建
        isNeedRebuild; retVal=$?
        if [ $retVal -eq $db_abnormal ]; then
            # 调用命令进行重建
            LOG_WARN "[doRepair_double] start to repair by [$OMM_GS_CTL build]. "
            local dbPwd=$(sudo /usr/local/bin/pwswitch -D key.so -fp "$fpr1nt")
            $OMM_GS_CTL -P "$dbPwd" build; retVal=$? ;
            unset dbPwd

            # 重建完成，需要清空一下记录
            recordStartResult $retVal
            #
            recordBuildResult $retVal
            LOG_WARN "[doRepair_double] repair finish[$retVal]."
            return $retVal
        fi

        return $db_stopped
    fi

    # 获取数据库状态
    dbinfo=$(getDBStatusInfo)

    # 从数据库的查询结果中分离出各项信息: LOCAL_ROLE, DB_STATE, DETAIL_INFORMATION, PEER_ROLE. 前面四个变量会在getDBStateWithoutCasecade赋值。
    getDBStateWithoutCasecade "$dbinfo"; retVal=$?

    # 不为备状态，或是级联备，不处理
    if [ "$LOCAL_ROLE" != "$gs_r_standby" -a "$LOCAL_ROLE" != "$gs_r_cstandby" ]; then
        LOG_WARN "[doRepair_double] LOCAL_ROLE[$LOCAL_ROLE] error. [$dbinfo]"
        return $r_success
    fi

    # 不是待修复状态，不处理
    if [ "$DB_STATE" != "$gs_s_needrepair" ]; then
        LOG_WARN "[doRepair_double] current DB_STATE[$DB_STATE] no need to repair. [$dbinfo]"
        return $r_success
    fi

    # 详细信息不需要重建，则不重建
    if ! echo "$DETAIL_INFORMATION" | grep -E "$gs_r_canrepair"; then
        LOG_WARN "[doRepair_double] current DETAIL_INFORMATION[$DETAIL_INFORMATION] error, it can not be repair. [$dbinfo]"
        return $r_success
    fi

    # 调用命令进行重建
    LOG_WARN "[doRepair_double] start to repair. [$dbinfo]"
    local dbPwd=$(sudo /usr/local/bin/pwswitch -D key.so -fp "$fpr1nt")
    $OMM_GS_CTL -P "$dbPwd" build; retVal=$?
    unset dbPwd

    # 重建完成，需要清空一下记录
    recordStartResult $retVal

    LOG_WARN "[doRepair_double] repair finish[$retVal]."

    return $retVal
}

######################################################################
#   FUNCTION   : doStop
#   DESCRIPTION: 数据库停止函数
######################################################################
doStop()
{
    local -i retVal=$r_success

    # 停止数据库
    local dbPwd=$(sudo /usr/local/bin/pwswitch -D key.so -fp "$fpr1nt")
    dbinfo=$($OMM_GS_CTL -P "$dbPwd" stop -m fast); retVal=$?
    unset dbPwd

    # 强制停数据库
    doStopforce

    return $r_success
}

######################################################################
#   FUNCTION   : doStopforce
#   DESCRIPTION: 数据库强制停止函数
######################################################################
doStopforce()
{
    local -i retVal=$r_success

    # 强制停止数据库
    local dbPwd=$(sudo /usr/local/bin/pwswitch -D key.so -fp "$fpr1nt")
    dbinfo=$($OMM_GS_CTL -P "$dbPwd" stop -m immediate); retVal=$?
    unset dbPwd

    # 强制杀进程
    ps -eo pid,euid,cmd | grep -E '[/, ]gaussdb[:, ]|[/, ]gaussdb$' | grep -v 'grep' | grep -v '[/, ]gaussdb[ ,]start' |  awk '{if($2 == curuid) print $1}' curuid=`id -u` | xargs kill -9 2>&1

    return $r_success
}

######################################################################
#   FUNCTION   : isNeedRebuild
#   DESCRIPTION: 判断能否进行重建
#####################################################################
isNeedRebuild()
{
    local -i failCount=0
    local buildStr=""

    local dbPwd=$(sudo /usr/local/bin/pwswitch -D key.so -fp "$fpr1nt")
    buildStr=$($OMM_GS_CTL -P "$dbPwd" querybuild 2>&1)
    unset dbPwd

    # 如果当前正在进行重建中，则还不需要处理
    if echo "$buildStr" | grep -w "Building" > /dev/null; then
        LOG_WARN "[isNeedRebuild] DB is rebuilding now. [$buildStr]"
        return $db_repairing
    fi

    # 数据库重建连续失败，需要重启数据库
    failCount=$(cat "$BUILD_FAIL_RECORD")
    if [ $failCount -gt $TIMES_TO_START ]; then
        LOG_ERROR "[isNeedRebuild] DB build failure for $failCount times, need restart. [$buildStr]"
        return $db_stop
    fi

    # 当前没有在重建，则判断数据库启动失败是否达到次数
    failCount=$(cat "$START_FAIL_RECORD")
    if [ $failCount -gt $TIMES_TO_REBUILD ]; then
        LOG_ERROR "[isNeedRebuild] DB start failure for $failCount times, need reparid. [$buildStr]"
        return $db_abnormal
    fi

    return $db_normal
}

######################################################################
#   FUNCTION   : StaToPri
#   DESCRIPTION: 备升主的操作， switchover，失败后尝试强制升主
######################################################################
StaToPri()
{
    local -i retVal=0

    local dbPwd=$(sudo /usr/local/bin/pwswitch -D key.so -fp "$fpr1nt")
    # 备升主，尝试正常切换 switchover
    $OMM_GS_CTL -P "$dbPwd" switchover -t 90
    retVal=$?
    unset dbPwd

    [ $retVal -eq 0 ] && relaodFloatIp; retVal=$?

    # 切换失败，命令执行失败或是状态没有切换为主用
    if [ $retVal -ne $r_success ] || ! checkLocalRole "$gs_r_primary"; then
        LOG_ERROR "[notifyToStandby] call [$OMM_GS_CTL switchover -t 90] failure[$retVal], try failover."

        # 是否需要尝试多几次后，再试呢？
        StaForceToPri; retVal=$?
        return $retVal
    fi

    # 切换成功
    return $r_success
}

######################################################################
#   FUNCTION   : StaForceToPri
#   DESCRIPTION: 备强制升主的操作， failover
######################################################################
StaForceToPri()
{
    local -i retVal=0

    local dbPwd=$(/usr/local/bin/pwswitch -D key.so -fp "$fpr1nt")
    # 备升主，强制切换 failover
    $OMM_GS_CTL -P "$dbPwd" failover
    unset dbPwd
    [ $retVal -eq 0 ] && relaodFloatIp; retVal=$?

    # 切换失败，命令执行失败或是状态没有切换为主用
    if [ $retVal -ne $r_success ] || ! checkLocalRole "$gs_r_primary"; then
        LOG_ERROR "[notifyToStandby] call [$OMM_GS_CTL failover] failure[$retVal], It can't be helped."
        return $r_failure
    fi

    return $r_success
}

######################################################################
#   FUNCTION   : notifyToPrimary
#   DESCRIPTION: 通知数据库角色转换为主的操作
######################################################################
notifyToPrimary()
{
    local -i retVal=0

    local dbPwd=$(sudo /usr/local/bin/pwswitch -D key.so -fp "$fpr1nt")
    # 通知数据库，将状态切换为主用
    $OMM_GS_CTL -P "$dbPwd" notify -w -M $gs_c_primary; retVal=$?
    unset dbPwd

    # 通知失败
    if [ $retVal -ne $r_success ]; then
        LOG_ERROR "[notifyToPrimary] call [$OMM_GS_CTL notify -M $gs_c_primary] failure[$retVal]."
        return $r_failure
    fi

    checkLocalRole "$gs_r_primary"

    return $r_success
}

######################################################################
#   FUNCTION   : notifyToStandby
#   DESCRIPTION: 通知数据库角色转换为备的操作
######################################################################
notifyToStandby()
{
    local -i retVal=0

    local dbPwd=$(sudo /usr/local/bin/pwswitch -D key.so -fp "$fpr1nt")
    # 通知数据库，将状态切换为备
    $OMM_GS_CTL -P "$dbPwd" notify -w -M $gs_c_standby; retVal=$?
    unset dbPwd

    # 通知失败
    if [ $retVal -ne $r_success ]; then
        LOG_ERROR "[notifyToStandby] call [$OMM_GS_CTL notify -M $gs_c_standby] failure[$retVal]."
        return $r_failure
    fi

    return $r_success
}

######################################################################
#   FUNCTION   : restartToState
#   DESCRIPTION: 重启数据库到目标状态的操作
#   需要输入重启后的检查状态，和重启后的状态，
######################################################################
restartToState()
{
    local chkState="$1"           # 启动后检查的状态
    local staState="$2"           # 启动时的状态
    local -i retVal=0

    LOG_INFO "[restartToState] start to restart db for $staState, and check state is $chkState."

    # 停止数据库，停止失败，则强制停止
    doStop

    # 启动数据库为目标状态
    if [ "$staState" == "$gs_c_normal" ]; then
        $OMM_GS_CTL start -w >>"$logFile" 2>&1; retVal=$?
    else
        $OMM_GS_CTL start -w -M "$staState" >>"$logFile" 2>&1; retVal=$?
    fi

    # 数据库未启动
    if [ $retVal -ne $r_success ]; then
        LOG_ERROR "[restartToState] call ($OMM_GS_CTL start [-M $staState]) failure[$retVal]."
        return $r_failure
    fi

    # 启动后，需要检查当前数据库是否已经启动
    if ! checkLocalRole "$chkState" ; then
        LOG_ERROR "[restartToState] call ($OMM_GS_CTL start [-M $staState]) success, but db still not [$chkState]."
        return $r_failure
    fi

    LOG_INFO "[restartToState] success to restart db for $staState, and check state is $chkState."
    return $r_success
}

####################################################################
#  FUNCTION     : main
#  DESCRIPTION  : PMS服务函数
#  CALLS        : 无
#  CALLED BY    : 无
#  INPUT        : 无
#  OUTPUT       : 无
#  READ GLOBVAR : 无
#  WRITE GLOBVAR: 无
#  RETURN       : 0 是
#                 1 否
####################################################################
function main()
{
    local -i retVal=0
    case "$optCommand" in
    status)
        # To Do 主备模式资源会用到 $2
        # 查询资源状态，返回码为上面列出的返回码
        getStatus; retVal=$?
        return $retVal
        ;;

    query)
        # 查询数据库双机状态，方便运维
        getDBStatusInfo; retVal=$?
        return $retVal
        ;;

    start)
        # To Do 主备模式资源不会用到该action（需要使用active）
        # 启动资源，返回码 0表示成功 1表示失败
        doStart; retVal=$?
        return $retVal
        ;;

    stop)
        # To Do
        # 停止资源，返回码 0表示成功 1表示失败
        doStop; retVal=$?
        return $retVal
        ;;

    force-stop|restart)
        # To Do在stop失败时，会执行此操作
        # 强制停止资源，返回码 0表示成功 1表示失败
        doStopforce; retVal=$?
        return $retVal
        ;;

    active)
        # To Do 仅主备模式资源会用到该action
        # 激活资源，返回码 0表示成功 1表示失败
        doActivate; retVal=$?
        return $retVal
        ;;
    deactive)
        # To Do 仅主备模式资源会用到该action
        # 去激活资源，返回码 0表示成功 1表示失败
        doDeactivate; retVal=$?
        return $retVal
        ;;

    repair)
        # To Do 此处可能需要使用 $2
        # 如果是停止失败，会进行force-stop，不需要修复
        # 在start、active、deactive失败时，会调用此接口
        # 修复资源，返回码 0表示成功 1表示失败
        doRepair; retVal=$?
        return $retVal
        ;;
    notify)
                # To Do 此处可能需要使用 $2
        # 资源状态变更时，会调用此操作
        # 资源状态变更通知，返回码 0表示成功 1表示失败
        [ -f "${NOTIFYSCRIPTNAME}" ] || { log "${NOTIFYSCRIPTNAME} is not exist." exit 0;}
        ${NOTIFYSCRIPTNAME} $MODULENAME $nextState
        exit $?
        ;;

    prepare)
        # To Do 此处可能需要使用 $2
        #主备切换之前，需要做的一些准备工作
        # 资源状态变更前的准备工作，返回码 0表示成功 1表示失败
        LOG_INFO "Not support cmd[$@]."
        return $db_notsupported
        ;;

    *)
        # 返回动作不存在
        LOG_INFO "Unknown cmd[$@]."
        return $db_notsupported
        ;;
    esac

}

# 获取脚本入参
declare DB_PWD="$1"; shift
declare logPath="$1"; shift
declare REMOTE_DC_NODE1_IP="$1"; shift
declare REMOTE_DC_NODE2_IP="$1"; shift
logFile="$logPath/omm_gaussdba.log"
inParamNum="$#"
inParamLst="$@"

DB_PWD=$(echo ${DB_PWD%\"})
DB_PWD=$(echo ${DB_PWD#\"})

echo $DB_PWD > key.so

declare optCommand="$1"; shift                                          # 当前运行的命令
declare runState="$1";  shift                                           # 当前ha的运行状态
declare selfParam="$1"; shift                                           # 自定义参数
[ "$optCommand" == "notify" ] && { declare nextState="$1"; shift; }     # 资源状态变更后的状态（仅在notify时有效，其他情况都无此入参），资源变更后的状态的取值为（0 = 正常, 1 = 故障）。
declare haName="$1";    shift                                           # ha name
eval $selfParam

declare scriptName="$(basename $0)"
LOG_WARN "Enter the script ${scriptName}($inParamNum): $inParamLst"

# 如果不是单机，则默认是双机配置
[ "$gsCurMode" != "$gsdbSingle" ] && gsCurMode="$gsdbDouble"

declare -i scriptRetVal=0
main ; scriptRetVal=$?

OMM_EXIT $scriptRetVal
