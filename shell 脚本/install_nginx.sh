#!/usr/bin/env bash

[ ! -x /usr/bin/wget ] && yum install -y wget
[ ! -x /usr/bin/vim ] && yum install -y vim

yum install gcc  pcre-devel  zlib-devel  -y