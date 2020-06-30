#!/bin/bash
#
##########################################################################################
# YOU MUST KEYIN SOME PARAMETERS HERE!!
# 底下的資料是您必須要填寫的！
email="root@localhost"		# 這是要將 logfile 寄給誰的 e-mail
				# 你也可以將這些資料寄給許多郵件地址，可以使用底下的格式：
				# email="root@localhost,yourID@hostname"
				# 每個 email 用逗號隔開，不要加空白鍵！

basedir="/dev/shm/logfile/"	# 這個是 logfile.sh 這支程式放置的目錄
funcdir="/root/bin/logfile"

outputall="no"		# 這個是『是否要將所有的登錄檔內容都印出來？
			# 對於一般新手來說，只要看彙整的資訊即可，
			# 所以這裡選擇 "no" ，如果想要知道所有的登錄訊息，則可以設定為 "yes" 

##########################################################################################
# 底下的資料看看就好，因為不需要更動，程式已經設計好了！
# 如果您有其他的額外發現，可以進行進一步的修改喔！ ^_^
export email basedir outputall funcdir
[ ! -d $basedir ] && mkdir $basedir


##########################################################################################
# 0. 設定一些基本的變數內容與檢驗 basedir 是否存在
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
#LANG=zh_TW.utf8
LANG=C
export PATH LANG LANGUAGE LC_TIME
localhostname=$(hostname)

# 修改使用者郵件位址！
temp=$(echo $email | cut -d '@' -f2)
if [ "$temp" == "localhost" ]; then
	email=$(echo $email | cut -d '@' -f1)\@"$localhostname"
fi

# 測驗 awk 與 sed 與 egrep 等會使用到的程式 是否存在
errormesg=""
programs="awk sed egrep ps cat cut tee netstat df uptime journalctl"
for profile in $programs
do
	which $profile > /dev/null 2>&1
	if [ "$?" != "0" ]; then
		echo -e "您的系統並沒有包含 $profile 程式；(Your system do not have $profile )"
		errormesg="yes"
	fi
done
if [ "$errormesg" == "yes" ]; then
	echo "您的系統缺乏本程式執行所需要的系統執行檔， $0 將停止作業"
	exit 1
fi

# 測驗 syslog 是否有啟動！
temp=$(ps -aux 2> /dev/null | grep systemd-journal | grep -v grep)
if [ "$temp" == "" ]; then
	echo -e "您的系統沒有啟動 systemd-journald 這個 daemon ，"
	echo -e "本程式主要針對 systemd-journald 產生的 logfile 來分析，"
	echo -e "因此，沒有 systemd-journald 則本程式沒有執行之必要。"
	exit 0
fi

# 測驗暫存目錄是否存在！
if [ ! -d "$basedir" ]; then
	echo -e "$basedir 此目錄並不存在，本程式 $0 無法進行工作！"
	exit 1
fi


##########################################################################################
# 0.1 設定版本資訊，以及相關的 log files 內容表格！
lastdate="2015-08-20"
versions="Version 0.3"
hosthome=$(hostname)
logfile="$basedir/logfile_mail.txt"
declare -i datenu=$(date +%k)
if [ "$datenu" -le "6" ]; then
	date --date='1 day ago' +%b' '%e   > "$basedir/dattime"
	date --date='1 day ago' +%Y-%m-%d  > "$basedir/dattime2"
else
	date +%b' '%e   > "$basedir/dattime"
	date +%Y-%m-%d  > "$basedir/dattime2"
fi
y="`cat $basedir/dattime`"
y2="`cat $basedir/dattime2`"
export lastdate hosthome logfile y

# 0.1.1 secure file
log=$(journalctl SYSLOG_FACILITY=4 SYSLOG_FACILITY=10 --since yesterday --until today | grep -v "^\-\-")
if [ "$log" != "" ]; then
	journalctl SYSLOG_FACILITY=4 SYSLOG_FACILITY=10 --since yesterday --until today | grep -v "^\-\-" > "$basedir/securelog"
fi

