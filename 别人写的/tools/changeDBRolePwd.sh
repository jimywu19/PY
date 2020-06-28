#!/bin/bash
set +x
. /etc/profile 2>/dev/null

fpr1nt="$fpr1nt@$$"
__dig__=`md5sum $0|awk '{print $1}'`

. $HA_DIR/tools/func/globalvar.sh || { echo "fail to load $HA_DIR/tools/func/globalvar.sh"; exit 1; }
. $HA_DIR/tools/func/func.sh || { echo "fail to load $HA_DIR/tools/func/func.sh"; exit 1; }
. $HA_DIR/tools/func/dblib.sh || { echo "fail to load $HA_DIR/tools/func/dblib.sh"; exit 1; }
. $HA_DIR/tools/gsDB/dbfunc.sh || { echo "fail to load $HA_DIR/tools/gsDB/dbfunc.sh"; exit 1; }
. $HA_DIR/tools/backupAndRestore/com_fun.sh || { echo "fail to load $HA_DIR/tools/backupAndRestore/com_fun.sh"; exit 1; }

PG_HBA_CONF=$HA_DIR/../data/db/pg_hba.conf
mkdir -p $_HA_SH_LOG_DIR_
chown $DB_USER: $_HA_SH_LOG_DIR_
LOG_FILE=$_HA_SH_LOG_DIR_/changeDBRolePwd.log

unset DB_PWD_E
unset DB_PWD_VALUE
unset DB_ROLE_NAME
unset DB_NAME
unset OLDPASSWD
unset DBADMINPASSWD
unset NEWPASSWD
unset NEWPASSWDCONFIRM

getCurPath()
{
    if [ "` dirname "$0" `" = "" ] || [ "` dirname "$0" `" = "." ] ; then
        CURRENT_PATH="`pwd`"
    else
        cd ` dirname "$0" `
        CURRENT_PATH="`pwd`"
        cd - > /dev/null 2>&1
    fi
}

checkUser()
{
    local curUser=`/usr/bin/whoami | /usr/bin/awk '{print $1}'`
    if [ "${curUser}" != "root" ]; then
        echo "The current user is not root."
        exit 1
    fi
}

check_if_standby()
{
    is_primary
    retRes=$?
    if [ $retRes -eq 1 ]; then
        echo "This is standby node, execute in primary node !"
        LOG_ERROR "[End] This is standby node, execute in primary node !"
        exit 1
    fi
}

