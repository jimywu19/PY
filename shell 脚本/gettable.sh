#!/bin/bash
fromdb=127.0.0.1
paswd=root@123
tablefile=table.sql
datafile=data.sql


databa=`mysql -h"${fromdb}" -uroot -p"${paswd}" -e "show databases;" 2> /etc/null |grep -Ev mysql|grep -Ev information_schema|grep -Ev performance_schema|grep -Ev sys|grep -Ev Database`

delnotes(){
	sed -i  '/\/\*/d' $1
	sed -i '/\*\//d' $1
	sed -i '/^--/d' $1
	sed -i '/^$/d' $1
}

gettable(){
	for db in rms
	do
		echo "CREATE DATABASE \`$db\`;" >> $tablefile
		echo "USE $db;" >> $tablefile
		echo "`mysqldump -h"${fromdb}" -uroot -p"${paswd}" --no-data --opt -d $db 2> /etc/null`" >> $tablefile
	done
	sed -i '/DROP TABLE IF EXISTS/d' $tablefile
	delnotes $tablefile
}

getdata(){
	
	for db in rms
	do
		echo "USE \`$db\`;" >> $datafile
		echo "`mysqldump -h"${fromdb}" -uroot -p"${paswd}"  -t $db 2> /etc/null`" >> $datafile
		echo "" >> $datafile
		echo "" >> $datafile
	done
	delnotes $datafile
}

gettable
read -p "是否导出数据 默认y(y/n):" isok
if [ -z $isok ];then
	isok=y
fi
case $isok in
"y")
	getdata;;
"Y")
	getdata;;
*)
	exit 0
esac

