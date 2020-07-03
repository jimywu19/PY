#!/usr/bin/env bash

[ ! -x /usr/bin/wget ] && yum install -y wget
[ ! -x /usr/bin/vim ] && yum install -y vim

# install Mysql
MYSQL_TMP="/tmp/mysql"
MYSQL_PORT=3306

mkdir $MYSQL_TMP
cd $MYSQL_TMP

cat >mysql_download_url <<EOF
http://183.131.202.100:8100/soft2/Mysql/mysql-community-client-5.7.28-1.el7.x86_64.rpm
http://183.131.202.100:8100/soft2/Mysql/mysql-community-common-5.7.28-1.el7.x86_64.rpm
http://183.131.202.100:8100/soft2/Mysql/mysql-community-devel-5.7.28-1.el7.x86_64.rpm
http://183.131.202.100:8100/soft2/Mysql/mysql-community-embedded-compat-5.7.28-1.el7.x86_64.rpm
http://183.131.202.100:8100/soft2/Mysql/mysql-community-libs-5.7.28-1.el7.x86_64.rpm
http://183.131.202.100:8100/soft2/Mysql/mysql-community-libs-compat-5.7.28-1.el7.x86_64.rpm
http://183.131.202.100:8100/soft2/Mysql/mysql-community-server-5.7.28-1.el7.x86_64.rpm
EOF

wget -i mysql_download_url
rpm -ivh mysql-community* --nodeps --force
echo -e "\ncharacter_set_server=utf8mb4" >> /etc/my.cnf

systemctl start mysqld
systemctl enable mysqld

tmp_password=$(grep "temporary password" /var/log/mysqld.log|awk '{print $11}')

systemctl enable firewalld
systemctl start firewalld
firewall-cmd --add-port=${MYSQL_PORT}/tcp --permanent
firewall-cmd --add-port=22/tcp --permanent
firewall-cmd --reload

rm -rf $MYSQL_TMP

echo -e "Mysql数据库已经安装成功。"
echo -e "数据库初始密码是：\033[0;31m$tmp_password\033[0m ,请及时修改！"

