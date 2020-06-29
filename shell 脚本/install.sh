#!/usr/bin/env bash


FASTDFS_BASE=/home/wb/fastdfs
FASTDFS_TMP=/home/wb/tmp
LOCAL_IP=$(ifconfig eth0 |grep -w inet|awk '{print $2}')
HTTP_PORT=8888

#颜色字体
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#当前用户ROOT判断,非root打印提示信息并退出
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] This script must be run as root!" && exit 1

yum install -y wget

# install fastdfs

[ -d $FASTDFS_BASE ] || mkdir -p $FASTDFS_BASE/{client,data,logs}
[ -d $FASTDFS_TMP ] || mkdir -p $FASTDFS_TMP

#下载安装文件源代码
cd $FASTDFS_TMP
wget http://183.131.202.100:8100/soft2/FastDFS/fastdfs-5.11.tar.gz
wget http://183.131.202.100:8100/soft2/FastDFS/libfastcommon-1.0.39.tar.gz
wget http://183.131.202.100:8100/soft2/FastDFS/fastdfs-nginx-module-1.20.tar.gz
wget http://183.131.202.100:8100/soft2/FastDFS/nginx-1.16.0.tar.gz

tar xf fastdfs-5.11.tar.gz
tar xf libfastcommon-1.0.39.tar.gz
tar xf fastdfs-nginx-module-1.20.tar.gz
tar xf nginx-1.16.0.tar.gz 

cd libfastcommon-1.0.39
./make.sh && ./make.sh install

cd ../fastdfs-5.11
./make.sh && ./make.sh install

cp ./conf/* /etc/fdfs/
cp $FASTDFS_TMP/fastdfs-nginx-module-1.20/src/mod_fastdfs.conf /etc/fdfs

#安装nginx
cd ../nginx-1.16.0
sed -i "s#/usr/local/include#/usr/include/fastdfs /usr/include/fastcommon/#"  $FASTDFS_TMP/fastdfs-nginx-module-1.20/src/config
./configure \
--with-debug \
--with-pcre-jit \
--with-http_ssl_module \
--with-http_stub_status_module \
--with-http_realip_module \
--with-http_auth_request_module \
--with-http_addition_module \
--with-http_dav_module \
--with-http_gunzip_module \
--with-http_gzip_static_module \
--with-http_v2_module \
--with-http_sub_module \
--with-stream \
--with-stream_ssl_module \
--with-mail \
--with-threads \
--add-module=$FASTDFS_TMP/fastdfs-nginx-module-1.20/src
make && make install
ln -s /usr/local/nginx/sbin/nginx /usr/sbin/nginx

#创建更新nginx配置文件
cat >/usr/local/nginx/conf/nginx.conf <<EOF
worker_processes  1;
events {
    worker_connections  1024;
}
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;
    server {
        listen    $HTTP_PORT   ;
        server_name  localhost;
        location /M00 {
            root  $FASTDFS_BASE/data ;
            ngx_fastdfs_module;
        }
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }
}
EOF

#创建systemctl启动服务文件
cat >/usr/lib/systemd/system/nginx.service << EOF
[Unit]
Description=nginx service
After=network.target 
 
[Service] 
Type=forking
# 路径对应安装路径
ExecStart=/usr/local/nginx/sbin/nginx
ExecReload=/usr/local/nginx/sbin/nginx -s reload
ExecStop=/usr/local/nginx/sbin/nginx -s quit
PrivateTmp=true 
 
[Install] 
WantedBy=multi-user.target
EOF


#修改配置文件
sed -i "s#base_path=.*#base_path=$FASTDFS_BASE#" /etc/fdfs/tracker.conf
sed -i "s#http.server_port=8080#http.server_port=$HTTP_PORT#" /etc/fdfs/tracker.conf

sed -i "s#base_path=.*#base_path=$FASTDFS_BASE#" /etc/fdfs/storage.conf
sed -i "s#store_path0=.*#store_path0=$FASTDFS_BASE#" /etc/fdfs/storage.conf
sed -i "s#tracker_server=.*#tracker_server=$LOCAL_IP:22122#" /etc/fdfs/storage.conf

sed -i "s#base_path=.*#base_path=$FASTDFS_BASE/client#" /etc/fdfs/client.conf
sed -i "s#tracker_server=.*#tracker_server=$LOCAL_IP:22122#" /etc/fdfs/client.conf
sed -i "s#http\.tracker_server_port=.*#http\.tracker_server_port=$HTTP_PORT#" /etc/fdfs/client.conf

sed -i "s#tracker_server=.*#tracker_server=$LOCAL_IP:22122#" /etc/fdfs/mod_fastdfs.conf
sed -i "s#store_path0=.*#store_path0=$FASTDFS_BASE#" /etc/fdfs/mod_fastdfs.conf

#启动服务
fdfs_trackerd /etc/fdfs/tracker.conf start
fdfs_storaged /etc/fdfs/storage.conf start
systemctl enable nginx
systemctl start nginx 

#添加防火墙端口
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --add-port=${HTTP_PORT}/tcp --permanent
firewall-cmd --add-port=22122/tcp --permanent
firewall-cmd --add-port=23000/tcp --permanent
firewall-cmd --reload
