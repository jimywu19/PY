#!/bin/bash

# 整个数据库监控的逻辑如下：
#   --------------------------------- 单机 ---------------------------------  #
#   如果数据库不在位，则返回停止，由启动脚本启动。
#   如果数据库角色不正确，且不是中间态，则返回异常，由修复脚本修复
#   修复时，如果在重建则本次不处理，等待重建完成后才修复
#   ========================================================================  #
#
#   --------------------------------- 双机 ---------------------------------  #
#
#
#
#
#   ========================================================================  #




######################################################################
#   FUNCTION   : getStatus
#   DESCRIPTION: 数据库状态查询函数
######################################################################
getStatus()
{
    # 数据库的状态检查大体步骤如下，具体处理单双机有一些区别
    # Step1: 数据库不在位，需要返回不在位
    # Step2: 数据库在位，检查是否pending，是则返回与期望状态相反
    # Step3: 数据库在位，处于中间状态，返回相应的中间态
    # Step4: 数据库在位，检查是否需要重建，如果需要重建，则数据库角色为备端返回需要重建
    # Step5: 数据库在位，不需要重建，如果数据库角色正确，返回OK
    # Step6: 数据库在位，数据库角色不正确，返回需要激活或去激活
    local -i retVal=$r_success

    if [ "$gsCurMode" == "$gsdbSingle" ]; then
        getStatus_single ; retVal=$?
    else
        getStatus_double ; retVal=$?
        if [ "$runState" == "active" ] && [ "$retVal" == "$db_primary" ]; then
            retryReloadIp4Db
        fi
    fi

    return $retVal
}

######################################################################
#   FUNCTION   : getStatus_single
#   DESCRIPTION: 单机数据库状态查询函数
#   脚本返回码 :
#   单主模式 或 双主模式
#    db_normal:0           #   正常运行
#    db_abnormal:1         #   运行异常
#    db_stopped:2          #   停止
#    db_unknown:3          #   状态未知
#    db_starting:4         #   正在启动
#    db_stopping:5         #   正在停止
#    db_primary:6          #   主正常运行
#    db_standby:7          #   备正常运行
#    db_activating:8       #   正在升主
#    db_deactivating:9     #   正在降备
#    db_notsupported:10    #   动作不存在
#    db_repairing:11       #   正在修复
######################################################################
getStatus_single()
{
    local dbinfo=""
    local -i retVal=$r_success

    # 查询数据库是否正常运行
    # 数据库未启动
    if ! isDBRunning; then
        LOG_ERROR "[getStatus_single] db no runnig now."
        return $db_stopped
    fi

    # 获取数据库状态
    dbinfo=$(getDBStatusInfo)

    # 从数据库的查询结果中分离出各项信息: LOCAL_ROLE, DB_STATE, DETAIL_INFORMATION, PEER_ROLE. 前面四个变量会在getDBStateWithoutCasecade赋值。
    getDBStateWithoutCasecade "$dbinfo"; retVal=$?             # 执行命令，立即获取返回值。写在同一行，是为了避免后续修改时，在两个语句中插入了其他命令，导致获取失败

    # 根据数据库的角色进行判断，正常情况下，只会出现Normal和空（即获取失败）
    case "$LOCAL_ROLE" in
        "$gs_r_normal")
            LOG_INFO "[getStatus_single] db current role Normal. [$dbinfo]"
            return $db_normal
            ;;

        # 以下三种状态，虽然在单机下不可能出现，但是需要进行异常处理，这三种状态下，先判断是否在重建中。
        "$gs_r_primary"|"$gs_r_standby"|"$gs_r_cstandby")
            LOG_WARN "[getStatus_single] db current role error[$LOCAL_ROLE], need further check. [$dbinfo]"
            ;;

        # Pending角色下的数据库，可以直接状态变更，所以返回未启动
        "$gs_r_pending")
            LOG_WARN "[getStatus_single] db current role Pending, need restart. [$dbinfo]"
            return $db_abnormal
            ;;

        # 其他角色不是数据库的正常角色，可能是获取失败了，认为数据库没有启动
        "$gs_r_unknown"|*)
            LOG_ERROR "[getStatus_single] db current role[$LOCAL_ROLE] error! [$dbinfo]"
            return $db_abnormal
            ;;
    esac

    # 以下判断是在本端数据库角色为主、备、级联备的情况的判断，属于异常处理。
    case "$DB_STATE" in
        # 以下几种状态，表示数据库状态不稳定，待稳定后再进行下一步处理，以避免出问题。
        "$gs_s_rebuilding")
            LOG_WARN "[getStatus_single] db state[$DB_STATE] instable now, need wait. [$dbinfo]"
            return $db_repairing
            ;;

        "$gs_s_demoting")
            LOG_WARN "[getStatus_single] db state[$DB_STATE] instable now, need wait. [$dbinfo]"
            return $db_deactivating
            ;;

        "$gs_s_waiting"|"$gs_s_promoting")
            LOG_WARN "[getStatus_single] db state[$DB_STATE] instable now, need wait. [$dbinfo]"
            return $db_activating
            ;;

        "$gs_s_starting")
            LOG_WARN "[getStatus_single] db state[$DB_STATE] instable now, need wait. [$dbinfo]"
            return $db_starting
            ;;

        # 其他状态，直接重启为单机
        "$gs_s_normal"|"$gs_s_needrepair"|"$gs_s_unknown"|*)
            LOG_WARN "[getStatus_single] db state[$DB_STATE] stable now, need restart. [$dbinfo]"
            return $db_abnormal
            ;;
    esac

    # 数据库正常运行
    return $db_normal
}


