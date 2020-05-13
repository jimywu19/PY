#!/usr/bin/env python
# encoding: utf-8
# check if qemu-ga is not running, start it if it is not running

import sys
import os
import time

SYSTEMDDIR = "/run/systemd/system"
QGAINIT = "/etc/init.d/qemu-ga"
QGARC= "/etc/rc.d/qemu-ga"
QGAPID = "/var/run/qemu-ga.pid"

statinfo = os.stat(r"/var/log/qemu-ga.log")
nowtime = time.time()

if nowtime - statinfo.st_mtime > 180:
    if os.path.isdir(SYSTEMDDIR):
        os.system("systemctl stop qemu-ga.service")
        time.sleep(1)
        os.system("systemctl start qemu-ga.service")
    elif os.path.isfile(QGAINIT):
        os.system("/etc/init.d/qemu-ga stop")
        time.sleep(1)
        if os.path.isfile(QGAPID):
            os.remove(QGAPID)
        os.system("/etc/init.d/qemu-ga start")
    elif os.path.isfile(QGARC):
        os.system("/etc/rc.d/qemu-ga stop")
        time.sleep(1)
        os.system("/etc/rc.d/qemu-ga start")

sys.exit(0)
