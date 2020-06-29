#!/usr/bin/env bash

#颜色字体
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#当前用户ROOT判断,非root打印提示信息并退出
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] This script must be run as root!" && exit 1

#获取当前脚本运行的目录
workdir=$( cd $( dirname "$0") && pwd )

#交互输入，默认值设置
echo "Please enter password for ShadowsocksR:"
read -p "(Default password: teddysun.com):" pwd
[ -z "${pwd}" ] && shadowsockspwd="teddysun.com"
#输入非数字和非范围内数字提示
    expr ${pwd} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] Input error, please input a number"
        continue
    fi
    if [[ "$pwd" -lt 1 || "$pwd" -gt ${#obfs[@]} ]]; then
        echo -e "[${red}Error${plain}] Input error, please input a number between 1 and ${#obfs[@]}"
        continue
    fi