######################################################################
#   FUNCTION   : getStatus_double
#   DESCRIPTION: 双机数据库状态查询函数
#   脚本返回码 :
#   主备模式
#   db_normal:0           #   正常运行
#   db_abnormal:1         #   运行异常
#   db_stopped:2          #   停止
#   db_unknown:3          #   状态未知
#   db_starting:4         #   正在启动
#   db_stopping:5         #   正在停止
#   db_primary:6          #   主正常运行
#   db_standby:7          #   备正常运行
#   db_activating:8       #   正在升主
#   db_deactivating:9     #   正在降备
#   db_notsupported:10    #   动作不存在
#   db_repairing:11       #   正在修复
######################################################################
getStatus_double()
{
    local dbinfo=""
    local -i retVal=0
    local -i outResult=$r_success                    # 返回的结果，用于在主备用情况下，暂存结果。

    # 查询数据库是否正常运行
    # 数据库未启动
    if ! isDBRunning; then
        LOG_ERROR "[getStatus_double] db no runnig now."

        # 数据库没有运行，有可能是启动不了，检查是否需要重建
        isNeedRebuild; retVal=$?
        [ $retVal -eq $db_normal ] || return $retVal
        return $db_stopped
    fi

    # 获取数据库状态
    dbinfo=$(getDBStatusInfo)

    # 从数据库的查询结果中分离出各项信息: LOCAL_ROLE, DB_STATE, DETAIL_INFORMATION, PEER_ROLE. 前面四个变量会在getDBStateWithoutCasecade赋值。
    getDBStateWithoutCasecade "$dbinfo"; retVal=$?

    # 根据数据库的角色进行判断，正常情况下，只会出现 Pendig, Primary, Standby 和空（即获取失败）
    case "$LOCAL_ROLE" in
        # Pending状态下的数据库，可以直接状态变更，所以返回期望状态的反状态
        "$gs_r_pending")
            LOG_WARN "[getStatus_double] db current role[$LOCAL_ROLE], current ha role[$runState]."
            return $db_normal
            ;;

        # 以下两种状态，需要先判断是否正在重建
        "$gs_r_primary")
            outResult=$db_primary
            LOG_INFO "[getStatus_double] db current role[$LOCAL_ROLE], need further check."
            ;;

        "$gs_r_standby")
            outResult=$db_standby
            LOG_INFO "[getStatus_double] db current role[$LOCAL_ROLE], need further check."
            ;;

        # 以下角色不是双机会出现的角色，直接重启即可
        "$gs_r_normal"|"$gs_r_cstandby"|"$gs_r_unknown"|*)
            LOG_ERROR "[getStatus_double] db current role[$LOCAL_ROLE] error! [$dbinfo]"
            return $db_stopped
            ;;
    esac

    # 当前为HA的状态为未知时，数据库主备需要返回为正常
    [ "$runState" == "unknown" ] && outResult=$db_normal

    # 以下判断是在本端数据库角色为主、备、级联备的情况的判断，需要判断数据库的状态
    case "$DB_STATE" in
        # 以下几种状态，表示数据库状态不稳定，待稳定后再进行下一步处理，以避免出问题。
        "$gs_s_rebuilding")
            LOG_WARN "[getStatus_double] db state[$DB_STATE] instable now, need wait. [$dbinfo]"
            return $db_abnormal #HA advice when standby is repairing, return excepion to it.
            ;;

        "$gs_s_demoting")
            LOG_WARN "[getStatus_double] db state[$DB_STATE] instable now, need wait. [$dbinfo]"
            return $db_deactivating
            ;;

        "$gs_s_waiting"|"$gs_s_promoting")
            LOG_WARN "[getStatus_double] db state[$DB_STATE] instable now, need wait. [$dbinfo]"
            return $db_activating
            ;;

        "$gs_s_starting")
            LOG_WARN "[getStatus_double] db state[$DB_STATE] instable now, need wait. [$dbinfo]"
            return $db_starting
            ;;

        # 数据库需要重建，则需要考虑对端情况
        "NeedRepair")
            # 重建状态不一定都是需要修复的，这个需要高斯DB后续修改
            if echo "$DETAIL_INFORMATION" | grep -E "$gs_r_canrepair"; then
                LOG_WARN "[getStatus_double] db state[$DB_STATE] need repair now, and current role[$LOCAL_ROLE]. [$dbinfo]"
                # 如果数据库角色为主，则不先不进行其他处理
                [ "$LOCAL_ROLE" == "Primary" ] && return $db_activating
                # 否则，返回需要修复
                return $db_abnormal
            else
                LOG_WARN "[getStatus_double] db state[$DB_STATE] need repair now, but no need to repair, DETAIL_INFORMATION[$DETAIL_INFORMATION]. [$dbinfo]"
                return $outResult
            fi
            ;;

        # 其他状态，直接重启跳转到需要的状态
        "$gs_s_normal"|"$gs_s_unknown"|*)
            LOG_INFO "[getStatus_double] db state[$DB_STATE] stable now, can goto want role."
            return $outResult
            ;;
    esac

    # 数据库正常运行，返回当前状态
    return $db_normal
}


