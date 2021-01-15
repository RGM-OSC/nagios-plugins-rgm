#!/usr/bin/env python3
# -*- coding: utf-8 -*-

'''
DESCRIPTION : Nagios plugin to retrieve disk average queue size from ES Metricbeat for Linux machines.

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
        Nagios plugin used to return disk average queue size from ElasticSearch for Linux machines.
        This plugin return the value of latest metricbeat document pushed by client.
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
            Q('exists', **{'field': 'system.diskio.iostat.queue.avg_size'})
        ]
    )
    # we'll output 'system.diskio.iostat.queue.avg_size' and '@timestamp' fields
    request = request.source(['@timestamp', 'system.diskio.iostat.queue.avg_size'])
    # sorting by '@timestamp', latest at first
    request = request.sort({'@timestamp': {'order': 'desc', 'unmapped_type': 'boolean'}})
    # we return only the first result
    request = request[0]
    # execute request on ES server
    response = request.execute()

    if len(response) > 0:
        esdate = dateutil.parser.parse(response[0]['@timestamp'])
        now = datetime.now(tzlocal())
        delta = (now - esdate).total_seconds() / 60

        if(delta > args.timeout):
            print("Latest data was too old for processing - older than " + str(args.timeout) + " minutes.")
            sys.exit(3)

        esqueue = response[0]['system']['diskio']['iostat']['queue']['avg_size']

        queue_length = "disk average queue length: {}".format(int(esqueue))
        if esqueue < args.warning:
            rc = 0
        elif esqueue < args.critical:
            rc = 1
        else:
            rc = 2
        print(
            "{rc}: {queue_length}".format(
                rc=NagiosRetCode[rc],
                queue_length=queue_length
            )
        )
    else:
        print("{}: failed to retrieve disk average queue length information".format(NagiosRetCode[rc]))

    sys.exit(rc)
