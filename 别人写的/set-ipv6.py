#!/usr/bin/env python
# encoding: utf-8

import sys
import os
import re
import subprocess
import socket

import traceback
import logging
import logging.config
from xml.dom.minidom import parseString

logging.config.fileConfig('/etc/qemu-ga/network.conf')
LOG = logging.getLogger("CastoolsSetIPV6")


class Distro(object):
    def __init__(self, net_cfg = None):
        LOG.debug('call Distro')
        self._net_cfg = net_cfg
        self.init()

    def init(self):
        pass

    def _is_valid_ipv4(self, addr = None):
        try:
            socket.inet_pton(socket.AF_INET, addr)
        except AttributeError:
            try:
                socket.inet_aton(addr)
            except socket.error:
                return False
            return addr.count('.') == 3
        except socket.error:
            return False
        return True

    def _is_valid_ipv6(self, addr = None):
        try:
            socket.inet_pton(socket.AF_INET6, address)
        except socket.error:
            return False
        return True

    def _check_support_ipv6(self, outs_cfg = None, outs_ip = None):
        pass

    def check_support_ipv6(self):
        proc = subprocess.Popen('ifconfig -a %s' %
                                self._net_cfg['name'],
                                shell = True,
                                stdout = subprocess.PIPE)
        outs_cfg, errs = proc.communicate()
        proc = subprocess.Popen('ip address show %s' %
                                self._net_cfg['name'],
                                shell = True,
                                stdout = subprocess.PIPE)
        outs_ip, errs = proc.communicate()

        return self._check_support_ipv6(outs_cfg, outs_ip)

    def _enable_ipv6(self):
        pass

    def enable_ipv6(self):
        LOG.debug('enable ipv6')
        ipv6 = ('/proc/sys/net/ipv6/conf/%s/disable_ipv6' %
                self._net_cfg['name'])
        if os.path.isfile(ipv6):
            ipv6file = open(ipv6, 'w')
            ipv6file.write('0')
            ipv6file.close()
        self._enable_ipv6()

    def add_ipv6_dhcp(self):
        self._update_ipv6_dhcp()

    def del_ipv6_dhcp(self):
        pass

    def _update_ipv6_dhcp(self):
        pass

    def update_ipv6_dhcp(self):
        self._update_ipv6_dhcp()

    def add_ipv6_static(self):
        pass

    def del_ipv6_static(self):
        pass

    def _update_ipv6_static(self):
        pass

    def _set_ipv6_gateway(self):
        pass

    def _set_ipv6_dns(self):
        pass

    def _set_ipv6_default_route(self):
        ret_route = subprocess.call('route -A inet6 add default gw %s dev %s' %
                                    (self._net_cfg['gateway'],
                                     self._net_cfg['name']),
                                    shell = True)
        ret_iproute = subprocess.call('ip -6 route add default via %s dev %s' %
                                      (self._net_cfg['gateway'],
                                       self._net_cfg['name']),
                                      shell = True)
        LOG.debug('ret_route(%s), ret_iproute(%s)', ret_route, ret_iproute)
        if ret_route == 127 and ret_iproute == 127:
            raise Exception('cannot find route/ip command')

    def update_ipv6_static(self):
        self._update_ipv6_static()
        self._set_ipv6_gateway()
        self._set_ipv6_dns()

    def add_mtu(self):
        pass

    def del_mtu(self):
        pass

    def _update_mtu(self):
        pass

    def update_mtu(self):
        self._update_mtu()

    def restart_interface(self):
        LOG.info('restart the interface(%s)', self._net_cfg['name'])
        try:
            proc = subprocess.Popen('ifconfig %s down' % self._net_cfg['name'],
                                    shell = True,
                                    stdout = subprocess.PIPE)
            outs_down, errs = proc.communicate()
            LOG.debug('ifconfig down(%s)', outs_down)
            proc = subprocess.Popen('ifup %s' % self._net_cfg['name'],
                                    shell = True,
                                    stdout = subprocess.PIPE)
            outs_up, errs = proc.communicate()
            LOG.info('ifup(%s)', outs_up)
            proc = subprocess.Popen('ifdown %s' % self._net_cfg['name'],
                                    shell = True,
                                    stdout = subprocess.PIPE)
            outs_down, errs = proc.communicate()
            LOG.debug('ifdown(%s)', outs_down)
            proc = subprocess.Popen('ifup %s' % self._net_cfg['name'],
                                    shell = True,
                                    stdout = subprocess.PIPE)
            outs_up, errs = proc.communicate()
            LOG.info('ifup(%s)', outs_up)
        except Exception:
            LOG.warning('restart_interface fail')