######################################################################
#   FUNCTION   : doStart
#   DESCRIPTION: 数据库启动函数
######################################################################
doStart()
{
    local -i retVal=$r_success

    # 未启动，则根据单机双机配置启动为相应的模式
    if [ "$gsCurMode" == "$gsdbSingle" ]; then
        doStart_single ; retVal=$?
    else
        doStart_double ; retVal=$?
    fi

    return $retVal
}

######################################################################
#   FUNCTION   : doStart_single
#   DESCRIPTION: 单机数据库启动函数，只将数据启动为Normal
######################################################################
doStart_single()
{
    local -i retVal=$r_success

    # 启动前，先检查当前数据库是否已经启动为Normal
    if checkLocalRole "Normal"; then
        LOG_INFO "[doStart_single] db had been start already."
        return $r_success
    fi

    # 启动数据库
    restartToNormal; retVal=$?

    return $retVal
}

######################################################################
#   FUNCTION   : doStart_double
#   DESCRIPTION: 双机数据库启动函数
######################################################################
doStart_double()
{
    local -i retVal=$r_success

    # 启动前，先检查当前数据库是否已经启动为Primary|standby|Pending
    if checkLocalRole "Primary|standby|Pending"; then
        LOG_INFO "[doStart_double] db had been start already."
        return $r_success
    fi

    # 启动数据库
    restartToPending; retVal=$?

    return $retVal
}

