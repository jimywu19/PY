#!/usr/bin/env bash

# install fastdfs

FASTDFS_BASE=/home/wb/fastdfs
FASTDFS_TMP=/home/wb/tmp
LOCAL_IP=$(ifconfig eth0 |grep -w inet|awk '{print $2}')
HTTP_PORT=8888

[ -d $FASTDFS_BASE ] || mkdir -p $FASTDFS_BASE/{client,data,logs}
[ -d $FASTDFS_TMP ] || mkdir -p $FASTDFS_TMP

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


cp ./conf/* /etc/fdfs/

sed -i "s#base_path=.*#base_path=$FASTDFS_BASE#" /etc/fdfs/tracker.conf
sed -i "s#http.server_port=8080#http.server_port=$HTTP_PORT#" /etc/fdfs/tracker.conf

sed -i "s#base_path=.*#base_path=$FASTDFS_BASE#" /etc/fdfs/storage.conf
sed -i "s#store_path0=.*#store_path0=$FASTDFS_BASE#" /etc/fdfs/storage.conf
sed -i "s#tracker_server=.*#tracker_server=$LOCAL_IP:22122#" /etc/fdfs/storage.conf


sed -i "s#base_path=.*#base_path=$FASTDFS_BASE/client#" /etc/fdfs/client.conf
sed -i "s#tracker_server=.*#tracker_server=$LOCAL_IP:22122#" /etc/fdfs/client.conf
sed -i "s#http\.tracker_server_port=.*#http\.tracker_server_port=$HTTP_PORT#" /etc/fdfs/client.conf


fdfs_trackerd /etc/fdfs/tracker.conf start
fdfs_storaged /etc/fdfs/storage.conf start


