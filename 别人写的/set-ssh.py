#!/usr/bin/env python
# encoding: utf-8

import os
import sys
import pwd
import subprocess
import logging
import logging.config

logging.config.fileConfig('/etc/qemu-ga/network.conf')
LOG = logging.getLogger("CastoolsSetSSH")

DEF_SSHD_CFG = "/etc/ssh/sshd_config"

VALID_KEY_TYPES = (
        "dsa",
        "ecdsa",
        "ecdsa-sha2-nistp256",
        "ecdsa-sha2-nistp256-cert-v01@openssh.com",
        "ecdsa-sha2-nistp384",
        "ecdsa-sha2-nistp384-cert-v01@openssh.com",
        "ecdsa-sha2-nistp521",
        "ecdsa-sha2-nistp521-cert-v01@openssh.com",
        "ed25519",
        "rsa",
        "rsa-sha2-256",
        "rsa-sha2-512",
        "ssh-dss",
        "ssh-dss-cert-v01@openssh.com",
        "ssh-ed25519",
        "ssh-ed25519-cert-v01@openssh.com",
        "ssh-rsa",
        "ssh-rsa-cert-v01@openssh.com",
        )


class SshdConfigLine(object):
    def __init__(self, line, k=None, v=None):
        self.line = line
        self._key = k
        self.value = v

    @property
    def key(self):
        if self._key is None:
            return None
        return self._key.lower()

    def __str__(self):
        if self._key is None:
            return str(self.line)
        else:
            v = str(self._key)
            if self.value:
                v += " " + str(self.value)
            return v


def parse_ssh_config(fname):
    lines_cfg = []
    lines = []
    if not os.path.isfile(fname):
        return lines_cfg
    try:
        if os.path.isfile(fname):
            with open(fname, 'r') as f:
                lines = f.readlines()
    except Exception as e:
        LOG.error("Error reading lines from %s (%s)" , fname, e)
        lines = []
    for line in lines:
        line = line.strip()
        if not line or line.startswith("#"):
            lines_cfg.append(SshdConfigLine(line))
            continue
        try:
            key, val = line.split(None, 1)
        except ValueError:
            key, val = line.split('=', 1)
        lines_cfg.append(SshdConfigLine(line, key, val))
        return lines_cfg


def parse_ssh_config_map(fname):
    lines = parse_ssh_config(fname)
    if not lines:
        return {}
    ret = {}
    for line in lines:
        if not line.key:
            continue
        ret[line.key] = line.value
    return ret


def restart_ssh_daemon(username):
    try:
        ssh_cfg = parse_ssh_config_map(DEF_SSHD_CFG)
        if (username == 'root' and
            ssh_cfg.get("PermitRootLogin", '').strip().lower() != 'yes'):
                with open(DEF_SSHD_CFG, 'a') as f:
                    f.write('PermitRootLogin yes\n');
    except Exception as e:
        raise Exception("restart_ssh_daemon error(%s)", e)
    cmds = ['service sshd restart',
            'service ssh restart',
            'systemctl restart sshd.service',
            'systemctl restart ssh.service',
            '/etc/init.d/sshd restart',
            '/etc/init.d/ssh restart',
            ]
    for cmd in cmds:
        subprocess.call('%s' % cmd, shell = True)


class AuthKeyLine(object):
    def __init__(self, source, keytype=None, base64=None,
            comment=None, options=None):
        self.base64 = base64
        self.comment = comment
        self.options = options
        self.keytype = keytype
        self.source = source

    def valid(self):
        return (self.base64 and self.keytype)

    def __str__(self):
        toks = []
        if self.options:
            toks.append(self.options)
        if self.keytype:
            toks.append(self.keytype)
        if self.base64:
            toks.append(self.base64)
        if self.comment:
            toks.append(self.comment)
        if not toks:
            return self.source
        else:
            return ' '.join(toks)


class AuthKeyLineParser(object):
    def _extract_options(self, ent):
        quoted = False
        i = 0
        while (i < len(ent) and
                ((quoted) or (ent[i] not in (" ", "\t")))):
            curc = ent[i]
            if i + 1 >= len(ent):
                i = i + 1
                break
            nextc = ent[i + 1]
            if curc == "\\" and nextc == '"':
                i = i + 1
            elif curc == '"':
                quoted = not quoted
            i = i + 1

            options = ent[0:i]

            remain = ent[i:].lstrip()
            return (options, remain)

    def parse(self, src_line, options=None):
        line = src_line.rstrip("\r\n")
        if line.startswith("#") or line.strip() == '':
            return AuthKeyLine(src_line)

        def parse_ssh_key(ent):
            toks = ent.split(None, 2)
            if len(toks) < 2:
                raise TypeError("To few fields: %s" % len(toks))
            if toks[0] not in VALID_KEY_TYPES:
                raise TypeError("Invalid keytype %s" % toks[0])

            if len(toks) == 2:
                toks.append("")

            return toks

        ent = line.strip()
        try:
            (keytype, base64, comment) = parse_ssh_key(ent)
        except TypeError:
            (keyopts, remain) = self._extract_options(ent)
            if options is None:
                options = keyopts

            try:
                (keytype, base64, comment) = parse_ssh_key(remain)
            except TypeError:
                return AuthKeyLine(src_line)

        return AuthKeyLine(src_line, keytype=keytype, base64=base64,
                comment=comment, options=options)