######################################################################
#   FUNCTION   : doActivate
#   DESCRIPTION: 数据库激活函数
######################################################################
doActivate()
{
    # 本端没有启动，尝试启动为主
    if ! isDBRunning; then
        LOG_WARN "[doActivate] db no runnig now."

        # 启动数据库
        restartToPrimary; retVal=$?
        return $retVal
    fi

    # 获取数据库状态
    dbinfo=$(getDBStatusInfo)

    # 从数据库的查询结果中分离出各项信息: LOCAL_ROLE, DB_STATE, DETAIL_INFORMATION, PEER_ROLE. 前面四个变量会在getDBStateWithoutCasecade赋值。
    getDBStateWithoutCasecade "$dbinfo"; retVal=$?

    case "$LOCAL_ROLE" in
        # 本端pending时，直接升主
        "$gs_r_pending")
            LOG_WARN "[doActivate] db current role[$LOCAL_ROLE], current ha role[$runState], need restart. [$dbinfo]"
            notifyToPrimary; retVal=$?
            return $retVal
            ;;

        # 已经是主用状态，不需要处理
        "$gs_r_primary")
            LOG_INFO "[doActivate] db current role[$LOCAL_ROLE] no need to change. [$dbinfo]"
            return $r_success
            ;;

        "$gs_r_standby")
            LOG_INFO "[doActivate] db current role[$LOCAL_ROLE], need further check. [$dbinfo]"
            ;;

        # 以下角色不是双机会出现的角色，直接重启即可
        "$gs_r_normal"|"$gs_r_cstandby"|"$gs_r_unknown"|*)
            LOG_ERROR "[doActivate] db current role[$LOCAL_ROLE] error! [$dbinfo]"
            restartToPrimary; retVal=$?
            return $retVal
            ;;
    esac

    # 本端角色不正确，需要判断对端，以及重建的情况
    case "$DB_STATE" in
        # 对端在位，且状态正常，先尝试switchover，再尝试failover
        "$gs_s_normal")
            LOG_WARN "[doActivate] db state[$DB_STATE] stable now, start change to primary. [$dbinfo]"
            StaToPri; retVal=$?
            return $retVal
            ;;

        # 以下几种状态，表示数据库状态不稳定，待稳定后再进行下一步处理，以避免出问题。
        "$gs_s_rebuilding"|"$gs_s_starting"|"$gs_s_demoting"|"$gs_s_promoting"|"$gs_s_waiting")
            LOG_WARN "[doActivate] db state[$DB_STATE] instable now, need wait. [$dbinfo]"
            return $r_success
            ;;

        # 数据库需要重建，待修复时处理
        "$gs_s_needrepair")
            # 重建状态不一定都是需要修复的，这个需要高斯DB后续修改
            if echo "$DETAIL_INFORMATION" | grep -E "$gs_r_canrepair"; then
                LOG_WARN "[doActivate] db state[$DB_STATE] need repair now, can not start to primary. [$dbinfo]"
                return $r_success
            fi

            # 不需要修复的情况，直接跳转到需要的状态。
                LOG_WARN "[doActivate] db state[$DB_STATE], DETAIL_INFORMATION[$DETAIL_INFORMATION] can not repair, start change to primary. [$dbinfo]"
                restartToPrimary; retVal=$?
                return $retVal
            ;;

        # 其他状态，直接重启跳转到需要的状态
        "$gs_s_unknown"|*)
            LOG_INFO "[doActivate] db state[$DB_STATE] stable now, can goto want role. [$dbinfo]"
            restartToPrimary; retVal=$?
            return $retVal
            ;;
    esac

    return $r_success
}

######################################################################
#   FUNCTION   : doDeactivate
#   DESCRIPTION: 数据库去激活函数
######################################################################
doDeactivate()
{
    # 本端没有启动，尝试启动为备
    if ! isDBRunning; then
        LOG_WARN "[doDeactivate] db no runnig now."

        # 启动数据库
        restartToStandby; retVal=$?
        return $retVal
    fi

    # 获取数据库状态
    dbinfo=$(getDBStatusInfo)

    # 从数据库的查询结果中分离出各项信息: LOCAL_ROLE, DB_STATE, DETAIL_INFORMATION, PEER_ROLE. 前面四个变量会在getDBStateWithoutCasecade赋值。
    getDBStateWithoutCasecade "$dbinfo"; retVal=$?

    case "$LOCAL_ROLE" in
        # 本端pending时，直接降备
        "$gs_r_pending")
            LOG_WARN "[doDeactivate] db current role[$LOCAL_ROLE], current ha role[$runState], need notify to standby. [$dbinfo]"

            notifyToStandby; retVal=$?
            return $retVal
            ;;

        # 已经是备用角色，不需要处理
        "$gs_r_standby")
            LOG_INFO "[doDeactivate] db current role[$LOCAL_ROLE] no need to change. [$dbinfo]"
            return $r_success
            ;;

        # 主角色下，需要检查
        "$gs_r_primary")
            LOG_INFO "[doDeactivate] db current role[$LOCAL_ROLE], need further check. [$dbinfo]"
            ;;

        # 以下角色不是双机会出现的角色，直接重启即可
        "$gs_r_normal"|"$gs_r_cstandby"|"$gs_r_unknown"|*)
            LOG_ERROR "[doDeactivate] db current role[$LOCAL_ROLE] error! [$dbinfo]"
            restartToStandby; retVal=$?
            return $retVal
            ;;
    esac

    # 本端角色不正确，需要判断对端，以及重建的情况
    case "$DB_STATE" in
        # 对端在位，且状态正常，不能直接降备，需要等待对端进行swithover或是双主时本端降备
        "$gs_s_normal")
            LOG_WARN "[doDeactivate] db state[$DB_STATE] stable now, start change to stabndby. [$dbinfo]"
            ;;

        # 以下几种状态，表示数据库状态不稳定，待稳定后再进行下一步处理，以避免出问题。
        "$gs_s_rebuilding"|"$gs_s_starting"|"$gs_s_demoting"|"$gs_s_promoting"|"$gs_s_waiting")
            LOG_WARN "[doDeactivate] db state[$DB_STATE] instable now, need wait. [$dbinfo]"
            return $r_success
            ;;

        # 数据库需要重建，待修复时处理
        "$gs_s_needrepair")
            # 重建状态不一定都是需要修复的，这个需要高斯DB后续修改
            if echo "$DETAIL_INFORMATION" | grep -E "$gs_r_canrepair"; then
                LOG_WARN "[doDeactivate] db state[$DB_STATE] need repair now, can not start to standby. [$dbinfo]"
                return $r_success
            fi

            # 不需要修复的情况，直接跳转到需要的状态。
            LOG_WARN "[doDeactivate] db state[$DB_STATE], DETAIL_INFORMATION[$DETAIL_INFORMATION] can not repair, start change to stabndby. [$dbinfo]"
            ;;

        # 其他状态，直接重启跳转到需要的状态
        "$gs_s_unknown"|*)
            LOG_INFO "[doDeactivate] db state[$DB_STATE] stable now, can goto want role. [$dbinfo]"
            restartToStandby; retVal=$?
            return $retVal
            ;;
    esac

    # 主降备，在操作前，需要看对端的状态
    if [ "" == "$PEER_ROLE" ]; then
        PriToSta; retVal=$?
        return $retVal
    fi

    LOG_WARN "[doDeactivate] db state[$DB_STATE] stable now, and peer role[$PEER_ROLE], need peer to primary first. [$dbinfo]"
    return $r_success
}


