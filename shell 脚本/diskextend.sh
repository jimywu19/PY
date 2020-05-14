#!/bin/bash

cp /etc/fstab /etc/fstab.bak2
sed -i '/\/data/d' /etc/fstab
umount /data
lvremove -y /dev/mapper/centos-data
lvextend -L 500G /dev/mapper/centos-root
xfs_growfs /dev/mapper/centos-root