class Rhel(Distro):
    def init(self):
        LOG.debug('call Rhel')
        self._ifcfg_file = ('/etc/sysconfig/network-scripts/ifcfg-%s' %
                            self._net_cfg['name'])
        self._ifcfg_file_bak = self._ifcfg_file + '.bak'
        self._network_file = '/etc/sysconfig/network'
        self._ip6tables_file = '/etc/sysconfig/ip6tables'

    def _check_support_ipv6(self, outs_cfg = None, outs_ip = None):
        if re.search("\s+inet6 fe80:", outs_cfg.decode('utf-8')):
            return True
        elif re.search("\s+inet6 fe80:", outs_ip.decode('utf-8')):
            return True
        else:
            LOG.debug('interface(%s) not support ipv6', self._net_cfg['name'])
            return False

    def _enable_ipv6(self):
        sysctl_cnf = '/etc/sysctl.conf'
        if os.path.exists(sysctl_cnf):
            os.rename(sysctl_cnf, sysctl_cnf + '.bak')
            f = open(sysctl_cnf + '.bak', 'r')
            lines = f.readlines()
            f.close()
        else:
            lines = []
        f = open(sysctl_cnf, 'w')
        for line in lines:
            if re.match("net.ipv6.conf.all.disable_ipv6=1",
                        line.decode('utf-8')):
                f.write("#net.ipv6.conf.all.disable_ipv6=1\n")
            elif re.match("net.ipv6.conf.default.disable_ipv6=1",
                          line.decode('utf-8')):
                f.write("#net.ipv6.conf.default.disable_ipv6=1\n")
            else:
                f.write(line)
        f.close()

    def _check_ip6tables(self):
        if os.path.exists(self._ip6tables_file):
            os.rename(self._ip6tables_file, self._ip6tables_file + '.bak')
            f = open(self._ip6tables_file + '.bak', 'r')
            lines = f.readlines()
            f.close()
        else:
            lines = []
        f = open(self._ip6tables_file, 'w')
        for line in lines:
            if re.match('^-A INPUT -j REJECT --reject-with '
                        'icmp6-adm-prohibited',
                        line.decode('utf-8')):
                f.write('#-A INPUT -j REJECT --reject-with '
                        'icmp6-adm-prohibited\n')
            else:
                f.write(line)
        f.close()
        subprocess.call('service ip6tables restart', shell = True)
        subprocess.call('/etc/init.d/ip6tables restart', shell = True)

    def _update_ipv6_dhcp(self):
        self._check_ip6tables()
        if os.path.exists(self._network_file):
            os.rename(self._network_file, self._network_file + '.bak')
            f = open(self._network_file + '.bak', 'r')
            lines = f.readlines()
            f.close()
        else:
            lines = []
        f = open(self._network_file, 'w')
        for line in lines:
            if re.match("NETWORKING_IPV6", line.decode('utf-8')):
                continue
            else:
                f.write(line)
        f.write("NETWORKING_IPV6=yes")
        f.close()

        if os.path.exists(self._ifcfg_file):
            os.rename(self._ifcfg_file, self._ifcfg_file_bak)
            f = open(self._ifcfg_file_bak, 'r')
            contents = f.readlines()
            for line in contents:
                if re.search("(%s|%s)" % (self._net_cfg['mac'].upper(),
                                              self._net_cfg['mac'].lower()),
                                 line.decode('utf-8')):
                    lines = contents
                    break
                else:
                    lines = []
            f.close()
        else:
            lines = []
        f = open(self._ifcfg_file, 'w')
        f.write('DEVICE=%s\n' % self._net_cfg['name'])
        f.write('HWADDR=%s\n' % self._net_cfg['mac'].lower())
        f.write('ONBOOT=yes\n')
        for line in lines:
            if not re.match("(IPV6|DHCPV6C)", line.decode('utf-8')):
                if re.match("(HWADDR|MACADDR|DEVICE|ONBOOT)",
                            line.decode('utf-8')):
                    continue
                else:
                    f.write(line)
        mode = self._net_cfg.get('mode')
        if mode == 'dhcpv6-stateless':
            f.write('IPV6INIT=yes\n')
            f.write('DHCPV6C=yes\n')
            f.write('IPV6_AUTOCONF=yes\n')
            f.write('DHCPV6C_OPTIONS=-S\n')
        elif mode == 'slaac':
            f.write('IPV6INIT=yes\n')
            f.write('DHCPV6C=no\n')
            f.write('IPV6_AUTOCONF=yes\n')
        else:
            f.write('IPV6INIT=yes\n')
            f.write('DHCPV6C=yes\n')
            f.write('IPV6_AUTOCONF=no\n')
        f.close()

    def _update_ipv6_static(self):
        if os.path.exists(self._ifcfg_file):
            os.rename(self._ifcfg_file, self._ifcfg_file_bak)
            f = open(self._ifcfg_file_bak, 'r')
            contents = f.readlines()
            for line in contents:
                if re.search("(%s|%s)" % (self._net_cfg['mac'].upper(),
                                          self._net_cfg['mac'].lower()),
                             line.decode('utf-8')):
                    lines = contents
                    break
                else:
                    lines = []
            f.close()
        else:
            lines = []
        f = open(self._ifcfg_file, 'w')
        f.write('DEVICE=%s\n' % self._net_cfg['name'])
        f.write('HWADDR=%s\n' % self._net_cfg['mac'].lower())
        f.write('ONBOOT=yes\n')
        for line in lines:
            if not re.match("(IPV6|DHCPV6C)", line.decode('utf-8')):
                if re.match("(HWADDR|MACADDR|DEVICE|ONBOOT|PEERDNS)",
                            line.decode('utf-8')):
                    continue
                else:
                    f.write(line)
        f.write('IPV6INIT=yes\n')
        f.write('IPV6_AUTOCONF=no\n')
        if self._net_cfg.has_key('ip'):
            if self._net_cfg.has_key('prefix'):
                f.write('IPV6ADDR=%s/%s\n' %
                        (self._net_cfg['ip'], self._net_cfg['prefix']))
            else:
                f.write('IPV6ADDR=%s\n' % self._net_cfg['ip'])
        f.close()

    def _set_ipv6_gateway(self):
        if self._net_cfg.has_key('gateway'):
            f = open(self._ifcfg_file, 'a+')
            f.write('IPV6_DEFAULTGW=%s\n' % self._net_cfg['gateway'])
            f.close()
            self._set_ipv6_default_route()

    def _set_ipv6_dns(self):
        resolv_conf = '/etc/resolv.conf'
        if self._net_cfg.has_key('dns'):
            f = open(self._ifcfg_file, 'a+')
            f.write('PEERDNS=yes\n')
            f.close()
            f = open(resolv_conf, 'a+')
            servers = f.read()
            for dns in self._net_cfg['dns']:
                if servers.find(dns) == -1:
                    f.write('nameserver %s\n' % dns)
            f.close()

    def _update_mtu(self):
        if os.path.exists(self._ifcfg_file):
            os.rename(self._ifcfg_file, self._ifcfg_file_bak)
            f = open(self._ifcfg_file_bak, 'r')
            contents = f.readlines()
            for line in contents:
                if re.search("(%s|%s)" % (self._net_cfg['mac'].upper(),
                                          self._net_cfg['mac'].lower()),
                             line.decode('utf-8')):
                    lines = contents
                    break
                else:
                    lines = []
            f.close()
        else:
            lines = []
        f = open(self._ifcfg_file, 'w')
        f.write('DEVICE=%s\n' % self._net_cfg['name'])
        f.write('HWADDR=%s\n' % self._net_cfg['mac'].lower())
        f.write('ONBOOT=yes\n')
        f.write('MTU=%s\n' % self._net_cfg['mtu'])
        for line in lines:
            if re.match("(HWADDR|MACADDR|DEVICE|ONBOOT|MTU)",
                        line.decode('utf-8')):
                continue
            else:
                f.write(line)
        f.close()


