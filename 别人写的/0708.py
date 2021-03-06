# _*_ coding: utf-8 _*_

# cve_2019_0708漏洞检测

import os
import sys
import subprocess
import argparse
import telnetlib
from functools import  partial
from multiprocessing.dummy import Pool as ThreadPool
from IPy import IP

current_abs_path = os.path.abspath(__file__)
current_abs_path_dir = os.path.dirname(current_abs_path)
poc = os.path.abspath(current_abs_path_dir) + os.sep + '0708detector.exe'

# def gib():
#     try:
#         gdf = input('请输出IP的前三个段和.例: <192.168.1.> :')
#         absq = open('3389_hosts', 'w')
#         for i in range(1,255):
#             absq.write(gdf+(str(i))+"\n")
#     except:
#             print('[-]生成失败请检查1.txt文件是否存在')


def cve_2019_0708(ip, port):
    command = poc + ' -t ' + ip + ' -p ' + port
    result = subprocess.getoutput(command)

    # print(command, '\n', result)

    if 'WARNING: SERVER IS VULNERABLE' in result:
        result = '%s 存在CVE-2019-0708漏洞' % ip
        f=open('result.txt','a+')
        f.write(result)
        f.write('\n')
        f.close()
    else:
        result = '%s 安全' % ip
    print(result)

def portScan(ip, port='3389'):
    server = telnetlib.Telnet()
    try:
        server.open(ip,port,timeout=1)
        
        server.close()
        print("[*]%s 端口开启" % ip)
        cve_2019_0708(ip,port)
    except Exception as ex:
        # print(Exception)
        pass

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Example: python {} -t 192.168.1.0/24 -p 3389'.format(sys.argv[0]))
    # parser.add_argument("-t"
    # CIDR形式，如：192.168.1.0/24')
    parser.add_argument("-p", "--port", default='3389', help=u'默认端口3389')
    exptypegroup = parser.add_mutually_exclusive_group()  # 添加互斥参数
    exptypegroup.add_argument("-t", "--target", help=u'可以输入单个IP地址，或者输入CIDR形式，如：192.168.1.0/24，注意CIDR格式，第一位必须是所在IP段的网络号')
    exptypegroup.add_argument("-f", "--file", type=str, help=u'输入IP地址文件')
    ARGS = parser.parse_args()

    rdp_hosts = []
    if ARGS.target:
        try:
            ip=IP(ARGS.target)
        except:
            print('[-]IP地址格式错误，请注意CIDR格式')
            exit()
        for x in ip:
            rdp_hosts.append(str(x))
            
    elif ARGS.file:
        with open(ARGS.file, 'r') as f:
            data = f.readlines()
            for x in data:
                ip = x.strip()
                rdp_hosts.append(ip)
    if ARGS.port:
        port = ARGS.port  


    print('--------扫描中--------')
    partial = partial(portScan,port=port)
    pool = ThreadPool(10)
    pool.map(partial,rdp_hosts)
    print('--------扫描结束，结果在result.txt中--------')