def parse_authorized_keys(fname):
    lines = []
    try:
        if os.path.isfile(fname):
            with open(fname, 'r') as f:
                lines = f.readlines()
    except Exception as e:
        LOG.error("Error reading lines from %s (%s)" , fname, e)
        lines = []

    parser = AuthKeyLineParser()
    contents = []
    for line in lines:
        contents.append(parser.parse(line))
    return contents


def update_authorized_keys(old_entries, keys):
    to_add = list(keys)

    for i in range(0, len(old_entries)):
        ent = old_entries[i]
        if not ent.valid():
            continue
        for k in keys:
            if not ent.valid():
                continue
            if k.base64 == ent.base64:
                ent = k
                if k in to_add:
                    to_add.remove(k)
        old_entries[i] = ent

    for key in to_add:
        old_entries.append(key)

    lines = [str(b) for b in old_entries]

    lines.append('')
    return '\n'.join(lines)


def users_ssh_info(username):
    pw_ent = pwd.getpwnam(username)
    if not pw_ent or not pw_ent.pw_dir:
        raise RuntimeError("Unable to get ssh info for user %r" % (username))
    return (os.path.join(pw_ent.pw_dir, '.ssh'), pw_ent)


def extract_authorized_keys(username):
    (ssh_dir, pw_ent) = users_ssh_info(username)
    auth_key_fn = None
    try:
        ssh_cfg = parse_ssh_config_map(DEF_SSHD_CFG)
        auth_key_fn = ssh_cfg.get("authorizedkeysfile", '').strip()
        if not auth_key_fn:
            auth_key_fn = "%h/.ssh/authorized_keys"
        auth_key_fn = auth_key_fn.replace("%h", pw_ent.pw_dir)
        auth_key_fn = auth_key_fn.replace("%u", username)
        auth_key_fn = auth_key_fn.replace("%%", '%')
        if not auth_key_fn.startswith('/'):
            auth_key_fn = os.path.join(pw_ent.pw_dir, auth_key_fn)
    except (IOError, OSError):
        auth_key_fn = os.path.join(ssh_dir, 'authorized_keys')
        LOG.info("Failed extracting 'AuthorizedKeysFile' in ssh "
                "config from %r, using 'AuthorizedKeysFile' file "
                "%r instead", DEF_SSHD_CFG, auth_key_fn)
    return (auth_key_fn, parse_authorized_keys(auth_key_fn))


def setup_user_keys(keys, username, options=None):
    def ensure_dir(path, mode=None):
        if not os.path.isdir(path):
            os.makedirs(path)
            os.chmod(path, mode)
        else:
            os.chmod(path, mode)

    def chownbyid(fname, uid=None, gid=None):
        if uid in [None, -1] and gid in [None, -1]:
            return
        LOG.debug("Changing the ownership of %s to %s:%s", fname, uid, gid)
        os.chown(fname, uid, gid)

    def write_file(filename, content, mode=0o644):
        ensure_dir(os.path.dirname(filename), mode)
        try:
            mode_r = "%o" % mode
        except TypeError:
            mode_r = "%r" % mode
        LOG.debug("Writing to %s - [%s] %s", filename, mode_r, len(content))
        with open(filename, 'w') as fh:
            fh.write(content)
            fh.flush()
        os.chmod(filename, mode)

    (ssh_dir, pwent) = users_ssh_info(username)
    if not os.path.isdir(ssh_dir):
        ensure_dir(ssh_dir, mode=0o700)
        chownbyid(ssh_dir, pwent.pw_uid, pwent.pw_gid)

    parser = AuthKeyLineParser()
    key_entries = []
    for k in keys:
        key_entries.append(parser.parse(str(k), options=options))

    (auth_key_fn, auth_key_entries) = extract_authorized_keys(username)
    content = update_authorized_keys(auth_key_entries, key_entries)
    ensure_dir(os.path.dirname(auth_key_fn), mode=0o700)
    write_file(auth_key_fn, content, mode=0o600)
    chownbyid(auth_key_fn, pwent.pw_uid, pwent.pw_gid)


def usage():
    print('Usage: python set_ssh.py [username:base64]')

if __name__ == '__main__':
    LOG.info(sys.argv)
    try:
        arc = len(sys.argv)
        if arc == 2:
            parameters = sys.argv[1].split(':', 1)
            username = parameters[0]
            pubkey = []
            pubkey.append(parameters[1])
        else:
            raise Exception("arc isn't equl 2")
    except Exception as e:
        usage()
        LOG.error("parameters error(%s)", e)
        sys.exit(1)
    try:
        restart_ssh_daemon(username)
        setup_user_keys(pubkey, username)
    except Exception as e:
        LOG.error("FAILED, %s", e, exc_info = True)
        ret = 1
    else:
        LOG.info("SUCESS")
        ret = 0
    finally:
        sys.exit(ret)
