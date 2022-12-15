#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import argparse
import MySQLdb


if __name__ == '__main__':


    parser = argparse.ArgumentParser(
        description="""
        """,
        usage="""
        """,
#        epilog="version {}, copyright {}".format(__version__, __copyright__)
    )
    parser.add_argument('--contract', type=str, required=True, help='SCC contract')
    parser.add_argument('--site', type=str, required=True, help='SCC site')
    parser.add_argument('--equipment', type=str, required=True, help='equipement (hostname)')
    parser.add_argument('--service', type=str, required=True, help='service name')
    parser.add_argument('--table', type=str, required=True, help='Ged table')
    args = parser.parse_args()

    sqlcnx = {
        'unix_socket': '/var/lib/mysql/mysql.sock',
        'user': '',
        'passwd': '',
        'db': 'ged',
    }
    with open('/srv/rgm/ged/etc/bkd/gedmysql.cfg', 'r') as h:
        for line in h.readlines():
            l = line.strip().split()
            if len(l)  != 2:
                continue
            elif l[0] == 'mysql_login' and len(l[1]) > 0:
                sqlcnx['user'] = l[1]
            elif l[0] == 'mysql_password' and len(l[1]) > 0:
                sqlcnx['passwd'] = l[1]
    sql = MySQLdb.connect(**sqlcnx)

    cur = sql.cursor(MySQLdb.cursors.Cursor)
    req = "SELECT id, queue, state, description FROM {table} WHERE contract='{contract}' AND site='{site}' AND equipment='{equipment}' AND service='{service}'".format(
        table = args.table + '_queue_active',
        contract = args.contract,
        site = args.site,
        equipment = args.equipment,
        service = args.service,
    )
    cur.execute(req)
    res = cur.fetchall()

    l = len(res)
    rc = 3
    if l == 0:
        print("UNKNOWN - No entry found in ged table '{table}' for contract '{contract}' site '{site}' host '{equipment}' service '{service}'".format(
            table = args.table,
            contract = args.contract,
            site = args.site,
            equipment = args.equipment,
            service = args.service,
        ))
    elif l > 1:
        print("UNKNOWN - Multiple entries found in ged table '{table}' for contract '{contract}' site '{site}' host '{equipment}' service '{service}'".format(
            table = args.table,
            contract = args.contract,
            site = args.site,
            equipment = args.equipment,
            service = args.service,
        ))
    else:
        (id, queue, rc, description) = res[0]
        print(description)
    cur.close()

    sys.exit(rc)
