#!/usr/bin/python
############################################################################
#    File Name: set-ip.py
# Date Created: 2013-11-11
#       Author: hupengfei/04221
#  Description:
#        Input: XML
#       Output: error Code with some errors
#       Return: 0 if succeffully, other with errors
#      Caution: input validation is guaranteed by castools
#-----------------------------------------------------------------------------
#  Modification History
#  DATE        NAME             DESCRIPTION
##############################################################################
import sys
import os
import re
import subprocess
import logging
import traceback
from xml.dom.minidom import parseString

def exchange_mask(mask):
    count_bit = lambda bin_str: len([i for i in bin_str if i=='1'])
    mask_splited = mask.split('.')
    mask_count = [count_bit(bin(int(i))) for i in mask_splited]
    return sum(mask_count)

# The main function
if __name__ == '__main__':
    try:
        logging.basicConfig(format='%(asctime)s %(levelname)s/%(lineno)dL: %(message)s', filename='/var/log/set-ip.log', level=logging.DEBUG)
    except IOError:
        # can't open log file
        print(traceback.format_exc())
        sys.exit(1)

    try:
        logging.info(sys.argv)
        # parameters validation
        arc = len(sys.argv)
        if arc != 2:
            sys.exit(1)

        try:
            root = parseString(sys.argv[1])
        except ET.ParseError:
            logging.error(traceback.format_exc())
            sys.exit(1)

        Elements = root.getElementsByTagName('mac')
        if len(Elements) != 0:
            mac = Elements[0].childNodes[0].nodeValue
        Elements = root.getElementsByTagName('ip')
        if len(Elements) != 0:
            ip = Elements[0].childNodes[0].nodeValue
        Elements = root.getElementsByTagName('mask')
        if len(Elements) != 0:
            mask = Elements[0].childNodes[0].nodeValue
        Elements = root.getElementsByTagName('destination')
        if len(Elements) != 0:
            destination = Elements[0].childNodes[0].nodeValue
        Elements = root.getElementsByTagName('netmask')
        if len(Elements) != 0:
            netmask = Elements[0].childNodes[0].nodeValue
        Elements = root.getElementsByTagName('gateway')
        if len(Elements) != 0:
            gateway = Elements[0].childNodes[0].nodeValue
        dns = root.getElementsByTagName('dns')
        Elements = root.getElementsByTagName('hostname')
        if len(Elements) != 0:
            hostname = Elements[0].childNodes[0].nodeValue
        Elements = root.getElementsByTagName('restart')
        if len(Elements) != 0:
            restart = Elements[0].childNodes[0].nodeValue
        else:
            restart = None

        if 'ip' in dir():
            # In order to make compatible with Python version lower than 2.7
            #disable bond
            bonds_mst = '/sys/class/net/bonding_masters'
            if os.path.isfile(bonds_mst):
                bonds_file = open(bonds_mst, 'r')
                buffer = bonds_file.read()
                bonds = buffer.split('\n')[0].split(' ')
                for bond in bonds:
                    subprocess.call('echo -%s > %s' % (bond, bonds_mst), shell = True)
                bonds_file.close()
            proc = subprocess.Popen('ifconfig -a', shell = True, stdout = subprocess.PIPE)
            outs, errs = proc.communicate()
            m1 = re.search("(\S+)\s+Link encap:\S+\s+\S+\s+(%s|%s)" % (mac.upper(), mac.lower()), outs.decode('utf-8'))
            m2 = re.search("(\S+): flags=.*\n(\s+inet.*\n)?(\s+inet6.*\n)?\s+ether %s" % mac.lower(), outs.decode('utf-8'))
            m3 = re.search("(\S+): flags=.*\n(\s+options=.*\n)?\s+ether %s" % mac.lower(), outs.decode('utf-8'))
            proc = subprocess.Popen('ip link show', shell = True, stdout = subprocess.PIPE)
            outs, errs = proc.communicate()
            m4 = re.search("[0-9]+:\s+(\S+):.*\n\s+link/ether (%s|%s)" % (mac.upper(), mac.lower()), outs.decode('utf-8'))
            if m1 is not None:
                interface = m1.group(1)
            elif m2 is not None:
                interface = m2.group(1)
            elif m3 is not None:
                interface = m3.group(1)
            elif m4 is not None:
                interface = m4.group(1)
            else:
                logging.error('mac error')
                sys.exit(1)
            if (len(ip.split(';')) > 1):
                multi_ip = True
                ip_list = ip.split(';')
                mask_list = mask.split(';')
                ip = ip_list.pop(0)
                mask = mask_list.pop(0)
            else:
                multi_ip = False
            if ip != 'dhcp':
                if subprocess.call('ifconfig %s %s netmask %s' % (interface, ip, mask), shell = True) != 0:
                    mask_count = exchange_mask(mask)
                    subprocess.call('ip address flush dev %s' % interface, shell = True)
                    if subprocess.call('ip address add %s/%s dev %s' % (ip, mask_count, interface), shell = True) != 0:
                        logging.error('ifconfig/ip address add error')
                        sys.exit(1)

            ubuntu = '/etc/network/interfaces'
            redhat = '/etc/sysconfig/network-scripts'
            rocky = '/etc/sysconfig/network-devices'
            opensuse = '/etc/sysconfig/network'
            freebsd = '/etc/rc.conf'
            if os.path.isfile(ubuntu):
                ifcfg = ubuntu
                ifcfg_bak = ifcfg + '.bak'
                ipv6_confes = []
                ret = subprocess.call('mv %s %s' % (ifcfg, ifcfg_bak), shell = True)
                if ret != 0:
                    logging.error('mv return error %d' % ret)
                    sys.exit(1)
                subprocess.call('sync 1>/dev/null 2>&1', shell = True)
                delete = False
                is_ipv6 = False
                is_hwaddr = True
                bak_file = open(ifcfg_bak, 'r')
                cfg_file = open(ifcfg, 'w')
                for line in bak_file:
                    if re.match('auto %s:' % interface, line.decode('utf-8')):
                        delete = True
                        continue
                    if delete:
                        if re.match("iface %s inet6 " %
                                interface, line.decode('utf-8')):
                            is_ipv6 = True
                        elif re.match("iface %s inet " %
                                interface, line.decode('utf-8')):
                            is_ipv6 = False
                        if (line.find('auto ') == 0 and \
                                line != 'auto ' + interface + '\n') or \
                                (line.find('allow-hotplug ') == 0 and \
                                 line != 'allow-hotplug ' + interface + '\n'):
                            delete = False
                            cfg_file.write(line)
                        elif is_ipv6 == True:
                            if re.search('#hwaddr', line.decode('utf-8')):
                                if re.search('%s' % mac.lower(),
                                             line.decode('utf-8')):
                                    is_hwaddr = True
                                else:
                                    is_hwaddr = False
                            if re.search('inet6|hwaddr|up|dhcp|address|netmask|'
                                         'gateway',
                                         line.decode('utf-8')):
                                if is_hwaddr == True:
                                    ipv6_confes.append(line)
                    else:
                        if line == 'auto ' + interface + '\n' or \
                           line == 'allow-hotplug ' + interface + '\n':
                            delete = True
                        else:
                            cfg_file.write(line)
                cfg_file.write('auto %s\n' % interface)
                if ip == 'dhcp':
                    cfg_file.write('iface %s inet dhcp\n' % interface)
                    cfg_file.write('\t#hwaddr %s\n' % mac.lower())
                else:
                    cfg_file.write('iface %s inet static\n' % interface)
                    cfg_file.write('\t#hwaddr %s\n' % mac.lower())
                    cfg_file.write('\taddress %s\n' % ip)
                    cfg_file.write('\tnetmask %s\n' % mask)
                    if 'gateway' in dir():
                        cfg_file.write('\tgateway %s\n' % gateway)
                    if len(dns) != 0:
                        cfg_file.write('\tdns-nameservers ')
                        for server in dns:
                            cfg_file.write('%s ' % server.childNodes[0].nodeValue)
                        cfg_file.write('\n')
                    if multi_ip == True:
                        for i in range(len(ip_list)):
                            cfg_file.write('\nauto %s:%d\n' % (interface, i))
                            cfg_file.write('iface %s:%d inet static\n' %
                                    (interface, i))
                            cfg_file.write('\t#hwaddr %s\n' % mac.lower())
                            cfg_file.write('\taddress %s\n' % ip_list[i])
                            cfg_file.write('\tnetmask %s\n' % mask_list[i])
                if is_hwaddr == True:
                    for ipv6_conf in ipv6_confes:
                        cfg_file.write('%s' % ipv6_conf)
                bak_file.close()
                cfg_file.close()
            elif os.path.isdir(redhat):
                ifcfg = redhat + '/ifcfg-' + interface
                ifcfg_bak = ifcfg + '.bak'
                # Maybe ifcfg doesn't exist
                subprocess.call('cp %s %s' % (ifcfg, ifcfg_bak), shell = True)
                subprocess.call('sync 1>/dev/null 2>&1', shell = True)
                cfg_file = open(ifcfg, 'w')
                cfg_file.write('DEVICE=%s\n' % interface)
                cfg_file.write('ONBOOT=yes\n')
                cfg_file.write('HWADDR=%s\n' % mac)
                if ip == 'dhcp':
                    cfg_file.write('BOOTPROTO=dhcp\n')
                else:
                    cfg_file.write('BOOTPROTO=none\n')
                    cfg_file.write('TYPE=Ethernet\n')
                    cfg_file.write('IPADDR=%s\n' % ip)
                    cfg_file.write('NETMASK=%s\n' % mask)
                    if multi_ip == True:
                        for i in range(len(ip_list)):
                            cfg_file.write('IPADDR%d=%s\n' % (i+2, ip_list[i]))
                            cfg_file.write('NETMASK%d=%s\n' %
                                    (i+2, mask_list[i]))
                    if 'gateway' in dir():
                        cfg_file.write('GATEWAY=%s\n' % gateway)
                    if len(dns) != 0:
                        i = 1
                        for server in dns:
                            cfg_file.write('DNS%d=%s\n' % (i, server.childNodes[0].nodeValue))
                            i = i + 1
                    else:
                        if os.path.exists(ifcfg_bak):
                            bak_file = open(ifcfg_bak, 'r')
                            for line in bak_file:
                                if re.match("(DNS)", line.decode('utf-8')):
                                    cfg_file.write(line)
                            bak_file.close()
                if os.path.exists(ifcfg_bak):
                    cfg_file_bak = open(ifcfg_bak, 'r')
                    lines = cfg_file_bak.readlines()
                    for line in lines:
                        if re.match("(IPV6|DHCPV6C|PEERDNS)", line.decode('utf-8')):
                            cfg_file.write(line)
                    cfg_file_bak.close()
                cfg_file.close()
            elif os.path.isdir(rocky):
                subprocess.call("sed -i '/^bonding mode=/d' /etc/sysconfig/modules", shell = True)
                ifcfg = rocky + '/ifcfg-' + interface
                ifcfg_bak = ifcfg + '.bak'
                # Maybe ifcfg doesn't exist
                subprocess.call('cp %s %s' % (ifcfg, ifcfg_bak), shell = True)
                subprocess.call('sync 1>/dev/null 2>&1', shell = True)
                cfg_file = open(ifcfg, 'w')
                cfg_file.write('DEVICE=%s\n' % interface)
                cfg_file.write('ONBOOT=yes\n')
                cfg_file.write('HWADDR=%s\n' % mac)
                if ip == 'dhcp':
                    cfg_file.write('BOOTPROTO=dhcp\n')
                else:
                    cfg_file.write('BOOTPROTO=none\n')
                    cfg_file.write('TYPE=Ethernet\n')
                    cfg_file.write('IPADDR=%s\n' % ip)
                    cfg_file.write('NETMASK=%s\n' % mask)
                    if 'gateway' in dir():
                        cfg_file.write('GATEWAY=%s\n' % gateway)
                    if len(dns) != 0:
                        i = 1
                        for server in dns:
                            cfg_file.write('DNS%d=%s\n' % (i, server.childNodes[0].nodeValue))
                            i = i + 1
                    else:
                        if os.path.exists(ifcfg_bak):
                            bak_file = open(ifcfg_bak, 'r')
                            for line in bak_file:
                                if line.find('DNS') != -1:
                                    cfg_file.write(line)
                            bak_file.close()
                cfg_file.close()
            elif os.path.isdir(opensuse):
                ifcfg = opensuse + '/ifcfg-' + interface
                ifcfg_bak = ifcfg + '.bak'
                nmcfg = opensuse+'/config'
                gwcfg = opensuse + '/routes'
                # Maybe ifcfg doesn't exist
                subprocess.call('cp %s %s' % (ifcfg, ifcfg_bak), shell = True)
                subprocess.call('sync 1>/dev/null 2>&1', shell = True)
                subprocess.call("sed -i 's/NETWORKMANAGER=\"yes\"/NETWORKMANAGER=\"no\"/g' nmcfg ", shell = True)
                if os.path.exists(ifcfg_bak):
                    ifcfg_bak_file = open(ifcfg_bak, 'r')
                    lines = ifcfg_bak_file.readlines()
                else:
                    lines = []
                cfg_file = open(ifcfg, 'w')
                cfg_file.write('STARTMODE=auto\n')
                cfg_file.write('LLADDR=%s\n' % mac)
                boot_proto = ''
                for line in lines:
                    if re.match('STARTMODE|LLADDR|IPADDR=|IPADDR_IPV4|'
                                'NETMASK=|NETMASK_IPV4', line.decode('utf-8')):
                        continue
                    elif re.match("^BOOTPROTO=dhcp$", line.decode('utf-8')):
                        boot_proto = 'dhcp'
                    elif re.match("^BOOTPROTO=dhcp4$", line.decode('utf-8')):
                        boot_proto = 'dhcp4'
                    elif re.match("^BOOTPROTO=dhcp6$", line.decode('utf-8')):
                        boot_proto = 'dhcp6'
                    elif re.match("^BOOTPROTO=static$", line.decode('utf-8')):
                        continue
                    else:
                        cfg_file.write(line)
                if ip == 'dhcp':
                    if boot_proto == 'dhcp6' or boot_proto == 'dhcp':
                        cfg_file.write('BOOTPROTO=dhcp\n')
                    else:
                        cfg_file.write('BOOTPROTO=dhcp4\n')
                else:
                    cfg_file.write('BOOTPROTO=static\n')
                    cfg_file.write('IPADDR_IPV4=%s\n' % ip)
                    cfg_file.write('NETMASK_IPV4=%s\n' % mask)
                    if 'gateway' in dir():
                        gw_file = open(gwcfg, 'w')
                        gw_file.write('default %s\n' % gateway)
                        gw_file.close()
                cfg_file.close()
            elif os.path.isfile(freebsd):
                setroute = True
                setip = True
                config_inter = 'ifconfig_' + interface
                ifcfg = freebsd
                ifcfg_bak = ifcfg + '.bak'
                # Maybe ifcfg doesn't exist
                subprocess.call('mv %s %s' % (ifcfg, ifcfg_bak), shell = True)
                subprocess.call('sync 1>/dev/null 2>&1', shell = True)
                cfg_file = open(ifcfg, 'w')
                cfg_file_bak = open(ifcfg_bak, 'r')
                for line in cfg_file_bak:
                    if (line.find(config_inter + '=') == 0):
                        setip = False
                        macval = re.search('"%s=\"inet+\s+(\S+)+\s+netmask+\s+'
                                '(\S+)+\""' % config_inter,
                                line.decode('utf-8'))
                        if macval:
                            if macval.group(1) and macval.group(2):
                                subprocess.call('ifconfig %s %s delete' %
                                        (interface,  macval.group(1)),
                                        shell = True)
                        if ip == 'dhcp':
                            cfg_file.write('%s="DHCP"\n' % config_inter)
                            subprocess.call('dhclient %s' % interface,
                                    shell = True)
                        else:
                            cfg_file.write('%s="inet %s netmask %s"\n' %
                                    (config_inter, ip, mask))
                    elif (line.find('defaultrouter') == 0):
                        setroute = False
                        if 'gateway' in dir():
                            cfg_file.write('defaultrouter="%s"\n' % gateway)
                        else:
                            cfg_file.write(line)
                    else:
                        cfg_file.write(line)
                if setip:
                    if ip == 'dhcp':
                        cfg_file.write('%s="DHCP"\n' % config_inter)
                        subprocess.call('dhclient %s' % interface, shell = True)
                    else:
                        cfg_file.write('%s="inet %s netmask %s"\n' % (config_inter, ip, mask))
                if setroute:
                    if 'gateway' in dir():
                        cfg_file.write('defaultrouter="%s"\n' % gateway)
                cfg_file.close()
                cfg_file_bak.close()
            else:
                logging.error('system config error')
                sys.exit(1)
            #restart ethX
            if restart is not None and restart == 'false':
                pass
            else:
                if os.path.isfile(freebsd):
                    subprocess.call('/etc/netstart',
                                    shell = True)
                else:
                    subprocess.call('ifconfig %s down 1>/dev/null 2>&1' %
                                    interface,
                                    shell = True)
                    subprocess.call('ifup %s 1>/dev/null 2>&1' %
                                    interface,
                                    shell = True)
                    subprocess.call('ifdown %s 1>/dev/null 2>&1' %
                                    interface,
                                    shell = True)
                    subprocess.call('ifdown %s --force 1>/dev/null 2>&1' %
                                    interface,
                                    shell = True)
                    subprocess.call('ifup %s 1>/dev/null 2>&1' %
                                    interface,
                                    shell = True)
                    if multi_ip == True and os.path.isfile(ubuntu):
                        ifcfg = ubuntu
                        cfg_file = open(ifcfg,'r')
                        for line in cfg_file:
                            if re.match('auto %s:' % interface, \
                                    line.decode('utf-8')):
                                subprocess.call('ifdown %s 1>/dev/null 2>&1' %
                                    (line.split()).pop(),
                                    shell = True)
                                subprocess.call('ifup %s 1>/dev/null 2>&1' %
                                    (line.split()).pop(),
                                    shell = True)
                        cfg_file.close()
            if ip != 'dhcp':
                proc = subprocess.Popen('hostname', shell = True, \
                                        stdout = subprocess.PIPE)
                outs, errs = proc.communicate()
                if proc.returncode != 0:
                    logging.error('hostname error')
                    sys.exit(1)
                host = outs.decode('utf-8')
                hosts = '/etc/hosts'
                hosts_bak = hosts + '.bak'
                subprocess.call('cp %s %s' % (hosts, hosts_bak), shell = True)
                subprocess.call('sync 1>/dev/null 2>&1', shell = True)
                bak_file = open(hosts_bak, 'r')
                cfg_file = open(hosts, 'w')
                for line in bak_file:
                    if line.find(ip) == -1 and line.find(host) == -1:
                        cfg_file.write(line)
                cfg_file.write('%s %s' % (ip, host))
                bak_file.close()
                cfg_file.close()

            if 'gateway' in dir():
                if os.path.isfile(freebsd):
                    returncode = subprocess.call('route add default %s' % gateway, \
                                                 shell = True)
                else:
                    returncode = subprocess.call('route add default gw %s' % gateway, \
                                                 shell = True)
                    if returncode != 0:
                        returncode = subprocess.call('command -v ip >/dev/null', \
                                                     shell = True)
                if returncode != 0 and returncode != 1 and returncode != 7:
                    logging.error('gateway route add error')
                    sys.exit(1)

        if len(dns) != 0:
            resolv = open('/etc/resolv.conf', 'a+')
            servers = resolv.read()
            for server in dns:
                if servers.find(server.childNodes[0].nodeValue) == -1:
                    resolv.write('nameserver %s\n' % server.childNodes[0].nodeValue)
            resolv.close()

        if 'hostname' in dir():
            proc = subprocess.Popen('hostname', shell = True, \
                                    stdout = subprocess.PIPE)
            outs, errs = proc.communicate()
            if proc.returncode != 0:
                logging.error('hostname error')
                sys.exit(1)
            host = outs.decode('utf-8')

            proc1 = subprocess.Popen('ip addr', shell = True, \
                                    stdout = subprocess.PIPE)
            outs1_ip, errs = proc1.communicate()
            proc2 = subprocess.Popen('ifconfig -a', shell = True, \
                                    stdout = subprocess.PIPE)
            outs2_ip, errs = proc2.communicate()
            outs1_ipv6 = outs1_ip
            outs2_ipv6 = outs2_ip
            host_ip = ''
            host_ipv6 = ''
            if proc1.returncode == 0:
                iplist = re.findall("inet (\d+.\d+.\d+.\d+)/", outs1_ip.decode('utf-8'))
                ipv6list = re.findall("inet6 ([^/]+)/", outs1_ipv6.decode('utf-8'))
            elif proc2.returncode == 0:
                iplist = re.findall("inet (\d+.\d+.\d+.\d+) ", outs2_ip.decode('utf-8'))
                ipv6list = re.findall("inet6 (\S+)\s+prefixlen", outs2_ipv6.decode('utf-8'))
                if len(iplist) == 0:
                    iplist = re.findall("inet addr:(\d+.\d+.\d+.\d+) ", outs2_ip.decode('utf-8'))
                if len(ipv6list) == 0:
                    ipv6list = re.findall("inet6 addr:\s?([^/]+)/", outs2_ip.decode('utf-8'))
            else:
                logging.error('ip error')
                sys.exit(1)
            for ip in iplist:
                if ip != '127.0.0.1':
                    host_ip = ip;
                    break
            for ipv6 in ipv6list:
                if not re.match("fe80::", ipv6.decode('utf-8')) and not re.match("^::1$", ipv6.decode('utf-8')):
                    host_ipv6 = ipv6
                    break
            if subprocess.call('hostname %s' % hostname, shell = True) != 0:
                logging.error('hostname error')
                sys.exit(1)
            hosts = '/etc/hosts'
            hosts_bak = hosts + '.bak'
            subprocess.call('cp %s %s' % (hosts, hosts_bak), shell = True)
            subprocess.call('sync 1>/dev/null 2>&1', shell = True)
            bak_file = open(hosts_bak, 'r')
            cfg_file = open(hosts, 'w')
            for line in bak_file:
                if line.find(host_ip) <= 0 and line.find(host_ipv6) <= 0 and line.find(host) <= 0:
                    cfg_file.write(line)
            if len(host_ip):
                cfg_file.write('%s %s\n' % (host_ip, hostname))
            if len(host_ipv6):
                cfg_file.write('%s %s\n' % (host_ipv6, hostname))
            bak_file.close()
            cfg_file.close()

            ubuntu = '/etc/hostname'
            # for redhat and rocky
            redhat = '/etc/sysconfig/network'
            opensuse = '/etc/HOSTNAME'
            freebsd = '/etc/rc.conf'
            if os.path.isfile(ubuntu):
                hostcfg = ubuntu
                hostcfg_bak = hostcfg + '.bak'
                subprocess.call('cp %s %s' % (hostcfg, hostcfg_bak), \
                                shell = True)
                subprocess.call('sync 1>/dev/null 2>&1', shell = True)
                cfg_file = open(hostcfg, 'w')
                cfg_file.write('%s' % hostname)
                cfg_file.close()
                light = '/etc/init.d/lightdm'
                if os.path.isfile(light):
                    ver = open('/etc/issue.net', 'r')
                    buffer = ver.read()
                    if int(buffer.split(' ')[1].split('.')[0]) < 15:
                        subprocess.call('%s  restart' % (light), shell = True)
                    ver.close()
            elif os.path.isfile(redhat):
                hostcfg = redhat
                hostcfg_bak = hostcfg + '.bak'
                subprocess.call('cp %s %s' % (hostcfg, hostcfg_bak), \
                                shell = True)
                bak_file = open(hostcfg_bak, 'r')
                cfg_file = open(hostcfg, 'w')
                for line in bak_file:
                    if line.find('HOSTNAME') == -1:
                        cfg_file.write(line)
                cfg_file.write('HOSTNAME=%s\n' % hostname)
                bak_file.close()
                cfg_file.close()
            elif os.path.isfile(opensuse):
                hostcfg = opensuse
                hostcfg_bak = hostcfg + '.bak'
                subprocess.call('mv %s %s' % (hostcfg, hostcfg_bak), \
                                shell = True)
                subprocess.call('sync 1>/dev/null 2>&1', shell = True)
                bak_file = open(hostcfg_bak, 'r')
                bak_name = bak_file.read()
                bak_domain = re.search("[.]\S+" , bak_name)
                cfg_file = open(hostcfg, 'w')
                if bak_domain is not None:
                    cfg_file.write('%s%s' % (hostname,bak_domain.group()))
                else:
                    cfg_file.write('%s' % hostname)
                cfg_file.close()
                bak_file.close()
            elif os.path.isfile(freebsd):
                hostcfg = freebsd
                hostcfg_bak = hostcfg + '.bak'
                subprocess.call('cp %s %s' % (hostcfg, hostcfg_bak), \
                                shell = True)
                bak_file = open(hostcfg_bak, 'r')
                cfg_file = open(hostcfg, 'w')
                for line in bak_file:
                    if line.find('hostname') == -1:
                        cfg_file.write(line)
                cfg_file.write('hostname=%s\n' % hostname)
                bak_file.close()
                cfg_file.close()
            else:
                logging.error('not support the os')
                sys.exit(1)

        redhat = '/etc/sysconfig/'
        ubuntu = '/etc/network/interfaces'
        if 'destination' in dir():
            mask_count = exchange_mask(netmask)
            subprocess.call('ip route delete %s/%s' % (destination, mask_count), \
                                     shell = True)
            returncode = subprocess.call('ip route add %s/%s via %s' % (destination, mask_count, gateway), \
                                     shell = True)
            if returncode != 0:
                logging.error('ip route error')
                sys.exit(1)

            if os.path.isdir(redhat):
                srout_cfg = redhat + 'static-routes'
                srout_cfg_bak = srout_cfg + '.bak'
                subprocess.call('mv %s %s' % (srout_cfg, srout_cfg_bak), \
                                shell = True)
                rout_cmd = ('any net %s/%s gw %s\n' % (destination, mask_count, gateway))
                srout_file = open(srout_cfg, 'a')
                if os.path.isfile(srout_cfg_bak):
                    srout_file_bak = open(srout_cfg_bak, 'r')
                    for line in srout_file_bak:
                        if line.find(rout_cmd) == -1:
                            srout_file.write(line)
                srout_file.write(rout_cmd)
                srout_file.close()
                if os.path.isfile(srout_cfg_bak):
                    srout_file_bak.close()

            elif os.path.isfile(ubuntu):
                srout_cfg = ubuntu
                srout_cfg_bak = srout_cfg + '.rotbak'
                subprocess.call('mv %s %s' % (srout_cfg, srout_cfg_bak), \
                                shell = True)
                rout_cmd = ('up route add -net %s netmask %s gw %s\n' % (destination, netmask, gateway))
                srout_file = open(srout_cfg, 'a')
                if os.path.isfile(srout_cfg_bak):
                    srout_file_bak = open(srout_cfg_bak, 'r')
                    for line in srout_file_bak:
                        if line.find(rout_cmd) == -1:
                            srout_file.write(line)
                srout_file.write(rout_cmd)
                srout_file.close()
                if os.path.isfile(srout_cfg_bak):
                    srout_file_bak.close()

            else:
                logging.error('not support the os')
                sys.exit(1)

    except SystemExit:
        sys.exit(1)
    except Exception:
        logging.error(traceback.format_exc())
        sys.exit(1)