class Ubuntu(Distro):
    def init(self):
        LOG.debug('call ubuntu')
        self._ifcfg_file = '/etc/network/interfaces'
        self._ifcfg_file_bak = self._ifcfg_file + '.bak'
        self._net_file_dict = {}
    def _check_support_ipv6(self, outs_cfg = None, outs_ip = None):
        if re.search("\s+inet6 fe80:", outs_cfg.decode('utf-8')):
            return True
        elif re.search("\s+inet6 fe80:", outs_ip.decode('utf-8')):
            return True
        else:
            LOG.debug('interface(%s) not support ipv6', self._net_cfg['name'])
            return False

    def _enable_ipv6(self):
        lines = ''
        sysctl_cnf = '/etc/default/ufw'
        if os.path.exists(sysctl_cnf):
            os.rename(sysctl_cnf, sysctl_cnf + '.bak')
            f = open(sysctl_cnf + '.bak', 'r')
            lines = f.readlines()
            f.close()
        f = open(sysctl_cnf, 'w')
        for line in lines:
            if not re.match("IPV6=", line.decode('utf-8')):
                f.write(line)
        f.write("IPV6=yes\n")
        f.close()

    def _parse_ifcfg(self):
        root = {}
        iface = {}
        family = {}
        iflists = []
        cmds = []

        f = open(self._ifcfg_file, 'r')
        lines = f.readlines()
        f.close()

        level = 0
        for line in reversed(lines):
            if re.match('(auto|allow-hotplug)[\s]+[\S]+', line.decode('utf-8')):
                level = 1
            elif re.match('iface[\s]+[\S]+[\s]+inet(.*)', line.decode('utf-8')):
                level = 2
            elif re.match('^[\s]+[\S]+[\s]+(.*)', line.decode('utf-8')):
                level = 3
            else:
                level = 0

            if level == 1:
                tmpstr = re.search('([\S]+)[\s]+([\S]+)', line.decode('utf-8'))
                if tmpstr:
                    iface['family'] = family.copy()
                    iface['opt'] = line.replace('\n', '')
                    root[tmpstr.group(2)] = iface.copy()
                    iflists.append(tmpstr.group(2))
                family.clear()
                iface.clear()
            elif level == 2:
                cmds.reverse()
                tmpstr = re.match('iface[\s]+([\S]+)[\s]+([\S]+)[\s]+([\S]+)',
                                  line.decode('utf-8'))
                if tmpstr:
                    if tmpstr.group(2) == 'inet':
                        family['cmds'] = cmds[:]
                        family['inet'] = line.replace('\n', '')
                    elif tmpstr.group(2) == 'inet6':
                        family['cmds6'] = cmds[:]
                        family['inet6'] = line.replace('\n', '')
                cmds = []
            elif level == 3:
                cmds.append(line.replace('\n', ''))
        iflists.reverse()
        root['iflists'] = iflists[:]
        self._net_file_dict = root

    def _save_ipv4(self):
        os.rename(self._ifcfg_file, self._ifcfg_file_bak)
        ipv4_static = True
        ipv4_confes = []
        cfg_file = open(self._ifcfg_file, 'w')
        f = open(self._ifcfg_file_bak, 'r')
        lines = f.readlines()
        f.close()
        for line in lines:
            if re.match("iface %s inet dhcp" % self._net_cfg['name'],
                        line.decode('utf-8')):
                ipv4_static=False
        f = open(self._ifcfg_file_bak, 'r')
        lines = f.readlines()
        f.close()
        delete = False
        is_ipv4 = True
        is_hwaddr = True
        for line in lines:
            if delete:
                if re.search("inet ", line.decode('utf-8')):
                    is_ipv4 = True
                elif re.search("inet6 ", line.decode('utf-8')):
                    is_ipv4 = False
                if ((line.find('auto ') == 0 and
                     line != 'auto ' + self._net_cfg['name'] + '\n') or
                    (line.find('allow-hotplug ') == 0 and
                     line != 'allow-hotplug ' + self._net_cfg['name'] + '\n'
                    )):
                    delete = False
                    cfg_file.write(line)
                elif is_ipv4 == True:
                    if re.search('#hwaddr', line.decode('utf-8')):
                        if re.search('%s' % self._net_cfg['mac'].lower(),
                                     line.decode('utf-8')):
                            is_hwaddr = True
                        else:
                            is_hwaddr = False
                    if re.search('address|network|gateway|broadcast|'
                                 'netmask|dns-nameservers',
                                 line.decode('utf-8')):
                        if is_hwaddr == True:
                            ipv4_confes.append(line)
            else:
                if ((line == 'auto ' + self._net_cfg['name'] + '\n') or
                    (line == ('allow-hotplug ' + self._net_cfg['name'] +
                              '\n'))):
                    delete = True
                else:
                    cfg_file.write(line)
        cfg_file.write('auto %s\n' % self._net_cfg['name'])
        if is_hwaddr == True:
            if not ipv4_static:
                cfg_file.write('iface %s inet dhcp\n' % self._net_cfg['name'])
                cfg_file.write('\t#hwaddr %s\n' % self._net_cfg['mac'].lower())
            else:
                if ipv4_confes:
                    cfg_file.write('iface %s inet static\n' %
                                   self._net_cfg['name'])
                    cfg_file.write('\t#hwaddr %s\n' %
                                   self._net_cfg['mac'].lower())
                    for ipv4_conf in ipv4_confes:
                        cfg_file.write('%s' % ipv4_conf)
        cfg_file.close()

    def _update_ipv6_dhcp(self):
        lines = ''
        dhc6_cfg_file = "/etc/dhcp/dhclient6.conf"
        dhc6_cfg_file_bak = dhc6_cfg_file + ".bak"
        self._save_ipv4()
        f = open(self._ifcfg_file, 'a+')
        f.write('iface %s inet6 auto\n' % self._net_cfg['name'])
        f.write('\t#hwaddr %s\n' % self._net_cfg['mac'].lower())
        if self._net_cfg.get('mode') == 'dhcpv6-stateless':
            f.write('\tdhcp 1\n')
        else:
            mode = self._net_cfg.get('mode')
            if mode == 'dhcpv6-stateless':
                f.write('\tdhcp 1\n')
            elif mode == 'slaac':
                f.write('\tdhcp 0\n')
            else:
                f.write('\tup sleep 5\n')
                f.write('\tup dhclient -1 -6 -cf %s -lf '
                        '/var/lib/dhcp/dhclient6.%s.leases -v %s\n' %
                        (dhc6_cfg_file, self._net_cfg['name'],
                        self._net_cfg['name']))
                if os.path.isfile(dhc6_cfg_file):
                    os.rename(dhc6_cfg_file, dhc6_cfg_file_bak)
                    f1 = open(dhc6_cfg_file_bak, 'r')
                    lines = f1.readlines()
                    f1.close()
                f2 = open(dhc6_cfg_file, 'w')
                for line in lines:
                    if not re.search("timeout", line.decode('utf-8')):
                        f2.write('%s' % line)
                f2.write('timeout 10;\n')
                f2.close()
        f.close()

    def _update_ipv6_static(self):
        self._save_ipv4()
        f = open(self._ifcfg_file, 'a+')
        f.write('iface %s inet6 static\n' % self._net_cfg['name'])
        f.write('\t#hwaddr %s\n' % self._net_cfg['mac'].lower())
        f.write('\taddress %s\n' % self._net_cfg['ip'])
        f.write('\tnetmask %s\n' % self._net_cfg['prefix'])
        f.close()

    def _set_ipv6_gateway(self):
        if self._net_cfg.has_key('gateway'):
            f = open(self._ifcfg_file, 'a+')
            f.write('\tgateway %s\n' % self._net_cfg['gateway'])
            f.close()
            self._set_ipv6_default_route()

    def _set_ipv6_dns(self):
        resolv_conf = '/etc/resolv.conf'
        if self._net_cfg.has_key('dns'):
            f = open(resolv_conf, 'a+')
            servers = f.read()
            for dns in self._net_cfg['dns']:
                if servers.find(dns) == -1:
                    f.write('nameserver %s\n' % dns)
            f.close()

    def _update_mtu(self):
        self._parse_ifcfg()
        os.rename(self._ifcfg_file, self._ifcfg_file_bak)
        cfg_file = open(self._ifcfg_file, 'w')

        if self._net_file_dict.has_key('iflists'):
            for ifname in self._net_file_dict['iflists']:
                iface = self._net_file_dict[ifname]
                cfg_file.write('%s\n' % iface['opt'])
                family = iface['family']
                if family.has_key('inet'):
                    is_hwaddr = True
                    cmds = []
                    if family.has_key('cmds'):
                        cmds = family['cmds']
                    if ifname == self._net_cfg['name']:
                        for cmd in cmds:
                            if re.search('#hwaddr', cmd.decode('utf-8')):
                                if re.search('%s' %
                                             self._net_cfg['mac'].lower(),
                                             cmd.decode('utf-8')):
                                    is_hwaddr = True
                                else:
                                    is_hwaddr = False
                    if is_hwaddr:
                        cfg_file.write('%s\n' % family['inet'])
                        if ifname == self._net_cfg['name']:
                            cfg_file.write('\t#hwaddr %s\n' %
                                           self._net_cfg['mac'].lower())
                    for cmd in cmds:
                        if is_hwaddr == False:
                            break
                        if ifname == self._net_cfg['name']:
                            if (re.match('[\s]+#hwaddr[\s]+.*',
                                         cmd.decode('utf-8')) or
                                re.match('[\s]+pre-up[\s]+ifconfig[\s]+%s'
                                         '[\s]+mtu.*' % self._net_cfg['name'],
                                         cmd.decode('utf-8'))):
                                pass
                            else:
                                cfg_file.write('%s\n' % cmd)
                        else:
                            cfg_file.write('%s\n' % cmd)
                    if is_hwaddr and ifname == self._net_cfg['name']:
                        cfg_file.write('\tpre-up ifconfig %s mtu %s\n' %
                                       (ifname, self._net_cfg['mtu']))
                if family.has_key('inet6'):
                    is_hwaddr = True
                    cmds = []
                    if family.has_key('cmds6'):
                        cmds = family['cmds6']
                    if ifname == self._net_cfg['name']:
                        for cmd in cmds:
                            if re.search('#hwaddr', cmd.decode('utf-8')):
                                if re.search('%s' %
                                             self._net_cfg['mac'].lower(),
                                             cmd.decode('utf-8')):
                                    is_hwaddr = True
                                else:
                                    is_hwaddr = False
                    if is_hwaddr:
                        cfg_file.write('%s\n' % family['inet6'])
                        if ifname == self._net_cfg['name']:
                            cfg_file.write('\t#hwaddr %s\n' %
                                           self._net_cfg['mac'].lower())
                    for cmd in cmds:
                        if is_hwaddr == False:
                            break
                        if ifname == self._net_cfg['name']:
                            if (re.match('[\s]+#hwaddr[\s]+.*',
                                         cmd.decode('utf-8')) or
                                re.match('[\s]+pre-up[\s]+ifconfig[\s]+%s'
                                         '[\s]+mtu.*' % self._net_cfg['name'],
                                         cmd.decode('utf-8'))):
                                pass
                            else:
                                cfg_file.write('%s\n' % cmd)
                        else:
                            cfg_file.write('%s\n' % cmd)
                    if is_hwaddr and ifname == self._net_cfg['name']:
                        cfg_file.write('\tpre-up ifconfig %s mtu %s\n' %
                                       (ifname, self._net_cfg['mtu']))
        cfg_file.close()

    def restart_interface(self):
        LOG.info('restart the interface(%s)', self._net_cfg['name'])
        try:
            proc = subprocess.Popen('ifconfig %s down' % self._net_cfg['name'],
                                    shell = True,
                                    stdout = subprocess.PIPE)
            outs_down, errs = proc.communicate()
            LOG.debug('ifconfig down(%s)', outs_down)
            proc = subprocess.Popen('ifup %s' % self._net_cfg['name'],
                                    shell = True,
                                    stdout = subprocess.PIPE)
            outs_up, errs = proc.communicate()
            LOG.info('ifup(%s)', outs_up)
            proc = subprocess.Popen('ifdown %s --force' % self._net_cfg['name'],
                                    shell = True,
                                    stdout = subprocess.PIPE)
            outs_down, errs = proc.communicate()
            LOG.debug('ifdown(%s)', outs_down)
            proc = subprocess.Popen('ifup %s' % self._net_cfg['name'],
                                    shell = True,
                                    stdout = subprocess.PIPE)
            outs_up, errs = proc.communicate()
            LOG.info('ifup(%s)', outs_up)
        except Exception:
            LOG.warning('restart_interface fail')


