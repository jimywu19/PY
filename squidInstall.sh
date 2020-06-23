#!/bin/bash

#更新yum源
rm -f /etc/yum.repos.d/*
curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo

#安装squid
yum install -y squid httpd-tools

#修改配置文件
sed -i '/http_access deny all/d' "/etc/squid/squid.conf"
sed -i 's/http_port 3128/http_port 31028/' "/etc/squid/squid.conf"
cat <<EOF>>/etc/squid/squid.conf 

# require user auth 
auth_param basic program /usr/lib64/squid/basic_ncsa_auth /etc/squid/passwd
acl auth_user proxy_auth REQUIRED
http_access allow auth_user
http_access deny all
EOF

#增加用户
htpasswd -bc /etc/squid/passwd zhangsanfeng z1VrlD46V1Gj  >>/dev/null 2>&1

#增加自启动，运行
systemctl enable squid
systemctl start squid

#防火墙放通代理端口
systemctl start firewalld
systemctl enable firewalld

firewall-cmd --add-port 22/tcp --permanent
firewall-cmd --add-port 31028/tcp --permanent
firewall-cmd --reload
 