######################################################################
#   FUNCTION   : doNotify
#   DESCRIPTION: 数据异常时，通知函数。
######################################################################
doNotify()
{
    return $r_success
}


######################################################################
#   FUNCTION   : doRepair
#   DESCRIPTION: 数据修复函数
######################################################################
doRepair()
{
    local -i retVal=$r_success

    if [ "$gsCurMode" == "$gsdbSingle" ]; then
        doRepair_single ; retVal=$?
    else
        doRepair_double ; retVal=$?
    fi
    return $retVal
}


######################################################################
#   FUNCTION   : doRepair_single
#   DESCRIPTION: 单机数据修复函数
######################################################################
doRepair_single()
{
    # 数据库角色不正在，在此修复。
    # 如果当前不角色不正确，则进行重启，但是如果正在处理修复阶段，则先等待。
    local dbinfo=""
    local -i retVal=$r_success

    # 查询数据库是否正常运行
    # 数据库未启动
    if ! isDBRunning; then
        LOG_WARN "[doRepair_single] db no runnig now."

        # 启动数据库
        doStart_single; retVal=$?
        return $retVal
    fi

    # 获取数据库状态
    dbinfo=$(getDBStatusInfo)

    # 从数据库的查询结果中分离出各项信息: LOCAL_ROLE, DB_STATE, DETAIL_INFORMATION, PEER_ROLE. 前面四个变量会在getDBStateWithoutCasecade赋值。
    getDBStateWithoutCasecade "$dbinfo"; retVal=$?

    # 根据数据库的角色进行判断，正常情况下，只会出现Normal和空（即获取失败）
    case "$LOCAL_ROLE" in
        "$gs_r_normal")
            LOG_INFO "[doRepair_single] db current role Normal. [$dbinfo]"
            return $db_normal
            ;;

        # 以下三种状态，虽然在单机下不可能出现，但是需要进行异常处理，这三种状态下，目前不进行其他判断，直接重启
        "$gs_r_primary"|"$gs_r_standby"|"$gs_r_cstandby")
            LOG_WARN "[doRepair_single] db current role error[$LOCAL_ROLE], need restart. [$dbinfo]"
            # 重启数据库
            restartToNormal; retVal=$?
            return $retVal
            ;;

        # 其他角色不是数据库的正常角色，直接重启数据库
        *)
            LOG_ERROR "[doRepair_single] db current role[$LOCAL_ROLE] error! [$dbinfo]"
            # 重启数据库
            restartToNormal; retVal=$?
            return $retVal
            ;;
    esac

    # 重启数据库
    restartToNormal; retVal=$?    
    return $retVal
}


