#!/usr/bin/env python
# conding: 'utf-8'

import os
import re

def getCpuCount():
    with open('/proc/cpuinfo')  as f:
        res = 0
        line = f.readline().lower().lstrip()
        if line.startswith('processor'):
            res += 1
    print(res)
    return res

def getMem():
    with open('/proc/meminfo') as f2:
        line = f2.readline()
        if line.split(':')[0] == 'MemTotal':
            mem = line.split(':')[1].lstrip()
            mem = int(mem.split(' ')[0])/(1024*1024)
            men = int(mem)
    print(mem)
    return mem

def getDiskSize():
    result = os.popen("lsblk|grep -w vdb|awk '{print $4}'")
    diskSize = result.read()
    print(diskSize)
    return diskSize

if __name__ == '__main__':
    getCpuCount()
    getMem()
    getDiskSize()


