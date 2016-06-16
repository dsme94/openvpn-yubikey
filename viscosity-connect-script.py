#!/usr/bin/env python

import os
import subprocess
import sys
import time

def parse_cmdline(argv):
    conn_state, conn_names, yubi_token = argv[1], argv[2], None
    if conn_state == 'Connecting':
        yubi_token = argv[3]
    return conn_state, conn_names, yubi_token

def get_conn_index(conn_name):
    pref_dir = '/Users/%s/Library/Application Support/Viscosity/OpenVPN' % os.environ['USER']
    for index_dir in os.listdir(pref_dir):
        if not os.path.isdir(index_dir):
            continue
        conf = os.path.join(pref_dir, index_dir, 'config.conf')
        for line in open(conf, 'rb').readlines():
            if line.startswith('#viscosity name '):
                name = line[16:-1]
                if name == conn_name:
                    return index_dir

def get_password(index):
    key = 'Viscosity/%s/ovpn' % index
    cmd = ['/usr/bin/security', 'find-generic-password', '-ws', key, '-a', 'password']
    password = subprocess.check_output(cmd).strip()
    if len(password) > 44:
        password = password[:-44]
    return password

def set_password(index, password):
    key = 'Viscosity/%s/ovpn' % index
    cmd = ['/usr/bin/security', 'add-generic-password', '-Us', key, '-a', 'password', '-w', password]
    out = subprocess.check_output(cmd)
    print out

def main(argv):
    conn_state, conn_name, yubi_token = parse_cmdline(argv)
    index = get_conn_index(conn_name)
    if conn_state == 'Connecting':
        password = get_password(index)
        assert len(password) < 44
        set_password(index, password + yubi_token)
    elif conn_state in ('Connected', 'Disconnecting'):
        password = get_password(index)
        assert len(password) < 44
        set_password(index, password)

if __name__ == '__main__':
    main(sys.argv)