class Freebsd(Distro):
    def init(self):
        LOG.debug('call freebsd')
        self._ifcfg_file = '/etc/rc.conf'
        self._ifcfg_file_bak = self._ifcfg_file + '.bak'

    def _check_support_ipv6(self, outs_cfg = None, outs_ip = None):
        if re.search("\s+inet6 fe80:", outs_cfg.decode('utf-8')):
            return True
        elif re.search("\s+inet6 fe80:", outs_ip.decode('utf-8')):
            return True
        else:
            LOG.debug('interface(%s) not support ipv6', self._net_cfg['name'])
            return False

    def check_support_ipv6(self):
        proc = subprocess.Popen('ifconfig %s' % self._net_cfg['name'],
                                shell = True,
                                stdout = subprocess.PIPE)
        outs_cfg, errs = proc.communicate()
        outs_ip = outs_cfg
        return self._check_support_ipv6(outs_cfg, outs_ip)

    def _enable_ipv6(self):
        sysctl_cnf = '/etc/rc.conf'
        os.rename(sysctl_cnf, sysctl_cnf + '.bak')
        f = open(sysctl_cnf + '.bak', 'r')
        lines = f.readlines()
        f.close()
        f = open(sysctl_cnf, 'w')
        for line in lines:
            if not re.search("ipv6_activate_all_interfaces",
                             line.decode('utf-8')):
                f.write(line)
        f.close()
        f = open(sysctl_cnf, 'a+')
        f.write('ipv6_activate_all_interfaces="YES"\n')
        f.close()

    def _update_ipv6_dhcp(self):
        os.rename(self._ifcfg_file, self._ifcfg_file_bak)
        f = open(self._ifcfg_file_bak, 'r')
        lines = f.readlines()
        f.close()
        f = open(self._ifcfg_file, 'w')
        for line in lines:
            if not re.match('ifconfig_%s_ipv6|rtsold_enable|'
                            'ipv6_defaultrouter' % self._net_cfg['name'],
                            line.decode('utf-8')):
                f.write(line)
        if self._net_cfg.get('mode') == 'dhcpv6-stateless':
            f.write('ifconfig_%s_ipv6="inet6 accept_rtadv"\n' %
                    self._net_cfg['name'])
            f.write('rtsold_enable="YES"\n')
        else:
            LOG.error('Freebsd support dhcpv6-stateless only.')
            raise Exception('mode error')
        f.close()

    def _update_ipv6_static(self):
        os.rename(self._ifcfg_file, self._ifcfg_file_bak)
        f = open(self._ifcfg_file_bak, 'r')
        lines = f.readlines()
        f.close()
        f = open(self._ifcfg_file, 'w')
        for line in lines:
            if not re.match('ifconfig_%s_ipv6|rtsold_enable|'
                            'ipv6_defaultrouter' % self._net_cfg['name'],
                            line.decode('utf-8')):
                f.write(line)
            if re.match("ifconfig_%s_ipv6" %
                    self._net_cfg['name'], line.decode('utf-8')):
                macval = re.search('ifconfig_%s_ipv6=\"inet6+\s+(\S+)+\s+'
                                   'prefixlen+\s+(\S+)+\"' %
                                   self._net_cfg['name'], line.decode('utf-8'))
                if macval:
                    if macval.group(1) and macval.group(2):
                        proc = subprocess.Popen('ifconfig %s inet6 %s/%s '
                                'delete' % (self._net_cfg['name'],
                                            macval.group(1),
                                            macval.group(2)),
                                shell = True,
                                stdout = subprocess.PIPE)
                        outs, errs = proc.communicate()
        f.write('ifconfig_%s_ipv6="inet6 %s prefixlen %s"\n' %
                (self._net_cfg['name'], self._net_cfg['ip'],
                self._net_cfg['prefix']))
        if self._net_cfg.has_key('gateway'):
            f.write('ipv6_defaultrouter="%s"\n' % self._net_cfg['gateway'])
        f.close()

    def _set_ipv6_dns(self):
        resolv_conf = '/etc/resolv.conf'
        if self._net_cfg.has_key('dns'):
            f = open(resolv_conf, 'a+')
            servers = f.read()
            for dns in self._net_cfg['dns']:
                if servers.find(dns) == -1:
                    f.write('nameserver %s\n' % dns)
            f.close()

    def _update_mtu(self):
        sif_conf = '/etc/start_if.' + self._net_cfg['name']
        sif_cmds = []
        if os.path.exists(sif_conf):
            f = open(sif_conf, 'r')
            lines = f.readlines()
            f.close()
            for line in lines:
                if not re.match("ifconfig[\s]+%s[\s]+mtu[\s].*" %
                                self._net_cfg['name'],
                                line.decode('utf-8')):
                    sif_cmds.append(line.replace('\n', ''))
        sif_cmds.append('ifconfig %s mtu %s' %(self._net_cfg['name'],
                        self._net_cfg['mtu']))
        f = open(sif_conf, 'w')
        for line in sif_cmds:
            f.write('%s\n' % line)
        f.close()

    def restart_interface(self):
        LOG.info('restart the interface(%s)', self._net_cfg['name'])
        try:
            proc = subprocess.Popen('/etc/netstart',
                                    shell = True,
                                    stdout = subprocess.PIPE)
            outs_down, errs = proc.communicate()
            LOG.debug('/etc/netstart(%s)', outs_down)
        except Exception:
            LOG.warning('restart_interface fail')

