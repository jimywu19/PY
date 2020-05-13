#!/usr/bin/env python

import sys
import socket
import os
import re
import glob
import logging
from ftplib import FTP
from ftplib import error_temp
from ftplib import error_perm


# The main function
if __name__ == '__main__':
    try:
        logging.basicConfig(format='%(asctime)s %(levelname)s/%(lineno)dL: %(message)s', filename='/var/log/backup.log', level=logging.DEBUG)
    except IOError:
        # can't open log file
        print traceback.format_exc()
        sys.exit(6)
    try:

        logging.info(sys.argv)
        # parameters validation
        arc = len(sys.argv)
        if arc != 7:
            sys.exit(1)

        # Get the input parameters
        mode = sys.argv[1]
        if mode != "backup" and mode != "restore":
            sys.exit(1)
        ftp_server = sys.argv[2]
        port = 21
        username = sys.argv[3]
        password = sys.argv[4]
        src = sys.argv[5]
        dst = sys.argv[6]
        timeout = 30
        socket.setdefaulttimeout(timeout)
        ftp=FTP()
        ftp.connect(ftp_server,port)
        ftp.login(username,password)
        if mode == "backup":
            file = open(src, "rb")
            ftp.storbinary("STOR " + dst, file)
            file.close()
        else:
            file = open(dst, "wb")
            ftp.retrbinary("RETR " + src, file.write)
            file.close()
        ftp.quit()

    except socket.error, se:
        logging.error(se)
        sys.exit(2)
    except error_perm, fep:
        logging.error(fep)
        error_msg=fep.args[0]
        # User name or password error
        if error_msg.find("530") >= 0:
            sys.exit(3)
        # no directory or file error
        elif error_msg.find("550") >= 0:
            if mode == "backup":
                sys.exit(5)
            else:
                sys.exit(4)
        else:
            sys.exit(7)
    except error_temp, fep:
        logging.error(fep)
        error_msg=fep.args[0]
        if error_msg.find("452") >= 0:
            sys.exit(8)
        else:
            logging.error(error_msg)
            sys.exit(9)
    except IOError, ioe:
        logging.error(ioe)
        if mode == "backup":
            sys.exit(4)
        else:
            sys.exit(5)
    except SystemExit, se:
        sys.exit(se)
    except BaseException, e:
        logging.error(e)
        sys.exit(10)
    sys.exit(0)
