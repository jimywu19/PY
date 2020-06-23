#!/usr/bin/bash

# 可以带参数
method=$1
size=$2
mydir=$3
[ $#==0 ]&&{
echo -e "Missing parameter! Usage: $0 method size dirname"
echo -e "\t\t\tmethed- -----  add , extend, remove"
echo -e "\t\t\tsize -----  xxG\n"
}

myfdisk()
{
    # fdisk 分区第二硬盘，vdb ,分区格式lvm
echo "n
p
1


t
8e
w
" | fdisk /dev/vdb
vgextend centos /dev/vdb1
}

[ -b /dev/vdb1 ]||myfdisk

myextend()
{
    lvextend -L $size /dev/mapper/centos-root
    xfs_growfs /dev/mapper/centos-root
}

case $method in 
"extend")
# 扩容root根目录
myextend
;;

"add")
lvcreate -L $size -n $mydir centos
[ -d /$mydir ] || mkdir /$mydir
mkfs -t xfs /dev/mapper/centos-$mydir
mount /dev/centos/$mydir /$mydir
uuiddata=$(blkid |grep "centos-$mydir"|awk '{print $2}'|awk -F \"  '{print $2}')
cp /etc/fstab /etc/fstab.bak
[ -n $uuiddata ]&&echo "UUID=$uuiddata /$mydir                   xfs     defaults        0 0" >>/etc/fstab
;;

"remove")
mydir=$2
cp /etc/fstab /etc/fstab.bak2
sed -i "/\/$mydir/d" /etc/fstab
umount /$mydir
lvremove -y /dev/mapper/centos-$mydir
;;

"*")
;;

esac