class Suse(Distro):
    def init(self):
        LOG.debug('call Suse')
        self._ifcfg_file = ('/etc/sysconfig/network/ifcfg-%s' %
                            self._net_cfg['name'])
        self._ifcfg_file_bak = self._ifcfg_file + '.bak'
        self._route_file = '/etc/sysconfig/network/routes'
        self._sysctl_file = ('/etc/sysconfig/network/ifsysctl-%s' %
                             self._net_cfg['name'])
        self._netman_file = '/etc/sysconfig/network/config'
        self._net_file_dict = {}

        if os.path.exists(self._netman_file):
            f = open(self._netman_file, 'r')
            lines = f.readlines()
            f.close()
            f = open(self._netman_file, 'w')
            for line in lines:
                if re.match("NETWORKMANAGER=", line.decode('utf-8')):
                    continue
                else:
                    f.write(line)
            f.write("NETWORKMANAGER=\"no\"\n")
            f.close()

        if os.path.isfile(self._ifcfg_file):
            lines = []
            f = open(self._ifcfg_file, 'r')
            contents = f.readlines()
            f.close()
            for line in contents:
                if re.search("(%s|%s)" % (self._net_cfg['mac'].upper(),
                                          self._net_cfg['mac'].lower()),
                             line.decode('utf-8')):
                    lines = contents
                    break
                else:
                    lines = []

            for line in lines:
                m = re.match("(\S+)=[\',\"]?([^\'\"]*)[\',\"]?",
                             line.decode('utf-8'))
                if m is not None and len(m.group(2)) != 0:
                    self._net_file_dict[m.group(1)] = m.group(2).strip()

    def _check_support_ipv6(self, outs_cfg = None, outs_ip = None):
        if re.search("\s+inet6\s*addr:\s*fe80:", outs_cfg.decode('utf-8')):
            return True
        elif re.search("\s+inet6\s*fe80:", outs_ip.decode('utf-8')):
            return True
        else:
            LOG.debug('interface(%s) not support ipv6', self._net_cfg['name'])
            return False

    def _enable_ipv6(self):
        sysctl_cnf = '/etc/sysctl.conf'
        if os.path.exists(sysctl_cnf):
            os.rename(sysctl_cnf, sysctl_cnf + '.bak')
            f = open(sysctl_cnf + '.bak', 'r')
            lines = f.readlines()
            f.close()
        else:
            lines = []
        f = open(sysctl_cnf, 'w')
        for line in lines:
            if re.match("net.ipv6.conf.all.disable_ipv6=1",
                        line.decode('utf-8')):
                f.write("#net.ipv6.conf.all.disable_ipv6=1\n")
            elif re.match("net.ipv6.conf.default.disable_ipv6=1",
                          line.decode('utf-8')):
                f.write("#net.ipv6.conf.default.disable_ipv6=1\n")
            else:
                f.write(line)
        f.close()

    def _update_ipv6_dhcp(self):
        self._net_file_dict['STARTMODE'] = 'auto'
        self._net_file_dict['LLADDR'] = self._net_cfg['mac']
        if self._net_file_dict.has_key('BOOTPROTO'):
            if self._net_file_dict['BOOTPROTO'] == 'dhcp4':
                self._net_file_dict['BOOTPROTO'] = 'dhcp'
            elif self._net_file_dict['BOOTPROTO'] == 'dhcp6':
                self._net_file_dict['BOOTPROTO'] = 'dhcp6'
            elif self._net_file_dict['BOOTPROTO'] == 'dhcp':
                self._net_file_dict['BOOTPROTO'] = 'dhcp'
        else:
            self._net_file_dict['BOOTPROTO'] = 'dhcp6'

        if self._net_file_dict.has_key('IPADDR'):
            self._net_file_dict.pop('IPADDR')
        if self._net_file_dict.has_key('IPADDR_IPV6'):
            self._net_file_dict.pop('IPADDR_IPV6')
        if self._net_file_dict.has_key('PREFIXLEN'):
            self._net_file_dict.pop('PREFIXLEN')
        if self._net_file_dict.has_key('PREFIXLEN_IPV6'):
            self._net_file_dict.pop('PREFIXLEN_IPV6')
        if self._net_file_dict.has_key('NETMASK'):
            self._net_file_dict.pop('NETMASK')
        if self._net_file_dict.has_key('NETMASK_IPV6'):
            self._net_file_dict.pop('NETMASK_IPV6')

        mode = self._net_cfg.get('mode')
        f = open(self._sysctl_file, 'w')
        if mode == 'dhcpv6-stateless':
            self._net_file_dict['DHCLIENT6_MODE'] = 'info'
            f.write('net.ipv6.conf.$SYSCTL_IF.autoconf = 0\n')
            f.write('net.ipv6.conf.$SYSCTL_IF.use_tempaddr = 1\n')
        elif mode == 'slaac':
            self._net_file_dict['DHCLIENT6_MODE'] = 'auto'
            if self._net_file_dict.has_key('BOOTPROTO'):
                if self._net_file_dict['BOOTPROTO'] == 'dhcp6':
                    self._net_file_dict.pop('BOOTPROTO')
                elif self._net_file_dict['BOOTPROTO'] == 'dhcp':
                    self._net_file_dict['BOOTPROTO'] = 'dhcp4'
        else:
            self._net_file_dict['DHCLIENT6_MODE'] = 'managed'
            f.write('net.ipv6.conf.$SYSCTL_IF.autoconf = 0\n')
        f.close()

        if os.path.isfile(self._ifcfg_file):
            os.rename(self._ifcfg_file, self._ifcfg_file_bak)
        f = open(self._ifcfg_file, 'w')
        for key, value in self._net_file_dict.items():
            content = key + "='" + value + "'\n"
            f.write(content)
        f.close()

    def _update_ipv6_static(self):
        self._net_file_dict['STARTMODE'] = 'auto'
        self._net_file_dict['LLADDR'] = self._net_cfg['mac']
        self._net_file_dict['BOOTPROTO'] = 'static'
        self._net_file_dict['IPADDR_IPV6'] = self._net_cfg['ip']
        if self._net_cfg.has_key('prefix'):
            self._net_file_dict['PREFIXLEN_IPV6'] = self._net_cfg['prefix']
        if self._net_file_dict.has_key('NETMASK'):
            self._net_file_dict.pop('NETMASK')
        if self._net_file_dict.has_key('NETMASK_IPV6'):
            self._net_file_dict.pop('NETMASK_IPV6')

        if os.path.isfile(self._ifcfg_file):
            os.rename(self._ifcfg_file, self._ifcfg_file_bak)
        f = open(self._ifcfg_file, 'w')
        for key, value in self._net_file_dict.items():
            content = key + "='" + value + "'\n"
            f.write(content)
        f.close()

        f = open(self._sysctl_file, 'w')
        f.write('net.ipv6.conf.$SYSCTL_IF.autoconf = 0')
        f.close()

    def _set_ipv6_gateway(self):
        if self._net_cfg.has_key('gateway'):
            f = open(self._route_file, 'a+')
            f.write('default %s - %s\n'
                    % (self._net_cfg['gateway'], self._net_cfg['name']))
            f.close()
            self._set_ipv6_default_route()

    def _set_ipv6_dns(self):
        resolv_conf = '/etc/resolv.conf'
        if self._net_cfg.has_key('dns'):
            f = open(resolv_conf, 'a+')
            servers = f.read()
            for dns in self._net_cfg['dns']:
                if servers.find(dns) == -1:
                    f.write('nameserver %s\n' % dns)
            f.close()

    def _update_mtu(self):
        self._net_file_dict['STARTMODE'] = 'auto'
        self._net_file_dict['LLADDR'] = self._net_cfg['mac']
        self._net_file_dict['MTU'] = self._net_cfg['mtu']

        if os.path.isfile(self._ifcfg_file):
            os.rename(self._ifcfg_file, self._ifcfg_file_bak)
        f = open(self._ifcfg_file, 'w')
        for key, value in self._net_file_dict.items():
            content = key + "='" + value + "'\n"
            f.write(content)
        f.close()

    def restart_interface(self):
        LOG.info('restart the interface(%s)', self._net_cfg['name'])
        subprocess.call('SuSEfirewall2 stop', shell = True)
        try:
            proc = subprocess.Popen('ifconfig %s down' % self._net_cfg['name'],
                                    shell = True,
                                    stdout = subprocess.PIPE)
            outs_down, errs = proc.communicate()
            LOG.debug('ifconfig down(%s)', outs_down)
            proc = subprocess.Popen('ifup %s' % self._net_cfg['name'],
                                    shell = True,
                                    stdout = subprocess.PIPE)
            outs_up, errs = proc.communicate()
            LOG.info('ifup(%s)', outs_up)
            proc = subprocess.Popen('ifdown %s' % self._net_cfg['name'],
                                    shell = True,
                                    stdout = subprocess.PIPE)
            outs_down, errs = proc.communicate()
            LOG.debug('ifdown(%s)', outs_down)
            proc = subprocess.Popen('ifup %s' % self._net_cfg['name'],
                                    shell = True,
                                    stdout = subprocess.PIPE)
            outs_up, errs = proc.communicate()
            LOG.info('ifup(%s)', outs_up)
        except Exception:
            LOG.warning('restart_interface fail')
        subprocess.call('SuSEfirewall2 start', shell = True)