######function################################################
# method description: this script is used to limit password string by some rules
# rules: 
#  1. must contain special singnal as below:  `~!@#$%^&*()-_=+\|[{}];:'\",<.>/?  and space singnal
#  2. must obey any two rules as below :
#      1) must contain lowercase alphabet
#      2) must contain upercase alphabet
#      3) must contain numberic
#  3. should not be same with username and can not be a reversion string of username
#  4. length of string must be not less than 8.
############################################################
function checkPwd()
{
    local temp=$1;

    ###  rule4: length of string must be not less than 8.
    if [ ${#temp} -lt 8 ];then
        echo "Error: length of password less than 8.";
        LOG_ERROR "[End] length of password less than 8.";
        exit 1;
    fi
    
    ###  rule3:  password not be account name or its reversion
    local dbuser_rev=$(echo "$GSDB_ROLE"|rev);
    if [ "$temp" == "$GSDB_ROLE" ] || [ "$temp" == "$dbuser_rev" ]; then
        echo "Error: password not be account name or its reversion.";
        LOG_ERROR "[End] password not be account name or its reversion.";
        exit 1;
    fi
    
    ### rule1: could not contain special singnal    
    local result0=$(echo "$temp"|grep -e "[][\?\"\'/,\\]"|wc -l);
    if [ $result0 -ne 0 ];then
        echo "Error: password invalid.";
        LOG_ERROR "[End] password invalid.";
        exit 1;
    fi

    local result=$(echo "$temp"|grep -e "[\`\~\!\@\#\$%^&*\(\){}_=+|; :<.>]"|wc -l);
    ##   if $result is empty, then failed and retun 1
    if [ $result -eq 0 ];then
        local ret=$(echo "$temp"|grep -e "[-]"|wc -l);
        if [ $ret -eq 0 ];then
            echo  "Error: password does not match the policy.";
            LOG_ERROR  "[End] password does not match the policy.";
            exit 1;
        fi
    fi

    ### rule2:  contain any two : [0-9], [a-z], [A-Z]
    local result1=$(echo "$temp"|grep "[0-9]"|grep "[a-z]"|wc -l);
    local result2=$(echo "$temp"|grep "[0-9]"|grep "[A-Z]"|wc -l);
    local result3=$(echo "$temp"|grep "[a-z]"|grep "[A-Z]"|wc -l);

    ##  if string does not contain any two kinds before, then failed and return 1
    if [ $result1 -ne 0 ] || [ $result2 -ne 0 ] || [ $result3 -ne 0 ];then
        return
    else
        echo "Error: password should contain three diffrent kinds char.";
        LOG_ERROR "[End] password should contain three diffrent kinds char.";
        exit 1;
    fi
}
### end

is_reset=$1

checkUser
check_if_standby
getCurPath

LOG_INFO "[Start] Call changeRolePassword.."

#########################
if [ ! -z $is_reset ] && [ "$is_reset" != "reset" ] || [ $# -gt 1 ];then
    echo "Error: input parameter wrong.";
    LOG_ERROR "[End] input parameter wrong.";
    exit 1;
fi

if [ "$is_reset" == "reset" ];then
    echo -e "Start reset password for database role"
    echo -e -n "Database role: "
    read DB_ROLE_NAME

    LOG_INFO "Resetting password for database role: ${DB_ROLE_NAME}"
    echo -e "\nResetting password for database role: ${DB_ROLE_NAME}"
	echo -e -n "${GSDB_ROLE} password: "
    read -s DBADMINPASSWD
else
    echo -e "Start change password for database role"
    echo -e -n "Database role: "
    read DB_ROLE_NAME

    LOG_INFO "Changing password for database role: ${DB_ROLE_NAME}"
    echo -e "\nChanging password for database role: ${DB_ROLE_NAME}"
    echo -e -n "Old password: "
    read -s OLDPASSWD
fi

echo -e -n "\nNew password: "
read -s NEWPASSWD

echo -e -n "\nRetype new password: "
read -s NEWPASSWDCONFIRM
echo -e ""

if [ "$is_reset" == "reset" ];then
    if [ "${DBADMINPASSWD}" == "${NEWPASSWD}" ]; then
        echo "Error: new password and ${GSDB_ROLE} password is the same."
        LOG_ERROR "[End] Sorry, new password and ${GSDB_ROLE} password is the same."
        exit 1
    fi
else
    if [ "${OLDPASSWD}" == "${NEWPASSWD}" ]; then
        echo "Error: old password and new password is the same."
        LOG_ERROR "[End] Sorry, old password and new password is the same."
        exit 1
    fi
fi

if [ "${NEWPASSWD}" != "${NEWPASSWDCONFIRM}" ]; then
    echo "Error: new passwords twice do not match."
    LOG_ERROR "[End] Sorry, new passwords twice do not match."
    exit 1
fi
checkPwd ${NEWPASSWD}

DBKey_CONF_FILE="$BASE_DIR/data/config/DBKey.cfg"
if [ ! -f ${DBKey_CONF_FILE} ]; then
    echo "Error: DBKey config file is missing" 
    LOG_ERROR "[End] DBKey config file is missing"
    exit 1
fi

TMP_LOG_FILE="$BASE_DIR/data/config/tempfile.log"
if [ -f $TMP_LOG_FILE ]; then
    rm $TMP_LOG_FILE
fi

DB_PWD_E=$(grep "^$GSDB_ROLE:" $DBKey_CONF_FILE | sed "s/^$GSDB_ROLE://")
DB_PWD_VALUE=$(pwswitch -d "$DB_PWD_E" -fp "$fpr1nt")
[ -n "$DB_PWD_VALUE" ] || { echo "the script has been modified, can not do it"; exit 1; }

NEWPASSWD=$(echo "$NEWPASSWD" | sed "s/'/''/g")
OLDPASSWD=$(echo "$OLDPASSWD" | sed "s/'/''/g")

if [ "$is_reset" == "reset" ];then
    if [ "${GSDB_ROLE}" == "${DB_ROLE_NAME}" ]; then
        echo "Error: ${GSDB_ROLE} password cannot be reset, only permit change."
        LOG_ERROR "[End] Sorry, ${GSDB_ROLE} password cannot be reset, only permit change."
        exit 1
    fi

    if [ "${DBADMINPASSWD}" != "${DB_PWD_VALUE}" ]; then
        echo "Error: ${GSDB_ROLE} password is error."
        LOG_ERROR "[End] Sorry, ${GSDB_ROLE} password is error."
        exit 1
    fi
else
DB_NAME=`cat ${PG_HBA_CONF} | grep -i "${DB_ROLE_NAME}" | grep -v '^#' | grep -v '^$' | awk -F '[ ;]+' '{print $2}' | head -1`
su - $DB_USER -c "gsql -U $DB_ROLE_NAME -d $DB_NAME -W \"$OLDPASSWD\" <<XXXEOFXXX
    \q
XXXEOFXXX" > $TMP_LOG_FILE 2>&1
checkRet=$?
if [ $checkRet -ne 0 ]; then
    echo "Error: Failed to login database, old password is error!"
    LOG_ERROR "[End] Failed to login database, old password is error!"
    exit 1;
fi
cat "$TMP_LOG_FILE" >> $LOG_FILE
hasImportErr=$(grep "^FATAL:  Invalid username/password,login denied." "${TMP_LOG_FILE}" 2>/dev/null)
if [ -n "${hasImportErr}" ]; then
   echo "Error: database role or old password is wrong, login denied!"
   LOG_ERROR "[End] Database role or old password is wrong, login denied!"
   exit 1
fi
fi

if [ "$is_reset" == "reset" ];then
su - $DB_USER -c "gsql -W \"$DB_PWD_VALUE\" <<XXXEOFXXX
    set client_min_messages = error;
    ALTER USER ${DB_ROLE_NAME} IDENTIFIED BY '${NEWPASSWD}';
XXXEOFXXX" > $TMP_LOG_FILE 2>&1
else
su - $DB_USER -c "gsql -W \"$DB_PWD_VALUE\" <<XXXEOFXXX
    set client_min_messages = error;
    ALTER USER ${DB_ROLE_NAME} IDENTIFIED BY '${NEWPASSWD}' replace '${OLDPASSWD}';
XXXEOFXXX" > $TMP_LOG_FILE 2>&1
fi
iRet=$?

unset OLDPASSWD
unset DB_PWD_E
unset DB_PWD_VALUE
unset DBADMINPASSWD
cat "$TMP_LOG_FILE" >> $LOG_FILE

if [ $iRet -ne 0 ]; then
    echo "Error: failed to modify the password!"
    LOG_ERROR "[End] Failed to modify the password!"
    exit 1;
fi

hasImportErr=$(grep "^ERROR:  Password must contain at least" "${TMP_LOG_FILE}" 2>/dev/null)
if [ -n "${hasImportErr}" ]; then
   echo "Error: password does not match the policy."
   LOG_ERROR "[End] Password does not match the policy."
   exit 1
fi

hasImportErr=$(grep "^ERROR:  the password cannot be reused" "${TMP_LOG_FILE}" 2>/dev/null)
if [ -n "${hasImportErr}" ]; then
   echo  "Error: the password cannot be reused."
   LOG_ERROR "[End] The password cannot be reused."
   exit 1
fi

hasImportErr=$(grep "^ERROR: " "${TMP_LOG_FILE}")
if [ -n "${hasImportErr}" ]; then
   echo  "Error: modify password of database role failed."
   LOG_ERROR "[End] modify password of database role failed!"
   exit 1
fi

rm "$TMP_LOG_FILE"

DB_PWD_E=$(pwswitch -e "${NEWPASSWD}")
sed -i "/^$DB_ROLE_NAME:/d" $DBKey_CONF_FILE
echo "$DB_ROLE_NAME:$DB_PWD_E" >> $DBKey_CONF_FILE
unset DB_PWD_E

echo "Success: modify DB Role Password executed."
LOG_INFO "[End] modify DB Role Password executed and successfully."
