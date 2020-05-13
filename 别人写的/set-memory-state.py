#!/usr/bin/python
############################################################################
#    File Name: set-memory-state.py
# Date Created: 2015-1-7
#       Author: y08227
#  Description:
#        Input: state "online" "offline"
#       Output: error Code with some errors
#       Return: 0 if succeffully, other with errors
#      Caution: input validation is guaranteed by castools
#-----------------------------------------------------------------------------
#  Modification History
#  DATE        NAME             DESCRIPTION
#  2015-1-7    y08227           PN:MemHotPlug.SetMemOnline Des:set memory online
##############################################################################
import sys
import subprocess
import logging
import os
import time

def setOnline(files):
    for file in files:
        print(file)
        proc = subprocess.Popen("cat %s" % file, shell = True, \
                                stdout = subprocess.PIPE)
        outs, errs = proc.communicate()
        if proc.returncode != 0:
            logging.error('set-memory-state cat error')
            sys.exit(1)
        outs = outs.decode('utf-8').rstrip('\n')
        if outs == 'offline':
            proc = subprocess.Popen("echo online > %s" % file, \
                                    shell = True, stdout = subprocess.PIPE)
            outs, errs = proc.communicate()
            if proc.returncode != 0:
                logging.error('set-memory-state echo online error')
                sys.exit(1)

if len(sys.argv) != 2:
    logging.error('Invalid number of arguments: %d' % len(sys.argv))
    sys.exit(1)

if sys.argv[1] == 'online':
    proc =subprocess.Popen("cat /boot/config-* | grep ^CONFIG_ACPI_HOTPLUG_MEMORY=",
                           shell = True, stdout = subprocess.PIPE)
    val,errs = proc.communicate()
    if proc.returncode != 0:
        logging.error('set-memory-state cat error')
        sys.exit(1)
    val = val.decode('utf-8').rstrip("\n")
    if "CONFIG_ACPI_HOTPLUG_MEMORY=y" in val:
        print("support hotplug,do nothing")
        pass
    elif "CONFIG_ACPI_HOTPLUG_MEMORY=n" in val:
        print("not support hotplug")
        sys.exit(3) #not support hotplug
    elif "CONFIG_ACPI_HOTPLUG_MEMORY=m" in val:
        print("hotplug is a model")
        val = os.system("lsmod | grep acpi_memhotplug")
        if val == 0 :
            print("the hotplug model has installed, do nothing")
            pass
        else :
            print("the hotplug model is not install, not support hotplug,exit 3")
            sys.exit(3)
    else:
        print(val)
        sys.exit(3)

    preMemoryNum = 0
    count = 0
    time.sleep(0.5)
    while 1:
        proc = subprocess.Popen("ls /sys/devices/system/memory/memory*/state 2>/dev/null", \
                                shell = True, stdout = subprocess.PIPE)
        outs, errs = proc.communicate()
        if proc.returncode != 0:
            logging.error('set-memory-state ls error')
            sys.exit(1)
        configFiles = outs.decode('utf-8').rstrip('\n').split('\n')
        memoryNum = len(configFiles)
        if memoryNum != preMemoryNum :
            setOnline(configFiles)
            preMemoryNum = memoryNum
            count = 0
            time.sleep(1)
        else:
            count += 1
            if count < 3:
                time.sleep(1)
                continue
            else:
                break
else:
    if sys.argv[1] == 'offline':
        logging.error('Not support memory hot unplug.')
        sys.exit(3)
    else:
        logging.error('Invalid argunemt: %s.' % sys.argv[1])
    sys.exit(1)

