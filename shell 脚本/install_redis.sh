#!/usr/bin/env bash

#[ ! -x /usr/bin/wget ] && yum install -y wget
[ ! -x /usr/bin/vim ] && yum install -y vim
[ ! -x /usr/bin/gcc ] && yum install -y gcc

#install redis server

REDIS_TMP="/tmp/redis"
REDIS_PORT="6379"       #在这里设置端口
REDIS_PASSWD=$(head /dev/urandom|base64|sed 's/[^A-Za-z0-9]//g'|cut -c1-10|head -n1)   #随机10位密码

[ ! -d $REDIS_TMP ] && mkdir -p $REDIS_TMP    #创建临时目录
cd $REDIS_TMP

#下载安装
curl -O http://183.131.202.100:8100/soft2/redis-3.2.1.tar.gz
tar xf redis-3.2.1.tar.gz
cd redis-3.2.1
make && make install

#修改配置文件
cp redis.conf /etc/redis.conf
sed -i "s/^daemonize no/daemonize yes/" /etc/redis.conf 
sed -i "s/^# requirepass .*/requirepass $REDIS_PASSWD/" /etc/redis.conf
sed -i "s/^port.*/port $REDIS_PORT/" /etc/redis.conf
#sed -i "s/^\(bind.*\)/#\1/" /etc/redis.conf
sed -i "s/^bind.*/#&/" /etc/redis.conf

#内核参数优化
sed -i "s#^net.core.somaxconn.*#net.core.somaxconn=1024#" /etc/sysctl.conf 2>/dev/null
# 内存分配策略,可选值：0、1、2,现改为1
# 0， 表示内核将检查是否有足够的可用内存供应用进程使用；如果有足够的可用内存，内存申请允许；否则，内存申请失败，并把错误返回给应用进程。
# 1， 表示内核允许分配所有的物理内存，而不管当前的内存状态如何。
# 2， 表示内核允许分配超过所有物理内存和交换空间总和的内存
sed -i "s#^vm.overcommit_memory.*#vm.overcommit_memory=1#" /etc/sysctl.conf 2>/dev/null

echo "net.core.somaxconn=1024" >> /etc/sysctl.conf
echo "vm.overcommit_memory=1" >> /etc/sysctl.conf
sysctl -p
echo 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' >>/etc/rc.local

#添加自启动
echo "redis-server /etc/redis.conf" >>/etc/rc.local
chmod u+x /etc/rc.d/rc.local
#启动服务
redis-server /etc/redis.conf
#配置防火墙
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --add-port=${REDIS_PORT}/tcp --permanent
firewall-cmd --add-port=22/tcp --permanent
firewall-cmd --reload

#删除安装程序及目录
rm -rf $REDIS_TMP

echo -e "redis服务已经安装完成！"
echo -e "服务连接密码是$REDIS_PASSWD ,请做好保存！"