class Init(object):
    def __init__(self, net_cfg = None, distro = None):
        self._module_name = 'set-ipv6'
        self._distro = distro
        self._distros_files_or_dirs = {
                'Rhel': '/etc/sysconfig/network-scripts',
                'Ubuntu': '/etc/network',
                'Suse': '/etc/sysconfig/network',
                'Freebsd': '/etc/pkg'
                }
        self._distro_obj = None
        self._net_cfg = net_cfg

        self.distro()

    def distro(self):
        if not self._distro:
            try:
                for keycls, file_dir in self._distros_files_or_dirs.items():
                    if os.path.isdir(file_dir):
                        self._distro = keycls
                        break
                if not self._distro:
                    raise Exception('not support the OS')
            except Exception:
                raise Exception("distro error")
        if not self._distro_obj:
            try:
                module = __import__(self._module_name)
                distrocls = getattr(module, self._distro)
                self._distro_obj = distrocls(self._net_cfg)
            except Exception:
                raise Exception("import distrocls fail")

    def check_support_ipv6(self):
        self._distro_obj.check_support_ipv6()

    def enable_ipv6(self):
        self._distro_obj.enable_ipv6()

    def add_ipv6_dhcp(self):
        self._distro_obj.add_ipv6_dhcp()

    def del_ipv6_dhcp(self):
        self._distro_obj.del_ipv6_dhcp()

    def update_ipv6_dhcp(self):
        self._distro_obj.update_ipv6_dhcp()

    def add_ipv6_static(self):
        self._distro_obj.add_ipv6_static()

    def del_ipv6_static(self):
        self._distro_obj.del_ipv6_static()

    def update_ipv6_static(self):
        self._distro_obj.update_ipv6_static()

    def add_mtu(self):
        self._distro_obj.add_mtu()

    def del_mtu(self):
        self._distro_obj.del_mtu()

    def update_mtu(self):
        self._distro_obj.update_mtu()

    def restart_interface(self):
        self._distro_obj.restart_interface()


