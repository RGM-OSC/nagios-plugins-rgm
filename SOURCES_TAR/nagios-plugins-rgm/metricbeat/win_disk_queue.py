#!/usr/bin/env python3
# -*- coding: utf-8 -*-

'''
DESCRIPTION : Nagios plugin to retrieve logical and physical disks average queue size
from ES Metricbeat for Windows systems.

AUTHOR : Lucas Fueyo <lfueyo@fr.scc.com>
'''

__author__ = 'Lucas Fueyo'
__copyright__ = '2020, SCC'
__credits__ = ['Lucas Fueyo']
__license__ = 'GPL'
__version__ = '0.1.0'
__maintainer__ = 'Lucas Fueyo'


import sys
import logging
import rgmbeat
from datetime import datetime
import dateutil.parser
from dateutil.tz import tzlocal

import elasticsearch_dsl
from elasticsearch_dsl import Q


NagiosRetCode = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')

escnx = None


if __name__ == '__main__':

    rc = 3

    #parser = argparse.ArgumentParser(
    parser = rgmbeat.RGMArgumentParser(
        description="""
        Nagios plugin used to return logical and physical disks average queue size from ElasticSearch for Windows machines.
        This plugin return the value of latest metricbeat documents pushed by client.
        """,
        usage="""
        """,
        epilog="version {}, copyright {}".format(__version__, __copyright__)
    )
    parser.add_argument('-H', '--hostname', type=str, help='hostname or IP address', required=True)
    parser.add_argument('-w', '--warning', type=int, nargs='?', help='warning trigger', default=5)
    parser.add_argument('-c', '--critical', type=int, nargs='?', help='critical trigger', default=10)
    parser.add_argument('-t', '--timeout', type=int, help='data validity timeout (in minutes)', default=5)
    parser.add_argument(
        '-E', '--elastichost', type=str, help='connection URL of ElasticSearch server',
        default="localhost:9200"
    )
    args = parser.parse_args()

    escnx = elasticsearch_dsl.connections.create_connection(hosts=[args.elastichost], timeout=20)
    # construct an Elasticsearch DSL Search() object, using Q() shortcuts to build the query
    request = elasticsearch_dsl.Search(using=escnx, index="metricbeat-*", doc_type='_doc')
    request = request.query(
        'bool', must=[
            'match_all',
            # as Q shortcut doesn't support nested keywords (eg. 'agent.type' for instance)
            # we must provide keywords as kwargs dict type
            Q('match', **{'agent.type': 'metricbeat'}),
            Q('match', **{'host.name': args.hostname}),
            Q('exists', **{'field': 'windows.perfmon.*_disk.average_queue_length'})
        ]
    )

    request.aggs.bucket('most_recent', 'max', field='@timestamp')
    # we'll output 'windows.perfmon.*_disk.average_queue_length' and '@timestamp' fields
    request = request.source(['@timestamp', 'windows.perfmon.logical_disk.name', 'windows.perfmon.logical_disk.average_queue_length', 'windows.perfmon.physical_disk.name', 'windows.perfmon.physical_disk.average_queue_length'])
    # sorting by '@timestamp', latest at first
    request = request.sort({'@timestamp': {'order': 'desc', 'unmapped_type': 'boolean'}})
    # we return only the first result
    request = request[0:40]
    # execute request on ES server
    response = request.execute()
    # we loop on our response and retrieve only the latest timestamp
    response = [i for i in response if i['@timestamp'] == response['aggregations']['most_recent']['value_as_string']]

    if len(response) > 0:
        rc = 0
        outtext = []
        outdisks = {}
        outdisks['logical_disk'] = []
        outdisks['physical_disk'] = []
        sortedlogical_disks = []
        sortedphysical_disks = []
        total_disks_warn = 0

        esdate = dateutil.parser.parse(response[0]['@timestamp'])
        now = datetime.now(tzlocal())
        delta = (now - esdate).total_seconds() / 60

        if(delta > args.timeout):
            print("Latest data was too old for processing - older than " + str(args.timeout) + " minutes.")
            sys.exit(3)

        for line in response:
            if('logical_disk' in line['windows']['perfmon']):
                disktype = 'logical_disk'
            else:
                disktype = 'physical_disk'

            disk_name = line['windows']['perfmon'][disktype]['name']
            disk_queue = line['windows']['perfmon'][disktype]['average_queue_length']

            if disk_queue < args.warning:
                disk_rc = 0
            elif disk_queue < args.critical:
                disk_rc = 1
                total_disks_warn += 1
                if rc == 0:
                    rc = 1
            else:
                disk_rc = 2
                total_disks_warn += 1
                rc = 2

            outdisks[disktype].append(
                "\n {state} - Disk Name : {DiskName} - Average Queue Size : {Queue} ".format(
                    state=NagiosRetCode[disk_rc],
                    DiskName=disk_name,
                    Queue=disk_queue
                )
            )

        outtext.append(
            "{total_disks_warn} disks in warning or critical state".format(
                total_disks_warn=total_disks_warn
            )
        )

        for line in outdisks['logical_disk']:
            if 'CRITICAL' in line:
                sortedlogical_disks.append(line)
        for line in outdisks['logical_disk']:
            if 'WARNING' in line:
                sortedlogical_disks.append(line)
        for line in outdisks['logical_disk']:
            if 'OK' in line:
                sortedlogical_disks.append(line)

        for line in outdisks['physical_disk']:
            if 'CRITICAL' in line:
                sortedphysical_disks.append(line)
        for line in outdisks['physical_disk']:
            if 'WARNING' in line:
                sortedphysical_disks.append(line)
        for line in outdisks['physical_disk']:
            if 'OK' in line:
                sortedphysical_disks.append(line)

        print(
            "{}: {}\n\
                Physical Disks : {}\n\
                Logical Disks : {}".format(
                    NagiosRetCode[rc],
                    " ".join(outtext),
                    " ".join(sortedphysical_disks),
                    " ".join(sortedlogical_disks)
            )
        )
    else:
        print("{}: failed to retrieve interfaces queue length information".format(NagiosRetCode[rc]))

    sys.exit(rc)