# 0.1.2 maillog file
log=$(journalctl SYSLOG_FACILITY=2 --since yesterday --until today | grep -v "^\-\-")
if [ "$log" != "" ]; then
	journalctl SYSLOG_FACILITY=2 --since yesterday --until today | grep -v "^\-\-" > "$basedir/maillog"
fi

# 0.1.3 messages file
journalctl SYSLOG_FACILITY=0 SYSLOG_FACILITY=1 SYSLOG_FACILITY=3 SYSLOG_FACILITY=5 \
      SYSLOG_FACILITY=6 SYSLOG_FACILITY=7 SYSLOG_FACILITY=8 SYSLOG_FACILITY=11 SYSLOG_FACILITY=16 \
      SYSLOG_FACILITY=17 SYSLOG_FACILITY=18 SYSLOG_FACILITY=19 SYSLOG_FACILITY=20 SYSLOG_FACILITY=21 \
      SYSLOG_FACILITY=22 SYSLOG_FACILITY=23 --since yesterday --until today | grep -v "^\-\-" > "$basedir/messageslog"
touch "$basedir/securelog"
touch "$basedir/maillog"
touch "$basedir/messageslog"

# The following lines are detecting your PC live?
  timeset1=`uptime | grep day`
  timeset2=`uptime | grep min`
  if [ "$timeset1" == "" ]; then
        if [ "$timeset2" == "" ]; then
                UPtime=`uptime | awk '{print $3}'`
        else
                UPtime=`uptime | awk '{print $3 " " $4}'`
        fi
  else
        if [ "$timeset2" == "" ]; then
                UPtime=`uptime | awk '{print $3 " " $4 " " $5}'`
        else
                UPtime=`uptime | awk '{print $3 " " $4 " " $5 " " $6}'`
        fi
  fi

# 顯示出本主機的 IP 喔！
IPs=$(echo $(ifconfig | grep 'inet '| awk '{print $2}' | grep -v '127.0.0.'))


##########################################################################################
# 1. 建立歡迎畫面通知，以及系統的資料彙整！
echo "" > $logfile
/sbin/restorecon -Rv $logfile
echo "=============== system summary =================================" >> $logfile
echo "Linux kernel  :  $(cat /proc/version | \
	awk '{print $1 " " $2 " " $3 " " $4}')" 			>> $logfile
echo "CPU informatin: $(cat /proc/cpuinfo |grep 'model name' | sed 's/model name.*://' | \
	uniq -c | sed 's/[[:space:]][[:space:]]*/ /g')"			>> $logfile
echo "CPU speed     : $( cat /proc/cpuinfo | grep "cpu MHz" | \
	sort | tail -n 1 | cut -d ':' -f2-) MHz" 			>> $logfile
echo "hostname is   :  $(hostname)" 					>> $logfile
echo "Network IP    :  ${IPs}"						>> $logfile
echo "Check time    :  $(date +%Y/%B/%d' '%H:%M:%S' '\(' '%A' '\))" 	>> $logfile
echo "Summary date  :  $(cat $basedir/dattime)"				>> $logfile
echo "Up times      :  $(echo $UPtime)" 				>> $logfile
echo "Filesystem summary: "						>> $logfile
df -Th	| sed 's/^/       /'				>> $logfile
if [ -x /opt/MegaRAID/MegaCli/MegaCli64 ]; then
	cd /root
	echo 								>> $logfile
	echo "Test the RAID card Volumes informations:"			>> $logfile
	/opt/MegaRAID/MegaCli/MegaCli64 -LDInfo -LALL -aAll | \
	grep -E '^Name|^Size|^State'					>> $logfile
	echo 								>> $logfile
	echo "Test RAID devices"					>> $logfile
	/opt/MegaRAID/MegaCli/MegaCli64 -PDList -aAll | \
	grep -E '^Firmware|^Slot|^Media Error|^Other Error'		>> $logfile
	cd -
fi
echo " "						>> $logfile
echo " "						>> $logfile

# 1.1 Port 分析
if [ -f $funcdir/function/ports ]; then
	source $funcdir/function/ports
fi