def parse_xml(xmlstr):
    try:
        root = parseString(xmlstr.lower())
    except Exception:
        raise Exception('parse xml fail')

    net_cfg = {}
    dnslist = []
    Elements = root.getElementsByTagName('action')
    if len(Elements) != 0:
        net_cfg['action'] = Elements[0].childNodes[0].nodeValue
    Elements = root.getElementsByTagName('mac')
    if len(Elements) != 0:
        net_cfg['mac'] = Elements[0].childNodes[0].nodeValue
    Elements = root.getElementsByTagName('ip')
    if len(Elements) != 0:
        net_cfg['ip'] = Elements[0].childNodes[0].nodeValue
    Elements = root.getElementsByTagName('prefix')
    if len(Elements) != 0:
        net_cfg['prefix'] = Elements[0].childNodes[0].nodeValue
    Elements = root.getElementsByTagName('gateway')
    if len(Elements) != 0:
        net_cfg['gateway'] = Elements[0].childNodes[0].nodeValue
    dns = root.getElementsByTagName('dns')
    for server in dns:
        dnslist.append(server.childNodes[0].nodeValue)
    if len(dnslist):
        net_cfg['dns'] = dnslist
    Elements = root.getElementsByTagName('mode')
    if len(Elements) != 0:
        net_cfg['mode'] = Elements[0].childNodes[0].nodeValue
    Elements = root.getElementsByTagName('mtu')
    if len(Elements) != 0:
        net_cfg['mtu'] = Elements[0].childNodes[0].nodeValue
    Elements = root.getElementsByTagName('restart')
    if len(Elements) != 0:
        net_cfg['restart'] = Elements[0].childNodes[0].nodeValue

    proc = subprocess.Popen('ifconfig -a',
                            shell = True,
                            stdout = subprocess.PIPE)
    outs, errs = proc.communicate()
    macval=None
    macval = re.search("(\S+)\s+Link encap:\S+\s+\S+\s+(%s|%s)" %
                       (net_cfg['mac'].upper(), net_cfg['mac'].lower()),
                       outs.decode('utf-8'))
    if macval is None:
        macval = re.search("(\S+)\s+Link encap:\S+\s+\S+\s+(%s|%s)" %
                           (net_cfg['mac'].upper(), net_cfg['mac'].lower()),
                           outs.decode('utf-8'))
    if macval is None:
        macval = re.search('(\S+): flags=.*\n(\s+inet.*\n)?(\s+inet6.*\n)'
                           '?\s+ether %s' %
                           net_cfg['mac'].lower(),
                           outs.decode('utf-8'))
    if macval is None:
        macval = re.search("(\S+): flags=.*\n(\s+options=.*\n)?\s+ether %s" %
                           net_cfg['mac'].lower(),
                           outs.decode('utf-8'))
    if macval is None:
        proc = subprocess.Popen('ip link show',
                                shell = True,
                                stdout = subprocess.PIPE)
        outs, errs = proc.communicate()
        macval = re.search("[0-9]+:\s+(\S+):.*\n\s+link/ether (%s|%s)" %
                           (net_cfg['mac'].upper(), net_cfg['mac'].lower()),
                           outs.decode('utf-8'))
    if macval is not None:
        net_cfg['name'] = macval.group(1)
    else:
        raise Exception('cannot find the mac')

    return net_cfg



