#!/srv/rgm/python-rgm/bin/python3
# -*- coding: utf-8 -*-

__author__ = 'Eric Belhomme'
__copyright__ = '2021, SCC'
__credits__ = [__author__]
__license__ = 'GPL'
__version__ = '0.1'
__maintainer__ = __author__


import sys, argparse, re, yaml
import subprocess

import pprint
pp = pprint.PrettyPrinter()


def exec_tctl(args: list):
    tctl = subprocess.run(
        ['sudo', '/usr/local/bin/tctl'] + args,
        stdout=subprocess.PIPE
    )
    return (tctl.returncode, tctl.stdout.decode('utf8'))


def get_pattern(message, pattern):
    regex = re.compile(pattern)
    for line in message:
        match = regex.match(line)
        if match:
            return match.group(1)
    return None


def check_teleport_status():
    msg = ''
    return exec_tctl(['status'])


def check_teleport_trusted_cluster():
    msg = ''
    rc, stdout = exec_tctl(['get', 'tc'])
    if rc != 0:
        return (3, 'UNKNOWN: Unable to access dial Teleport daemon')
    elif len(stdout) == 0:
        return (2, 'CRITICAL: no trusted cluster registered')
    else:
        yml = yaml.safe_load(stdout)
        if not yml['spec']['enabled']:
            rc = 1
            status = 'WARNING'
        else:
            status = 'OK'
        msg = "{}: trusted cluster to root '{}' (https://{}) enabled".format(
            status,
            yml['metadata']['name'],
            yml['spec']['web_proxy_addr']
        )

    return (rc, msg)


if __name__ == '__main__':

    parser = argparse.ArgumentParser(
        description="Nagios plugin For Teleport (https://goteleport.com)",
        usage="",
        epilog="version {}, copyright {}".format(__version__, __copyright__)
    )

    parser.add_argument(
        '-m', '--mode', type=str, required=True,
        choices=['status', 'trusted_cluster'],
        help='Operational mode'
    )

    args = parser.parse_args()

    rc = 2
    msg = 'UNKNOWN mode requested'
    if args.mode == 'status':
        (rc, msg) = check_teleport_status()
        if rc != 0:
            msg = 'OK: Teleport daemon is stopped'
            rc = 0
        else:
            cluster = get_pattern(msg.splitlines(), r'.*^Cluster\s+([-_\.\w\d]+)\s*$')
            version = get_pattern(msg.splitlines(), r'.*^Version\s+([\.\d]+)\s*$')
            msg = "OK: Teleport cluster '{}' version {} up and running".format(cluster, version)

    elif args.mode == 'trusted_cluster':
        (rc, msg) = check_teleport_status()
        if rc == 0:
            (rc, msg) = check_teleport_trusted_cluster()
        else:
            msg = 'OK: Teleport daemon is stopped'
            rc = 0

    print(msg)
    sys.exit(rc)

# EOF