##########################################################################################
# 2 開始測試需要進行的模組！
# 2.1 測試 ssh 是否存在？
input=`cat $basedir/netstat.tcp.output |egrep '(22|sshd)'`
if [ "$input" != "" ]; then
	source $funcdir/function/ssh
	funcssh
	echo " "	>> $logfile
fi

# 2.2 測試 FTP 的玩意兒～
input=`cat $basedir/netstat.tcp.output |egrep '(21|ftp)'`
if [ "$input" != "" ]; then
	if [ -f /etc/ftpaccess ]; then
		source $funcdir/function/wuftp
		funcwuftp
	fi
	proftppro=`which proftpd 2> /dev/null`
	if [ "$proftppro" != "" ]; then
		source $funcdir/function/proftp
		funcproftp
	fi
fi

# 2.3 pop3 測試
input=`cat $basedir/netstat.tcp.output |grep 110`
if [ "$input" != "" ]; then
	dovecot=`cat $basedir/netstat.tcp.output | grep dovecot`
	if [ "$dovecot" != "" ]; then
		source $funcdir/function/dovecot
		funcdovecot
		echo " " >> $logfile
	else
		source $funcdir/function/pop3
		funcpop3
		echo " "	>> $logfile
	fi
fi

# 2.4 Mail 測試
input=`cat $basedir/netstat.tcp.output $basedir/netstat.tcp.local 2> /dev/null |grep 25`
if [ "$input" != "" ]; then
	postfixtest=`netstat -tlnp 2> /dev/null |grep ':25'|grep master`
	#sendmailtest=`ps -aux 2> /dev/null |grep sendmail| grep -v 'grep'`
	if [ "$postfixtest" != "" ] ;  then
		source $funcdir/function/postfix
		funcpost
	else
		source $funcdir/function/sendmail
		funcsendmail
	fi
	procmail=`/bin/ls /var/log| grep procmail| head -n 1`
	if [ "$procmail" != "" ] ; then
		source $funcdir/function/procmail
		funcprocmail
	fi

	openwebmail=`ls /var/log | grep openwebmail | head -n 1`
	if [ "$openwebmail" != "" ]; then
		source $funcdir/function/openwebmail
		funcopenwebmail
	fi
fi

# 2.5 samba 測試
input=`cat $basedir/netstat.tcp.output  2> /dev/null |grep 139|grep smbd`
if [ "$input" != "" ]; then
	source $funcdir/function/samba
	funcsamba
fi

#####################################################################
# 10. 全部的資訊列出給人瞧一瞧！
if [ "$outputall" == "yes" ] || [ "$outputall" == "YES" ] ; then
	echo "  "                                  				>> $logfile
	echo "================= 全部的登錄檔資訊彙整 ======================="	>> $logfile
	echo "1. 重要的登錄記錄檔 ( Secure file )"           >> $logfile
	echo "   說明：已經取消了 pop3 的資訊！"	     >> $logfile
	grep -v 'pop3' $basedir/securelog 		     >> $logfile 
	echo " "                                             >> $logfile
	echo "2. 使用 last 這個指令輸出的結果"               >> $logfile
	last -20                                             >> $logfile
	echo " "                                             >> $logfile
	echo "3. 將特重要的 /var/log/messages 列出來瞧瞧！"  >> $logfile
	cat $basedir/messageslog 			     >> $logfile
	echo " "					     >> $logfile
	if [ -f /var/log/knockd.log ]; then
		echo "4. 開始分析 knockd 這個服務的相關資料" >> $logfile
		echo "4.1 正常登入主機的指令運作"	     >> $logfile
		grep "$y2" /var/log/knockd.log | grep 'iptables'     >> $logfile
		echo ""
		echo "4.2 因為某些原因，導致無法登入的 IP 與狀態！"  >> $logfile
		grep "$y2" /var/log/knockd.log | grep 'sequence timeout' >> $logfile
	fi
fi

# At last! we send this mail to you!
export LANG=zh_TW.utf8
export LC_ALL=zh_TW.utf8
if [ -x /usr/bin/uuencode ]; then
	uuencode $logfile logfile.html | mail -s "$hosthome logfile analysis results" $email 
else
	mail -s "$hosthome logfile analysis results" $email < $logfile
fi