if __name__ == '__main__':
    try:
        # parameters validation
        arc = len(sys.argv)
        if arc == 2:
            LOG.info(sys.argv)
        else:
            raise Exception("arc isn't equl 2")
    except Exception:
        LOG.error("parameters error")
        sys.exit(1)

    try:
        net_cfg = parse_xml(sys.argv[1])
        distro = Init(net_cfg)
        if not distro.check_support_ipv6():
            distro.enable_ipv6()

        if 'action' in net_cfg:
            if net_cfg['action'] == 'add':
                if 'ip' in net_cfg:
                    if net_cfg['ip'] != 'dhcp':
                        distro.add_ipv6_static()
                    else:
                        distro.add_ipv6_dhcp()
                if 'mtu' in net_cfg:
                    distro.add_mtu()

            elif net_cfg['action'] == 'del':
                if 'ip' in net_cfg:
                    if net_cfg['ip'] != 'dhcp':
                        distro.del_ipv6_static()
                    else:
                        distro.del_ipv6_dhcp()
                if 'mtu' in net_cfg:
                    distro.del_mtu()

            elif net_cfg['action'] == 'update':
                if 'ip' in net_cfg:
                    if net_cfg['ip'] != 'dhcp':
                        distro.update_ipv6_static()
                    else:
                        distro.update_ipv6_dhcp()
                if 'mtu' in net_cfg:
                    distro.update_mtu()

            else:
                raise Exception('not support action(%s)',
                                net_cfg['action'])

            if 'restart' in net_cfg and net_cfg['restart'] == 'false':
                pass
            else:
                distro.restart_interface()
        else:
            if 'restart' in net_cfg and net_cfg['restart'] == 'false':
                pass
            else:
                distro.restart_interface()
    except Exception:
        LOG.error("FAILED", exc_info = True)
        ret = 1
    else:
        LOG.info("SUCESS")
        ret = 0

    sys.exit(ret)
