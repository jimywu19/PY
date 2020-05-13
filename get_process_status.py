# -*- coding: utf-8 -*-
import os
import sys

PY3 = sys.version_info[0] == 3
if PY3:
    FS_ENCODING = sys.getfilesystemencoding()
    ENCODING_ERRORS_HANDLER = 'surrogateescape'
if PY3:
    def decode(s):
        return s.decode(encoding=FS_ENCODING, errors=ENCODING_ERRORS_HANDLER)
else:
    def decode(s):
        return s
if PY3:
    def b(s):
        return s.encode("latin-1")
else:
    def b(s):
        return s.encode()

PROCFS_PATH = "/proc"
PROC_STATUSES = {
    "R": "running",
    "S": "sleeping",
    "D": "disk-sleep",
    "T": "stopped",
    "t": "tracing-stop",
    "Z": "zombie",
    "X": "dead",
    "x": "dead",
    "K": "wake-kill",
    "W": "waking"
}

def open_binary(fname, **kwargs):
    return open(fname, "rb", **kwargs)

def open_text(fname, **kwargs):
    """On Python 3 opens a file in text mode by using fs encoding and
    a proper en/decoding errors handler.
    On Python 2 this is just an alias for open(name, 'rt').
    """
    if PY3:
        kwargs.setdefault('encoding', FS_ENCODING)
        kwargs.setdefault('errors', ENCODING_ERRORS_HANDLER)
    return open(fname, "rt", **kwargs)

def get_pids():
    """Returns a list of PIDs currently running on the system."""
    return [int(x) for x in os.listdir(b(PROCFS_PATH)) if x.isdigit()]

def parse_stat_file(pid):
    with open_binary("%s/%s/stat" % (PROCFS_PATH, pid)) as f:
        data = f.read()
    # Process name is between parentheses. It can contain spaces and
    # other parentheses. This is taken into account by looking for
    # the first occurrence of "(" and the last occurence of ")".
    rpar = data.rfind(b')')
    name = data[data.find(b'(') + 1:rpar]
    fields_after_name = data[rpar + 2:].split()
    return [name] + fields_after_name

def get_name(pid):
    name = parse_stat_file(pid)[0]
    if PY3:
        name = decode(name)
    # XXX - gets changed later and probably needs refactoring
    return name

def get_cmdline(pid):
    with open_text("%s/%s/cmdline" % (PROCFS_PATH, pid)) as f:
        data = f.read()
    if not data:
        # may happen in case of zombie process
        return []
    if data.endswith('\x00'):
        data = data[:-1]
    return [x for x in data.split('\x00')]

def get_status(pid):
    letter = parse_stat_file(pid)[1]
    if PY3:
        letter = letter.decode()
    # XXX is '?' legit? (we're not supposed to return it anyway)
    return PROC_STATUSES.get(letter, '?')

def get_process_status(name):
    result = []
    for pid in get_pids():
        prostr = ''
        try:
            name_pid = get_name(pid)
        except:
            pass
        else:
            if name_pid == name:
                prostr = "pid:%s,state:%s,process:%s"%(pid, get_status(pid), name)
                result.append(prostr)
                continue

        try:
            cmdline_pid = get_cmdline(pid)
        except:
            pass
        else:
            if cmdline_pid and cmdline_pid[0] == name:
                prostr = "pid:%s,state:%s,process:%s"%(pid, get_status(pid), cmdline_pid[0])
                result.append(prostr)
    return result

def usage():
    print('Usage: get_process_status.py <process name|path>')
    sys.exit(1)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        usage()
    else:
        namelist = sys.argv[1].split(',')
    statuslist = []
    for name in namelist:
        if len(name) == 0:
            continue
        prostr = ''
        result = get_process_status(name)
        if len(result) != 0:
            pass
        else:
            prostr = "pid:-1,state:unknown,process:%s" % (name)
            result.append(prostr)
        statuslist += result
    #output
    for status in statuslist:
        print(status)
    sys.exit(0)
