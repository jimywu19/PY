#!/usr/bin/env bash

[ ! -x /usr/bin/wget ] && yum install -y wget
[ ! -x /usr/bin/vim ] && yum install -y vim

#install redis server
REDIS_tmp="/tmp/redis"
REDIS_PASSWD=""

[ ! -d $REDIS_tmp ] && mkdir -p $REDIS_tmp
cd $REDIS_tmp

wget http://183.131.202.100:8100/soft2/redis-3.2.1.tar.gz
tar xf redis-3.2.1.tar.gz
cd redis-3.2.1
make && make install
cp redis.conf /etc/redis.conf

sed -i "s/daemonize no/daemonize yes/" /etc/redis.conf 
sed -i "s/# requirepass .*/requirepass $REDIS_PASSWD/" /etc/redis.conf


sed -i "s#^net.core.somaxconn.*#net.core.somaxconn=1024#" /etc/sysctl.conf
sed -i "s#^vm.overcommit_memory.*#vm.overcommit_memory=1#" /etc/sysctl.conf

echo "net.core.somaxconn=1024" >> /etc/sysctl.conf
echo "vm.overcommit_memory=1" >> /etc/sysctl.conf
sysctl -p

echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled" >>/etc/rc.local

redis-server /etc/redis.conf