#!/usr/bin/env bash

yum install -y wget vim

# install Mysql
mysql_home=/usr/local/Mysql

mkdir $mysql_home
cd $mysql_home

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


